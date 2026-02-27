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
    {'code': '0104', 'name': 'Venezolano de Crédito'},
    {'code': '0105', 'name': 'Banco Mercantil'},
    {'code': '0108', 'name': 'Banco Provincial'},
    {'code': '0114', 'name': 'Bancaribe'},
    {'code': '0115', 'name': 'Banco Exterior'},
    {'code': '0128', 'name': 'Banco Caroní'},
    {'code': '0134', 'name': 'Banesco'},
    {'code': '0137', 'name': 'Banco Sofitasa'},
    {'code': '0138', 'name': 'Banco Plaza'},
    {'code': '0151', 'name': 'BFC Fondo Común'},
    {'code': '0156', 'name': '100% Banco'},
    {'code': '0157', 'name': 'DelSur'},
    {'code': '0163', 'name': 'Banco del Tesoro'},
    {'code': '0166', 'name': 'Banco Agrícola de Venezuela'},
    {'code': '0168', 'name': 'Bancrecer'},
    {'code': '0169', 'name': 'Mi Banco'},
    {'code': '0171', 'name': 'Banco Activo'},
    {'code': '0172', 'name': 'Bancamiga'},
    {'code': '0174', 'name': 'Banplus'},
    {'code': '0175', 'name': 'Banco Bicentenario'},
    {'code': '0177', 'name': 'BANFANB'},
    {'code': '0178', 'name': 'N58 Banco Digital'},
    {'code': '0191', 'name': 'Banco Nacional de Crédito'},
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
      await playerProvider.addPaymentMethod(bankCode: _selectedBankCode!);

      if (mounted) {
        Navigator.pop(context, true);
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
    final player = playerProvider.currentPlayer;
    final dni = player?.cedula ?? 'No definido';
    final phone = player?.phone ?? 'No definido';

    return Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      child: Container(
        padding: const EdgeInsets.all(2),
        decoration: BoxDecoration(
          color: AppTheme.accentGold.withOpacity(0.1),
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: AppTheme.accentGold.withOpacity(0.2), width: 1),
        ),
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: const Color(0xFF151517),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppTheme.accentGold.withOpacity(0.5), width: 1.5),
          ),
          constraints: const BoxConstraints(maxWidth: 400),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppTheme.accentGold.withOpacity(0.1),
                        shape: BoxShape.circle,
                        border: Border.all(color: AppTheme.accentGold.withOpacity(0.3)),
                      ),
                      child: const Icon(Icons.account_balance_rounded, color: AppTheme.accentGold, size: 20),
                    ),
                    const SizedBox(width: 15),
                    const Text(
                      'AÑADIR PAGO MÓVIL',
                      style: TextStyle(
                        color: Colors.white, 
                        fontWeight: FontWeight.bold, 
                        fontSize: 15,
                        fontFamily: 'Orbitron',
                        letterSpacing: 1.2,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Se vincularán estos datos para tus retiros:',
                        style: TextStyle(color: Colors.white70, fontSize: 12),
                      ),
                      const SizedBox(height: 20),
                      _buildInfoRow(Icons.badge, 'CÉDULA', dni, true),
                      const SizedBox(height: 12),
                      _buildInfoRow(Icons.phone_android, 'TELÉFONO', phone, true),
                      const SizedBox(height: 24),
                      DropdownButtonFormField<String>(
                        dropdownColor: const Color(0xFF1C1C1E),
                        style: const TextStyle(color: Colors.white, fontSize: 14),
                        hint: const Text(
                          'Selecciona tu banco',
                          style: TextStyle(color: Colors.white60, fontSize: 14),
                        ),
                        decoration: _inputDecoration('Banco Emisor', true),
                        value: _selectedBankCode,
                        isExpanded: true,
                        menuMaxHeight: 300,
                        selectedItemBuilder: (BuildContext context) {
                          return _banks.map<Widget>((bank) {
                            return Text(
                              '${bank['code']} - ${bank['name']}',
                              style: const TextStyle(color: Colors.white),
                              overflow: TextOverflow.ellipsis,
                            );
                          }).toList();
                        },
                        items: _banks.map((bank) {
                          return DropdownMenuItem(
                            value: bank['code'],
                            child: Text(
                              '${bank['code']} - ${bank['name']}',
                              style: const TextStyle(color: Colors.white),
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
                const SizedBox(height: 32),
                Row(
                  children: [
                    Expanded(
                      child: TextButton(
                        onPressed: _isLoading ? null : () => Navigator.pop(context, false),
                        child: const Text('CANCELAR', style: TextStyle(color: Colors.white54, fontWeight: FontWeight.bold, fontSize: 12)),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: _isLoading ? null : _saveMethod,
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
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black),
                            )
                          : const Text('GUARDAR', style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1.0)),
                      ),
                    ),
                  ],
                ),
              ],
            ),
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
