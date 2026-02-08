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
  
  // Selectores para cédula y teléfono
  String _selectedNationalityType = 'V'; // V o E
  String _selectedPhonePrefix = '0412'; // Prefijo por defecto
  
  bool _isPasswordVisible = false;
  bool _isConfirmPasswordVisible = false;
  bool _acceptedTerms = false;
  
  // Opciones de nacionalidad
  final List<String> _nationalityTypes = ['V', 'E'];
  
  // Prefijos de operadoras venezolanas
  final List<String> _phonePrefixes = ['0412', '0414', '0424', '0416', '0426', '0422'];
  
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
          cedula: '$_selectedNationalityType${_cedulaController.text.trim()}', // Combinar V/E + número
          phone: '$_selectedPhonePrefix${_phoneController.text.trim()}', // Combinar prefijo + número
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

  void _showTermsDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.cardBg,
        title: const Text("Términos y Condiciones", style: TextStyle(color: Colors.white)),
        content: SingleChildScrollView(
          child: const Text(
            "Lorem ipsum dolor sit amet, consectetur adipiscing elit. Sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat. Duis aute irure dolor in reprehenderit in voluptate velit esse cillum dolore eu fugiat nulla pariatur. Excepteur sint occaecat cupidatat non proident, sunt in culpa qui officia deserunt mollit anim id est laborum.\n\n"
            "1. Uso del servicio...\n"
            "2. Privacidad de datos...\n"
            "3. Responsabilidades...",
            style: TextStyle(color: Colors.white70),
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
    return Scaffold(
      resizeToAvoidBottomInset: true, // Permitir que el teclado empuje
      body: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(), // Tap para ocultar teclado
        child: AnimatedCyberBackground(
          child: SafeArea(
          child: Column(
            children: [
              Align(
                alignment: Alignment.topLeft,
                child: IconButton(
                  icon: const Icon(Icons.arrow_back, color: Colors.white),
                  onPressed: () => Navigator.pop(context),
                ),
              ),
              
              Expanded(
                child: Center(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(24.0),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            'Crear Cuenta',
                            style: Theme.of(context).textTheme.displayLarge,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Únete a la aventura',
                            style: Theme.of(context).textTheme.bodyLarge,
                          ),
                          const SizedBox(height: 40),

                          // ==========================================
                          // CAMPO CÉDULA
                          // ==========================================
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Dropdown para V/E
                              Container(
                                width: 70,
                                margin: const EdgeInsets.only(right: 12),
                                child: DropdownButtonFormField<String>(
                                  value: _selectedNationalityType,
                                  dropdownColor: AppTheme.cardBg,
                                  style: const TextStyle(color: Colors.white),
                                  decoration: const InputDecoration(
                                    labelText: 'Tipo',
                                    labelStyle: TextStyle(color: Colors.white60, fontSize: 12),
                                    contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 16),
                                  ),
                                  items: _nationalityTypes.map((type) {
                                    return DropdownMenuItem(
                                      value: type,
                                      child: Text(type, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                                    );
                                  }).toList(),
                                  onChanged: (value) {
                                    setState(() {
                                      _selectedNationalityType = value!;
                                    });
                                  },
                                ),
                              ),
                              
                              // Campo para el número de cédula
                              Expanded(
                                child: TextFormField(
                                  controller: _cedulaController,
                                  style: const TextStyle(color: Colors.white),
                                  keyboardType: TextInputType.number,
                                  inputFormatters: [
                                    LengthLimitingTextInputFormatter(9), // Máximo 9 dígitos
                                    FilteringTextInputFormatter.digitsOnly,
                                  ],
                                  decoration: const InputDecoration(
                                    labelText: 'Número de Cédula',
                                    labelStyle: TextStyle(color: Colors.white60),
                                    prefixIcon: Icon(Icons.badge_outlined, color: Colors.white60),
                                    hintText: '12345678',
                                    hintStyle: TextStyle(color: Colors.white24),
                                  ),
                                  validator: (value) {
                                    if (value == null || value.isEmpty) {
                                      return 'Ingresa tu cédula';
                                    }
                                    
                                    // Validar longitud: 6-9 dígitos
                                    if (value.length < 6 || value.length > 9) {
                                      return 'Debe tener entre 6 y 9 dígitos';
                                    }
                                    
                                    return null;
                                  },
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 20),

                          // ==========================================
                          // CAMPO TELÉFONO
                          // ==========================================
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Dropdown para prefijo
                              Container(
                                width: 90,
                                margin: const EdgeInsets.only(right: 12),
                                child: DropdownButtonFormField<String>(
                                  value: _selectedPhonePrefix,
                                  dropdownColor: AppTheme.cardBg,
                                  style: const TextStyle(color: Colors.white),
                                  decoration: const InputDecoration(
                                    labelText: 'Prefijo',
                                    labelStyle: TextStyle(color: Colors.white60, fontSize: 12),
                                    contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 16),
                                  ),
                                  items: _phonePrefixes.map((prefix) {
                                    return DropdownMenuItem(
                                      value: prefix,
                                      child: Text(prefix, style: const TextStyle(fontSize: 14)),
                                    );
                                  }).toList(),
                                  onChanged: (value) {
                                    setState(() {
                                      _selectedPhonePrefix = value!;
                                    });
                                  },
                                ),
                              ),
                              
                              // Campo para el número
                              Expanded(
                                child: TextFormField(
                                  controller: _phoneController,
                                  style: const TextStyle(color: Colors.white),
                                  keyboardType: TextInputType.phone,
                                  inputFormatters: [
                                    LengthLimitingTextInputFormatter(7), // Solo 7 dígitos
                                    FilteringTextInputFormatter.digitsOnly,
                                  ],
                                  decoration: const InputDecoration(
                                    labelText: 'Número',
                                    labelStyle: TextStyle(color: Colors.white60),
                                    prefixIcon: Icon(Icons.phone_android_outlined, color: Colors.white60),
                                    hintText: '1234567',
                                    hintStyle: TextStyle(color: Colors.white24),
                                  ),
                                  validator: (value) {
                                    if (value == null || value.isEmpty) {
                                      return 'Ingresa tu número';
                                    }
                                    
                                    if (value.length != 7) {
                                      return 'Debe tener 7 dígitos';
                                    }
                                    
                                    return null;
                                  },
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 20),
                          
                          // ==========================================
                          // CAMPO NOMBRE
                          // ==========================================
                          TextFormField(
                            controller: _nameController,
                            style: const TextStyle(color: Colors.white),
                            inputFormatters: [
                              LengthLimitingTextInputFormatter(50),
                              FilteringTextInputFormatter.allow(
                                RegExp(r'[a-zA-ZñÑáéíóúÁÉÍÓÚ\s]'),
                              ),
                            ],
                            decoration: const InputDecoration(
                              labelText: 'Nombre Completo',
                              labelStyle: TextStyle(color: Colors.white60),
                              prefixIcon: Icon(Icons.person_outline, color: Colors.white60),
                            ),
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'Ingresa tu nombre';
                              }
                              if (!value.trim().contains(' ')) {
                                return 'Ingresa tu nombre completo (Nombre y Apellido)';
                              }
                              
                              // Filtro de groserías
                              final lowerValue = value.toLowerCase();
                              for (final word in _bannedWords) {
                                if (lowerValue.contains(word)) {
                                  return 'Nombre no permitido. Elige otro.';
                                }
                              }
                              
                              return null;
                            },
                          ),
                          const SizedBox(height: 20),
                          
                          // Email field
                          TextFormField(
                            controller: _emailController,
                            keyboardType: TextInputType.emailAddress,
                            style: const TextStyle(color: Colors.white),
                            decoration: const InputDecoration(
                              labelText: 'Email',
                              labelStyle: TextStyle(color: Colors.white60),
                              prefixIcon: Icon(Icons.email_outlined, color: Colors.white60),
                            ),
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'Ingresa tu email';
                              }
                              if (!value.contains('@')) {
                                return 'Email inválido';
                              }
                              
                              // Bloqueo de dominios temporales
                              final domain = value.split('@').last.toLowerCase();
                              final blockedDomains = ['yopmail.com', 'tempmail.com', '10minutemail.com', 'guerrillamail.com', 'mailinator.com'];
                              
                              if (blockedDomains.contains(domain)) {
                                return 'Dominio de correo no permitido';
                              }
                              
                              return null;
                            },
                          ),
                          const SizedBox(height: 20),
                          
                          // Password field
                          TextFormField(
                            controller: _passwordController,
                            obscureText: !_isPasswordVisible,
                            style: const TextStyle(color: Colors.white),
                            decoration: InputDecoration(
                              labelText: 'Contraseña',
                              labelStyle: const TextStyle(color: Colors.white60),
                              prefixIcon: const Icon(Icons.lock_outline, color: Colors.white60),
                              suffixIcon: IconButton(
                                icon: Icon(
                                  _isPasswordVisible ? Icons.visibility : Icons.visibility_off,
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
                              if (value.length > 30) {
                                return 'Máximo 30 caracteres';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 20),
                          
                          // Confirm password field
                          TextFormField(
                            controller: _confirmPasswordController,
                            obscureText: !_isConfirmPasswordVisible,
                            style: const TextStyle(color: Colors.white),
                            decoration: InputDecoration(
                              labelText: 'Confirmar Contraseña',
                              labelStyle: const TextStyle(color: Colors.white60),
                              prefixIcon: const Icon(Icons.lock_outline, color: Colors.white60),
                              suffixIcon: IconButton(
                                icon: Icon(
                                  _isConfirmPasswordVisible ? Icons.visibility : Icons.visibility_off,
                                  color: Colors.white60,
                                ),
                                onPressed: () {
                                  setState(() {
                                    _isConfirmPasswordVisible = !_isConfirmPasswordVisible;
                                  });
                                },
                              ),
                            ),
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'Confirma tu contraseña';
                              }
                              if (value != _passwordController.text) {
                                return 'Las contraseñas no coinciden';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 20),
                          
                          // TÉRMINOS Y CONDICIONES
                          CheckboxListTile(
                            contentPadding: EdgeInsets.zero,
                            title: RichText(
                              text: TextSpan(
                                children: [
                                  const TextSpan(
                                    text: "Acepto los ",
                                    style: TextStyle(color: Colors.white70, fontSize: 14),
                                  ),
                                  TextSpan(
                                    text: "términos y condiciones de uso.",
                                    style: const TextStyle(
                                      color: AppTheme.accentGold, 
                                      fontSize: 14,
                                      decoration: TextDecoration.underline,
                                    ),
                                    recognizer: TapGestureRecognizer()
                                      ..onTap = _showTermsDialog,
                                  ),
                                ],
                              ),
                            ),
                            value: _acceptedTerms,
                            activeColor: AppTheme.accentGold,
                            checkColor: Colors.black,
                            onChanged: (newValue) {
                              setState(() {
                                _acceptedTerms = newValue ?? false;
                              });
                            },
                            controlAffinity: ListTileControlAffinity.leading,
                          ),
                          
                          const SizedBox(height: 30),
                          
                          // Register button
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
                                onPressed: _handleRegister,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.transparent,
                                  shadowColor: Colors.transparent,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                                child: const Text(
                                  'CREAR CUENTA',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: 1.2,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    ),
    );
  }
}