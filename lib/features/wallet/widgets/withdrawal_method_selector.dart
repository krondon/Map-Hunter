import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../core/theme/app_theme.dart';
import '../providers/payment_method_provider.dart';
import '../../auth/providers/player_provider.dart';
import 'add_withdrawal_method_dialog.dart';
import 'edit_payment_method_dialog.dart';

/// Pure UI Widget for selecting withdrawal methods
/// 
/// Responsibilities:
/// - Display list of payment methods
/// - Handle user interactions (select, delete, add)
/// - Delegate all business logic to PaymentMethodProvider
class WithdrawalMethodSelector extends StatefulWidget {
  final Function(Map<String, dynamic>) onMethodSelected;

  const WithdrawalMethodSelector({
    super.key,
    required this.onMethodSelected,
  });

  @override
  State<WithdrawalMethodSelector> createState() => _WithdrawalMethodSelectorState();
}

class _WithdrawalMethodSelectorState extends State<WithdrawalMethodSelector> {
  String? _selectedMethodId;

  @override
  void initState() {
    super.initState();
    _loadMethods();
  }

  Future<void> _loadMethods() async {
    final playerProvider = Provider.of<PlayerProvider>(context, listen: false);
    final paymentProvider = Provider.of<PaymentMethodProvider>(context, listen: false);
    
    final userId = playerProvider.currentPlayer?.userId;
    if (userId != null) {
      await paymentProvider.loadMethods(userId);
    }
  }

  Future<void> _deleteMethod(String id) async {
    final playerProvider = Provider.of<PlayerProvider>(context, listen: false);
    final paymentProvider = Provider.of<PaymentMethodProvider>(context, listen: false);
    
    final userId = playerProvider.currentPlayer?.userId;
    if (userId == null) return;

    final success = await paymentProvider.deleteMethod(id, userId);
    
    if (!success && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(paymentProvider.error ?? 'Error eliminando método')),
      );
    }
    
    if (_selectedMethodId == id) {
      setState(() => _selectedMethodId = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: const BoxDecoration(
        color: AppTheme.cardBg,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Selecciona Método de Retiro',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              IconButton(
                icon: const Icon(Icons.add_circle, color: AppTheme.accentGold),
                onPressed: () async {
                  final result = await showDialog(
                    context: context,
                    builder: (_) => const AddWithdrawalMethodDialog(),
                  );
                  if (result == true) {
                    _loadMethods();
                  }
                },
              ),
            ],
          ),
          const SizedBox(height: 16),
          Consumer<PaymentMethodProvider>(
            builder: (context, provider, child) {
              if (provider.isLoading) {
                return const Center(
                  child: CircularProgressIndicator(color: AppTheme.accentGold),
                );
              }

              if (provider.methods.isEmpty) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 20),
                    child: Column(
                      children: [
                        const Icon(Icons.account_balance_wallet_outlined,
                            size: 48, color: Colors.white24),
                        const SizedBox(height: 12),
                        const Text(
                          'No tienes métodos registrados',
                          style: TextStyle(color: Colors.white60),
                        ),
                        TextButton(
                          onPressed: () async {
                            final result = await showDialog(
                              context: context,
                              builder: (_) => const AddWithdrawalMethodDialog(),
                            );
                            if (result == true) {
                              _loadMethods();
                            }
                          },
                          child: const Text('Agregar Pago Móvil',
                              style: TextStyle(color: AppTheme.accentGold)),
                        ),
                      ],
                    ),
                  ),
                );
              }

              return Flexible(
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: provider.methods.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (context, index) {
                    final method = provider.methods[index];
                    final isSelected = _selectedMethodId == method['id'];
                    final bankCode = method['bank_code'] ?? '???';
                    final phone = method['phone_number'] ?? '???';
                    
                    return Container(
                      decoration: BoxDecoration(
                        color: isSelected
                            ? AppTheme.accentGold.withOpacity(0.1)
                            : Colors.white.withOpacity(0.05),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isSelected
                              ? AppTheme.accentGold
                              : Colors.white.withOpacity(0.1),
                        ),
                      ),
                      child: ListTile(
                        onTap: () {
                          setState(() => _selectedMethodId = method['id']);
                          widget.onMethodSelected(method);
                        },
                        leading: const Icon(Icons.phone_android,
                            color: AppTheme.secondaryPink),
                        title: Text(
                          'Pago Móvil - Banco $bankCode',
                          style: const TextStyle(
                              color: Colors.white, fontWeight: FontWeight.bold),
                        ),
                        subtitle: Text(
                          phone,
                          style: const TextStyle(color: Colors.white70),
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            GestureDetector(
                              onTap: () {}, // Bubble block
                              child: IconButton(
                                icon: const Icon(Icons.edit_outlined, color: Colors.white38),
                                onPressed: () async {
                                  final result = await showDialog(
                                    context: context,
                                    builder: (_) => EditPaymentMethodDialog(method: method),
                                  );
                                  if (result == true) {
                                    _loadMethods();
                                  }
                                },
                              ),
                            ),
                            GestureDetector(
                               onTap: () {}, // Bubble block
                               child: IconButton(
                                icon: const Icon(Icons.delete_outline,
                                    color: Colors.white38),
                                onPressed: () => _deleteMethod(method['id']),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}
