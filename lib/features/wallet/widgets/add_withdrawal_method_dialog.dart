import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../../../core/theme/app_theme.dart';
import '../../auth/providers/player_provider.dart';
import '../providers/payment_method_provider.dart';
import '../repositories/payment_method_repository.dart';

/// Pure UI Dialog for adding withdrawal methods
/// 
/// Responsibilities:
/// - Display form for bank selection
/// - Validate user input
/// - Delegate creation to PaymentMethodProvider
class AddWithdrawalMethodDialog extends StatefulWidget {
  const AddWithdrawalMethodDialog({super.key});

  @override
  State<AddWithdrawalMethodDialog> createState() => _AddWithdrawalMethodDialogState();
}

class _AddWithdrawalMethodDialogState extends State<AddWithdrawalMethodDialog> {
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

  Future<void> _saveMethod() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedBankCode == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Selecciona un banco')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final playerProvider = Provider.of<PlayerProvider>(context, listen: false);
      final paymentProvider = Provider.of<PaymentMethodProvider>(context, listen: false);
      final player = playerProvider.currentPlayer;

      if (player == null) throw Exception('Usuario no identificado');
      if (player.cedula == null || player.phone == null) {
         throw Exception('Perfil incompleto (Faltan datos de identidad)');
      }

      final data = PaymentMethodCreate(
        userId: player.userId,
        bankCode: _selectedBankCode!,
        phoneNumber: player.phone!,
        dni: player.cedula!,
        isDefault: false,
      );

      final success = await paymentProvider.createMethod(data);

      if (mounted) {
        if (success) {
          Navigator.pop(context, true);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Método de retiro agregado'),
              backgroundColor: AppTheme.successGreen,
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(paymentProvider.error ?? 'Error desconocido'),
              backgroundColor: AppTheme.dangerRed,
            ),
          );
        }
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
    // READ ONLY DATA FROM PROFILE
    final player = Provider.of<PlayerProvider>(context, listen: false).currentPlayer;
    final dni = player?.cedula ?? '---';
    final phone = player?.phone ?? '---';

    return Dialog(
      backgroundColor: AppTheme.cardBg,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: AppTheme.accentGold.withOpacity(0.3)),
      ),
      child: Container(
        padding: const EdgeInsets.all(20),
        constraints: BoxConstraints(
          maxWidth: 400,
          maxHeight: MediaQuery.of(context).size.height * 0.8,
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Title
              Row(
                children: [
                  const Icon(Icons.add_card, color: AppTheme.accentGold),
                  const SizedBox(width: 12),
                  const Text(
                    'Agregar Pago Móvil',
                    style: TextStyle(
                        color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // Content
              Form(
                key: _formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppTheme.secondaryPink.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: AppTheme.secondaryPink.withOpacity(0.3)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.lock_outline,
                              color: AppTheme.secondaryPink, size: 20),
                          const SizedBox(width: 10),
                          const Expanded(
                            child: Text(
                              'Por seguridad, solo puedes retirar a cuentas asociadas a tu identidad registrada.',
                              style: TextStyle(color: Colors.white70, fontSize: 12),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
        
                    // READ ONLY FIELDS
                    _buildReadOnlyField('Cédula de Identidad', dni, Icons.badge),
                    const SizedBox(height: 12),
                    _buildReadOnlyField('Teléfono Móvil', phone, Icons.phone_android),
                    const SizedBox(height: 20),
        
                    // BANK SELECTOR
                    DropdownButtonFormField<String>(
                      dropdownColor: AppTheme.cardBg,
                      style: const TextStyle(color: Colors.white),
                      decoration: _inputDecoration('Banco'),
                      value: _selectedBankCode,
                      isExpanded: true,
                      menuMaxHeight: 300,
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
                    onPressed: _isLoading ? null : () => Navigator.pop(context),
                    child:
                        const Text('Cancelar', style: TextStyle(color: Colors.white60)),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: _isLoading ? null : _saveMethod,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.accentGold,
                      foregroundColor: Colors.black,
                    ),
                    child: _isLoading
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.black))
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

  Widget _buildReadOnlyField(String label, String value, IconData icon) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(color: Colors.white60, fontSize: 12)),
        const SizedBox(height: 4),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
          decoration: BoxDecoration(
            color: Colors.black38,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: Colors.white10),
          ),
          child: Row(
            children: [
              Icon(icon, color: Colors.white38, size: 20),
              const SizedBox(width: 12),
              Text(
                value,
                style: const TextStyle(
                    color: Colors.white70,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.5),
              ),
              const Spacer(),
              const Icon(Icons.lock, color: Colors.white24, size: 16),
            ],
          ),
        ),
      ],
    );
  }

  InputDecoration _inputDecoration(String label) {
    return InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(color: Colors.white60),
      enabledBorder: OutlineInputBorder(
        borderSide: BorderSide(color: Colors.white.withOpacity(0.3)),
        borderRadius: BorderRadius.circular(10),
      ),
      focusedBorder: OutlineInputBorder(
        borderSide: const BorderSide(color: AppTheme.accentGold),
        borderRadius: BorderRadius.circular(10),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
    );
  }
}
