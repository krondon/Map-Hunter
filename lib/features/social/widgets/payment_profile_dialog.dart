import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../auth/providers/player_provider.dart';
import '../../../shared/widgets/loading_indicator.dart';
import '../../../core/theme/app_theme.dart';

class PaymentProfileDialog extends StatefulWidget {
  const PaymentProfileDialog({super.key});

  @override
  State<PaymentProfileDialog> createState() => _PaymentProfileDialogState();
}

class _PaymentProfileDialogState extends State<PaymentProfileDialog> {
  final _formKey = GlobalKey<FormState>();
  String _documentType = 'V';
  final TextEditingController _dniController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    // Pre-fill user data if available
    final player = Provider.of<PlayerProvider>(context, listen: false).currentPlayer;
    if (player != null) {
      if (player.documentType != null) {
         _documentType = player.documentType!;
      }
      if (player.cedula != null) {
         _dniController.text = player.cedula!;
      }
      if (player.phone != null) {
         _phoneController.text = player.phone!;
      }
    }
  }

  @override
  void dispose() {
    _dniController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);
    
    final fullDni = '$_documentType${_dniController.text.trim()}';

    try {
      await Provider.of<PlayerProvider>(context, listen: false).updateProfile(
        cedula: fullDni,
        phone: _phoneController.text.trim(),
      );

      if (mounted) {
        Navigator.pop(context, true); // Return true on success
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Perfil de pago actualizado'),
            backgroundColor: AppTheme.successGreen,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: AppTheme.dangerRed,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final playerProvider = Provider.of<PlayerProvider>(context);
    final isDarkMode = playerProvider.isDarkMode;
    
    return AlertDialog(
      backgroundColor: isDarkMode ? AppTheme.cardBg : Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: AppTheme.accentGold.withOpacity(0.3)),
      ),
      title: Row(
        children: [
          const Icon(Icons.person_pin, color: AppTheme.accentGold),
          const SizedBox(width: 12),
          Text(
            'Completar Datos',
            style: TextStyle(color: isDarkMode ? Colors.white : const Color(0xFF1A1A1D), fontWeight: FontWeight.bold),
          ),
        ],
      ),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Para realizar operaciones de pago móvil, necesitamos completar tu perfil.',
                style: TextStyle(color: isDarkMode ? Colors.white70 : const Color(0xFF4A4A5A), fontSize: 13),
              ),
              const SizedBox(height: 20),
              
              // Document Type & DNI Row
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Document Type Dropdown
                  Container(
                    width: 70,
                    margin: const EdgeInsets.only(right: 12),
                    child: DropdownButtonFormField<String>(
                      value: _documentType,
                      dropdownColor: isDarkMode ? AppTheme.cardBg : Colors.white,
                      style: TextStyle(color: isDarkMode ? Colors.white : const Color(0xFF1A1A1D)),
                      decoration: _inputDecoration('Tipo', isDarkMode),
                      items: ['V', 'E', 'J', 'G'].map((type) {
                        return DropdownMenuItem(
                          value: type,
                          child: Text(type),
                        );
                      }).toList(),
                      onChanged: (val) {
                        if (val != null) setState(() => _documentType = val);
                      },
                    ),
                  ),
                  
                  // DNI Input
                  Expanded(
                    child: TextFormField(
                      controller: _dniController,
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      style: TextStyle(color: isDarkMode ? Colors.white : const Color(0xFF1A1A1D)),
                      decoration: _inputDecoration('Cédula / RIF (Solo números)', isDarkMode),
                      validator: (value) {
                        if (value == null || value.isEmpty) return 'Requerido';
                        if (value.length < 5) return 'Inválido';
                        return null;
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              
              // Phone Input
              TextFormField(
                controller: _phoneController,
                keyboardType: TextInputType.phone,
                style: TextStyle(color: isDarkMode ? Colors.white : const Color(0xFF1A1A1D)),
                decoration: _inputDecoration('Teléfono (04141234567)', isDarkMode),
                validator: (value) {
                  if (value == null || value.isEmpty) return 'Requerido';
                  if (value.length < 10) return 'Teléfono inválido';
                  return null;
                },
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isLoading ? null : () => Navigator.pop(context, false),
          child: Text('Cancelar', style: TextStyle(color: isDarkMode ? Colors.white60 : Colors.black45)),
        ),
        ElevatedButton(
          onPressed: _isLoading ? _saveProfile : _saveProfile,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppTheme.accentGold,
            foregroundColor: Colors.black,
          ),
          child: _isLoading 
            ? const LoadingIndicator(fontSize: 10, color: Colors.black)
            : const Text('Guardar y Continuar'),
        ),
      ],
    );
  }

  InputDecoration _inputDecoration(String label, bool isDarkMode) {
    return InputDecoration(
      labelText: label,
      labelStyle: TextStyle(color: isDarkMode ? Colors.white60 : Colors.black54),
      enabledBorder: OutlineInputBorder(
        borderSide: BorderSide(color: (isDarkMode ? Colors.white : Colors.black).withOpacity(0.2)),
        borderRadius: BorderRadius.circular(10),
      ),
      focusedBorder: OutlineInputBorder(
        borderSide: const BorderSide(color: AppTheme.accentGold),
        borderRadius: BorderRadius.circular(10),
      ),
      errorBorder: OutlineInputBorder(
        borderSide: const BorderSide(color: AppTheme.dangerRed),
        borderRadius: BorderRadius.circular(10),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderSide: const BorderSide(color: AppTheme.dangerRed),
        borderRadius: BorderRadius.circular(10),
      ),
    );
  }
}
