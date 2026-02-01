import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../auth/providers/player_provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/animated_cyber_background.dart';
import 'profile_screen.dart';
import '../../game/screens/scenarios_screen.dart';
import '../../../shared/widgets/glitch_text.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/services/pago_a_pago_service.dart';
import '../../../core/models/pago_a_pago_models.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter/services.dart';

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

                      // Transaction History Section (Placeholder)
                      Container(
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
                            const SizedBox(height: 20),
                            const Center(
                              child: Text(
                                'No hay transacciones recientes',
                                style: TextStyle(
                                  color: Colors.white38,
                                  fontSize: 14,
                                ),
                              ),
                            ),
                          ],
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

  void _showRechargeDialog() {
    _amountController.clear();
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
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                   const Text(
                    'Ingresa la cantidad de tréboles que deseas comprar. (1 🍀 = 1\$)',
                    style: TextStyle(color: Colors.white70),
                  ),
                  const SizedBox(height: 20),
                  TextField(
                    controller: _amountController,
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly], // Only allow integers
                    style: const TextStyle(color: Colors.white),
                    onChanged: (val) => setState(() {}),
                    decoration: InputDecoration(
                      labelText: 'Cantidad (Enteros)',
                      labelStyle: const TextStyle(color: Colors.white60),
                      prefixIcon: const Icon(Icons.star, color: Colors.white60),
                      enabledBorder: OutlineInputBorder(
                        borderSide: BorderSide(color: Colors.white.withOpacity(0.3)),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderSide: const BorderSide(color: AppTheme.accentGold),
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                   // Calculation Display
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.black26,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.white10),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          "Estimado en Bolívares (Tasa Ref: 370.25):",
                          style: TextStyle(color: Colors.white54, fontSize: 12),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _amountController.text.isEmpty 
                              ? "0.00 VES"
                              : "${(int.tryParse(_amountController.text) ?? 0) * 370.25} VES",
                          style: const TextStyle(
                            color: AppTheme.accentGold, 
                            fontWeight: FontWeight.bold,
                            fontSize: 16
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (_isLoading)
                   const Padding(
                     padding: EdgeInsets.only(top: 20.0),
                     child: CircularProgressIndicator(color: AppTheme.accentGold),
                   ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: _isLoading ? null : () => Navigator.pop(ctx),
                child: const Text('Cancelar', style: TextStyle(color: Colors.white60)),
              ),
              ElevatedButton(
                onPressed: _isLoading ? null : () async {
                  final amount = int.tryParse(_amountController.text); // Validate Integer
                  if (amount == null || amount <= 0) {
                     ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Ingresa un monto entero válido > 0')),
                    );
                    return;
                  }

                  setState(() => _isLoading = true);
                  
                  // Iniciar proceso de pago (cast to double for compatibility)
                  await _initiatePayment(context, amount.toDouble());

                  if (mounted) {
                    setState(() => _isLoading = false);
                    Navigator.pop(ctx);
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.accentGold,
                  foregroundColor: Colors.black,
                ),
                child: const Text('Pagar'),
              ),
            ],
          );
        }
      ),
    );
  }

  Future<void> _initiatePayment(BuildContext context, double amount) async {
    final playerProvider = Provider.of<PlayerProvider>(context, listen: false);
    final user = playerProvider.currentPlayer;
    
    if (user == null) {
       ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Error: No hay usuario autenticado.')),
      );
      return;
    }

    try {
      final token = Supabase.instance.client.auth.currentSession?.accessToken;
      if (token == null) throw Exception("No hay sesión activa");

      // Instanciar servicio
      // La API KEY ya no es necesaria para llamar al Edge Function, pero el constructor la pide.
      // Podemos pasar un string vacío o el valor del env si se quisiera.
      final apiKey = dotenv.env['PAGO_PAGO_API_KEY'] ?? ''; 
      final service = PagoAPagoService(apiKey: apiKey);

      // Crear request
      final request = PaymentOrderRequest(
        amount: amount, 
        currency: 'VES', 
        email: user.email,
        phone: user.phone ?? '0000000000',
        dni: user.cedula ?? 'V00000000',
        motive: 'Recarga de ${amount.toInt()} Tréboles - MapHunter', // Display as int
        expiresAt: DateTime.now().add(const Duration(hours: 1)).toIso8601String(),
        typeOrder: 'EXTERNAL',
        convertFromUsd: true,
        extraData: {
          'user_id': user.userId,
        },
      );

      final response = await service.createPaymentOrder(request, token);

      if (!mounted) return;

      if (response.success && response.paymentUrl != null) {
        final url = Uri.parse(response.paymentUrl!);
        if (await canLaunchUrl(url)) {
          await launchUrl(url, mode: LaunchMode.externalApplication);
          
          ScaffoldMessenger.of(context).showSnackBar(
             const SnackBar(
               content: Text('Abriendo pasarela de pago...'),
               backgroundColor: AppTheme.successGreen,
             ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
             SnackBar(content: Text('No se pudo abrir el link: ${response.paymentUrl}')),
          );
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
           SnackBar(
             content: Text('Error al crear orden: ${response.message}'),
             backgroundColor: AppTheme.dangerRed,
           ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: $e'),
          backgroundColor: AppTheme.dangerRed,
        )
      );
    }
  }

  void _showWithdrawDialog() {
    final amountController = TextEditingController();
    final bankController = TextEditingController(); // Código banco (ej: 0102)
    final phoneController = TextEditingController(); // 0424...
    final dniController = TextEditingController(); // V12345678
    
    // Prefill data if available
    final player = Provider.of<PlayerProvider>(context, listen: false).currentPlayer;
    if (player != null) {
      phoneController.text = player.phone ?? '';
      dniController.text = player.cedula ?? '';
    }

    bool isLoading = false;

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
                Icon(Icons.remove_circle, color: AppTheme.secondaryPink),
                const SizedBox(width: 12),
                const Text(
                  'Retirar Fondos (Pago Móvil)',
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                ),
              ],
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'Retira tus tréboles a tu cuenta bancaria vía Pago Móvil.',
                    style: TextStyle(color: Colors.white70, fontSize: 12),
                  ),
                  const SizedBox(height: 16),
                  
                  // Amount
                  TextField(
                    controller: amountController,
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly], // Only Digits
                    style: const TextStyle(color: Colors.white),
                    decoration: _inputDecoration('Monto Exacto (Tréboles)', Icons.monetization_on),
                  ),
                  const SizedBox(height: 12),

                  // Bank Code
                  TextField(
                    controller: bankController,
                    keyboardType: TextInputType.number,
                    style: const TextStyle(color: Colors.white),
                    decoration: _inputDecoration('Código Banco (ej: 0102)', Icons.account_balance),
                  ),
                  const SizedBox(height: 12),

                  // Phone
                  TextField(
                    controller: phoneController,
                    keyboardType: TextInputType.phone,
                    style: const TextStyle(color: Colors.white),
                    decoration: _inputDecoration('Teléfono (0414...)', Icons.phone_android),
                  ),
                  const SizedBox(height: 12),

                  // DNI
                  TextField(
                    controller: dniController,
                    style: const TextStyle(color: Colors.white),
                    decoration: _inputDecoration('Cédula (V123...)', Icons.badge),
                  ),

                  if (isLoading)
                    const Padding(
                      padding: EdgeInsets.only(top: 16.0),
                      child: CircularProgressIndicator(color: AppTheme.secondaryPink),
                    ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: isLoading ? null : () => Navigator.pop(ctx),
                child: const Text('Cancelar', style: TextStyle(color: Colors.white60)),
              ),
              ElevatedButton(
                onPressed: isLoading ? null : () async {
                  final amount = int.tryParse(amountController.text); // Validate Integer
                  if (amount == null || amount <= 0) {
                     ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Monto inválido (Solo enteros)')));
                     return;
                  }
                  if (bankController.text.isEmpty || phoneController.text.isEmpty || dniController.text.isEmpty) {
                     ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Todos los campos son obligatorios')));
                     return;
                  }

                  setState(() => isLoading = true);

                  try {
                    // Check Balance first (client side check)
                    final playerProvider = Provider.of<PlayerProvider>(context, listen: false);
                    final balance = playerProvider.currentPlayer?.clovers ?? 0;
                    if (balance < amount) {
                       throw Exception("Saldo insuficiente");
                    }

                    final apiKey = dotenv.env['PAGO_PAGO_API_KEY'] ?? '';
                    final service = PagoAPagoService(apiKey: apiKey);
                    
                    final token = Supabase.instance.client.auth.currentSession?.accessToken;
                    if (token == null) throw Exception("No hay sesión activa");

                    final request = WithdrawalRequest(
                      amount: amount.toDouble(),
                      bank: bankController.text,
                      dni: dniController.text,
                      phone: phoneController.text,
                    );

                    final response = await service.withdrawFunds(request, token);

                    if (!mounted) return;

                    if (response.success) {
                      Navigator.pop(ctx);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('¡Retiro exitoso!'),
                          backgroundColor: AppTheme.successGreen,
                        )
                      );
                      // Trigger refresh of profile/balance
                      // This depends on how PlayerProvider refreshes. 
                      // Ideally we reload the user profile.
                      // playerProvider.reloadProfile(); (Assuming something like this exists or happens auto)
                    } else {
                      throw Exception(response.message);
                    }

                  } catch (e) {
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Error: $e'),
                          backgroundColor: AppTheme.dangerRed,
                        )
                      );
                    }
                  } finally {
                    if (mounted) setState(() => isLoading = false);
                  }
                },
                style: ElevatedButton.styleFrom(backgroundColor: AppTheme.secondaryPink),
                child: const Text('Retirar', style: TextStyle(color: Colors.white)),
              ),
            ],
          );
        }
      ),
    );
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
