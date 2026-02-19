import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/gestures.dart';
import 'package:provider/provider.dart';
import '../providers/player_provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/animated_cyber_background.dart';
import '../../../core/utils/error_handler.dart';
import '../../../shared/widgets/cyber_tutorial_overlay.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../shared/widgets/loading_overlay.dart';
import 'login_screen.dart';

// RE-FORCE CLEAN VERSION - NO _isDarkMode
class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _cedulaController = TextEditingController();
  final _phoneController = TextEditingController();
  
  // Selectores para cédula y teléfono
  String _selectedNationalityType = 'V'; // V o E
  String _selectedPhonePrefix = '0412'; // Prefijo por defecto
  
  bool _isPasswordVisible = false;
  bool _isConfirmPasswordVisible = false;
  bool _acceptedTerms = false;
  bool _isRegistering = false;
  
  // Opciones de nacionalidad
  final List<String> _nationalityTypes = ['V', 'E'];
  
  // Prefijos de operadoras venezolanas
  final List<String> _phonePrefixes = ['0412', '0414', '0424', '0416', '0426', '0422'];
  
  // Lista básica de palabras prohibidas (se puede expandir)
  final List<String> _bannedWords = ['admin', 'root', 'moderator', 'tonto', 'estupido', 'idiota', 'groseria', 'puto', 'mierda'];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkFirstTime();
    });
  }

  Future<void> _checkFirstTime() async {
    final prefs = await SharedPreferences.getInstance();
    final bool hasSeenTutorial = prefs.getBool('seen_register_tutorial') ?? false;
    if (!hasSeenTutorial) {
      if (mounted) _showTutorial(context);
      await prefs.setBool('seen_register_tutorial', true);
    }
  }

  void _showTutorial(BuildContext context) {
    Navigator.of(context).push(
      PageRouteBuilder(
        opaque: false,
        pageBuilder: (context, _, __) => CyberTutorialOverlay(
          steps: [
            TutorialStep(
              title: "TU IDENTIDAD",
              description: "Ingresa tu cédula y teléfono correctamente. Estos datos son vitales para validar tu identidad en el gremio.",
              icon: Icons.badge_outlined,
            ),
            TutorialStep(
              title: "DATOS DE ACCESO",
              description: "Tu correo y contraseña serán tus credenciales únicas para entrar al mundo de MapHunter. ¡No las compartas!",
              icon: Icons.vpn_key_outlined,
            ),
            TutorialStep(
              title: "TÉRMINOS DEL GREMIO",
              description: "Lee con atención y acepta las reglas del juego para poder registrarte y comenzar tu aventura.",
              icon: Icons.gavel_outlined,
            ),
          ],
          onFinish: () => Navigator.pop(context),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _cedulaController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    
    // Precargar ambas imágenes de fondo para transiciones suaves
    precacheImage(const AssetImage('assets/images/hero.png'), context);
    precacheImage(const AssetImage('assets/images/loginclaro.png'), context);
  }

  Future<void> _handleRegister() async {
    if (_isRegistering) return; // Prevent double-tap
    if (!_formKey.currentState!.validate()) return;
    
    if (!_acceptedTerms) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Debes aceptar los términos y condiciones para continuar.'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() => _isRegistering = true);

    try {
      final playerProvider = Provider.of<PlayerProvider>(context, listen: false);

      // Sanitización estricta de datos
      final cedulaToSend = '$_selectedNationalityType${_cedulaController.text.trim()}'.toUpperCase();
      final phoneToSend = _phoneController.text.trim().replaceAll(RegExp(r'[^0-9]'), '');
      final emailToSend = _emailController.text.trim().toLowerCase();
      final nameToSend = _nameController.text.trim();

      debugPrint('REGISTER PAYLOAD: Cedula: $cedulaToSend, Phone: $phoneToSend, Email: $emailToSend');

      await playerProvider.register(
        nameToSend,
        emailToSend,
        _passwordController.text,
        cedula: cedulaToSend,
        phone: phoneToSend,
      );

      if (!mounted) return;

      // Mostrar mensaje claro de éxito
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Row(
            children: [
              Icon(Icons.mark_email_read_outlined, color: Colors.white),
              SizedBox(width: 12),
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '¡Registro exitoso!',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                    Text(
                      'Por favor, revisa tu correo para activar tu cuenta antes de iniciar sesión.',
                      style: TextStyle(fontSize: 14),
                    ),
                  ],
                ),
              ),
            ],
          ),
          backgroundColor: AppTheme.successGreen,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          margin: const EdgeInsets.all(20),
          duration: const Duration(seconds: 5),
        ),
      );

      // Redirigir al Login tras un breve delay
      await Future.delayed(const Duration(milliseconds: 1500));
      if (!mounted) return;

      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const LoginScreen()),
      );
    } catch (e) {
      if (!mounted) return;

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
      if (mounted) setState(() => _isRegistering = false);
    }
  }

  void _showTermsDialog(bool isDarkMode) {
    const Color dSurface1 = Color(0xFF1A1A1D);
    const Color lSurface1 = Color(0xFFFFFFFF);
    const Color lTextPrimary = Color(0xFF1A1A1D);
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: isDarkMode ? dSurface1 : lSurface1,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          "Términos y Condiciones", 
          style: TextStyle(color: isDarkMode ? Colors.white : lTextPrimary, fontWeight: FontWeight.bold)
        ),
        content: SingleChildScrollView(
          child: Text(
            "Lorem ipsum dolor sit amet, consectetur adipiscing elit. Sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat. Duis aute irure dolor in reprehenderit in voluptate velit esse cillum dolore eu fugiat nulla pariatur. Excepteur sint occaecat cupidatat non proident, sunt in culpa qui officia deserunt mollit anim id est laborum.\n\n"
            "1. Uso del servicio...\n"
            "2. Privacidad de datos...\n"
            "3. Responsabilidades...",
            style: TextStyle(color: isDarkMode ? Colors.white70 : Colors.black87),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text("Cerrar", style: TextStyle(color: isDarkMode ? Colors.white70 : lTextPrimary)),
          ),
        ],
      ),
    );
  }

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
    final Color currentBorder = isDarkMode ? dBorderGray : lBorderGray;
    final Color currentText = isDarkMode ? Colors.white : lTextPrimary;
    final Color currentTextSec = isDarkMode ? Colors.white70 : lTextSecondary;

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
          fillColor: const Color(0xFF2A2A2E).withOpacity(0.8), // Force dark background
          labelStyle: const TextStyle(color: Colors.white70, fontSize: 14, fontWeight: FontWeight.w600),
          prefixIconColor: isDarkMode ? dGoldMain : dGoldMain, // Always gold for consistency
          suffixIconColor: Colors.white70,
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: dBorderGray, width: 1.5),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: dGoldMain, width: 2),
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
              Positioned.fill(
                child: isDarkMode
                    ? Opacity(
                        opacity: 0.7,
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
                          Container(
                            color: Colors.black.withOpacity(0.2),
                          ),
                        ],
                      ),
              ),
              SafeArea(
                child: Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 8.0),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.arrow_back, color: Colors.white),
                            onPressed: () => Navigator.pop(context),
                          ),
                          IconButton(
                            icon: Icon(
                              isDarkMode ? Icons.wb_sunny_outlined : Icons.nightlight_round_outlined,
                              color: Colors.white,
                            ),
                            onPressed: () {
                              playerProvider.toggleDarkMode(!isDarkMode);
                            },
                          ),
                          IconButton(
                            icon: const Icon(Icons.help_outline, color: Colors.white),
                            onPressed: () => _showTutorial(context),
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: Center(
                        child: SingleChildScrollView(
                          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 10.0),
                          child: Form(
                            key: _formKey,
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  'CREAR CUENTA',
                                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: 3,
                                    fontSize: 24,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  "Únete a la aventura ☘️",
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: Colors.white.withOpacity(0.9),
                                    fontWeight: FontWeight.w400,
                                    letterSpacing: 2.0,
                                  ),
                                ),
                                const SizedBox(height: 30),

                                // Cédula / RIF
                                Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    SizedBox(
                                      width: 80,
                                      child: DropdownButtonFormField<String>(
                                        value: _selectedNationalityType,
                                        items: _nationalityTypes.map((type) {
                                          return DropdownMenuItem(
                                            value: type,
                                            child: Text(
                                              type,
                                              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                                            ),
                                          );
                                        }).toList(),
                                        onChanged: (value) {
                                          if (value != null) {
                                            setState(() => _selectedNationalityType = value);
                                          }
                                        },
                                          decoration: InputDecoration(
                                            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
                                            filled: true,
                                            fillColor: const Color(0xFF2A2A2E).withOpacity(0.8),
                                          ),
                                          dropdownColor: const Color(0xFF1A1A1D),
                                          style: const TextStyle(color: Colors.white),
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    
                                    Expanded(
                                      child: TextFormField(
                                        controller: _cedulaController,
                                        style: const TextStyle(color: Colors.white),
                                        keyboardType: TextInputType.number,
                                        inputFormatters: [
                                          FilteringTextInputFormatter.digitsOnly,
                                          LengthLimitingTextInputFormatter(9),
                                        ],
                                        decoration: const InputDecoration(
                                          labelText: 'CÉDULA/PASAPORTE',
                                          prefixIcon: Icon(Icons.badge_outlined),
                                          hintText: '12345678',
                                        ),
                                        validator: (value) {
                                          if (value == null || value.isEmpty) return 'Ingresa tu cédula';
                                          if (value.length < 6) return 'Mínimo 6 dígitos';
                                          return null;
                                        },
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 16),

                                // Teléfono
                                TextFormField(
                                  controller: _phoneController,
                                  style: const TextStyle(color: Colors.white),
                                  keyboardType: TextInputType.number, 
                                  inputFormatters: [
                                    FilteringTextInputFormatter.digitsOnly,
                                    LengthLimitingTextInputFormatter(11),
                                  ],
                                  decoration: const InputDecoration(
                                    labelText: 'TELÉFONO',
                                    prefixIcon: Icon(Icons.phone_android_outlined),
                                    hintText: '04121234567',
                                  ),
                                  validator: (value) {
                                    if (value == null || value.isEmpty) return 'Ingresa tu teléfono';
                                    if (value.length < 11) return 'Ingresa el número completo (11 dígitos)';
                                    final prefixRegex = RegExp(r'^04(12|14|24|16|26|22)');
                                    if (!prefixRegex.hasMatch(value)) return 'Prefijo inválido (ej: 0412...)';
                                    return null;
                                  },
                                ),
                                const SizedBox(height: 16),

                                // Nombre completo
                                TextFormField(
                                  controller: _nameController,
                                  style: const TextStyle(color: Colors.white),
                                  inputFormatters: [
                                    LengthLimitingTextInputFormatter(50),
                                    FilteringTextInputFormatter.allow(RegExp(r'[a-zA-ZñÑáéíóúÁÉÍÓÚ\s]')),
                                  ],
                                  decoration: const InputDecoration(
                                    labelText: 'NOMBRE COMPLETO',
                                    prefixIcon: Icon(Icons.person_outline),
                                  ),
                                  validator: (value) {
                                    if (value == null || value.isEmpty) return 'Ingresa tu nombre';
                                    if (!value.trim().contains(' ')) return 'Ingresa Nombre y Apellido';
                                    final lowerName = value.toLowerCase();
                                    for (final word in _bannedWords) {
                                      if (lowerName.contains(word)) return 'El nombre contiene palabras no permitidas';
                                    }
                                    return null;
                                  },
                                ),
                                const SizedBox(height: 16),

                                // Email
                                TextFormField(
                                  controller: _emailController,
                                  keyboardType: TextInputType.emailAddress,
                                  style: const TextStyle(color: Colors.white),
                                  decoration: const InputDecoration(
                                    labelText: 'EMAIL',
                                    prefixIcon: Icon(Icons.email_outlined),
                                  ),
                                  validator: (value) {
                                    if (value == null || value.isEmpty) return 'Ingresa tu email';
                                    final emailRegex = RegExp(r'^[\w\.\-]+@[\w\.\-]+\.[a-zA-Z]{2,}$');
                                    if (!emailRegex.hasMatch(value.trim())) return 'Formato de email inválido';
                                    return null;
                                  },
                                ),
                                const SizedBox(height: 16),

                                // Password
                                TextFormField(
                                  controller: _passwordController,
                                  obscureText: !_isPasswordVisible,
                                  style: const TextStyle(color: Colors.white),
                                  decoration: InputDecoration(
                                    labelText: 'CONTRASEÑA',
                                    prefixIcon: const Icon(Icons.lock_outline),
                                    suffixIcon: IconButton(
                                      icon: Icon(_isPasswordVisible ? Icons.visibility : Icons.visibility_off),
                                      onPressed: () => setState(() => _isPasswordVisible = !_isPasswordVisible),
                                    ),
                                  ),
                                  validator: (value) {
                                    if (value == null || value.isEmpty) return 'Ingresa tu contraseña';
                                    if (value.length < 6) return 'Mínimo 6 caracteres';
                                    return null;
                                  },
                                ),
                                const SizedBox(height: 16),

                                // Confirm Password
                                TextFormField(
                                  controller: _confirmPasswordController,
                                  obscureText: !_isConfirmPasswordVisible,
                                  style: const TextStyle(color: Colors.white),
                                  decoration: InputDecoration(
                                    labelText: 'CONFIRMAR CONTRASEÑA',
                                    prefixIcon: const Icon(Icons.lock_outline),
                                    suffixIcon: IconButton(
                                      icon: Icon(_isConfirmPasswordVisible ? Icons.visibility : Icons.visibility_off),
                                      onPressed: () => setState(() => _isConfirmPasswordVisible = !_isConfirmPasswordVisible),
                                    ),
                                  ),
                                  validator: (value) {
                                    if (value == null || value.isEmpty) return 'Confirma tu contraseña';
                                    if (value != _passwordController.text) return 'Las contraseñas no coinciden';
                                    return null;
                                  },
                                ),
                                const SizedBox(height: 10),

                                // Términos y condiciones
                                Theme(
                                  data: ThemeData(
                                    unselectedWidgetColor: Colors.white30,
                                  ),
                                  child: CheckboxListTile(
                                    contentPadding: EdgeInsets.zero,
                                    title: RichText(
                                      text: TextSpan(
                                        children: [
                                          const TextSpan(
                                            text: "Acepto los ",
                                            style: TextStyle(color: Colors.white70, fontSize: 13),
                                          ),
                                          TextSpan(
                                            text: "términos y condiciones de uso.",
                                            style: TextStyle(
                                              color: isDarkMode ? dGoldMain : dGoldLight, 
                                              fontSize: 13,
                                              fontWeight: FontWeight.bold,
                                            ),
                                            recognizer: TapGestureRecognizer()..onTap = () => _showTermsDialog(isDarkMode),
                                          ),
                                        ],
                                      ),
                                    ),
                                    value: _acceptedTerms,
                                    activeColor: isDarkMode ? dGoldMain : lMysticPurple,
                                    checkColor: isDarkMode ? Colors.black : Colors.white,
                                    onChanged: (newValue) => setState(() => _acceptedTerms = newValue ?? false),
                                    controlAffinity: ListTileControlAffinity.leading,
                                  ),
                                ),
                                
                                const SizedBox(height: 20),

                                // Register button
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
                                      onPressed: _isRegistering ? null : _handleRegister,
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
                                      child: _isRegistering
                                        ? const SizedBox(
                                            width: 24,
                                            height: 24,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2.5,
                                              valueColor: AlwaysStoppedAnimation<Color>(Colors.black54),
                                            ),
                                          )
                                        : const Text(
                                        'CREAR CUENTA',
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
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}