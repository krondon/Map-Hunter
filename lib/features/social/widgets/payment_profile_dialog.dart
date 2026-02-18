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
    
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 30),
      child: Container(
        padding: const EdgeInsets.all(2),
        decoration: BoxDecoration(
          color: AppTheme.accentGold.withOpacity(0.2),
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: AppTheme.accentGold.withOpacity(0.35), width: 1),
        ),
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: const Color(0xFF151517),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppTheme.accentGold, width: 1.5),
            boxShadow: [
              BoxShadow(
                color: AppTheme.accentGold.withOpacity(0.1),
                blurRadius: 15,
                spreadRadius: 2,
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppTheme.accentGold.withOpacity(0.1),
                      border: Border.all(color: AppTheme.accentGold.withOpacity(0.5)),
                    ),
                    child: const Icon(Icons.person_pin, color: AppTheme.accentGold, size: 24),
                  ),
                  const SizedBox(width: 15),
                  const Text(
                    'COMPLETAR DATOS',
                    style: TextStyle(
                      color: AppTheme.accentGold,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.5,
                      fontFamily: 'Orbitron',
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              
              const Text(
                'Para realizar operaciones de pago móvil, necesitamos completar tu perfil con datos válidos.',
                style: TextStyle(color: Colors.white70, fontSize: 13, height: 1.4),
              ),
              const SizedBox(height: 24),
              
              Form(
                key: _formKey,
                child: Column(
                  children: [
                    // Document Type & DNI Row
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Document Type Dropdown
                        Container(
                          width: 85,
                          margin: const EdgeInsets.only(right: 12),
                          child: DropdownButtonFormField<String>(
                            value: _documentType,
                            dropdownColor: const Color(0xFF1C1C1E),
                            style: const TextStyle(color: Colors.white),
                            decoration: _inputDecoration('Tipo', true),
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
                            style: const TextStyle(color: Colors.white),
                            decoration: _inputDecoration('Cédula / RIF (Números)', true),
                            validator: (value) {
                              if (value == null || value.isEmpty) return 'Requerido';
                              if (value.length < 5) return 'Inválido';
                              return null;
                            },
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 18),
                    
                    // Phone Input
                    TextFormField(
                      controller: _phoneController,
                      keyboardType: TextInputType.phone,
                      style: const TextStyle(color: Colors.white),
                      decoration: _inputDecoration('Teléfono (04141234567)', true),
                      validator: (value) {
                        if (value == null || value.isEmpty) return 'Requerido';
                        if (value.length < 10) return 'Teléfono inválido';
                        return null;
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),
              
              // Actions
              Row(
                children: [
                  Expanded(
                    child: TextButton(
                      onPressed: _isLoading ? null : () => Navigator.pop(context, false),
                      child: const Text(
                        'CANCELAR',
                        style: TextStyle(color: Colors.white54, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : _saveProfile,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.accentGold,
                        foregroundColor: Colors.black,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        elevation: 0,
                      ),
                      child: _isLoading 
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(Colors.black),
                            ),
                          )
                        : const Text(
                            'GUARDAR',
                            style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1.0),
                          ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  InputDecoration _inputDecoration(String label, bool isDarkMode) {
    return InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(color: Colors.white60),
      filled: true,
      fillColor: const Color(0xFF1C1C1E),
      enabledBorder: OutlineInputBorder(
        borderSide: BorderSide(color: Colors.white.withOpacity(0.1)),
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
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
    );
  }
}
