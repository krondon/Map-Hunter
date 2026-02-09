import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/gestures.dart';
import 'package:provider/provider.dart';
import '../providers/player_provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/animated_cyber_background.dart';
import '../../../core/utils/error_handler.dart';

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
  bool _isPasswordVisible = false;
  bool _isConfirmPasswordVisible = false;
  bool _acceptedTerms = false;
  
  // Lista básica de palabras prohibidas (se puede expandir)
  final List<String> _bannedWords = ['admin', 'root', 'moderator', 'tonto', 'estupido', 'idiota', 'groseria', 'puto', 'mierda'];

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

  Future<void> _handleRegister() async {
    if (_formKey.currentState!.validate()) {
      if (!_acceptedTerms) {
         ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Debes aceptar los términos y condiciones para continuar.'),
            backgroundColor: Colors.orange,
          ),
        );
        return;
      }

      try {
        final playerProvider = Provider.of<PlayerProvider>(context, listen: false);
        
        // 1. Mostrar indicador de carga
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => const Center(child: CircularProgressIndicator()),
        );

        // 2. Ejecutar registro
        await playerProvider.register(
          _nameController.text.trim(),
          _emailController.text.trim(),
          _passwordController.text,
          cedula: _cedulaController.text.trim(),
          phone: _phoneController.text.trim(),
        );
        
        if (!mounted) return;
        
        // 3. Cerrar el indicador de carga
        Navigator.pop(context);

        // 4. Mostrar mensaje discreto de éxito
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Row(
              children: [
                Icon(Icons.check_circle_outline, color: Colors.white),
                SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Cuenta creada exitosamente. ¡Inicia sesión!',
                    style: TextStyle(fontWeight: FontWeight.w500),
                  ),
                ),
              ],
            ),
            backgroundColor: AppTheme.successGreen,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            margin: const EdgeInsets.all(20),
            duration: const Duration(seconds: 3),
          ),
        );

        // 5. Regresar inmediatamente a la vista de Login
        Navigator.pop(context);

      } catch (e) {
        if (!mounted) return;
        Navigator.pop(context); // Cierra el indicador de carga si hubo error
        
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

  bool _isDarkMode = false; // Inicia en Modo Día

  void _showTermsDialog() {
    const Color dSurface1 = Color(0xFF1A1A1D);
    const Color lSurface1 = Color(0xFFFFFFFF);
    const Color lTextPrimary = Color(0xFF1A1A1D);
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: _isDarkMode ? dSurface1 : lSurface1,
        title: Text(
          "Términos y Condiciones", 
          style: TextStyle(color: _isDarkMode ? Colors.white : lTextPrimary)
        ),
        content: SingleChildScrollView(
          child: Text(
            "Lorem ipsum dolor sit amet, consectetur adipiscing elit. Sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat. Duis aute irure dolor in reprehenderit in voluptate velit esse cillum dolore eu fugiat nulla pariatur. Excepteur sint occaecat cupidatat non proident, sunt in culpa qui officia deserunt mollit anim id est laborum.\n\n"
            "1. Uso del servicio...\n"
            "2. Privacidad de datos...\n"
            "3. Responsabilidades...",
            style: TextStyle(color: _isDarkMode ? Colors.white70 : Colors.black87),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cerrar"),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
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

    final Color currentSurface0 = _isDarkMode ? dSurface0 : lSurface0;
    final Color currentSurface1 = _isDarkMode ? dSurface1 : lSurface1;
    final Color currentBrand = _isDarkMode ? dMysticPurple : lMysticPurple;
    final Color currentBrandDeep = _isDarkMode ? dMysticPurpleDeep : lMysticPurpleDeep;
    final Color currentBorder = _isDarkMode ? dBorderGray : lBorderGray;
    final Color currentText = _isDarkMode ? Colors.white : lTextPrimary;
    final Color currentTextSec = _isDarkMode ? Colors.white70 : lTextSecondary;

    return Theme(
      data: Theme.of(context).copyWith(
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: currentSurface1,
          labelStyle: TextStyle(color: currentTextSec.withOpacity(0.6), fontSize: 14),
          prefixIconColor: currentBrand,
          suffixIconColor: currentTextSec.withOpacity(0.6),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: currentBorder, width: 1.5),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: currentBrand, width: 2),
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
              // Fondo con degradado
              Positioned.fill(
                child: Container(
                  decoration: BoxDecoration(
                    gradient: RadialGradient(
                      center: const Alignment(-0.8, -0.6),
                      radius: 1.5,
                      colors: [
                        currentBrandDeep,
                        currentSurface0,
                      ],
                    ),
                  ),
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
                            icon: Icon(Icons.arrow_back, color: _isDarkMode ? Colors.white : lMysticPurple),
                            onPressed: () => Navigator.pop(context),
                          ),
                          IconButton(
                            icon: Icon(
                              _isDarkMode ? Icons.wb_sunny_outlined : Icons.nightlight_round_outlined,
                              color: _isDarkMode ? Colors.white : lMysticPurple,
                            ),
                            onPressed: () => setState(() => _isDarkMode = !_isDarkMode),
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
                                    color: currentText,
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
                                    color: currentTextSec,
                                    fontWeight: FontWeight.w400,
                                    letterSpacing: 2.0,
                                  ),
                                ),
                                const SizedBox(height: 30),

                                // Cédula / RIF
                                TextFormField(
                                  controller: _cedulaController,
                                  style: TextStyle(color: currentText),
                                  decoration: InputDecoration(
                                    labelText: 'CÉDULA / RIF',
                                    prefixIcon: const Icon(Icons.badge_outlined),
                                    hintText: 'V12345678',
                                    hintStyle: TextStyle(color: currentTextSec.withOpacity(0.3), fontSize: 13),
                                  ),
                                  validator: (value) {
                                    if (value == null || value.isEmpty) return 'Ingresa tu cédula o RIF';
                                    return null;
                                  },
                                ),
                                const SizedBox(height: 16),

                                // Teléfono
                                TextFormField(
                                  controller: _phoneController,
                                  style: TextStyle(color: currentText),
                                  keyboardType: TextInputType.phone,
                                  decoration: InputDecoration(
                                    labelText: 'TELÉFONO',
                                    prefixIcon: const Icon(Icons.phone_android_outlined),
                                    hintText: '04121234567',
                                    hintStyle: TextStyle(color: currentTextSec.withOpacity(0.3), fontSize: 13),
                                  ),
                                  validator: (value) {
                                    if (value == null || value.isEmpty) return 'Ingresa tu teléfono';
                                    return null;
                                  },
                                ),
                                const SizedBox(height: 16),

                                // Nombre completo
                                TextFormField(
                                  controller: _nameController,
                                  style: TextStyle(color: currentText),
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
                                    return null;
                                  },
                                ),
                                const SizedBox(height: 16),

                                // Email
                                TextFormField(
                                  controller: _emailController,
                                  keyboardType: TextInputType.emailAddress,
                                  style: TextStyle(color: currentText),
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

                                // Password
                                TextFormField(
                                  controller: _passwordController,
                                  obscureText: !_isPasswordVisible,
                                  style: TextStyle(color: currentText),
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
                                  style: TextStyle(color: currentText),
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
                                    unselectedWidgetColor: _isDarkMode ? Colors.white30 : Colors.black38,
                                  ),
                                  child: CheckboxListTile(
                                    contentPadding: EdgeInsets.zero,
                                    title: RichText(
                                      text: TextSpan(
                                        children: [
                                          TextSpan(
                                            text: "Acepto los ",
                                            style: TextStyle(color: currentTextSec, fontSize: 13),
                                          ),
                                          TextSpan(
                                            text: "términos y condiciones de uso.",
                                            style: TextStyle(
                                              color: _isDarkMode ? dGoldMain : lMysticPurple, 
                                              fontSize: 13,
                                              fontWeight: FontWeight.bold,
                                            ),
                                            recognizer: TapGestureRecognizer()..onTap = _showTermsDialog,
                                          ),
                                        ],
                                      ),
                                    ),
                                    value: _acceptedTerms,
                                    activeColor: currentBrand,
                                    checkColor: Colors.white,
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
                                      onPressed: _handleRegister,
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.transparent,
                                        shadowColor: Colors.transparent,
                                        foregroundColor: Colors.black,
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(12),
                                        ),
                                      ),
                                      child: const Text(
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