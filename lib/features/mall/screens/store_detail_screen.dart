import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/mall_store.dart';
import '../models/power_item.dart';
import '../../auth/providers/player_provider.dart';
import '../../game/providers/game_provider.dart';
import '../../game/providers/power_effect_provider.dart';
import '../../../core/theme/app_theme.dart';
import '../widgets/shop_item_card.dart';

class StoreDetailScreen extends StatefulWidget {
  final MallStore store;

  const StoreDetailScreen({super.key, required this.store});

  @override
  State<StoreDetailScreen> createState() => _StoreDetailScreenState();
}

class _StoreDetailScreenState extends State<StoreDetailScreen> {
  bool _isLoading = false;

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

      int successCount = 0;
      String? errorMessage;

      // Ejecutar compras individuales (el SP buy_item maneja límites por llamada)
      for (int i = 0; i < quantity; i++) {
        try {
          await playerProvider.purchaseItem(
            item.id,
            eventId,
            item.cost,
            isPower: isPower,
          );
          successCount++;
        } catch (e) {
          errorMessage = e.toString();
          break; // Si falla uno (ej. llegó al límite), paramos
        }
      }

      if (!mounted) return;

      if (successCount > 0) {
        // CRITICAL FIX: Sincronizar inventario inmediatamente
        final effectProvider = Provider.of<PowerEffectProvider>(context, listen: false);
        await playerProvider.syncRealInventory(effectProvider: effectProvider);
        
        // Actualizar vidas si es necesario
        if (item.id == 'extra_life') {
          // Usar syncLives para actualización inmediata sin red adicional
          // El PlayerProvider ya tiene el valor correcto tras la compra exitosa
          final newLives = playerProvider.currentPlayer?.lives ?? 3;
          gameProvider.syncLives(newLives); 
        }

        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(successCount == 1 
              ? 'Has obtenido: ${item.name}' 
              : 'Has obtenido $successCount x ${item.name}'),
            backgroundColor: AppTheme.successGreen,
          ),
        );
      }

      if (errorMessage != null && successCount < quantity) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMessage.contains('máximo') 
              ? 'Límite alcanzado ($successCount comprados)' 
              : 'Error parcial: $errorMessage'),
            backgroundColor: AppTheme.dangerRed,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }


  @override
  Widget build(BuildContext context) {
    final player = Provider.of<PlayerProvider>(context).currentPlayer;

    return Scaffold(
      body: Stack(
        children: [
          CustomScrollView(
            slivers: [
              SliverAppBar(
                expandedHeight: 200.0,
                floating: false,
                pinned: true,
                backgroundColor: AppTheme.darkBg,
                flexibleSpace: FlexibleSpaceBar(
                  title: Text(widget.store.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                  background: Image.network(
                    widget.store.imageUrl,
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
                          Row(
                            children: [

                              const SizedBox(width: 8),
                              // Monedas
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                decoration: BoxDecoration(
                                  color: AppTheme.accentGold.withOpacity(0.15),
                                  borderRadius: BorderRadius.circular(15),
                                  border: Border.all(color: AppTheme.accentGold.withOpacity(0.5))
                                ),
                                child: Row(
                                  children: [
                                    const Icon(Icons.monetization_on, size: 14, color: AppTheme.accentGold),
                                    const SizedBox(width: 4),
                                    Text(
                                      "${player?.coins ?? 0}",
                                      style: const TextStyle(color: AppTheme.accentGold, fontWeight: FontWeight.bold, fontSize: 13),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          )
                        ],
                      ),
                      const SizedBox(height: 10),
                      Text(
                        widget.store.description,
                        style: const TextStyle(color: Colors.white70)
                      ),
                      const SizedBox(height: 20),
                      
                      ListView.separated(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: widget.store.products.length,
                        separatorBuilder: (context, index) => const SizedBox(height: 12),
                          itemBuilder: (context, index) {
                            final item = widget.store.products[index];
                            final playerProvider = Provider.of<PlayerProvider>(context);
                            final gameProvider = Provider.of<GameProvider>(context);
                            final eventId = gameProvider.currentEventId;
                            
                            final bool isPower = item.type != PowerType.utility && item.id != 'extra_life';
                            final int? ownedCount = (eventId != null && isPower)
                                ? playerProvider.getPowerCount(item.id, eventId)
                                : (item.id == 'extra_life' ? gameProvider.lives : null);

                            return ShopItemCard(
                              item: item,
                              ownedCount: ownedCount,
                              onPurchase: (qty) => _purchaseItem(context, item, qty),
                            );
                          },
                      )
                    ],
                  ),
                ),
              )
            ],
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