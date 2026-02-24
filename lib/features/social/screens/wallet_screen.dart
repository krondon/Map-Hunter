import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../auth/providers/player_provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/animated_cyber_background.dart';
import '../../../shared/widgets/loading_indicator.dart';
import '../../../shared/widgets/loading_overlay.dart';
import '../../wallet/widgets/payment_webview_modal.dart'; // Added
import 'profile_screen.dart';
import '../../game/screens/scenarios_screen.dart';
import '../../../shared/widgets/glitch_text.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/services/pago_a_pago_service.dart';
import '../../../core/models/pago_a_pago_models.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import '../widgets/payment_profile_dialog.dart';
import '../widgets/payment_method_selector.dart';
import '../widgets/add_payment_method_dialog.dart';
import '../../wallet/widgets/withdrawal_method_selector.dart';
import '../../wallet/screens/transaction_history_screen.dart';
import '../../wallet/models/clover_plan.dart';
import '../../wallet/services/clover_plan_service.dart';
import '../../wallet/widgets/clover_plan_card.dart';
import '../../wallet/models/withdrawal_plan.dart';
import '../../wallet/services/withdrawal_plan_service.dart';
import '../../../core/services/app_config_service.dart';
import '../../wallet/models/transaction_item.dart';
import '../../wallet/repositories/transaction_repository.dart';
import '../../wallet/widgets/transaction_card.dart';
import '../../wallet/providers/payment_method_provider.dart';
import '../../wallet/widgets/edit_payment_method_dialog.dart';

class WalletScreen extends StatefulWidget {
  final bool hideScaffold;
  const WalletScreen({super.key, this.hideScaffold = false});

  @override
  State<WalletScreen> createState() => _WalletScreenState();
}

class _WalletScreenState extends State<WalletScreen> {
  final TextEditingController _amountController = TextEditingController();
  bool _isLoading = false;
  
  // History State
  final ITransactionRepository _transactionRepository = SupabaseTransactionRepository();
  List<TransactionItem> _recentTransactions = [];
  bool _isLoadingHistory = true;

  @override
  void initState() {
    super.initState();
    _loadRecentTransactions();
    _loadPaymentMethods();
  }

  Future<void> _loadPaymentMethods() async {
    final userId = Provider.of<PlayerProvider>(context, listen: false).currentPlayer?.userId;
    if (userId != null) {
      await Provider.of<PaymentMethodProvider>(context, listen: false).loadMethods(userId);
    }
  }

  Future<void> _loadRecentTransactions() async {
    try {
      final txs = await _transactionRepository.getMyTransactions(limit: 5);
      if (mounted) {
        setState(() {
          _recentTransactions = txs;
          _isLoadingHistory = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoadingHistory = false);
      debugPrint("Error loading history: $e");
    }
  }

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final playerProvider = Provider.of<PlayerProvider>(context);

    // FORCED TO TRUE: Always use dark mode colors in wallet, even in day mode
    final isDarkMode = true; // Previously: playerProvider.isDarkMode;
    final player = playerProvider.currentPlayer;
    final cloverBalance = player?.clovers ?? 0;

    final mainColumn = SafeArea(
          child: Column(
            children: [
              // Custom AppBar
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 0),
                child: SizedBox(
                  height: 60,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      // Back Button on the left
                      if (!widget.hideScaffold)
                        Positioned(
                          left: 0,
                          child: Container(
                            decoration: BoxDecoration(
                              color: isDarkMode ? Colors.white.withOpacity(0.1) : Colors.black.withOpacity(0.05),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: IconButton(
                              icon: Icon(Icons.arrow_back, color: isDarkMode ? Colors.white : Colors.black87),
                              onPressed: () => Navigator.pop(context),
                            ),
                          ),
                        ),
                      
                      // WALLET TITLE - Restored to center
                      const Text(
                        'WALLET',
                        style: TextStyle(
                          color: AppTheme.accentGold,
                          fontFamily: 'Orbitron',
                          fontSize: 22,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 2.0,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 10),
                      // Balance Card with Custom Clover Icon - GLASSMORPISM STYLE
                      ClipRRect(
                        borderRadius: BorderRadius.circular(34),
                        child: BackdropFilter(
                          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                          child: Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              color: const Color(0xFF10B981).withOpacity(0.25),
                              borderRadius: BorderRadius.circular(34),
                              border: Border.all(
                                color: const Color(0xFF10B981).withOpacity(0.6),
                                width: 1.5,
                              ),
                            ),
                            child: Container(
                              padding: const EdgeInsets.all(24),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(30),
                                border: Border.all(
                                  color: const Color(0xFF10B981).withOpacity(0.2),
                                  width: 1.0,
                                ),
                                color: const Color(0xFF10B981).withOpacity(0.02),
                              ),
                              child: Column(
                                children: [
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        'TRÉBOLES:',
                                        style: TextStyle(
                                          color: isDarkMode ? Colors.white : Colors.black87,
                                          fontSize: 20,
                                          fontWeight: FontWeight.w900,
                                          letterSpacing: 1.2,
                                          fontFamily: 'Orbitron',
                                        ),
                                      ),
                                      Flexible(
                                        child: FittedBox(
                                          fit: BoxFit.scaleDown,
                                          alignment: Alignment.centerRight,
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Text(
                                                cloverBalance.toString(),
                                                style: TextStyle(
                                                  color: isDarkMode ? Colors.white : Colors.black87,
                                                  fontSize: 42,
                                                  fontWeight: FontWeight.w900,
                                                ),
                                              ),
                                              const SizedBox(width: 8),
                                              const Text(
                                                "🍀",
                                                style: TextStyle(fontSize: 28),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),


                      const SizedBox(height: 40),

                      // Action Buttons
                      Row(
                        children: [
                          Expanded(
                            child: Opacity(
                              opacity: _isLoading ? 0.5 : 1.0,
                              child: _buildActionButton(
                                icon: Icons.add_circle_outline,
                                label: 'RECARGAR',
                                color: AppTheme.accentGold,
                                onTap: _isLoading ? () {} : () => _showRechargeDialog(),
                              ),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Opacity(
                              opacity: _isLoading ? 0.5 : 1.0,
                              child: _buildActionButton(
                                icon: Icons.remove_circle_outline,
                                label: 'RETIRAR',
                                color: AppTheme.secondaryPink,
                                onTap: _isLoading ? () {} : () => _showWithdrawDialog(),
                              ),
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 40),

                      // Recent Transactions Section - PREVIOUS STYLE (DOUBLE BORDER)
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(28),
                          border: Border.all(
                            color: Colors.white.withOpacity(0.2),
                            width: 1,
                          ),
                        ),
                        child: Container(
                          padding: const EdgeInsets.all(24),
                          decoration: BoxDecoration(
                            color: Colors.black.withOpacity(0.6),
                            borderRadius: BorderRadius.circular(24),
                            border: Border.all(
                              color: Colors.white.withOpacity(0.3),
                              width: 2,
                            ),
                          ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(8),
                                      decoration: BoxDecoration(
                                        color: AppTheme.accentGold.withOpacity(0.1),
                                        shape: BoxShape.circle,
                                        border: Border.all(color: AppTheme.accentGold.withOpacity(0.2)),
                                      ),
                                      child: const Icon(
                                        Icons.history,
                                        color: AppTheme.accentGold,
                                        size: 16,
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Text(
                                      'HISTORIAL RECIENTE',
                                      style: TextStyle(
                                        color: isDarkMode ? Colors.white : Colors.black87,
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                        fontFamily: 'Orbitron',
                                        letterSpacing: 1.0,
                                      ),
                                    ),
                                    const Spacer(),
                                    TextButton(
                                      onPressed: () {
                                        Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder: (_) => const TransactionHistoryScreen(),
                                          ),
                                        ).then((_) => _loadRecentTransactions());
                                      },
                                      child: const Text(
                                        'Ver Todo',
                                        style: TextStyle(
                                          color: AppTheme.accentGold,
                                          fontSize: 11,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 24),
                            
                            if (_isLoadingHistory)
                               const Center(child: LoadingIndicator(fontSize: 14))
                            else if (_recentTransactions.isEmpty)
                              Center(
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(vertical: 20.0),
                                  child: Text(
                                    'No hay transacciones recientes',
                                    style: TextStyle(color: isDarkMode ? Colors.white38 : Colors.black38),
                                  ),
                                ),
                              )
                            else
                              ListView.separated(
                                shrinkWrap: true,
                                physics: const NeverScrollableScrollPhysics(),
                                itemCount: _recentTransactions.length,
                                separatorBuilder: (_, __) => const SizedBox(height: 8),
                                itemBuilder: (context, index) {
                                  // Use standard TransactionCard but perhaps slightly more compact if needed
                                  // For now, using the standard one is consistent.
                                  return TransactionCard(
                                    item: _recentTransactions[index],
                                    // We can disable buttons here if we want strictly read-only preview
                                    // or allow resume functionality. I'll allow resume.
                                    onResumePayment: _recentTransactions[index].canResumePayment
                                        ? () async {
                                           // Navigate to Full History for context
                                           Navigator.push(
                                              context,
                                              MaterialPageRoute(
                                                builder: (_) => const TransactionHistoryScreen(),
                                              ),
                                            ).then((_) => _loadRecentTransactions());
                                          }
                                        : null,
                                    onCancelOrder: _recentTransactions[index].canCancel
                                        ? () async {
                                            // Cancel Logic with Confirmation
                                            final confirm = await showDialog<bool>(
                                              context: context,
                                              builder: (context) => AlertDialog(
                                                backgroundColor: isDarkMode ? AppTheme.cardBg : Colors.white,
                                                title: Text('Cancelar Orden', style: TextStyle(color: isDarkMode ? Colors.white : const Color(0xFF1A1A1D))),
                                                content: Text(
                                                  '¿Estás seguro de que quieres cancelar esta orden pendiente?',
                                                  style: TextStyle(color: isDarkMode ? Colors.white70 : const Color(0xFF4A4A5A)),
                                                ),
                                                actions: [
                                                  TextButton(
                                                    onPressed: () => Navigator.pop(context, false),
                                                    child: const Text('No', style: TextStyle(color: Colors.white54)),
                                                  ),
                                                  TextButton(
                                                    onPressed: () => Navigator.pop(context, true),
                                                    child: const Text('Sí, Cancelar', style: TextStyle(color: AppTheme.dangerRed)),
                                                  ),
                                                ],
                                              ),
                                            );
                                            
                                            if (confirm != true) return;
 
                                            setState(() => _isLoadingHistory = true);
                                            final success = await _transactionRepository.cancelOrder(_recentTransactions[index].id);
                                            if (mounted) {
                                              ScaffoldMessenger.of(context).showSnackBar(
                                                SnackBar(
                                                  content: Text(success ? 'Orden cancelada' : 'Error al cancelar'),
                                                  backgroundColor: success ? AppTheme.successGreen : AppTheme.dangerRed,
                                                ),
                                              );
                                              _loadRecentTransactions();
                                            }
                                          }
                                        : null,
                                  );
                                },
                               ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
    );

    final content = widget.hideScaffold 
        ? mainColumn 
        : AnimatedCyberBackground(child: mainColumn);

    if (widget.hideScaffold) return content;

    return Scaffold(
      backgroundColor: const Color(0xFF151517),
      extendBody: true,
      bottomNavigationBar: _buildBottomNavBar(),
      body: content,
    );
  }

  Widget _buildCustomCloverIcon() {
    return SizedBox(
      width: 80,
      height: 80,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Top leaf
          Positioned(
            top: 0,
            child: Container(
              width: 30,
              height: 30,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    const Color(0xFF10B981),
                    const Color(0xFF059669),
                  ],
                ),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF10B981).withOpacity(0.6),
                    blurRadius: 10,
                  ),
                ],
              ),
            ),
          ),
          // Right leaf
          Positioned(
            right: 0,
            child: Container(
              width: 30,
              height: 30,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    const Color(0xFF10B981),
                    const Color(0xFF059669),
                  ],
                ),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF10B981).withOpacity(0.6),
                    blurRadius: 10,
                  ),
                ],
              ),
            ),
          ),
          // Bottom leaf
          Positioned(
            bottom: 0,
            child: Container(
              width: 30,
              height: 30,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    const Color(0xFF10B981),
                    const Color(0xFF059669),
                  ],
                ),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF10B981).withOpacity(0.6),
                    blurRadius: 10,
                  ),
                ],
              ),
            ),
          ),
          // Left leaf
          Positioned(
            left: 0,
            child: Container(
              width: 30,
              height: 30,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    const Color(0xFF10B981),
                    const Color(0xFF059669),
                  ],
                ),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF10B981).withOpacity(0.6),
                    blurRadius: 10,
                  ),
                ],
              ),
            ),
          ),
          // Center
          Container(
            width: 20,
            height: 20,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: const Color(0xFF34D399),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF10B981).withOpacity(0.8),
                  blurRadius: 15,
                  spreadRadius: 2,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: color.withOpacity(0.25),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: color.withOpacity(0.6),
                width: 1.5,
              ),
            ),
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: color.withOpacity(0.2),
                  width: 1.0,
                ),
                color: color.withOpacity(0.02),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: color.withOpacity(0.2),
                      shape: BoxShape.circle,
                      border: Border.all(color: color.withOpacity(0.4)),
                    ),
                    child: Icon(icon, color: color, size: 16),
                  ),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      label,
                      style: TextStyle(
                        fontFamily: 'Orbitron',
                        color: color,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.5,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _showRechargeDialog() async {
    if (_isLoading) return; // Debounce prevention
    final playerProvider = Provider.of<PlayerProvider>(context, listen: false);
    
    // Refresh profile to ensure we have the latest DNI/Phone data from DB
    // This is critical to skip the form if data exists.
    LoadingOverlay.show(context);
    await playerProvider.refreshProfile();
    if (mounted) LoadingOverlay.hide(context);

    final player = playerProvider.currentPlayer;
    if (player == null) return;

    // 1. Validate Profile
    if (!player.hasCompletePaymentProfile) {
       final bool? success = await showDialog(
         context: context,
         barrierDismissible: false,
         builder: (_) => const PaymentProfileDialog()
       );
       
       if (success != true) return; // User cancelled or failed
    }
    
    // 2. Select Method
    if (!mounted) return;
    
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => PaymentMethodSelector(
        onMethodSelected: (methodId) async {
          Navigator.pop(ctx);
            if (methodId == 'pago_movil') {
            
            LoadingOverlay.show(context);
            try {
              // Check if user has a payment method
              final methods = await Supabase.instance.client
                  .from('user_payment_methods')
                  .select('id')
                  .eq('user_id', player.userId)
                  .limit(1);
                  
              if (!mounted) return;
              LoadingOverlay.hide(context);

              if (methods.isEmpty) {
                // Show Add Dialog
                final bool? success = await showDialog(
                  context: context,
                  barrierDismissible: false,
                  builder: (_) => const AddPaymentMethodDialog()
                );
                
                if (success == true) {
                   _showPlanSelectorDialog();
                }
              } else {
                 _showPlanSelectorDialog();
              }
            } catch (e) {
              if (mounted) setState(() => _isLoading = false);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Error validando métodos: $e')),
              );
            }

          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Método no disponible por el momento')),
            );
          }
        }
      )
    );
  }

  void _showPlanSelectorDialog() {
    String? selectedPlanId;
    
    // Combined future to fetch plans and gateway fee together
    final configService = AppConfigService(supabaseClient: Supabase.instance.client);
    final combinedFuture = Future.wait([
      CloverPlanService(supabaseClient: Supabase.instance.client).fetchActivePlans(),
      configService.getGatewayFeePercentage(),
    ]);
    
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setState) {
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
                      // Title
                      Row(
                        children: [
                          Icon(Icons.add_circle, color: AppTheme.accentGold, size: 22),
                          const SizedBox(width: 12),
                          const Text(
                            'Comprar Tréboles',
                            style: TextStyle(
                              color: Colors.white, 
                              fontWeight: FontWeight.bold, 
                              fontSize: 18,
                              fontFamily: 'Orbitron',
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      
                      const Text(
                        'Selecciona un plan de tréboles:',
                        style: TextStyle(color: Colors.white70, fontSize: 13),
                      ),
                      const SizedBox(height: 16),

                      FutureBuilder<List<dynamic>>(
                        future: combinedFuture,
                        builder: (context, snapshot) {
                          if (snapshot.connectionState == ConnectionState.waiting) {
                            return const SizedBox(
                              height: 150,
                              child: LoadingIndicator(),
                            );
                          }
                          
                          if (snapshot.hasError) {
                            return Center(
                              child: Text(
                                'Error: ${snapshot.error}',
                                style: const TextStyle(color: Colors.redAccent, fontSize: 12),
                              ),
                            );
                          }
                          
                          final plans = (snapshot.data?[0] as List<CloverPlan>?) ?? [];
                          
                          // Ensure specific order: Basico, Pro (top) and Elite (bottom)
                          // Sorting by quantity: 50, 150, 500
                          plans.sort((a, b) => a.cloversQuantity.compareTo(b.cloversQuantity));
                          
                          final gatewayFee = (snapshot.data?[1] as double?) ?? 0.0;
                          
                          // Helper to build a plan card with consistent styling
                          Widget buildPlanItem(CloverPlan plan) {
                            return CloverPlanCard(
                              plan: plan,
                              isSelected: selectedPlanId == plan.id,
                              feePercentage: gatewayFee,
                              onTap: () {
                                setState(() => selectedPlanId = plan.id);
                              },
                            );
                          }

                          return Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (gatewayFee > 0) ...[
                                Container(
                                  width: double.infinity,
                                  padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                                  decoration: BoxDecoration(
                                    color: Colors.orange.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(color: Colors.orange.withOpacity(0.6), width: 1.2),
                                  ),
                                  child: Column(
                                    children: [
                                      const Text(
                                        'Nota:',
                                        style: TextStyle(
                                          color: Colors.orangeAccent, 
                                          fontWeight: FontWeight.w900, 
                                          fontSize: 14,
                                          letterSpacing: 1.0,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        'La pasarela cobra el ${gatewayFee.toStringAsFixed(0)}% de comisión',
                                        style: const TextStyle(
                                          color: Colors.orangeAccent, 
                                          fontSize: 13,
                                          fontWeight: FontWeight.w600,
                                        ),
                                        textAlign: TextAlign.center,
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 24),
                              ],

                              if (plans.length >= 3)
                                Column(
                                  children: [
                                    // Row 1: Basico & Pro
                                    Row(
                                      children: [
                                        Expanded(child: buildPlanItem(plans[0])),
                                        const SizedBox(width: 12),
                                        Expanded(child: buildPlanItem(plans[1])),
                                      ],
                                    ),
                                    const SizedBox(height: 12),
                                    // Row 2: Elite (Centered)
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        SizedBox(
                                          width: 150, // Fixed width for the last one to stay centered
                                          child: buildPlanItem(plans[2]),
                                        ),
                                      ],
                                    ),
                                  ],
                                )
                              else
                                // Fallback for fewer plans
                                Wrap(
                                  alignment: WrapAlignment.center,
                                  spacing: 12,
                                  runSpacing: 12,
                                  children: plans.map((p) => SizedBox(width: 150, child: buildPlanItem(p))).toList(),
                                ),
                            ],
                          );
                        },
                      ),
                      
                      const SizedBox(height: 32),

                      // Actions
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          TextButton(
                            onPressed: _isLoading ? null : () => Navigator.pop(ctx),
                            child: const Text('Cancelar', style: TextStyle(color: Colors.white54, fontWeight: FontWeight.bold)),
                          ),
                          const SizedBox(width: 12),
                          ElevatedButton(
                            onPressed: (_isLoading || selectedPlanId == null) ? null : () async {
                              setState(() => _isLoading = true);
                              await _initiatePayment(context, selectedPlanId!);
                              if (mounted) {
                                setState(() => _isLoading = false);
                                Navigator.pop(ctx);
                              }
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppTheme.accentGold,
                              foregroundColor: Colors.black,
                              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              elevation: 0,
                            ),
                            child: _isLoading 
                              ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black))
                              : const Text('Pagar', style: TextStyle(fontWeight: FontWeight.bold)),
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
      ),
    );
  }

  /// Initiates payment with selected plan ID.
  /// 
  /// The Edge Function validates the plan and retrieves the true price from the database.
  Future<void> _initiatePayment(BuildContext context, String planId) async {
    final playerProvider = Provider.of<PlayerProvider>(context, listen: false);
    final user = playerProvider.currentPlayer;
    
    if (user == null) {
       ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Error: No hay usuario autenticado.')),
      );
      return;
    }

    try {
      debugPrint('[WalletScreen] Initiating payment for plan: $planId');
      
      // Call Edge Function directly with plan_id only (security: price validated server-side)
      final response = await Supabase.instance.client.functions.invoke(
        'api_pay_orders',
        body: {
          'plan_id': planId,
        },
      );

      if (!mounted) return;

      if (response.status != 200) {
        throw Exception('Error en servicio de pagos (${response.status}): ${response.data}');
      }

      final responseData = response.data;
      debugPrint('[WalletScreen] RAW RESPONSE: $responseData');

      if (responseData == null) {
         throw Exception('Respuesta vacía del servicio de pagos');
      }
      
      if (responseData['success'] == false) {
         throw Exception('API Error: ${responseData['message'] ?? responseData['error'] ?? "Unknown error"}');
      }

      // Parse response
      final Map<String, dynamic> dataObj = responseData['data'] ?? responseData['result'] ?? responseData;
      final String? paymentUrl = dataObj['payment_url']?.toString() ?? dataObj['url']?.toString();

      if (paymentUrl == null || paymentUrl.isEmpty) {
        throw Exception('URL de pago no recibida');
      }

      if (!mounted) return;

      // Open WebView as a Modal Bottom Sheet
      final bool? result = await showModalBottomSheet<bool>(
        context: context,
        isScrollControlled: true,
        isDismissible: false,
        enableDrag: false,
        backgroundColor: Colors.transparent,
        builder: (ctx) => SafeArea(
          child: Padding(
            padding: EdgeInsets.only(
              top: MediaQuery.of(context).padding.top + 20,
            ),
            child: ClipRRect(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
              child: PaymentWebViewModal(paymentUrl: paymentUrl),
            ),
          ),
        ),
      );

      if (result == true) {
         if (!mounted) return;
        //  ScaffoldMessenger.of(context).showSnackBar(
        //    const SnackBar(
        //      content: Text('¡Pago Exitoso! Verificando saldo...'),
        //      backgroundColor: AppTheme.successGreen,
        //    ),
        //  );
         
         await Future.delayed(const Duration(seconds: 2));
         if (mounted) {
            await Provider.of<PlayerProvider>(context, listen: false).refreshProfile();
            await _loadRecentTransactions(); // Refresh history to show success/pending
         }
      } else {
         if (!mounted) return;
         // Refresh anyway to show the pending order if it was created
         _loadRecentTransactions();
         ScaffoldMessenger.of(context).showSnackBar(
           const SnackBar(content: Text('Operación cancelada o pendiente.')),
         );
      }
    } catch (e) {
      debugPrint('[WalletScreen] Payment error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: AppTheme.dangerRed,
          )
        );
      }
    }
  }

  void _showWithdrawDialog() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => WithdrawalMethodSelector(
        onMethodSelected: (method) {
          Navigator.pop(ctx);
          // Allow bottom sheet animation to finish
          Future.delayed(const Duration(milliseconds: 300), () {
            if (mounted) _showWithdrawPlanDialog(method);
          });
        },
      ),
    );
  }

  void _showWithdrawPlanDialog(Map<String, dynamic> method) {
    String? selectedPlanId;
    final bankCode = method['bank_code'] ?? '???';
    final phone = method['phone_number'] ?? '???';

    // Combined future: check rate validity AND load plans in parallel
    final configService = AppConfigService(supabaseClient: Supabase.instance.client);
    final combinedFuture = Future.wait([
      WithdrawalPlanService(supabaseClient: Supabase.instance.client).fetchActivePlans(),
      configService.isBcvRateValid(),
    ]);

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
            backgroundColor: const Color(0xFF1A1A1D),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(24),
              side: const BorderSide(color: AppTheme.secondaryPink, width: 1),
            ),
            title: Row(
              children: [
                const Icon(Icons.publish_rounded, color: AppTheme.secondaryPink, size: 28),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Retirar Tréboles',
                        style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                      Text(
                        'A: $bankCode - $phone',
                        style: const TextStyle(color: Colors.white60, fontSize: 12),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            content: SizedBox(
              width: double.maxFinite,
              child: FutureBuilder<List<dynamic>>(
                future: combinedFuture,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const SizedBox(
                      height: 200,
                      child: LoadingIndicator(color: AppTheme.secondaryPink),
                    );
                  }

                  if (snapshot.hasError) {
                    return SizedBox(
                      height: 100,
                      child: Center(
                        child: Text(
                          'Error: ${snapshot.error}',
                          style: const TextStyle(color: Colors.redAccent),
                        ),
                      ),
                    );
                  }

                  final plans = (snapshot.data?[0] as List<WithdrawalPlan>?) ?? [];
                  final isRateValid = (snapshot.data?[1] as bool?) ?? false;

                  if (plans.isEmpty) {
                    return const SizedBox(
                      height: 100,
                      child: Center(
                        child: Text(
                          'No hay planes de retiro disponibles',
                          style: TextStyle(color: Colors.white70),
                        ),
                      ),
                    );
                  }

                  return Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // ── FAIL-SAFE: Maintenance Banner ──
                      if (!isRateValid) ...[
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.red.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: Colors.redAccent.withOpacity(0.5)),
                          ),
                          child: const Row(
                            children: [
                              Icon(Icons.warning_amber_rounded, color: Colors.redAccent, size: 22),
                              SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  'El sistema de cambio está en mantenimiento temporal. Los retiros no están disponibles en este momento.',
                                  style: TextStyle(color: Colors.redAccent, fontSize: 12, fontWeight: FontWeight.w500),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),
                      ],
                      const Text(
                        'Selecciona cuántos tréboles quieres retirar:',
                        style: TextStyle(color: Colors.white70),
                      ),
                      const SizedBox(height: 16),
                      // Plan Cards
                      ...plans.map((plan) {
                        final isSelected = selectedPlanId == plan.id;
                        return GestureDetector(
                          onTap: isRateValid
                              ? () => setState(() => selectedPlanId = plan.id)
                              : null, // Disable selection when rate is stale
                          child: Opacity(
                            opacity: isRateValid ? 1.0 : 0.5,
                            child: Container(
                              margin: const EdgeInsets.only(bottom: 12),
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? AppTheme.secondaryPink.withOpacity(0.2)
                                    : Colors.white.withOpacity(0.05),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: isSelected
                                      ? AppTheme.secondaryPink
                                      : Colors.white.withOpacity(0.1),
                                  width: isSelected ? 2 : 1,
                                ),
                              ),
                              child: Row(
                                children: [
                                  // Icon
                                  Container(
                                    width: 48,
                                    height: 48,
                                    decoration: BoxDecoration(
                                      color: AppTheme.secondaryPink.withOpacity(0.2),
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: Center(
                                      child: Text(
                                        plan.icon ?? '💸',
                                        style: const TextStyle(fontSize: 24),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  // Info
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          plan.name,
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontWeight: FontWeight.bold,
                                            fontSize: 16,
                                          ),
                                        ),
                                        Text(
                                          'Costo: ${plan.cloversCost} 🍀',
                                          style: const TextStyle(
                                            color: Colors.white60,
                                            fontSize: 14,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  // Amount
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    children: [
                                      Text(
                                        plan.formattedAmountUsd,
                                        style: TextStyle(
                                          color: isSelected ? AppTheme.secondaryPink : Colors.white,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 18,
                                        ),
                                      ),
                                      const Text(
                                        'USD',
                                        style: TextStyle(color: Colors.white54, fontSize: 12),
                                      ),
                                    ],
                                  ),
                                  // Check
                                  if (isSelected) ...[
                                    const SizedBox(width: 8),
                                    const Icon(Icons.check_circle, color: AppTheme.secondaryPink),
                                  ],
                                ],
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                      if (_isLoading)
                        const Padding(
                          padding: EdgeInsets.only(top: 16),
                          child: LoadingIndicator(color: AppTheme.secondaryPink, fontSize: 14),
                        ),
                    ],
                  );
                },
              ),
            ),
            actions: [
              TextButton(
                onPressed: _isLoading ? null : () => Navigator.pop(ctx),
                child: const Text(
                  'Cancelar', 
                  style: TextStyle(
                    color: Colors.white54, 
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
              ),
              FutureBuilder<List<dynamic>>(
                future: combinedFuture,
                builder: (context, snapshot) {
                  final isRateValid = (snapshot.data?[1] as bool?) ?? false;
                  return ElevatedButton(
                    onPressed: (_isLoading || selectedPlanId == null || !isRateValid)
                        ? null
                        : () async {
                            setState(() => _isLoading = true);
                            await _processWithdrawalWithPlan(context, selectedPlanId!, method);
                            if (mounted) {
                              setState(() => _isLoading = false);
                              Navigator.pop(ctx);
                            }
                          },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.secondaryPink,
                      disabledBackgroundColor: Colors.grey.withOpacity(0.3),
                    ),
                    child: Text(
                      isRateValid ? 'Confirmar Retiro' : 'En Mantenimiento',
                      style: const TextStyle(color: Colors.white),
                    ),
                  );
                },
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _processWithdrawal(BuildContext context, double amount,
      Map<String, dynamic> method) async {
    try {
      final playerProvider =
          Provider.of<PlayerProvider>(context, listen: false);
      final balance = playerProvider.currentPlayer?.clovers ?? 0;

      if (balance < amount) throw Exception("Saldo insuficiente");

      final apiKey = dotenv.env['PAGO_PAGO_API_KEY'] ?? '';
      final service = PagoAPagoService(apiKey: apiKey);
      final token = Supabase.instance.client.auth.currentSession?.accessToken;

      if (token == null) throw Exception("No hay sesión activa");

      // Construct STRICT Request based on User Payment Method
      final request = WithdrawalRequest(
        amount: amount,
        bank: method['bank_code'],
        dni: method['dni'], // From saved method (which came from profile)
        phone: method['phone_number'], // From saved method
        cta: null, // Mobile Payment only
      );

      final response = await service.withdrawFunds(request, token);

      if (!mounted) return;

      if (response.success) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('¡Retiro exitoso!'),
            backgroundColor: AppTheme.successGreen));
        // Refresh logic would go here
      } else {
        throw Exception(response.message);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('Error: $e'), backgroundColor: AppTheme.dangerRed));
      }
    }
  }

  /// Process withdrawal using a withdrawal plan ID.
  /// 
  /// Sends plan_id to api_withdraw_funds Edge Function which handles:
  /// - Fetching plan details from withdrawal_plans table
  /// - Converting USD to VES using exchange rate from app_config
  /// - Validating clover balance
  /// - Processing the payment
  Future<void> _processWithdrawalWithPlan(
      BuildContext context, String planId, Map<String, dynamic> method) async {
    try {
      debugPrint('[WalletScreen] Processing withdrawal with plan: $planId');

      final response = await Supabase.instance.client.functions.invoke(
        'api_withdraw_funds',
        body: {
          'plan_id': planId,
          'bank': method['bank_code'],
          'dni': method['dni'],
          'phone': method['phone_number'],
        },
      );

      if (!mounted) return;

      if (response.status != 200) {
        final errorData = response.data;
        throw Exception(errorData?['error'] ?? 'Error en el servidor (${response.status})');
      }

      final data = response.data;
      if (data?['success'] == true) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('¡Retiro procesado exitosamente!'),
          backgroundColor: AppTheme.successGreen,
        ));
        // Refresh balance and history
        await Provider.of<PlayerProvider>(context, listen: false).refreshProfile();
        _loadRecentTransactions();
      } else {
        throw Exception(data?['error'] ?? 'Error desconocido');
      }
    } catch (e) {
      debugPrint('[WalletScreen] Withdrawal error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Error: $e'),
          backgroundColor: AppTheme.dangerRed,
        ));
      }
    }
  }

  InputDecoration _inputDecoration(String label, IconData icon) {
    return InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(color: Colors.white60),
      prefixIcon: Icon(icon, color: Colors.white60),
      enabledBorder: OutlineInputBorder(
        borderSide: BorderSide(color: Colors.white.withOpacity(0.3)),
        borderRadius: BorderRadius.circular(10),
      ),
      focusedBorder: OutlineInputBorder(
        borderSide: const BorderSide(color: AppTheme.secondaryPink),
        borderRadius: BorderRadius.circular(10),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
    );
  }

  Widget _buildBottomNavBar() {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      decoration: BoxDecoration(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _buildNavItem(0, Icons.weekend, 'Local'),
            _buildNavItem(1, Icons.explore, 'Escenarios'),
            _buildNavItem(2, Icons.account_balance_wallet, 'Recargas'),
            _buildNavItem(3, Icons.person, 'Perfil'),
          ],
        ),
      ),
    );
  }

  Widget _buildNavItem(int index, IconData icon, String label) {
    final isSelected = index == 2; // Recargas is always selected in this screen
    return GestureDetector(
      onTap: () {
        // Navigation logic
        switch (index) {
          case 0: // Local
            _showComingSoonDialog(label);
            break;
          case 1: // Escenarios
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                builder: (context) => const ScenariosScreen(),
              ),
            );
            break;
          case 2: // Recargas - already here
            break;
          case 3: // Perfil
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const ProfileScreen(),
              ),
            );
            break;
        }
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: EdgeInsets.symmetric(
          horizontal: isSelected ? 16 : 12,
          vertical: 8,
        ),
        decoration: BoxDecoration(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              color: isSelected ? AppTheme.accentGold : Colors.white54,
              size: isSelected ? 24 : 22,
            ),
            if (isSelected) ...[
              const SizedBox(width: 6),
              Text(
                label,
                style: const TextStyle(
                  color: AppTheme.accentGold,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  void _showComingSoonDialog(String featureName) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.cardBg,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: AppTheme.accentGold.withOpacity(0.3)),
        ),
        title: Row(
          children: [
            Icon(Icons.construction, color: AppTheme.accentGold),
            const SizedBox(width: 12),
            const Text(
              'Próximamente',
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        content: Text(
          'La sección "$featureName" estará disponible muy pronto. ¡Mantente atento a las actualizaciones!',
          style: const TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(
              'Entendido',
              style: TextStyle(color: AppTheme.accentGold),
            ),
          ),
        ],
      ),
    );
  }
}
