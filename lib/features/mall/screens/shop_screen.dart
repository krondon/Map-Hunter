import 'package:flutter/material.dart';
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

  Future<void> _purchaseItem(BuildContext context, PowerItem item) async {
    if (_isLoading) return;

    final playerProvider = Provider.of<PlayerProvider>(context, listen: false);
    final gameProvider = Provider.of<GameProvider>(context, listen: false);

    final String? eventId = gameProvider.currentEventId;


    if (eventId == null) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Error: Debes estar en un evento para comprar.')),
    );
    return;
  }
    
    // Validar visualmente antes de llamar al backend
    if ((playerProvider.currentPlayer?.coins ?? 0) < item.cost) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No tienes suficientes monedas'),
          backgroundColor: AppTheme.dangerRed,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final success = await playerProvider.purchaseItem(item.id, eventId, item.cost);
      
      if (!mounted) return;

      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${item.name} comprado!'),
            backgroundColor: AppTheme.successGreen,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Error al realizar la compra. Intenta de nuevo.'),
            backgroundColor: AppTheme.dangerRed,
          ),
        );
      }
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
    final shopItems = PowerItem.getShopItems();
    
    return Scaffold(
      appBar: AppBar(
        backgroundColor: AppTheme.darkBg,
        title: const Text('La Tiendita'),
        actions: [
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
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: shopItems.length,
                    itemBuilder: (context, index) {
                      final item = shopItems[index];
                      return ShopItemCard(
                        item: item,
                        onPurchase: () => _purchaseItem(context, item),
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