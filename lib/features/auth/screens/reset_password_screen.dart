import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/error_handler.dart';
import '../providers/player_provider.dart';
import 'login_screen.dart';
import '../../../shared/widgets/loading_indicator.dart';

class ResetPasswordScreen extends StatefulWidget {
  const ResetPasswordScreen({super.key});

  @override
  State<ResetPasswordScreen> createState() => _ResetPasswordScreenState();
}

class _ResetPasswordScreenState extends State<ResetPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  bool _isPasswordVisible = false;
  bool _isLoading = false;

  @override
  void dispose() {
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    precacheImage(const AssetImage('assets/images/hero.png'), context);
    precacheImage(const AssetImage('assets/images/loginclaro.png'), context);
  }

  Future<void> _handleResetPassword() async {
    if (_formKey.currentState!.validate()) {
      setState(() => _isLoading = true);
      try {
        final playerProvider = context.read<PlayerProvider>();
        await playerProvider.updatePassword(_passwordController.text);

        if (!mounted) return;
        
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('¡Contraseña actualizada! Bienvenido de nuevo.'),
            backgroundColor: AppTheme.accentGold,
          ),
        );

        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const LoginScreen()),
          (route) => false,
        );
      } catch (e) {
        if (!mounted) return;
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(ErrorHandler.getFriendlyErrorMessage(e)),
            backgroundColor: AppTheme.dangerRed,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final playerProvider = context.watch<PlayerProvider>();
    final isDarkMode = playerProvider.isDarkMode;

    const Color dGoldMain = Color(0xFFFECB00);
    const Color dGoldLight = Color(0xFFFFF176);
    const Color dBorderGray = Color(0xFF3D3D4D);
    const Color lSurface0 = Color(0xFFF2F2F7);

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
          fillColor: const Color(0xFF2A2A2E).withOpacity(0.8), // Mismo fondo oscuro de inputs que Login
          labelStyle: const TextStyle(
            color: Colors.white70,
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
          hintStyle: const TextStyle(color: Colors.white38, fontSize: 14),
          prefixIconColor: dGoldMain,
          suffixIconColor: Colors.white70,
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(
              color: dBorderGray,
              width: 1.5,
            ),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(
              color: dGoldMain,
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
        backgroundColor: isDarkMode ? const Color(0xFF0D0D0F) : lSurface0,
        resizeToAvoidBottomInset: true,
        body: GestureDetector(
          onTap: () => FocusScope.of(context).unfocus(),
          child: Stack(
            children: [
              // Fondo dinámico idéntico al Login
              Positioned.fill(
                child: isDarkMode
                    ? Opacity(
                        opacity: 0.6,
                        child: Image.asset(
                          'assets/images/hero.png',
                          fit: BoxFit.cover,
                          alignment: Alignment.center,
                        ),
                      )
                    : Stack(
                        children: [
                          Image.asset(
                            'assets/images/loginclaro.png',
                            fit: BoxFit.cover,
                            alignment: Alignment.center,
                            width: double.infinity,
                            height: double.infinity,
                          ),
                          Container(color: Colors.black.withOpacity(0.2)),
                        ],
                      ),
              ),
              
              SafeArea(
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    return SingleChildScrollView(
                      physics: const ClampingScrollPhysics(),
                      child: ConstrainedBox(
                        constraints: BoxConstraints(minHeight: constraints.maxHeight),
                        child: IntrinsicHeight(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 20.0),
                            child: Form(
                              key: _formKey,
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  // Botón de cambio de tema
                                  Align(
                                    alignment: Alignment.topRight,
                                    child: IconButton(
                                      icon: Icon(
                                        isDarkMode ? Icons.wb_sunny_outlined : Icons.nightlight_round_outlined,
                                        color: Colors.white,
                                        size: 28,
                                      ),
                                      onPressed: () => playerProvider.toggleDarkMode(!isDarkMode),
                                    ),
                                  ),
                                  
                                  const Spacer(flex: 1),
                                  
                                  // Icono: Logo MapHunter (como pidió el usuario)
                                  Image.asset(
                                    'assets/images/logo4.1.png',
                                    height: 180,
                                    fit: BoxFit.contain,
                                  ),
                                  const SizedBox(height: 10),
                                  
                                  const Text(
                                    "Nueva Contraseña",
                                    style: TextStyle(
                                      fontSize: 28,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white,
                                      letterSpacing: 1.2,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    "Ingresa tu nueva clave de acceso",
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: Colors.white.withOpacity(0.6),
                                    ),
                                  ),
                                  const SizedBox(height: 40),
                                  
                                  // Input Nueva Contraseña
                                  TextFormField(
                                    controller: _passwordController,
                                    obscureText: !_isPasswordVisible,
                                    style: const TextStyle(color: Colors.white),
                                    textInputAction: TextInputAction.next,
                                    decoration: InputDecoration(
                                      labelText: 'Contraseña Nueva',
                                      prefixIcon: const Icon(Icons.lock_outline_rounded),
                                      suffixIcon: IconButton(
                                        icon: Icon(_isPasswordVisible ? Icons.visibility : Icons.visibility_off),
                                        onPressed: () => setState(() => _isPasswordVisible = !_isPasswordVisible),
                                      ),
                                    ),
                                    validator: (value) {
                                      if (value == null || value.isEmpty) return 'Ingresa tu nueva clave';
                                      if (value.length < 6) return 'Mínimo 6 caracteres';
                                      return null;
                                    },
                                  ),
                                  const SizedBox(height: 16),
                                  
                                  // Input Confirmar Contraseña
                                  TextFormField(
                                    controller: _confirmPasswordController,
                                    obscureText: !_isPasswordVisible,
                                    style: const TextStyle(color: Colors.white),
                                    textInputAction: TextInputAction.done,
                                    onEditingComplete: _handleResetPassword,
                                    decoration: const InputDecoration(
                                      labelText: 'Confirmar Contraseña',
                                      prefixIcon: Icon(Icons.lock_person_outlined),
                                    ),
                                    validator: (value) {
                                      if (value != _passwordController.text) return 'Las contraseñas no coinciden';
                                      return null;
                                    },
                                  ),
                                  const SizedBox(height: 30),
  
                                  // Botón principal con Gradient "Legendary Gold" (Igual al Login)
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
                                        onPressed: _isLoading ? null : _handleResetPassword,
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: Colors.transparent,
                                          shadowColor: Colors.transparent,
                                          foregroundColor: Colors.black,
                                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                        ),
                                        child: _isLoading
                                            ? const SizedBox(
                                                width: 24,
                                                height: 24,
                                                child: CircularProgressIndicator(
                                                  strokeWidth: 2.5,
                                                  valueColor: AlwaysStoppedAnimation<Color>(Colors.black54),
                                                ),
                                              )
                                            : const Text(
                                                'ACTUALIZAR Y ENTRAR',
                                                style: TextStyle(
                                                  fontSize: 16,
                                                  fontWeight: FontWeight.w900,
                                                  letterSpacing: 1.5,
                                                ),
                                              ),
                                      ),
                                    ),
                                  ),
                                  
                                  const Spacer(flex: 2),
                                  
                                  // Botón Volver con estilo de GameModeSelector (Morado/Blur)
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(34),
                                    child: BackdropFilter(
                                      filter: ColorFilter.mode(Colors.black.withOpacity(0.1), BlendMode.dstIn),
                                      child: Container(
                                        padding: const EdgeInsets.all(4),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFF9D4EDD).withOpacity(0.1),
                                          borderRadius: BorderRadius.circular(34),
                                          border: Border.all(
                                            color: const Color(0xFF9D4EDD).withOpacity(0.4),
                                            width: 1,
                                          ),
                                        ),
                                        child: TextButton.icon(
                                          onPressed: () => Navigator.of(context).pushReplacement(
                                            MaterialPageRoute(builder: (_) => const LoginScreen())
                                          ),
                                          icon: const Icon(Icons.arrow_back, color: Colors.white, size: 20),
                                          label: const Text("CANCELAR Y VOLVER",
                                              style: TextStyle(
                                                color: Colors.white,
                                                fontSize: 14,
                                                fontFamily: 'Orbitron',
                                                letterSpacing: 1.0,
                                              )),
                                          style: TextButton.styleFrom(
                                            backgroundColor: const Color(0xFF0D0D0F).withOpacity(0.6),
                                            foregroundColor: Colors.white,
                                            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                                            shape: RoundedRectangleBorder(
                                                borderRadius: BorderRadius.circular(30),
                                                side: const BorderSide(color: Color(0xFF9D4EDD), width: 2.0)),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 10),
                                ],
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
}
