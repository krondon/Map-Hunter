import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../core/theme/app_theme.dart';
import '../../auth/providers/player_provider.dart';
import '../providers/payment_method_provider.dart';
import '../repositories/payment_method_repository.dart';

class EditPaymentMethodDialog extends StatefulWidget {
  final Map<String, dynamic> method;
  const EditPaymentMethodDialog({super.key, required this.method});

  @override
  State<EditPaymentMethodDialog> createState() => _EditPaymentMethodDialogState();
}

class _EditPaymentMethodDialogState extends State<EditPaymentMethodDialog> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _phoneController;
  late TextEditingController _dniController;
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
  void initState() {
    super.initState();
    _selectedBankCode = widget.method['bank_code'];
    _phoneController = TextEditingController(text: widget.method['phone_number'] ?? '');
    _dniController = TextEditingController(text: widget.method['dni'] ?? '');
  }

  @override
  void dispose() {
    _phoneController.dispose();
    _dniController.dispose();
    super.dispose();
  }

  Future<void> _updateMethod() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedBankCode == null) return;

    setState(() => _isLoading = true);

    try {
      final playerProvider = Provider.of<PlayerProvider>(context, listen: false);
      final paymentProvider = Provider.of<PaymentMethodProvider>(context, listen: false);
      final player = playerProvider.currentPlayer;

      if (player == null) throw Exception('Usuario no identificado');

      final data = PaymentMethodCreate(
        userId: player.userId,
        bankCode: _selectedBankCode!,
        phoneNumber: _phoneController.text.trim(),
        dni: _dniController.text.trim(),
        isDefault: widget.method['is_default'] ?? false,
      );

      final success = await paymentProvider.updateMethod(widget.method['id'], data);

      if (mounted) {
        if (success) {
          Navigator.pop(context, true);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Pago Móvil actualizado'),
              backgroundColor: AppTheme.successGreen,
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(paymentProvider.error ?? 'Error actualizando'),
              backgroundColor: AppTheme.dangerRed,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: AppTheme.dangerRed),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
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
                      child: const Icon(Icons.edit_note_rounded, color: AppTheme.accentGold, size: 20),
                    ),
                    const SizedBox(width: 15),
                    const Text(
                      'EDITAR PAGO MÓVIL',
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
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextFormField(
                        controller: _phoneController,
                        style: const TextStyle(color: Colors.white),
                        decoration: _inputDecoration('Número de Teléfono', Icons.phone_android),
                        validator: (v) => (v == null || v.isEmpty) ? 'Requerido' : null,
                      ),
                      const SizedBox(height: 20),
                      DropdownButtonFormField<String>(
                        dropdownColor: const Color(0xFF1C1C1E),
                        style: const TextStyle(color: Colors.white, fontSize: 14),
                        hint: const Text('Cambiar banco', style: TextStyle(color: Colors.white60)),
                        decoration: _inputDecoration('Selecciona Banco', Icons.account_balance),
                        value: _selectedBankCode,
                        isExpanded: true,
                        menuMaxHeight: 300,
                        items: _banks.map((bank) {
                          return DropdownMenuItem(
                            value: bank['code'],
                            child: Text('${bank['code']} - ${bank['name']}'),
                          );
                        }).toList(),
                        onChanged: (val) => setState(() => _selectedBankCode = val),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 32),
                Row(
                  children: [
                    Expanded(
                      child: TextButton(
                        onPressed: _isLoading ? null : () => Navigator.pop(context),
                        child: const Text('CANCELAR', style: TextStyle(color: Colors.white54, fontWeight: FontWeight.bold, fontSize: 12)),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: _isLoading ? null : _updateMethod,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.accentGold,
                          foregroundColor: Colors.black,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        child: _isLoading
                          ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black))
                          : const Text('ACTUALIZAR', style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1.0)),
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

  InputDecoration _inputDecoration(String label, IconData icon) {
    return InputDecoration(
      labelText: label,
      prefixIcon: Icon(icon, color: Colors.white38, size: 20),
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
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
    );
  }
}
