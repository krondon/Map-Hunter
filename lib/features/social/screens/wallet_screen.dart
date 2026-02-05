import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../auth/providers/player_provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/animated_cyber_background.dart';
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

class WalletScreen extends StatefulWidget {
  const WalletScreen({super.key});

  @override
  State<WalletScreen> createState() => _WalletScreenState();
}

class _WalletScreenState extends State<WalletScreen> {
  final TextEditingController _amountController = TextEditingController();
  bool _isLoading = false;

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final playerProvider = Provider.of<PlayerProvider>(context);


    final player = playerProvider.currentPlayer;
    final cloverBalance = player?.clovers ?? 0;

    return Scaffold(
      backgroundColor: AppTheme.darkBg,
      extendBody: true,
      bottomNavigationBar: _buildBottomNavBar(),
      body: AnimatedCyberBackground(
        child: SafeArea(
          child: Column(
            children: [
              // Custom AppBar
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
                      text: "MapHunter",
                      fontSize: 22,
                    ),
                  ],
                ),
              ),

              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    children: [
                      // Balance Card with Custom Clover Icon
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 20),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              const Color(0xFF10B981).withOpacity(0.3),
                              const Color(0xFF059669).withOpacity(0.2),
                            ],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(30),
                          border: Border.all(
                            color: const Color(0xFF10B981).withOpacity(0.5),
                            width: 2,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFF10B981).withOpacity(0.3),
                              blurRadius: 30,
                              spreadRadius: 5,
                            ),
                          ],
                        ),
                        child: Column(
                          children: [
                            const Text(
                              'TRÉBOLES',
                              style: TextStyle(
                                color: Colors.white70,
                                fontSize: 12,
                                letterSpacing: 4,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            const SizedBox(height: 6),
                            
                            // Custom Clover Icon (4-leaf clover made with circles)
                            Transform.scale(
                              scale: 0.6,
                              child: _buildCustomCloverIcon(),
                            ),
                            
                            const SizedBox(height: 6),
                            
                            // Balance Amount
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.baseline,
                              textBaseline: TextBaseline.alphabetic,
                              children: [
                                Text(
                                  cloverBalance.toString(),
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 36,
                                    fontWeight: FontWeight.w900,
                                    height: 1,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            // Massive Conversion info
                            const SizedBox(height: 12),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                              decoration: BoxDecoration(
                                color: AppTheme.accentGold.withOpacity(0.15),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(color: AppTheme.accentGold.withOpacity(0.3)),
                              ),
                              child: const Text(
                                '1 🍀 = 1\$',
                                style: TextStyle(
                                  color: AppTheme.accentGold,
                                  fontSize: 22,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 1,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),


                      const SizedBox(height: 40),

                      // Action Buttons
                      Row(
                        children: [
                          Expanded(
                            child: _buildActionButton(
                              icon: Icons.add_circle_outline,
                              label: 'RECARGAR',
                              color: AppTheme.accentGold,
                              onTap: () => _showRechargeDialog(),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: _buildActionButton(
                              icon: Icons.remove_circle_outline,
                              label: 'RETIRAR',
                              color: AppTheme.secondaryPink,
                              onTap: () => _showWithdrawDialog(),
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 40),

                      // Transaction History Section (Placeholder -> Entry Point)
                      GestureDetector(
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const TransactionHistoryScreen(),
                            ),
                          );
                        },
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(24),
                          decoration: BoxDecoration(
                            color: AppTheme.cardBg.withOpacity(0.5),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: Colors.white.withOpacity(0.1),
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Row(
                                    children: [
                                      Icon(
                                        Icons.history,
                                        color: AppTheme.accentGold,
                                        size: 20,
                                      ),
                                      const SizedBox(width: 8),
                                      const Text(
                                        'HISTORIAL DE TRANSACCIONES',
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontSize: 12,
                                          fontWeight: FontWeight.bold,
                                          letterSpacing: 1,
                                        ),
                                      ),
                                    ],
                                  ),
                                  Icon(
                                    Icons.arrow_forward_ios,
                                    color: Colors.white.withOpacity(0.3),
                                    size: 14,
                                  ),
                                ],
                              ),
                              const SizedBox(height: 20),
                              const Center(
                                child: Text(
                                  'Ver historial completo y pendientes',
                                  style: TextStyle(
                                    color: Colors.white38,
                                    fontSize: 14,
                                  ),
                                ),
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
        ),
      ),
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
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 20),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              color.withOpacity(0.3),
              color.withOpacity(0.1),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: color.withOpacity(0.5),
            width: 2,
          ),
          boxShadow: [
            BoxShadow(
              color: color.withOpacity(0.2),
              blurRadius: 15,
              spreadRadius: 1,
            ),
          ],
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 32),
            const SizedBox(height: 8),
            Text(
              label,
              style: TextStyle(
                color: color,
                fontSize: 14,
                fontWeight: FontWeight.bold,
                letterSpacing: 1,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showRechargeDialog() async {
    final playerProvider = Provider.of<PlayerProvider>(context, listen: false);
    
    // Refresh profile to ensure we have the latest DNI/Phone data from DB
    // This is critical to skip the form if data exists.
    setState(() => _isLoading = true);
    await playerProvider.refreshProfile();
    setState(() => _isLoading = false);

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
            
            setState(() => _isLoading = true);
            try {
              // Check if user has a payment method
              final methods = await Supabase.instance.client
                  .from('user_payment_methods')
                  .select('id')
                  .eq('user_id', player.userId)
                  .limit(1);
                  
              if (!mounted) return;
              setState(() => _isLoading = false);

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
    
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
            backgroundColor: AppTheme.cardBg,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
              side: BorderSide(color: AppTheme.accentGold.withOpacity(0.3)),
            ),
            title: Row(
              children: [
                Icon(Icons.add_circle, color: AppTheme.accentGold),
                const SizedBox(width: 12),
                const Text(
                  'Comprar Tréboles',
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            content: SizedBox(
              width: double.maxFinite,
              child: FutureBuilder<List<CloverPlan>>(
                future: CloverPlanService(
                  supabaseClient: Supabase.instance.client,
                ).fetchActivePlans(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const SizedBox(
                      height: 200,
                      child: Center(
                        child: CircularProgressIndicator(color: AppTheme.accentGold),
                      ),
                    );
                  }
                  
                  if (snapshot.hasError) {
                    return SizedBox(
                      height: 100,
                      child: Center(
                        child: Text(
                          'Error cargando planes: ${snapshot.error}',
                          style: const TextStyle(color: Colors.redAccent),
                        ),
                      ),
                    );
                  }
                  
                  final plans = snapshot.data ?? [];
                  if (plans.isEmpty) {
                    return const SizedBox(
                      height: 100,
                      child: Center(
                        child: Text(
                          'No hay planes disponibles',
                          style: TextStyle(color: Colors.white70),
                        ),
                      ),
                    );
                  }
                  
                  return Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Selecciona un plan de tréboles:',
                        style: TextStyle(color: Colors.white70),
                      ),
                      const SizedBox(height: 16),
                      // Plan Cards Grid
                      Wrap(
                        spacing: 12,
                        runSpacing: 12,
                        children: plans.map((plan) {
                          return SizedBox(
                            width: (MediaQuery.of(context).size.width - 140) / 2,
                            child: CloverPlanCard(
                              plan: plan,
                              isSelected: selectedPlanId == plan.id,
                              onTap: () {
                                setState(() => selectedPlanId = plan.id);
                              },
                            ),
                          );
                        }).toList(),
                      ),
                      if (_isLoading)
                        const Padding(
                          padding: EdgeInsets.only(top: 20.0),
                          child: Center(
                            child: CircularProgressIndicator(color: AppTheme.accentGold),
                          ),
                        ),
                    ],
                  );
                },
              ),
            ),
            actions: [
              TextButton(
                onPressed: _isLoading ? null : () => Navigator.pop(ctx),
                child: const Text('Cancelar', style: TextStyle(color: Colors.white60)),
              ),
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
                  disabledBackgroundColor: Colors.grey.withOpacity(0.3),
                ),
                child: const Text('Pagar'),
              ),
            ],
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
        builder: (ctx) => Padding(
          padding: EdgeInsets.only(top: MediaQuery.of(context).size.height * 0.1),
          child: ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
            child: PaymentWebViewModal(paymentUrl: paymentUrl),
          ),
        ),
      );

      if (result == true) {
         if (!mounted) return;
         ScaffoldMessenger.of(context).showSnackBar(
           const SnackBar(
             content: Text('¡Pago Exitoso! Verificando saldo...'),
             backgroundColor: AppTheme.successGreen,
           ),
         );
         
         await Future.delayed(const Duration(seconds: 2));
         if (mounted) {
            await Provider.of<PlayerProvider>(context, listen: false).refreshProfile();
         }
      } else {
         if (!mounted) return;
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

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
            backgroundColor: AppTheme.cardBg,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
              side: BorderSide(color: AppTheme.secondaryPink.withOpacity(0.3)),
            ),
            title: Row(
              children: [
                const Icon(Icons.monetization_on, color: AppTheme.secondaryPink),
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
              child: FutureBuilder<List<WithdrawalPlan>>(
                future: WithdrawalPlanService(
                  supabaseClient: Supabase.instance.client,
                ).fetchActivePlans(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const SizedBox(
                      height: 200,
                      child: Center(
                        child: CircularProgressIndicator(color: AppTheme.secondaryPink),
                      ),
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

                  final plans = snapshot.data ?? [];
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
                      const Text(
                        'Selecciona cuántos tréboles quieres retirar:',
                        style: TextStyle(color: Colors.white70),
                      ),
                      const SizedBox(height: 16),
                      // Plan Cards
                      ...plans.map((plan) {
                        final isSelected = selectedPlanId == plan.id;
                        return GestureDetector(
                          onTap: () => setState(() => selectedPlanId = plan.id),
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
                        );
                      }).toList(),
                      if (_isLoading)
                        const Padding(
                          padding: EdgeInsets.only(top: 16),
                          child: Center(
                            child: CircularProgressIndicator(color: AppTheme.secondaryPink),
                          ),
                        ),
                    ],
                  );
                },
              ),
            ),
            actions: [
              TextButton(
                onPressed: _isLoading ? null : () => Navigator.pop(ctx),
                child: const Text('Cancelar', style: TextStyle(color: Colors.white60)),
              ),
              ElevatedButton(
                onPressed: (_isLoading || selectedPlanId == null)
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
                child: const Text('Confirmar Retiro', style: TextStyle(color: Colors.white)),
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
        // Refresh balance
        await Provider.of<PlayerProvider>(context, listen: false).refreshProfile();
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
