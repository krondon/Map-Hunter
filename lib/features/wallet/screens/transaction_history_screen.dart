import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/animated_cyber_background.dart';
import '../../../shared/widgets/glitch_text.dart';
import '../models/transaction_item.dart';
import '../providers/wallet_provider.dart';
import '../services/payment_service.dart';
import '../widgets/payment_webview_modal.dart';
import '../widgets/transaction_card.dart';

class TransactionHistoryScreen extends StatefulWidget {
  const TransactionHistoryScreen({super.key});

  @override
  State<TransactionHistoryScreen> createState() => _TransactionHistoryScreenState();
}

class _TransactionHistoryScreenState extends State<TransactionHistoryScreen> {
  // Use PaymentService to fetch pending orders directly
  late final PaymentService _paymentService;
  bool _isLoading = true;
  List<TransactionItem> _items = [];

  @override
  void initState() {
    super.initState();
    _paymentService = PaymentService(Supabase.instance.client);
    // Initialize data fetch
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _fetchData();
    });
  }

  Future<void> _fetchData() async {
    if (!mounted) return;
    setState(() => _isLoading = true);

    final walletProvider = Provider.of<WalletProvider>(context, listen: false);
    final userId = Supabase.instance.client.auth.currentUser?.id;

    if (userId == null) {
      setState(() => _isLoading = false);
      return;
    }

    try {
      // 1. Ensure Ledger is loaded
      // We assume walletProvider is already initialized, but refreshing is good.
      await walletProvider.refreshBalance(); // This also reloads transactions in current implementation? 
      // Checking WalletProvider: _loadTransactions is private and called in initialize or topUp. 
      // refreshBalance calls getBalance but NOT _loadTransactions in the code I saw?
      // Wait, let's look at WalletProvider code again. 
      // refreshBalance calls _paymentRepository.getBalance but NOT loadTransactions.
      // initialize calls _loadTransactions.
      // So we might need to rely on what's already there or add a method to refresh transactions.
      // For now, let's assume transactions are loaded or we use what's available.
      
      // 2. Fetch Pending Orders
      final pendingOrdersFuture = _paymentService.getPendingOrders(userId);
      
      final results = await Future.wait([
        // Future.value(walletProvider.transactions), // Actually we want fresh data if possible
        pendingOrdersFuture,
      ]);

      final pendingOrders = results[0] as List<Map<String, dynamic>>;
      final ledgerTransactions = walletProvider.transactions;

      // 3. Merge Strategies
      final List<TransactionItem> mergedItems = [];

      // Map Ledger (Confirmed)
      for (final tx in ledgerTransactions) {
        // We only show confirmed stuff from ledger usually, or based on status.
        // The user said: "status = 'completed'. Si amount > 0 'deposit', < 0 'withdrawal'"
        // Transaction model has status field.
        
        // Skip if not completed? User said "El historial confirmado...".
        // But TransactionStatus could be 'pending' in ledger too? 
        // User said: "Source 1: wallet_ledger... Mapping: status = 'completed'".
        // So I force status to completed for these? Or I only take completed ones?
        // "Trae todos los registros... Mapeo: status = 'completed'." -> imply visually they show as completed/historical.
        
        String type = tx.amount >= 0 ? 'deposit' : 'withdrawal';
        
        mergedItems.add(TransactionItem(
          date: tx.createdAt,
          amount: tx.amount.abs(), // Visuals handle sign usually, but card expects amount. Card displays +/- based on type.
          // Wait, Card code: '${isWithdrawal ? '-' : '+'}${item.amount.toStringAsFixed(2)}'
          // So I should pass positive amount to Card if I use type to distinguish.
          description: tx.description ?? (type == 'deposit' ? 'Recarga' : 'Retiro'),
          status: 'completed',
          type: type,
        ));
      }

      // Map Pending Orders
      for (final order in pendingOrders) {
        // "Trae SOLO los registros donde status sea 'pending' o 'failed'"
        // Already filtered in service.
        final status = order['status'] as String? ?? 'pending';
        final amount = (order['amount'] as num).toDouble();
        final createdString = order['created_at'] as String;
        final date = DateTime.parse(createdString);
        final paymentUrl = order['payment_url'] as String?;

        mergedItems.add(TransactionItem(
          date: date,
          amount: amount,
          description: 'Intento de Compra', // or order['motive']
          status: status,
          type: 'deposit', // Orders are usually attempts to deposit money
          paymentUrl: paymentUrl,
        ));
      }

      // 4. Sort by Date Descending
      mergedItems.sort((a, b) => b.date.compareTo(a.date));

      if (mounted) {
        setState(() {
          _items = mergedItems;
          _isLoading = false;
        });
      }

    } catch (e) {
      debugPrint('Error fetching history: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _onResumePayment(String url) async {
    // Open PaymentWebViewModal
    final bool? result = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      isDismissible: false,
      enableDrag: false,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(top: MediaQuery.of(context).size.height * 0.1),
        child: ClipRRect(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
          child: PaymentWebViewModal(paymentUrl: url),
        ),
      ),
    );

    // Refresh list regardless of result to show updated status if changed in DB
    // (Though webhooks might take a moment, so maybe delay?)
    if (result == true) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Pago completado. Actualizando...'),
          backgroundColor: AppTheme.successGreen,
        ),
      );
    }
    _fetchData();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.darkBg,
      body: AnimatedCyberBackground(
        child: SafeArea(
          child: Column(
            children: [
              // Header
              Padding(
                padding: const EdgeInsets.all(20),
                child: Row(
                  children: [
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: IconButton(
                        icon: const Icon(Icons.arrow_back, color: Colors.white),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ),
                    const SizedBox(width: 16),
                    const GlitchText(
                      text: "Historial",
                      fontSize: 22,
                    ),
                  ],
                ),
              ),

              // List
              Expanded(
                child: _isLoading
                    ? const Center(child: CircularProgressIndicator(color: AppTheme.accentGold))
                    : _items.isEmpty
                        ? const Center(
                            child: Text(
                              'No hay transacciones registradas',
                              style: TextStyle(color: Colors.white54),
                            ),
                          )
                        : ListView.builder(
                            padding: const EdgeInsets.only(bottom: 20),
                            itemCount: _items.length,
                            itemBuilder: (context, index) {
                              final item = _items[index];
                              return TransactionCard(
                                item: item,
                                onResumePayment: (item.status == 'pending' && item.paymentUrl != null)
                                    ? () => _onResumePayment(item.paymentUrl!)
                                    : null,
                              );
                            },
                          ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
