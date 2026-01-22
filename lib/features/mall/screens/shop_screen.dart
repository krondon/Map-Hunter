import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:provider/provider.dart';
import '../../auth/providers/player_provider.dart';
import '../models/power_item.dart';
import '../../../core/theme/app_theme.dart';
import '../widgets/shop_item_card.dart';
import '../../game/providers/game_provider.dart';

class ShopScreen extends StatefulWidget {
  const ShopScreen({super.key});

  @override
  State<ShopScreen> createState() => _ShopScreenState();
}

class _ShopScreenState extends State<ShopScreen> {
  bool _isLoading = false;
  List<PowerItem> _shopItems = PowerItem.getShopItems(); // Lista local mutable

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await _fetchPowerConfigs(); // Fetch real durations first
      
      if (!mounted) return;
      final playerProvider = context.read<PlayerProvider>();
      final gameProvider = context.read<GameProvider>();
      final player = playerProvider.currentPlayer;
      final eventId = gameProvider.currentEventId;
      if (player != null && eventId != null) {
        await playerProvider.fetchInventory(player.userId, eventId);
      }
    });
  }

  Future<void> _fetchPowerConfigs() async {
    try {
      final supabase = Supabase.instance.client;
      // Seleccionamos slug y duration de la tabla powers
      final data = await supabase.from('powers').select('slug, duration');
      
      if (!mounted) return;

      setState(() {
        _shopItems = _shopItems.map((item) {
          // Buscar configuración en DB
          final matches = data.where((d) => d['slug'] == item.id);
          final config = matches.isNotEmpty ? matches.first : null;

          if (config != null) {
            final int duration = (config['duration'] as num?)?.toInt() ?? 0;
            
            // Actualizar descripción dinámica si tiene duración > 0
            String newDesc = item.description;
            if (duration > 0) {
              // Reemplazar patrones como "25s", "30s" por el valor real
              // Usamos una regex más flexible por si hay espacios
              newDesc = newDesc.replaceAll(RegExp(r'\b\d+\s*s\b'), '${duration}s');
            }

            return item.copyWith(
              durationSeconds: duration,
              description: newDesc,
            );
          }
          return item;
        }).toList();
      });
    } catch (e) {
      debugPrint("Error fetching power configs: $e");
    }
  }

  Future<void> _showQuickFeedback({
    required String icon,
    required String title,
    String message = '',
    Color accentColor = AppTheme.accentGold,
  }) async {
    if (!mounted) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => _QuickFeedbackDialog(
        icon: icon,
        title: title,
        message: message,
        accentColor: accentColor,
      ),
    );
  }

  Future<void> _purchaseItem(BuildContext context, PowerItem item, int quantity) async {
    if (_isLoading) return;

    setState(() => _isLoading = true);

    try {
      final playerProvider = Provider.of<PlayerProvider>(context, listen: false);
      final gameProvider = Provider.of<GameProvider>(context, listen: false);

      final String? eventId = gameProvider.currentEventId;

      if (eventId == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Error: Debes estar en un evento para comprar.')),
        );
        return;
      }

      final bool isPower = item.type != PowerType.utility && item.id != 'extra_life';
      final int totalCost = item.cost * quantity;

      // Validar monedas totales
      if ((playerProvider.currentPlayer?.coins ?? 0) < totalCost) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No tienes suficientes monedas para esta cantidad'),
            backgroundColor: AppTheme.dangerRed,
          ),
        );
        return;
      }

      bool overallSuccess = true;
      int purchasedCount = 0;

      // Bucle para comprar la cantidad seleccionada
      for (int i = 0; i < quantity; i++) {
        final success = await playerProvider.purchaseItem(
          item.id, 
          eventId, 
          item.cost, 
          isPower: isPower
        );
        
        if (success) {
          purchasedCount++;
        } else {
          overallSuccess = false;
          break;
        }
      }

      if (!mounted) return;

      if (purchasedCount > 0) {
        await _showQuickFeedback(
          icon: item.icon,
          title: purchasedCount > 1 ? '¡Compras Exitosas!' : '¡Compra Exitosa!',
          message: 'Has obtenido $purchasedCount x ${item.name}',
          accentColor: AppTheme.successGreen,
        );

        // Refrescar inventario
        if (playerProvider.currentPlayer != null) {
          await playerProvider.fetchInventory(playerProvider.currentPlayer!.userId, eventId);
          if (item.id == 'extra_life') {
            await gameProvider.fetchLives(playerProvider.currentPlayer!.userId);
          }
        }
      }

      if (!overallSuccess) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Algunas compras fallaron o alcanzaste un límite.'),
            backgroundColor: AppTheme.warningOrange,
          ),
        );
      }
    } catch (e) {
      debugPrint('Error purchasing item: $e');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final playerProvider = Provider.of<PlayerProvider>(context);
    final player = playerProvider.currentPlayer;
    // final shopItems = PowerItem.getShopItems(); // REPLACED by local state
    final gameProvider = Provider.of<GameProvider>(context);
    final eventId = gameProvider.currentEventId;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: AppTheme.darkBg,
        title: const Text('La Tiendita'),
        actions: [
          // Vidas
          Center(
            child: Container(
              margin: const EdgeInsets.only(right: 8),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [AppTheme.dangerRed, Color(0xFFFF5252)],
                ),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                children: [
                  const Icon(Icons.favorite, size: 16, color: Colors.white),
                  const SizedBox(width: 4),
                  Text(
                    '${player?.lives ?? 0}',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
          ),
          // Monedas
          Center(
            child: Container(
              margin: const EdgeInsets.only(right: 16),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                gradient: AppTheme.goldGradient,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                children: [
                  const Icon(Icons.monetization_on, size: 16),
                  const SizedBox(width: 4),
                  Text(
                    '${player?.coins ?? 0}',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
      body: Stack(
        children: [
          Container(
            decoration: const BoxDecoration(
              gradient: AppTheme.darkGradient,
            ),
            child: Column(
              children: [
                // NPC Header
                Container(
                  margin: const EdgeInsets.all(16),
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: AppTheme.cardBg,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 70,
                        height: 70,
                        decoration: BoxDecoration(
                          gradient: AppTheme.primaryGradient,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(
                          Icons.store,
                          size: 40,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(width: 16),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '¡Bienvenido!',
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                            SizedBox(height: 4),
                            Text(
                              'Compra poderes para tu aventura',
                              style: TextStyle(
                                color: Colors.white70,
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                // Shop items
                Expanded(
                  child: ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    itemCount: _shopItems.length,
                    itemBuilder: (context, index) {
                      final item = _shopItems[index];
                      final bool isPower = item.type != PowerType.utility &&
                          item.id != 'extra_life';
                      final int? ownedCount = (eventId != null && isPower)
                          ? playerProvider.getPowerCount(item.id, eventId)
                          : (item.id == 'extra_life' ? (player?.lives ?? 0) : null);

                      return ShopItemCard(
                        item: item,
                        ownedCount: ownedCount,
                        maxPerEvent: 3,
                        onPurchase: (qty) => _purchaseItem(context, item, qty),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),

          // Loading Overlay
          if (_isLoading)
            Container(
              color: Colors.black54,
              child: const Center(
                child: CircularProgressIndicator(color: AppTheme.accentGold),
              ),
            ),
        ],
      ),
    );
  }
}

class _QuickFeedbackDialog extends StatefulWidget {
  final String icon;
  final String title;
  final String message;
  final Color accentColor;

  const _QuickFeedbackDialog({
    required this.icon,
    required this.title,
    required this.message,
    required this.accentColor,
  });

  @override
  State<_QuickFeedbackDialog> createState() => _QuickFeedbackDialogState();
}

class _QuickFeedbackDialogState extends State<_QuickFeedbackDialog>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _scale;
  late final Animation<double> _opacity;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );

    _scale = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween(begin: 0.85, end: 1.06)
            .chain(CurveTween(curve: Curves.easeOutBack)),
        weight: 60,
      ),
      TweenSequenceItem(
        tween: Tween(begin: 1.06, end: 1.0)
            .chain(CurveTween(curve: Curves.easeInOut)),
        weight: 40,
      ),
    ]).animate(_controller);

    _opacity = Tween<double>(begin: 0, end: 1)
        .chain(CurveTween(curve: Curves.easeOut))
        .animate(_controller);

    _controller.forward();
    Future.delayed(const Duration(milliseconds: 1100), () {
      if (mounted) Navigator.of(context).pop();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      type: MaterialType.transparency,
      child: Center(
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, _) {
            return Opacity(
              opacity: _opacity.value,
              child: Transform.scale(
                scale: _scale.value,
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 24),
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: AppTheme.cardBg,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.white12),
                    boxShadow: [
                      BoxShadow(
                        color: widget.accentColor.withOpacity(0.2),
                        blurRadius: 20,
                        spreadRadius: 4,
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(widget.icon, style: const TextStyle(fontSize: 56)),
                      const SizedBox(height: 10),
                      Text(
                        widget.title,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: widget.accentColor,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      if (widget.message.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Text(
                          widget.message,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
