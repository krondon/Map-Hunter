import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:geolocator/geolocator.dart';
import '../providers/player_provider.dart';
import '../../../shared/models/player.dart';
import '../../../core/theme/app_theme.dart';
import 'register_screen.dart';
import '../../game/screens/scenarios_screen.dart';
import '../../game/screens/game_request_screen.dart';
import '../../layouts/screens/home_screen.dart';
import '../../admin/screens/dashboard-screen.dart';
import '../../../shared/widgets/animated_cyber_background.dart';
import '../../../core/utils/error_handler.dart';
import '../../game/providers/connectivity_provider.dart';
import '../../game/providers/game_provider.dart';
import 'dart:async'; // For TimeoutException
import 'dart:math' as math;


class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> with TickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isPasswordVisible = false;
  late AnimationController _shimmerTitleController;

  @override
  void initState() {
    super.initState();
    _shimmerTitleController = AnimationController(
      duration: const Duration(milliseconds: 2500),
      vsync: this,
    )..repeat();
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _shimmerTitleController.dispose();
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final playerProvider = Provider.of<PlayerProvider>(context, listen: false);
    if (playerProvider.banMessage != null) {
      final msg = playerProvider.banMessage!;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(msg),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
          ),
        );
        playerProvider.clearBanMessage();
      });
    }
  }

  Future<void> _handleLogin() async {
    if (_formKey.currentState!.validate()) {
      try {
        final playerProvider = Provider.of<PlayerProvider>(context, listen: false);
        final gameProvider = Provider.of<GameProvider>(context, listen: false);

        // Show loading indicator
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => const Center(child: CircularProgressIndicator()),
        );

        await playerProvider.login(
            _emailController.text.trim(), _passwordController.text);

        if (!mounted) return;
        Navigator.pop(context); // Dismiss loading

        // Verificar estado del usuario
        final player = playerProvider.currentPlayer;
        if (player == null) {
          if (playerProvider.banMessage != null) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(playerProvider.banMessage!),
                backgroundColor: Colors.red,
              ),
            );
            playerProvider.clearBanMessage();
          }
          return;
        }

        // Administradores van directamente al Dashboard
        if (player.role == 'admin') {
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (_) => const DashboardScreen()),
          );
          return;
        }

        // Solicitar permisos de ubicación antes de navegar
        await _checkPermissions();
        if (!mounted) return;

        // Iniciar monitoreo de conectividad
        context.read<ConnectivityProvider>().startMonitoring();

        // === GATEKEEPER: Verificar estado del usuario respecto a eventos ===
        debugPrint('LoginScreen: Checking user event status...');
        final statusResult = await gameProvider
            .checkUserEventStatus(player.userId)
            .timeout(const Duration(seconds: 10), onTimeout: () {
              throw TimeoutException('La verificación de estado tardó demasiado');
            });
        debugPrint('LoginScreen: User status is ${statusResult.status}');

        if (!mounted) return;

        switch (statusResult.status) {
          // === CASOS DE BLOQUEO ===
          case UserEventStatus.banned:
            // Usuario baneado - cerrar sesión y mostrar mensaje
            await playerProvider.logout();
            if (!mounted) return;
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Tu cuenta ha sido suspendida.'),
                backgroundColor: Colors.red,
              ),
            );
            break;

          case UserEventStatus.waitingApproval:
            // Usuario esperando aprobación - ir a lista de escenarios
             Navigator.of(context).pushReplacement(
              MaterialPageRoute(builder: (_) => const ScenariosScreen()),
            );
            break;

          // === CASOS DE FLUJO ABIERTO ===
          // El usuario siempre va al catálogo donde puede elegir entrar al evento
          case UserEventStatus.inGame:
          case UserEventStatus.readyToInitialize:
          case UserEventStatus.rejected:
          case UserEventStatus.noEvent:
            Navigator.of(context).pushReplacement(
              MaterialPageRoute(builder: (_) => const ScenariosScreen()),
            );
            break;
        }
      } catch (e) {
        if (!mounted) return;
        Navigator.pop(context); // Dismiss loading

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.error_outline, color: Colors.white),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    ErrorHandler.getFriendlyErrorMessage(e),
                    style: const TextStyle(fontWeight: FontWeight.w500),
                  ),
                ),
              ],
            ),
            backgroundColor: AppTheme.dangerRed,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            margin: const EdgeInsets.all(20),
            duration: const Duration(seconds: 4),
          ),
        );
      }
    }
  }

  Future<void> _showForgotPasswordDialog() async {
    final emailController = TextEditingController(text: _emailController.text);
    final formKey = GlobalKey<FormState>();
    bool isSending = false;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: AppTheme.cardBg,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Text(
            'Recuperar Contraseña',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
          ),
          content: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Ingresa tu email y te enviaremos un enlace para restablecer tu contraseña.',
                  style: TextStyle(color: Colors.white70),
                ),
                const SizedBox(height: 20),
                TextFormField(
                  controller: emailController,
                  style: const TextStyle(color: Colors.white),
                  decoration: const InputDecoration(
                    labelText: 'Email',
                    prefixIcon: Icon(Icons.email_outlined),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) return 'Ingresa tu email';
                    if (!value.contains('@')) return 'Email inválido';
                    return null;
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: isSending ? null : () => Navigator.pop(context),
              child: const Text('CANCELAR', style: TextStyle(color: Colors.white60)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryPurple,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              onPressed: isSending
                  ? null
                  : () async {
                      if (formKey.currentState!.validate()) {
                        setDialogState(() => isSending = true);
                        try {
                          await context
                              .read<PlayerProvider>()
                              .resetPassword(emailController.text.trim());
                          if (!mounted) return;
                          Navigator.pop(context);
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Enlace enviado. Revisa tu correo.'),
                              backgroundColor: AppTheme.accentGold,
                            ),
                          );
                        } catch (e) {
                          setDialogState(() => isSending = false);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(ErrorHandler.getFriendlyErrorMessage(e)),
                              backgroundColor: AppTheme.dangerRed,
                            ),
                          );
                        }
                      }
                    },
              child: isSending
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Text('ENVIAR'),
            ),
          ],
        ),
      ),
    );
  }


  Future<void> _checkPermissions() async {
    LocationPermission permission = await Geolocator.checkPermission();
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();

    // Si falta algo, mostramos el BottomSheet explicativo antes de pedirlo nativamente
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever ||
        !serviceEnabled) {
      if (mounted) {
        await showModalBottomSheet(
          context: context,
          isDismissible: false,
          enableDrag: false,
          backgroundColor: AppTheme.cardBg,
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          builder: (context) => Container(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.location_on_outlined,
                    size: 60, color: AppTheme.accentGold),
                const SizedBox(height: 16),
                const Text(
                  'Ubicación Necesaria',
                  style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.white),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Para encontrar los tesoros ocultos, necesitamos acceder a tu ubicación.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.white70),
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.accentGold,
                      foregroundColor: Colors.black,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    onPressed: () async {
                      Navigator.pop(context);
                      await _requestNativePermissions();
                    },
                    child: const Text('ACTIVAR UBICACIÓN',
                        style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ),
                // === BOTÓN DE DESARROLLADOR ===
                if (true) ...[
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.orange,
                        side: const BorderSide(color: Colors.orange),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      onPressed: () {
                        Navigator.pop(context); // Solo cierra sin pedir permiso
                      },
                      icon: const Icon(Icons.developer_mode),
                      label: const Text('DEV: Saltar Permisos'),
                    ),
                  ),
                ],
              ],
            ),
          ),
        );
      }
    } else {
      // Si ya tiene todo, solo verificamos por seguridad
      await _requestNativePermissions();
    }
  }

  Future<void> _requestNativePermissions() async {
    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }

    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      try {
        await Geolocator.getCurrentPosition(
            timeLimit: const Duration(seconds: 2));
      } catch (_) {}
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: AnimatedCyberBackground(
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24.0),
                  child: AutofillGroup( // Wrap with AutofillGroup for native support
                    child: Form(
                      key: _formKey,
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          // Título Animado
                          AnimatedBuilder(
                            animation: _shimmerTitleController,
                            builder: (context, child) {
                              return ShaderMask(
                                shaderCallback: (bounds) {
                                  return LinearGradient(
                                    colors: const [
                                      Colors.white,
                                      AppTheme.accentGold,
                                      Colors.white,
                                      AppTheme.accentGold,
                                      Colors.white,
                                    ],
                                    stops: const [0.0, 0.3, 0.5, 0.7, 1.0],
                                    begin: Alignment(-1.0 + (_shimmerTitleController.value * 2.0), -0.5),
                                    end: Alignment(1.0 + (_shimmerTitleController.value * 2.0), 0.5),
                                    tileMode: TileMode.clamp,
                                  ).createShader(bounds);
                                },
                                child: const _GlitchText(
                                  text: 'MAPHUNTER',
                                  style: TextStyle(
                                    fontSize: 32,
                                    fontWeight: FontWeight.w900,
                                    color: Colors.white,
                                    letterSpacing: 4,
                                  ),
                                ),
                              );
                            },
                          ),
                          const SizedBox(height: 20),

                          // Logo con imagen personalizada (Agrandado para llenar el espacio)
                          Container(
                            width: 180, // Aumentado de 140
                            height: 180, // Aumentado de 140
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: AppTheme.primaryPurple.withOpacity(0.4),
                                  blurRadius: 35,
                                  spreadRadius: 5,
                                ),
                              ],
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(90),
                              child: Transform.scale(
                                scale: 1.5, // Zoom para eliminar el padding que pusimos para el icono APK
                                child: Image.asset(
                                  'assets/images/logo.png',
                                  fit: BoxFit.cover,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 30),

                          // Subtítulo
                          Text(
                            'BIENVENIDO',
                            style: Theme.of(context).textTheme.displayLarge?.copyWith(
                              fontSize: 18,
                              letterSpacing: 2,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Inicia tu aventura',
                            style: Theme.of(context).textTheme.bodyLarge,
                          ),
                          const SizedBox(height: 50),

                          // Email field
                          TextFormField(
                            controller: _emailController,
                            keyboardType: TextInputType.emailAddress,
                            textInputAction: TextInputAction.next, // Improve flow
                            autofillHints: const [AutofillHints.email], // Native Autofill
                            style: const TextStyle(color: Colors.white),
                            decoration: const InputDecoration(
                              labelText: 'Email',
                              labelStyle: TextStyle(color: Colors.white60),
                              prefixIcon:
                                  Icon(Icons.email_outlined, color: Colors.white60),
                            ),
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'Ingresa tu email';
                              }
                              if (!value.contains('@')) {
                                return 'Email inválido';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 20),

                          // Password field
                          TextFormField(
                            controller: _passwordController,
                            obscureText: !_isPasswordVisible,
                            textInputAction: TextInputAction.done, // Trigger submission/save
                            autofillHints: const [AutofillHints.password], // Native Autofill
                            onEditingComplete: _handleLogin, // Submit on Enter
                            style: const TextStyle(color: Colors.white),
                            decoration: InputDecoration(
                              labelText: 'Contraseña',
                              labelStyle: const TextStyle(color: Colors.white60),
                              prefixIcon: const Icon(Icons.lock_outline,
                                  color: Colors.white60),
                              suffixIcon: IconButton(
                                icon: Icon(
                                  _isPasswordVisible
                                      ? Icons.visibility
                                      : Icons.visibility_off,
                                  color: Colors.white60,
                                ),
                                onPressed: () {
                                  setState(() {
                                    _isPasswordVisible = !_isPasswordVisible;
                                  });
                                },
                              ),
                            ),
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'Ingresa tu contraseña';
                              }
                              if (value.length < 6) {
                                return 'Mínimo 6 caracteres';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 10),
                          Align(
                            alignment: Alignment.centerRight,
                            child: TextButton(
                              onPressed: _showForgotPasswordDialog,
                              child: const Text(
                                '¿Olvidaste tu contraseña?',
                                style: TextStyle(
                                  color: Colors.white70,
                                  fontSize: 14,
                                ),
                              ),
                            ),
                          ),
                    const SizedBox(height: 20),

                    // Login button
                    SizedBox(
                      width: double.infinity,
                      height: 56,
                      child: Container(
                        decoration: BoxDecoration(
                          gradient: AppTheme.primaryGradient,
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(
                              color: AppTheme.primaryPurple.withOpacity(0.4),
                              blurRadius: 20,
                              offset: const Offset(0, 10),
                            ),
                          ],
                        ),
                        child: ElevatedButton(
                          onPressed: _handleLogin,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.transparent,
                            shadowColor: Colors.transparent,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: const Text(
                            'INICIAR SESIÓN',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 1.2,
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Register link
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          '¿No tienes cuenta? ',
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                        TextButton(
                          onPressed: () {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                  builder: (_) => const RegisterScreen()),
                            );
                          },
                          child: const Text(
                            'Regístrate',
                            style: TextStyle(
                              color: AppTheme.secondaryPink,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    ),
    );
  }
}

class _GlitchText extends StatefulWidget {
  final String text;
  final TextStyle style;

  const _GlitchText({required this.text, required this.style});

  @override
  State<_GlitchText> createState() => _GlitchTextState();
}

class _GlitchTextState extends State<_GlitchText> with SingleTickerProviderStateMixin {
  late AnimationController _glitchController;
  late String _displayText;
  final String _chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789!@#\$%^&*';
  Timer? _decodeTimer;
  int _decodeIndex = 0;

  @override
  void initState() {
    super.initState();
    _displayText = '';
    _startDecoding();

    _glitchController = AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 2000)
    )..repeat();
  }

  void _startDecoding() {
    _decodeTimer = Timer.periodic(const Duration(milliseconds: 50), (timer) {
      if (_decodeIndex >= widget.text.length) {
        timer.cancel();
        setState(() => _displayText = widget.text);
        return;
      }

      setState(() {
        _displayText = String.fromCharCodes(Iterable.generate(widget.text.length, (index) {
          if (index < _decodeIndex) return widget.text.codeUnitAt(index);
          return _chars.codeUnitAt(math.Random().nextInt(_chars.length));
        }));
        _decodeIndex++;
      });
    });
  }

  @override
  void dispose() {
    _glitchController.dispose();
    _decodeTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _glitchController,
      builder: (context, child) {
        final double glitchValue = _glitchController.value;
        final bool isGlitching = glitchValue > 0.90 && glitchValue < 0.95;
        
        double offsetX = 0;
        double offsetY = 0;
        
        if (isGlitching) {
          offsetX = (math.Random().nextDouble() - 0.5) * 5;
          offsetY = (math.Random().nextDouble() - 0.5) * 5;
        }

        return Stack(
          children: [
            if (isGlitching)
              Transform.translate(
                offset: Offset(offsetX + 2, offsetY),
                child: Text(
                  _displayText,
                  style: widget.style.copyWith(color: Colors.red.withOpacity(0.8)),
                ),
              ),
            if (isGlitching)
              Transform.translate(
                offset: Offset(offsetX - 2, offsetY),
                child: Text(
                  _displayText,
                  style: widget.style.copyWith(color: Colors.blue.withOpacity(0.8)),
                ),
              ),
            Transform.translate(
              offset: Offset(offsetX, offsetY),
              child: Text(
                _displayText,
                style: widget.style,
              ),
            ),
          ],
        );
      },
    );
  }
}