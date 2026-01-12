import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/mall_store.dart';
import '../models/power_item.dart';
import '../../auth/providers/player_provider.dart';
import '../../game/providers/game_provider.dart';
import '../../../core/theme/app_theme.dart';
import '../widgets/shop_item_card.dart';
import '../../../shared/utils/game_ui_utils.dart'; // Add this import

class StoreDetailScreen extends StatefulWidget {
  final MallStore store;

  const StoreDetailScreen({super.key, required this.store});

  @override
  State<StoreDetailScreen> createState() => _StoreDetailScreenState();
}

class _StoreDetailScreenState extends State<StoreDetailScreen> {
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final playerProvider = context.read<PlayerProvider>();
      final gameProvider = context.read<GameProvider>();
      final player = playerProvider.currentPlayer;
      final eventId = gameProvider.currentEventId;
      if (player != null && eventId != null) {
        await playerProvider.fetchInventory(player.id, eventId);
      }
    });
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

  Future<void> _purchaseItem(BuildContext context, PowerItem item) async {
    final playerProvider = Provider.of<PlayerProvider>(context, listen: false);
    final gameProvider = Provider.of<GameProvider>(context, listen: false);

    final String? eventId = gameProvider.currentEventId;

    // VALIDACIÓN 1: El event_id es obligatorio para filtrar por game_player_id
    if (eventId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No hay un evento activo seleccionado.')),
      );
      return;
    }

    // VALIDACIÓN 2: Determinar si es un poder (p_is_power en tu SQL)
    // Excluimos utilidades y vidas de la lógica de la tabla player_powers
    final bool isPower =
        item.type != PowerType.utility && item.id != 'extra_life';

    if (isPower) {
      // VALIDACIÓN 3: Límite de 3 unidades (Coincide con p_is_power y v_current_quantity >= 3)
      // playerProvider.getPowerCount debe estar filtrando localmente por el eventId actual
      final int count = playerProvider.getPowerCount(item.id, eventId);
      if (count >= 3) {
        await _showQuickFeedback(
          icon: item.icon,
          title: 'Límite alcanzado',
          message: 'Máximo 3 por evento ($count/3).',
          accentColor: AppTheme.dangerRed,
        );
        return;
      }
    }

    // Verificar límite de vidas
    if (item.id == 'extra_life') {
      if (playerProvider.currentPlayer != null) {
        // Actualizar vidas antes de verificar
        await gameProvider.fetchLives(playerProvider.currentPlayer!.id);
      }

      if (gameProvider.lives >= 3) {
        showGameDialog(context,
            title: 'Vida al Máximo',
            message:
                '¡Ya tienes 3 vidas! No puedes cargar más por ahora. Úsalas sabiamente.',
            icon: Icons.favorite,
            iconColor: AppTheme.dangerRed);
        return;
      }
    }

    // Verificar monedas visualmente
    if ((playerProvider.currentPlayer?.coins ?? 0) < item.cost) {
      showGameDialog(context,
          title: 'Saldo Insuficiente',
          message:
              'No tienes suficientes monedas para este objeto. ¡Resuelve más puzzles!',
          icon: Icons.monetization_on_outlined,
          iconColor: AppTheme.accentGold);
      return;
    }

    setState(() => _isLoading = true);

    try {
      // LLAMADA AL SQL: Aquí es donde invocas tu función 'buy_item'
      // Tu PlayerProvider debe ejecutar: supabase.rpc('buy_item', params: {...})
      await playerProvider.purchaseItem(item.id, eventId, item.cost,
          isPower: isPower);

      if (!mounted) return;

      await _showQuickFeedback(
        icon: item.icon,
        title: '¡Compra Exitosa!',
        message: 'Has obtenido: ${item.name}',
        accentColor: AppTheme.successGreen,
      );

      // ACTUALIZACIÓN: Refrescar usando tu nueva función 'get_my_inventory_by_event'
      // fetchInventory debe llamar internamente a esa función SQL
      if (item.id != 'extra_life') {
        await playerProvider.fetchInventory(
            playerProvider.currentPlayer!.id, eventId);
      } else {
        await gameProvider.fetchLives(playerProvider.currentPlayer!.id);
      }
    } catch (e) {
      // 3. Error
      if (!mounted) return;
      showGameSnackBar(context,
          title: 'Error de Compra', message: e.toString(), isError: true);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final playerProvider = Provider.of<PlayerProvider>(context);
    final player = playerProvider.currentPlayer;
    final gameProvider = Provider.of<GameProvider>(context);
    final eventId = gameProvider.currentEventId;

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
                  title: Text(widget.store.name,
                      style: const TextStyle(fontWeight: FontWeight.bold)),
                  background: (widget.store.imageUrl.isNotEmpty &&
                          widget.store.imageUrl.startsWith('http'))
                      ? Image.network(
                          widget.store.imageUrl,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) =>
                              Container(color: Colors.grey[800]),
                        )
                      : Container(
                          color: Colors.grey[800],
                          child: const Icon(Icons.store,
                              color: Colors.white24, size: 50),
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
                          const Expanded(
                            child: Text(
                              "Productos Disponibles",
                              style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Row(
                            mainAxisSize: MainAxisSize.min, // Optimize size
                            children: [
                              // Monedas
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 10, vertical: 5),
                                decoration: BoxDecoration(
                                    color: AppTheme.accentGold.withOpacity(0.2),
                                    borderRadius: BorderRadius.circular(15),
                                    border:
                                        Border.all(color: AppTheme.accentGold)),
                                child: Text(
                                  "💰 ${player?.coins ?? 0}",
                                  style: const TextStyle(
                                      color: AppTheme.accentGold,
                                      fontWeight: FontWeight.bold),
                                ),
                              ),
                              const SizedBox(width: 8),
                              // Vidas
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 10, vertical: 5),
                                decoration: BoxDecoration(
                                    color: AppTheme.dangerRed.withOpacity(0.2),
                                    borderRadius: BorderRadius.circular(15),
                                    border:
                                        Border.all(color: AppTheme.dangerRed)),
                                child: Row(
                                  children: [
                                    const Icon(Icons.favorite,
                                        size: 14, color: AppTheme.dangerRed),
                                    const SizedBox(width: 4),
                                    Text(
                                      "${player?.lives ?? 0}",
                                      style: const TextStyle(
                                          color: AppTheme.dangerRed,
                                          fontWeight: FontWeight.bold),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          )
                        ],
                      ),
                      const SizedBox(height: 10),
                      Text(widget.store.description,
                          style: const TextStyle(color: Colors.white70)),
                      const SizedBox(height: 20),
                      ListView.separated(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: widget.store.products.length,
                        separatorBuilder: (context, index) =>
                            const SizedBox(height: 12),
                        itemBuilder: (context, index) {
                          final item = widget.store.products[index];
                          final bool isPower = item.type != PowerType.utility &&
                              item.id != 'extra_life';
                          final int? ownedCount = (eventId != null && isPower)
                              ? playerProvider.getPowerCount(item.id, eventId)
                              : null;
                          // Usamos ShopItemCard reutilizable
                          return ShopItemCard(
                            item: item,
                            ownedCount: ownedCount,
                            maxPerEvent: 3,
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
