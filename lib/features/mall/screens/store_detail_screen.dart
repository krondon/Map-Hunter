import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/mall_store.dart';
import '../models/power_item.dart';
import '../../auth/providers/player_provider.dart';
import '../../../core/theme/app_theme.dart';
import '../widgets/shop_item_card.dart';

class StoreDetailScreen extends StatelessWidget {
  final MallStore store;

  const StoreDetailScreen({super.key, required this.store});

  void _purchaseItem(BuildContext context, PowerItem item) {
    final playerProvider = Provider.of<PlayerProvider>(context, listen: false);
    
    // Verificar monedas
    if (playerProvider.spendCoins(item.cost)) {
      // Lógica especial para vida extra
      if (item.id == 'extra_life') {
        // Como no se persiste en DB en este demo, solo lo actualizamos localmente
        if (playerProvider.currentPlayer != null) {
          playerProvider.currentPlayer!.lives++;
          // Hack para forzar notifyListeners ya que lives no llama notify
          playerProvider.notifyListeners(); 
        }
      } else {
        playerProvider.addItemToInventory(item.id);
      }
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${item.name} comprado!'),
          backgroundColor: AppTheme.successGreen,
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No tienes suficientes monedas'),
          backgroundColor: AppTheme.dangerRed,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final player = Provider.of<PlayerProvider>(context).currentPlayer;

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 200.0,
            floating: false,
            pinned: true,
            backgroundColor: AppTheme.darkBg,
            flexibleSpace: FlexibleSpaceBar(
              title: Text(store.name, style: TextStyle(fontWeight: FontWeight.bold)),
              background: Image.network(
                store.imageUrl,
                fit: BoxFit.cover,
                 errorBuilder: (_,__,___) => Container(color: Colors.grey[800]),
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Container(
              padding: const EdgeInsets.all(20),
              decoration: const BoxDecoration(
                gradient: AppTheme.darkGradient,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        "Productos Disponibles",
                        style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: AppTheme.accentGold.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(15),
                          border: Border.all(color: AppTheme.accentGold)
                        ),
                        child: Text(
                          "💰 ${player?.coins ?? 0}",
                          style: const TextStyle(color: AppTheme.accentGold, fontWeight: FontWeight.bold),
                        ),
                      )
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text(
                    store.description,
                    style: const TextStyle(color: Colors.white70)
                  ),
                  const SizedBox(height: 20),
                  
                  ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: store.products.length,
                    separatorBuilder: (context, index) => const SizedBox(height: 12),
                    itemBuilder: (context, index) {
                      final item = store.products[index];
                      // Usamos ShopItemCard reutilizable
                      return ShopItemCard(
                        item: item,
                        onPurchase: () => _purchaseItem(context, item),
                      );
                    },
                  )
                ],
              ),
            ),
          )
        ],
      ),
    );
  }
}
