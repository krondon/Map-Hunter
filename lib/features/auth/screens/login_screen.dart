import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:geolocator/geolocator.dart';
import '../providers/player_provider.dart';
import '../../../shared/models/player.dart';
import '../../../core/theme/app_theme.dart';
import 'register_screen.dart';
import 'avatar_selection_screen.dart';
import '../../game/screens/scenarios_screen.dart';
import '../../game/screens/game_request_screen.dart';
import '../../game/screens/game_mode_selector_screen.dart';
import '../../layouts/screens/home_screen.dart';
import '../../admin/screens/dashboard-screen.dart';
import '../../../shared/widgets/animated_cyber_background.dart';
import '../../../core/utils/error_handler.dart';
import '../../game/providers/connectivity_provider.dart';
import '../../game/providers/game_provider.dart';
import 'dart:async'; // For TimeoutException
import 'dart:math' as math;
import '../../../shared/widgets/loading_overlay.dart';
import '../../../shared/widgets/loading_indicator.dart';


class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> with TickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _emailFocus = FocusNode();
  final _passwordFocus = FocusNode();

  bool _isPasswordVisible = false;
  bool _isLoggingIn = false;
  late AnimationController _shimmerTitleController;

  @override
  void initState() {
    super.initState();
    
    // Asegurar modo inmersivo al cargar login
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    
    _shimmerTitleController = AnimationController(
      duration: const Duration(milliseconds: 2500),
      vsync: this,
    )..repeat();
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _emailFocus.dispose();
    _passwordFocus.dispose();

    _shimmerTitleController.dispose();
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    
    // Precargar ambas imágenes de fondo para transiciones suaves
    precacheImage(const AssetImage('assets/images/hero.png'), context);
    precacheImage(const AssetImage('assets/images/loginclaro.png'), context);
    
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
    if (_isLoggingIn) return; // Prevent double-tap
    if (!_formKey.currentState!.validate()) return;

      // 1. Unfocus specific fields
      _emailFocus.unfocus();
      _passwordFocus.unfocus();
      
      // 2. Kill any active focus in the scope
      FocusScope.of(context).requestFocus(FocusNode());
      
      // 3. Force system hide (just to be sure)
      SystemChannels.textInput.invokeMethod('TextInput.hide'); 

      // Force autofill save before processing login
      TextInput.finishAutofillContext(shouldSave: true);

    setState(() => _isLoggingIn = true);

      try {
        final playerProvider = Provider.of<PlayerProvider>(context, listen: false);
        final gameProvider = Provider.of<GameProvider>(context, listen: false);
        final isDarkMode = playerProvider.isDarkMode;

        // Show loading indicator
        LoadingOverlay.show(context);

        await playerProvider.login(
            _emailController.text.trim().toLowerCase(), _passwordController.text);

        if (!mounted) return;
        LoadingOverlay.hide(context); // Dismiss loading
        SystemChannels.textInput.invokeMethod('TextInput.hide'); // Force keyboard close again



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

        // === NUEVO CHEQUEO DE AVATAR ===
        // Si el usuario no tiene avatar O tiene uno inválido, lo mandamos a seleccionarlo
        final currentAvatar = player.avatarId;
        final isValidAvatar = currentAvatar != null && 
                              currentAvatar.isNotEmpty && 
                              AvatarSelectionScreen.validAvatarIds.contains(currentAvatar);

        if (!isValidAvatar) {
             Navigator.of(context).pushReplacement(
              MaterialPageRoute(builder: (_) => const AvatarSelectionScreen(eventId: null)),
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
            // Usuario esperando aprobación - ir a selector de modo
             Navigator.of(context).pushReplacement(
              MaterialPageRoute(builder: (_) => const GameModeSelectorScreen()),
            );
            break;

          // === CASOS DE FLUJO ABIERTO ===
          // El usuario siempre va al selector de modo
          case UserEventStatus.inGame:
          case UserEventStatus.readyToInitialize:
          case UserEventStatus.rejected:
          case UserEventStatus.noEvent:
            Navigator.of(context).pushReplacement(
              MaterialPageRoute(builder: (_) => const GameModeSelectorScreen()),
            );
            break;
        }
      } catch (e) {
        if (!mounted) return;
        LoadingOverlay.hide(context); // Dismiss loading

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
      } finally {
        if (mounted) setState(() => _isLoggingIn = false);
      }
  }

  Future<void> _showForgotPasswordDialog() async {
    final emailController = TextEditingController(text: _emailController.text);
    final formKey = GlobalKey<FormState>();
    bool isSending = false;

    // Colores definidos localmente para asegurar consistencia
    const Color dSurface1 = Color(0xFF1A1A1D);
    const Color dGoldMain = Color(0xFFFECB00);
    const Color dGoldLight = Color(0xFFFFF176);
    const Color lSurface1 = Color(0xFFFFFFFF);
    const Color lTextPrimary = Color(0xFF1A1A1D);
    const Color lTextSecondary = Color(0xFF4A4A5A);
    const Color lMysticPurple = Color(0xFF5A189A);

    await showDialog(
      context: context,
      builder: (context) {
        final isDarkMode = context.read<PlayerProvider>().isDarkMode;
        bool isSending = false;

        return StatefulBuilder(
          builder: (context, setDialogState) {
            // Forzar colores de modo oscuro para el modal
            const Color currentSurface = dSurface1;
            const Color currentText = Colors.white;
            const Color currentTextSec = Colors.white70;
            const Color currentBrand = dGoldMain;

            return AlertDialog(
              backgroundColor: currentSurface,
              surfaceTintColor: Colors.transparent, // CRÍTICO: Evita tinte azul
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              title: Text(
                'Recuperar Contraseña',
                style: TextStyle(color: currentText, fontWeight: FontWeight.bold),
              ),
          content: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Ingresa tu email y te enviaremos un enlace para restablecer tu contraseña.',
                  style: TextStyle(color: currentTextSec),
                ),
                const SizedBox(height: 20),
                TextFormField(
                  controller: emailController,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    labelText: 'Email',
                    labelStyle: TextStyle(color: currentTextSec.withOpacity(0.6)),
                    prefixIcon: const Icon(Icons.email_outlined, color: currentBrand), // Use constant brand color
                    filled: true,
                    fillColor: const Color(0xFF2A2A2E), // Dark input background
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: currentBrand, width: 2),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: currentTextSec.withOpacity(0.2)),
                    ),
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
              actionsPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
              actions: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: isSending ? null : () => Navigator.pop(context),
                      child: Text('CANCELAR', style: TextStyle(color: currentTextSec)),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [dGoldLight, dGoldMain],
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                        ),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.transparent,
                          shadowColor: Colors.transparent,
                          foregroundColor: Colors.black, // Dark text on gold button
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
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
                                  ? const LoadingIndicator(
                                      fontSize: 10, 
                                      showMessage: false,
                                      color: Colors.black // Black indicator on gold
                                    )
                            : const Text('ENVIAR', style: TextStyle(fontWeight: FontWeight.bold)),
                      ),
                    ),
                  ],
                ),
              ],
            );
          },
        );
      },
    );
  }


  Future<void> _checkPermissions() async {
    LocationPermission permission = await Geolocator.checkPermission();
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    final isDarkMode = context.read<PlayerProvider>().isDarkMode;

    // Colores dinámicos
    final Color dSurface = const Color(0xFF1A1A1D);
    final Color lSurface = const Color(0xFFFFFFFF);
    final Color dText = Colors.white;
    final Color lText = const Color(0xFF1A1A1D);
    final Color dBrand = const Color(0xFFFECB00);
    final Color lBrand = const Color(0xFF5A189A);

    final Color currentBg = isDarkMode ? dSurface : lSurface;
    final Color currentText = isDarkMode ? dText : lText;
    final Color currentBrand = isDarkMode ? dBrand : lBrand;

    // Si falta algo, mostramos el BottomSheet explicativo antes de pedirlo nativamente
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever ||
        !serviceEnabled) {
      if (mounted) {
        await showModalBottomSheet(
          context: context,
          isDismissible: false,
          enableDrag: false,
          backgroundColor: currentBg,
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          builder: (context) => Container(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.location_on_outlined,
                    size: 60, color: currentBrand),
                const SizedBox(height: 16),
                Text(
                  'Ubicación Necesaria',
                  style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: currentText),
                ),
                const SizedBox(height: 8),
                Text(
                  'Para encontrar los tesoros ocultos, necesitamos acceder a tu ubicación.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: currentText.withOpacity(0.7)),
                ),
                const SizedBox(height: 24),
                Container(
                  width: double.infinity,
                  height: 55,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: isDarkMode 
                          ? [const Color(0xFFFFF176), const Color(0xFFFECB00)] 
                          : [const Color(0xFF9D4EDD), const Color(0xFF5A189A)],
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.transparent,
                      shadowColor: Colors.transparent,
                      foregroundColor: isDarkMode ? Colors.black : Colors.white,
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
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: currentText.withOpacity(0.5),
                      side: BorderSide(color: currentText.withOpacity(0.2)),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    onPressed: () {
                      Navigator.pop(context);
                    },
                    child: const Text('SALTAR POR AHORA'),
                  ),
                ),
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

  // Se eliminó isDarkMode local para usar el de PlayerProvider

  @override
  Widget build(BuildContext context) {
    final playerProvider = context.watch<PlayerProvider>();
    final isDarkMode = playerProvider.isDarkMode;

    // Definición local de la paleta de colores del "Sistema Cromático"
    const Color dSurface0 = Color(0xFF0D0D0F);
    const Color dSurface1 = Color(0xFF1A1A1D);
    const Color dMysticPurple = Color(0xFF7B2CBF);
    const Color dMysticPurpleDeep = Color(0xFF150826);
    const Color dGoldMain = Color(0xFFFECB00);
    const Color dGoldLight = Color(0xFFFFF176);
    const Color dBorderGray = Color(0xFF3D3D4D);

    const Color lSurface0 = Color(0xFFF2F2F7);
    const Color lSurface1 = Color(0xFFFFFFFF);
    const Color lMysticPurple = Color(0xFF5A189A);
    const Color lMysticPurpleDeep = Color(0xFFE9D5FF);
    const Color lBorderGray = Color(0xFFD1D1DB);
    const Color lTextPrimary = Color(0xFF1A1A1D);
    const Color lTextSecondary = Color(0xFF4A4A5A);

    final Color currentSurface0 = isDarkMode ? dSurface0 : lSurface0;
    final Color currentSurface1 = isDarkMode ? dSurface1 : lSurface1;
    final Color currentBrand = isDarkMode ? dMysticPurple : lMysticPurple;
    final Color currentBrandDeep = isDarkMode ? dMysticPurpleDeep : lMysticPurpleDeep;
    final Color currentBorder = isDarkMode ? dBorderGray : lBorderGray;
    final Color currentText = isDarkMode ? Colors.white : const Color(0xFF1A1A1D);
    final Color currentTextSec = isDarkMode ? Colors.white70 : const Color(0xFF4A4A5A);

    return Theme(
      data: Theme.of(context).copyWith(
        primaryColor: dGoldMain,
        textSelectionTheme: const TextSelectionThemeData(
          cursorColor: dGoldMain,
          selectionColor: Color(0x40FECB00),
          selectionHandleColor: dGoldMain,
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: const Color(0xFF2A2A2E).withOpacity(0.8), // Force dark background for inputs
          labelStyle: const TextStyle(
            color: Colors.white70,
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
          prefixIconColor: isDarkMode ? currentBrand : dGoldMain,
          suffixIconColor: Colors.white70,
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(
              color: isDarkMode ? currentBorder : dBorderGray,
              width: 1.5,
            ),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(
              color: isDarkMode ? currentBrand : dGoldMain,
              width: 2,
            ),
          ),
          errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Colors.redAccent, width: 1.5),
          ),
        ),
      ),
      child: Scaffold(
        backgroundColor: currentSurface0,
        resizeToAvoidBottomInset: true,
        body: GestureDetector(
          onTap: () => FocusScope.of(context).unfocus(),
          child: Stack(
            children: [
              // Fondo con imagen hero.png en modo oscuro o loginclaro.png en modo claro
              Positioned.fill(
                child: isDarkMode
                    ? Opacity(
                        opacity: 0.6, // Opacidad para mejor legibilidad
                        child: Image.asset(
                          'assets/images/hero.png',
                          fit: BoxFit.cover,
                          alignment: Alignment.center,
                        ),
                      )
                    : Stack(
                        children: [
                          // Imagen de fondo
                          Image.asset(
                            'assets/images/loginclaro.png',
                            fit: BoxFit.cover,
                            alignment: Alignment.center,
                            width: double.infinity,
                            height: double.infinity,
                          ),
                          // Capa negra transparente para mejor legibilidad
                          Container(
                            color: Colors.black.withOpacity(0.2),
                          ),
                        ],
                      ),
              ),

              SafeArea(
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    return SingleChildScrollView(
                      physics: const ClampingScrollPhysics(),
                      child: ConstrainedBox(
                        constraints: BoxConstraints(
                          minHeight: constraints.maxHeight,
                        ),
                        child: IntrinsicHeight(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 20.0),
                            child: AutofillGroup(
                              child: Form(
                                key: _formKey,
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Align(
                                      alignment: Alignment.topRight,
                                      child: IconButton(
                                        icon: Icon(
                                          isDarkMode ? Icons.wb_sunny_outlined : Icons.nightlight_round_outlined,
                                          color: Colors.white,
                                          size: 28,
                                        ),
                                        onPressed: () {
                                          debugPrint("Toggle presionado: actual=$isDarkMode");
                                          playerProvider.toggleDarkMode(!isDarkMode);
                                        },
                                      ),
                                    ),
                                    const Spacer(flex: 1),
                                    // Logo de MapHunter
                                    Image.asset(
                                      'assets/images/logo4.1.png',
                                      height: 180,
                                      fit: BoxFit.contain,
                                    ),
                                    const SizedBox(height: 10),
                                    Text(
                                      "Búsqueda del tesoro ☘️",
                                      style: TextStyle(
                                        fontSize: 14,
                                        color: Colors.white.withOpacity(0.9),
                                         fontWeight: FontWeight.w400,
                                         letterSpacing: 2.0,
                                      ),
                                    ),
                                    const SizedBox(height: 40),

                                    Text(
                                      'INICIA TU AVENTURA',
                                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                        letterSpacing: 3,
                                        fontSize: 12,
                                      ),
                                    ),
                                    const SizedBox(height: 30),

                                    // Email field
                                    TextFormField(
                                      controller: _emailController,
                                      keyboardType: TextInputType.emailAddress,
                                      textInputAction: TextInputAction.next,
                                      autofillHints: const [AutofillHints.email],
                                      style: const TextStyle(color: Colors.white),
                                      decoration: const InputDecoration(
                                        labelText: 'EMAIL',
                                        prefixIcon: Icon(Icons.email_outlined),
                                      ),
                                      validator: (value) {
                                        if (value == null || value.isEmpty) return 'Ingresa tu email';
                                        if (!value.contains('@')) return 'Email inválido';
                                        return null;
                                      },
                                    ),
                                    const SizedBox(height: 16),

                                    // Password field
                                    TextFormField(
                                      controller: _passwordController,
                                      obscureText: !_isPasswordVisible,
                                      textInputAction: TextInputAction.done,
                                      autofillHints: const [AutofillHints.password],
                                      onEditingComplete: _handleLogin,
                                      style: const TextStyle(color: Colors.white),
                                      decoration: InputDecoration(
                                        labelText: 'CONTRASEÑA',
                                        prefixIcon: const Icon(Icons.lock_outline),
                                        suffixIcon: IconButton(
                                          icon: Icon(
                                            _isPasswordVisible ? Icons.visibility : Icons.visibility_off,
                                          ),
                                          onPressed: () {
                                            setState(() {
                                              _isPasswordVisible = !_isPasswordVisible;
                                            });
                                          },
                                        ),
                                      ),
                                      validator: (value) {
                                        if (value == null || value.isEmpty) return 'Ingresa tu contraseña';
                                        if (value.length < 6) return 'Mínimo 6 caracteres';
                                        return null;
                                      },
                                    ),
                                    Align(
                                      alignment: Alignment.centerRight,
                                      child: TextButton(
                                        onPressed: _showForgotPasswordDialog,
                                        child: Text(
                                          '¿Olvidaste tu contraseña?',
                                          style: TextStyle(
                                            color: Colors.white.withOpacity(0.8),
                                            fontWeight: FontWeight.normal,
                                            fontSize: 13,
                                          ),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(height: 20),
                                    
                                    // Login button con "Legendary Gold" Gradient
                                    SizedBox(
                                      width: double.infinity,
                                      height: 56,
                                      child: Container(
                                        decoration: BoxDecoration(
                                          gradient: const LinearGradient(
                                            colors: [dGoldLight, dGoldMain],
                                            begin: Alignment.topCenter,
                                            end: Alignment.bottomCenter,
                                          ),
                                          borderRadius: BorderRadius.circular(12),
                                          boxShadow: [
                                            BoxShadow(
                                              color: dGoldMain.withOpacity(0.3),
                                              blurRadius: 15,
                                              offset: const Offset(0, 5),
                                            ),
                                          ],
                                        ),
                                        child: ElevatedButton(
                                          onPressed: _isLoggingIn ? null : _handleLogin,
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: Colors.transparent,
                                            shadowColor: Colors.transparent,
                                            foregroundColor: Colors.black,
                                            disabledBackgroundColor: Colors.transparent,
                                            disabledForegroundColor: Colors.black45,
                                            shape: RoundedRectangleBorder(
                                              borderRadius: BorderRadius.circular(12),
                                            ),
                                          ),
                                          child: _isLoggingIn
                                            ? const SizedBox(
                                                width: 24,
                                                height: 24,
                                                child: CircularProgressIndicator(
                                                  strokeWidth: 2.5,
                                                  valueColor: AlwaysStoppedAnimation<Color>(Colors.black54),
                                                ),
                                              )
                                            : const Text(
                                            'INICIAR SESIÓN',
                                            style: TextStyle(
                                              fontSize: 16,
                                              fontWeight: FontWeight.w900,
                                              letterSpacing: 1.5,
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
                                          style: TextStyle(color: Colors.white.withOpacity(0.8)),
                                        ),
                                        TextButton(
                                          onPressed: () {
                                            Navigator.of(context).push(
                                              MaterialPageRoute(builder: (_) => const RegisterScreen()),
                                            );
                                          },
                                          child: Text(
                                            'Regístrate',
                                            style: TextStyle(
                                              color: dGoldMain,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const Spacer(flex: 2),
                                    
                                    // Morna Branding
                                    _buildMornaBranding(isDark: isDarkMode),
                                    const SizedBox(height: 10),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMornaBranding({bool isDark = true}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Text(
          'By',
          style: TextStyle(
            color: Colors.white,
            fontSize: 13,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(width: 12),
        // Imagen JD.PNG
        Image.asset(
          'assets/images/jd.PNG',
          height: 30, // Ajustado para que se vea bien junto al logo de Morna
        ),
        const SizedBox(width: 12),
        // Logo Morna
        Image.asset(
          'assets/images/morna_logo.png',
          height: 18,
        ),
      ],
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
        duration: const Duration(milliseconds: 4000)
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
      final double value = _glitchController.value;
      
      // Much slower oscillation (10x instead of 40x)
      double offsetX = math.sin(value * 10 * math.pi) * 0.5;
      double offsetY = math.cos(value * 8 * math.pi) * 0.3;
      
      // Chromatic aberrations breathing much slower (5x instead of 20x)
      double cyanX = offsetX - 1.5 - (math.sin(value * 5 * math.pi) * 2.0);
      double magX = offsetX + 1.5 + (math.cos(value * 5 * math.pi) * 2.0);
      
      // Softer periodic spikes
      double spike = 0.0;
      if (value > 0.45 && value < 0.50) {
        spike = 3.0 * math.sin((value - 0.45) * 20 * math.pi);
      } else if (value > 0.90 && value < 0.95) {
        spike = -2.0 * math.sin((value - 0.90) * 20 * math.pi);
      }
      offsetX += spike;

      Color currentColor = widget.style.color ?? Colors.white;
      if (value > 0.98) {
        currentColor = Colors.white;
      }

        return Stack(
          children: [
            // Constant Chromatic Aberration Shadows (Cyan/Magenta)
            Transform.translate(
              offset: Offset(cyanX, offsetY),
              child: Text(
                _displayText,
                style: widget.style.copyWith(
                  color: const Color(0xFF00FFFF).withOpacity(0.6), // Cyan
                ),
              ),
            ),
            Transform.translate(
              offset: Offset(magX, offsetY),
              child: Text(
                _displayText,
                style: widget.style.copyWith(
                  color: const Color(0xFFFF00FF).withOpacity(0.6), // Magenta
                ),
              ),
            ),
            // Primary Text
            Transform.translate(
              offset: Offset(offsetX, offsetY),
              child: Text(
                _displayText,
                style: widget.style.copyWith(color: currentColor),
              ),
            ),
          ],
        );
      },
    );
  }
}