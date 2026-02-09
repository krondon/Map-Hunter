import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../auth/providers/player_provider.dart';
import '../../auth/services/auth_service.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/loading_indicator.dart';

class AddPaymentMethodDialog extends StatefulWidget {
  const AddPaymentMethodDialog({super.key});

  @override
  State<AddPaymentMethodDialog> createState() => _AddPaymentMethodDialogState();
}

class _AddPaymentMethodDialogState extends State<AddPaymentMethodDialog> {
  final _formKey = GlobalKey<FormState>();
  String? _selectedBankCode;
  bool _isLoading = false;

  final List<Map<String, String>> _banks = [
    {'code': '0102', 'name': 'Banco de Venezuela'},
    {'code': '0105', 'name': 'Banco Mercantil'},
    {'code': '0108', 'name': 'Banco Provincial'},
    {'code': '0134', 'name': 'Banesco'},
    {'code': '0114', 'name': 'Bancaribe'},
    {'code': '0115', 'name': 'Banco Exterior'},
    {'code': '0137', 'name': 'Banco Sofitasa'},
    {'code': '0151', 'name': 'BFC Fondo Común'},
    {'code': '0163', 'name': 'Banco del Tesoro'},
    {'code': '0128', 'name': 'Banco Caroní'},
    {'code': '0175', 'name': 'Banco Bicentenario'},
    {'code': '0191', 'name': 'Banco Nacional de Crédito'},
    {'code': '0172', 'name': 'Bancamiga'},
    {'code': '0171', 'name': 'Banco Activo'},
  ];

  @override
  void dispose() {
    super.dispose();
  }

  Future<void> _saveMethod() async {
    if (!_formKey.currentState!.validate()) return;
    
    if (_selectedBankCode == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Por favor selecciona un banco')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final playerProvider = Provider.of<PlayerProvider>(context, listen: false);
      
      // We pass the selected bank code here
      await playerProvider.addPaymentMethod(bankCode: _selectedBankCode!);

      if (mounted) {
        Navigator.pop(context, true); // Return true on success
         ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Método de pago agregado correctamente'),
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
    final player = playerProvider.currentPlayer;
    final dni = player?.cedula ?? 'No definido';
    final phone = player?.phone ?? 'No definido';

    return Dialog(
      backgroundColor: isDarkMode ? AppTheme.cardBg : Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: AppTheme.accentGold.withOpacity(0.3)),
      ),
      child: Container(
        padding: const EdgeInsets.all(20),
        constraints: BoxConstraints(
          maxWidth: 400,
          maxHeight: MediaQuery.of(context).size.height * 0.8, // Force scroll if too tall
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Title
              Row(
                children: [
                  const Icon(Icons.credit_card, color: AppTheme.accentGold),
                  const SizedBox(width: 12),
                  Text(
                    'Agregar Pago Móvil',
                    style: TextStyle(color: isDarkMode ? Colors.white : const Color(0xFF1A1A1D), fontWeight: FontWeight.bold, fontSize: 18),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // Content
              Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Se usará tu Cédula y Teléfono del perfil.',
                      style: TextStyle(color: isDarkMode ? Colors.white70 : const Color(0xFF4A4A5A), fontSize: 13),
                    ),
                    const SizedBox(height: 16),
        
                    // Read-only Info
                     _buildInfoRow(Icons.badge, 'Cédula', dni, isDarkMode),
                    const SizedBox(height: 12),
                    _buildInfoRow(Icons.phone_android, 'Teléfono', phone, isDarkMode),
                    
                    const SizedBox(height: 20),
                    
                    // Bank Dropdown
                    DropdownButtonFormField<String>(
                      dropdownColor: isDarkMode ? AppTheme.cardBg : Colors.white,
                      style: TextStyle(color: isDarkMode ? Colors.white : const Color(0xFF1A1A1D)),
                      decoration: _inputDecoration('Banco', isDarkMode),
                      value: _selectedBankCode,
                      isExpanded: true, // Fix horizontal overflow
                      menuMaxHeight: 300, // Limit menu height
                      items: _banks.map((bank) {
                        return DropdownMenuItem(
                          value: bank['code'],
                          child: Text(
                            '${bank['code']} - ${bank['name']}',
                            overflow: TextOverflow.ellipsis,
                          ),
                        );
                      }).toList(),
                      onChanged: (val) => setState(() => _selectedBankCode = val),
                       validator: (value) {
                        if (value == null || value.isEmpty) return 'Requerido';
                        return null;
                      },
                    ),
                  ],
                ),
              ),
              
              const SizedBox(height: 24),

              // Actions
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: _isLoading ? null : () => Navigator.pop(context, false),
                    child: Text('Cancelar', style: TextStyle(color: isDarkMode ? Colors.white60 : Colors.black45)),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: _isLoading ? null : _saveMethod,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.accentGold,
                      foregroundColor: Colors.black,
                    ),
                    child: _isLoading 
                      ? const LoadingIndicator(fontSize: 10, color: Colors.black)
                      : const Text('Guardar'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value, bool isDarkMode) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
      decoration: BoxDecoration(
        color: isDarkMode ? Colors.white.withOpacity(0.05) : Colors.black.withOpacity(0.05),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: isDarkMode ? Colors.white10 : Colors.black12),
      ),
      child: Row(
        children: [
          Icon(icon, color: isDarkMode ? Colors.white54 : Colors.black45, size: 20),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: TextStyle(color: isDarkMode ? Colors.white38 : Colors.black38, fontSize: 10)),
              Text(value, style: TextStyle(color: isDarkMode ? Colors.white : const Color(0xFF1A1A1D), fontWeight: FontWeight.bold)),
            ],
          ),
        ],
      ),
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
