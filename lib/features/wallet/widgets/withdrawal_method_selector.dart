import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/theme/app_theme.dart';
import 'add_withdrawal_method_dialog.dart';

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
  List<Map<String, dynamic>> _methods = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadMethods();
  }

  Future<void> _loadMethods() async {
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) return;

    setState(() => _isLoading = true);
    try {
      final response = await Supabase.instance.client
          .from('user_payment_methods')
          .select()
          .eq('user_id', userId)
          .order('created_at', ascending: false);

      if (mounted) {
        setState(() {
          _methods = List<Map<String, dynamic>>.from(response);
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error cargando métodos: $e')),
        );
      }
    }
  }

  Future<void> _deleteMethod(String id) async {
    try {
      await Supabase.instance.client.from('user_payment_methods').delete().eq('id', id);
      await _loadMethods();
      if (_selectedMethodId == id) {
        setState(() => _selectedMethodId = null);
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error eliminando método: $e')),
      );
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
          if (_isLoading)
            const Center(child: CircularProgressIndicator(color: AppTheme.accentGold))
          else if (_methods.isEmpty)
            Center(
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
            )
          else
            Flexible(
              child: ListView.separated(
                shrinkWrap: true,
                itemCount: _methods.length,
                separatorBuilder: (_, __) => const SizedBox(height: 8),
                itemBuilder: (context, index) {
                  final method = _methods[index];
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
                      trailing: IconButton(
                        icon: const Icon(Icons.delete_outline,
                            color: Colors.white38),
                        onPressed: () => _deleteMethod(method['id']),
                      ),
                    ),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }
}
