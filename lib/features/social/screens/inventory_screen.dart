import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../game/providers/game_provider.dart';
import '../../auth/providers/player_provider.dart';
import '../../mall/models/power_item.dart';
import '../../../core/theme/app_theme.dart';
import '../widgets/inventory_item_card.dart';
import '../../mall/screens/mall_screen.dart';

class InventoryScreen extends StatelessWidget {
  const InventoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final playerProvider = Provider.of<PlayerProvider>(context);
    final player = playerProvider.currentPlayer;
    
    if (player == null) {
      return const Center(child: Text('No player data'));
    }

    // Agrupar items repetidos
    final Map<String, int> inventoryCounts = {};
    for (var itemId in player.inventory) {
      inventoryCounts[itemId] = (inventoryCounts[itemId] ?? 0) + 1;
    }
    final uniqueItems = inventoryCounts.keys.toList();
    
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: AppTheme.darkGradient,
        ),
        child: SafeArea(
          child: Column(
            children: [
              // Header
              Padding(
                padding: const EdgeInsets.all(20.0),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Inventario',
                            style: Theme.of(context).textTheme.displayMedium,
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 6,
                                ),
                                decoration: BoxDecoration(
                                  gradient: AppTheme.goldGradient,
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Row(
                                  children: [
                                    const Icon(
                                      Icons.monetization_on,
                                      size: 16,
                                      color: Colors.white,
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      '${player.coins}',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppTheme.cardBg,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        children: [
                          const Icon(
                            Icons.inventory_2,
                            color: AppTheme.secondaryPink,
                            size: 28,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${player.inventory.length}',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 18,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              
              // Inventory items grid
              Expanded(
                child: player.inventory.isEmpty
                    ? _buildEmptyState(context)
                    : GridView.builder(
                        padding: const EdgeInsets.all(16),
                        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          crossAxisSpacing: 12,
                          mainAxisSpacing: 12,
                          childAspectRatio: 0.85,
                        ),
                        itemCount: uniqueItems.length,
                        itemBuilder: (context, index) {
                          final itemId = uniqueItems[index];
                          final count = inventoryCounts[itemId] ?? 1;
                          
                          // Buscamos la definición del item para pintarlo (Nombre, Icono)
                          // Si no existe en la lista estática, creamos un placeholder.
                          final itemDef = PowerItem.getShopItems().firstWhere(
                            (item) => item.id == itemId,
                            orElse: () => PowerItem(
                              id: itemId,
                              name: 'Poder Misterioso',
                              description: 'Poder desconocido',
                              type: PowerType.buff,
                              cost: 0,
                              icon: '⚡',
                            ),
                          );
                        
                          return InventoryItemCard(
                            item: itemDef,
                            count: count,
                            onUse: () => _handleItemUse(context, itemDef, player.id),
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const MallScreen())),
        label: const Text('Ir al Mall'),
        icon: const Icon(Icons.store),
        backgroundColor: AppTheme.accentGold,
      ),
    );
  }

  /// Lógica centralizada para usar items (Ataque vs Defensa)
  Future<void> _handleItemUse(BuildContext context, PowerItem item, String myPlayerId) async {
    final playerProvider = Provider.of<PlayerProvider>(context, listen: false);
    final gameProvider = Provider.of<GameProvider>(context, listen: false);

    // Lista de IDs considerados ofensivos/sabotaje
    // Lo ideal es mover esto a una propiedad `isOffensive` en tu modelo PowerItem
    final offensiveItems = ['freeze', 'black_screen', 'slow_motion', 'time_penalty'];
    final bool requiresTarget = offensiveItems.contains(item.id) || item.type == PowerType.debuff;

    if (requiresTarget) {
      // --- MODO ATAQUE: SELECCIONAR RIVAL ---
      
      // 1. Obtener lista de candidatos (Rivales)
      List<dynamic> candidates = [];
      
      if (gameProvider.currentEventId != null && gameProvider.leaderboard.isNotEmpty) {
        // Usar leaderboard del evento actual si existe
        candidates = gameProvider.leaderboard;
      } else {
        // Fallback: Cargar lista global si no hay evento o leaderboard vacío
        if (playerProvider.allPlayers.isEmpty) {
           await playerProvider.fetchAllPlayers();
        }
        candidates = playerProvider.allPlayers;
      }

      // 2. Filtrar: Excluirme a mí mismo
      final rivals = candidates.where((p) => p.id != myPlayerId).toList();

      if (!context.mounted) return;

      if (rivals.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No hay rivales disponibles para atacar')),
        );
        return;
      }

      // 3. Mostrar Diálogo
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          backgroundColor: AppTheme.cardBg,
          title: Text(
            'Lanzar ${item.name}',
            style: const TextStyle(color: Colors.white),
          ),
          content: SizedBox(
            width: double.maxFinite,
            height: 300,
            child: Column(
              children: [
                const Text(
                  'Selecciona una víctima:',
                  style: TextStyle(color: Colors.white70),
                ),
                const SizedBox(height: 10),
                Expanded(
                  child: ListView.separated(
                    itemCount: rivals.length,
                    separatorBuilder: (_, __) => const Divider(color: Colors.white12),
                    itemBuilder: (context, i) {
                      final rival = rivals[i];
                      return ListTile(
                        leading: CircleAvatar(
                          backgroundColor: AppTheme.dangerRed,
                          child: Text(rival.name.isNotEmpty ? rival.name[0].toUpperCase() : 'R'),
                        ),
                        title: Text(
                          rival.name,
                          style: const TextStyle(color: Colors.white),
                        ),
                        trailing: const Icon(Icons.gps_fixed, color: AppTheme.dangerRed),
                        onTap: () {
                          Navigator.pop(context); // Cerrar
                          _executePower(context, item, rival.id, rival.name, isOffensive: true);
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancelar'),
            ),
          ],
        ),
      );

    } else {
      // --- MODO DEFENSA/BUFF: SE APLICA A UNO MISMO ---
      _executePower(context, item, myPlayerId, "ti mismo", isOffensive: false);
    }
  }

  Future<void> _executePower(
    BuildContext context, 
    PowerItem item, 
    String targetId, 
    String targetName,
    {required bool isOffensive}
  ) async {
    final playerProvider = Provider.of<PlayerProvider>(context, listen: false);

    // Feedback visual de carga
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(
        child: CircularProgressIndicator(color: AppTheme.accentGold)
      ),
    );

    // Ejecutar lógica en backend
    final success = await playerProvider.usePower(
      powerId: item.id,
      targetUserId: targetId,
    );

    if (!context.mounted) return;
    Navigator.pop(context); // Cerrar loading

    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            isOffensive 
              ? '¡Ataque enviado a $targetName!' 
              : '¡${item.name} activado!'
          ),
          backgroundColor: AppTheme.successGreen,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Error: No se pudo usar el objeto (¿Sin munición?)'),
          backgroundColor: AppTheme.dangerRed,
        ),
      );
    }
  }

  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.shopping_bag_outlined,
            size: 80,
            color: Colors.white.withOpacity(0.3),
          ),
          const SizedBox(height: 20),
          Text(
            'Inventario vacío',
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
              color: Colors.white54,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            'Visita La Tiendita para comprar poderes',
            style: Theme.of(context).textTheme.bodyMedium,
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}