import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/mall_store.dart';
import '../models/power_item.dart';
import '../../auth/providers/player_provider.dart';
import '../../game/providers/game_provider.dart';
import '../../game/providers/power_interfaces.dart';
import '../../../core/theme/app_theme.dart';
import '../widgets/shop_item_card.dart';
import '../../../core/providers/app_mode_provider.dart'; // IMPORT AGREGADO

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
        final effectProvider = Provider.of<PowerEffectManager>(context, listen: false);
        await playerProvider.syncRealInventory(effectProvider: effectProvider);
        
        // Actualizar vidas si es necesario
        if (item.id == 'extra_life') {
          // Usar syncLives para actualización inmediata sin red adicional
          // El PlayerProvider ya tiene el valor correcto tras la compra exitosa
          final newLives = playerProvider.currentPlayer?.lives ?? 3;
          gameProvider.syncLives(newLives); 
        }

        if (!mounted) return;
        
        await _showQuickFeedback(
          icon: item.icon,
          title: successCount > 1 ? '¡Compras Exitosas!' : '¡Compra Exitosa!',
          message: 'Has obtenido $successCount x ${item.name}',
          accentColor: AppTheme.successGreen,
        );

        /* ScaffoldMessenger used to be here, replaced by dialog */
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
                leading: Container(), // Hide default leading
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

                          IconButton(
                            icon: const Icon(Icons.rocket_launch, color: AppTheme.accentGold),
                            tooltip: 'Comprar Todo (DEV)',
                            onPressed: () async {
                              final playerProvider = Provider.of<PlayerProvider>(context, listen: false);
                              final gameProvider = Provider.of<GameProvider>(context, listen: false);
                              final eventId = gameProvider.currentEventId;

                              if (eventId == null) return;
                              setState(() => _isLoading = true);
                              try {
                                final message = await playerProvider.purchaseFullStock(eventId);
                                if (mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(message),
                                      backgroundColor: message.contains('Error') || message.contains('Faltan') 
                                        ? AppTheme.dangerRed 
                                        : AppTheme.successGreen,
                                    ),
                                  );
                                }
                              } finally {
                                if (mounted) setState(() => _isLoading = false);
                              }
                            },
                          ),

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
                      
                      // FALLBACK LOGIC: Si es Online y la tienda viene vacía (error de datos), mostramos todo el catálogo
                      Builder(
                        builder: (context) {
                          bool isOnline = false;
                          try {
                            // Using listen: false to just check state once
                            isOnline = Provider.of<AppModeProvider>(context, listen: false).isOnlineMode;
                            print("DEBUG: StoreDetailScreen isOnline=$isOnline");
                          } catch (e) {
                            print("DEBUG: StoreDetailScreen AppModeProvider Error: $e");
                          }
                          
                          // FORCE CATALOG IN ONLINE MODE: Siempre mostrar todo el catálogo disponible
                          // UPDATE: Usar los productos de la tienda (que traen precios personalizados)
                          // Si la tienda viene vacía, entonces sí usar el catálogo default
                          final displayProducts = widget.store.products.isNotEmpty 
                              ? widget.store.products 
                              : PowerItem.getShopItems();
                            
                          print("DEBUG: displayProducts length=${displayProducts.length}");

                          if (displayProducts.isEmpty) {
                            return const Padding(
                              padding: EdgeInsets.all(20.0),
                              child: Center(
                                child: Text(
                                  "No hay productos disponibles por el momento.",
                                  style: TextStyle(color: Colors.white54),
                                ),
                              ),
                            );
                          }

                          return ListView.separated(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: displayProducts.length,
                            separatorBuilder: (context, index) => const SizedBox(height: 12),
                            itemBuilder: (context, index) {
                                final item = displayProducts[index];
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
                          );
                        }
                      )
                    ],
                  ),
                ),
              )
            ],
          ),
          
          // Cyberpunk Back Button (Matching Inventory Screen)
          Positioned(
            top: MediaQuery.of(context).padding.top + 10,
            left: 20,
            child: GestureDetector(
              onTap: () => Navigator.of(context).pop(),
              child: Container(
                width: 42,
                height: 42,
                padding: const EdgeInsets.all(2),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: AppTheme.accentGold.withOpacity(0.3),
                    width: 1.0,
                  ),
                ),
                child: Container(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: const Color(0xFF0D0D0F),
                    border: Border.all(
                      color: AppTheme.accentGold,
                      width: 2.0,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: AppTheme.accentGold.withOpacity(0.5),
                        blurRadius: 8,
                        spreadRadius: 1,
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.arrow_back,
                    color: Colors.white,
                    size: 16,
                  ),
                ),
              ),
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