import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../shared/models/player.dart';
import 'package:treasure_hunt_rpg/features/game/providers/game_provider.dart';
import 'package:treasure_hunt_rpg/features/auth/providers/player_provider.dart';
import '../../mall/models/power_item.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/providers/app_mode_provider.dart'; // IMPORT AGREGADO
import '../widgets/inventory_item_card.dart';
import '../../mall/screens/mall_screen.dart';
import '../../mall/screens/store_detail_screen.dart'; // IMPORT AGREGADO
import '../../mall/models/mall_store.dart'; // IMPORT AGREGADO
import '../../../shared/utils/game_ui_utils.dart';
import '../../game/providers/power_interfaces.dart';
import '../../../shared/widgets/animated_cyber_background.dart';
import '../../../shared/widgets/loading_indicator.dart';
// PowerSwipeAction se mantiene disponible pero no se usa en este flujo simplificado

class InventoryScreen extends StatefulWidget {
  final String? eventId;
  const InventoryScreen({super.key, this.eventId});

  @override
  State<InventoryScreen> createState() => _InventoryScreenState();
}

class _InventoryScreenState extends State<InventoryScreen> {
  bool _isLoading = false;

  bool get isDarkMode =>
      Provider.of<PlayerProvider>(context, listen: false).isDarkMode;
  Color get currentCard =>
      isDarkMode ? AppTheme.dSurface1 : Colors.white.withOpacity(0.9);
  Color get currentText => isDarkMode ? Colors.white : AppTheme.dSurface0;
  Color get currentTextSec => isDarkMode ? Colors.white70 : Colors.black54;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _fetchInventory();
    });
  }

  @override
  void didUpdateWidget(InventoryScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.eventId != oldWidget.eventId) {
      _fetchInventory();
    }
  }

  Future<void> _fetchInventory() async {
    final playerProvider = Provider.of<PlayerProvider>(context, listen: false);
    final gameProvider = Provider.of<GameProvider>(context, listen: false);
    final player = playerProvider.currentPlayer;

    final eventId = widget.eventId ?? gameProvider.currentEventId;

    if (player != null && eventId != null) {
      await playerProvider.fetchInventory(player.userId, eventId);
    }
  }

  @override
  Widget build(BuildContext context) {
    const bool isDarkMode = true;
    final playerProvider = Provider.of<PlayerProvider>(context);
    final player = playerProvider.currentPlayer;

    if (player == null) {
      return const Scaffold(
        backgroundColor: AppTheme.darkBg,
        body: Center(
          child: LoadingIndicator(),
        ),
      );
    }

    // Agrupar items repetidos
    final Map<String, int> inventoryCounts = {};
    for (var itemId in player.inventory) {
      inventoryCounts[itemId] = (inventoryCounts[itemId] ?? 0) + 1;
    }
    final uniqueItems = inventoryCounts.keys.toList()..sort();

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        children: [
          AnimatedCyberBackground(
            child: Stack(
              children: [
                Positioned.fill(
                  child: Image.asset(
                    playerProvider.isDarkMode
                        ? 'assets/images/fotogrupalnoche.png'
                        : 'assets/images/personajesgrupal.png',
                    fit: BoxFit.cover,
                    alignment: Alignment.center,
                  ),
                ), // Added comma explicitly
                // Removed dark overlay as requested
                // Removed dark overlay as requested
                SafeArea(
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
                              const Text(
                                'Inventario',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 28,
                                  fontWeight: FontWeight.w900,
                                  fontFamily: 'Orbitron',
                                  letterSpacing: 1.5,
                                ),
                              ),
                              const SizedBox(height: 4),
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
                        ClipRRect(
                          borderRadius: BorderRadius.circular(16),
                          child: BackdropFilter(
                            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                            child: Container(
                              padding: const EdgeInsets.all(3),
                              decoration: BoxDecoration(
                                color: const Color(0xFF0D0D0F).withOpacity(0.6),
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: AppTheme.secondaryPink.withOpacity(0.6),
                                  width: 1.5,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: AppTheme.secondaryPink.withOpacity(0.1),
                                    blurRadius: 12,
                                  ),
                                ],
                              ),
                              child: Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(13),
                                  border: Border.all(
                                    color: AppTheme.secondaryPink.withOpacity(0.2),
                                    width: 1,
                                  ),
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
                            ),
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
                                gridDelegate:
                                    const SliverGridDelegateWithFixedCrossAxisCount(
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
                                  final itemDef =
                                      PowerItem.getShopItems().firstWhere(
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

                                  final effectProvider =
                                      Provider.of<PowerEffectReader>(context);

                                  // Logic for Defense Power Exclusivity
                                  // 1. Identify if this item is a defense power
                                  final isDefensive = [
                                    'shield',
                                    'invisibility',
                                    'return'
                                  ].contains(itemDef.id);

                                  bool isActive = false;
                                  bool isDisabled = false;
                                  String? disabledLabel;

                                  if (isDefensive) {
                                    // Check if THIS specific power is active
                                    isActive = effectProvider
                                        .isEffectActive(itemDef.id);

                                    // Check if we should disable it (because another defense is active)
                                    if (!isActive) {
                                      // Now we can use the interface directly!
                                      if (!effectProvider
                                          .canActivateDefensePower(
                                              itemDef.id)) {
                                        isDisabled = true;
                                        disabledLabel = 'Defensa en uso';
                                      }
                                    }
                                  }

                                  if (isDefensive) {
                                    debugPrint(
                                        '🔘 [UI-SYNC] Button State for ${itemDef.id}: Active=$isActive, Disabled=$isDisabled');
                                  }

                                  return InventoryItemCard(
                                    item: itemDef,
                                    count: count,
                                    isActive: isActive,
                                    isDisabled: isDisabled,
                                    disabledLabel: disabledLabel,
                                    onUse: () => _handleItemUse(
                                        context, itemDef, player.id),
                                  );
                                },
                              ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ), // Added comma explicitly

          if (_isLoading)
            Container(
              color: Colors.black54,
              child: const Center(
                child: LoadingIndicator(),
              ),
            ),
        ],
      ),
      floatingActionButton: Padding(
        padding: const EdgeInsets.only(bottom: 80.0),
        child: FloatingActionButton.extended(
          onPressed: () {
            final isOnline =
                Provider.of<AppModeProvider>(context, listen: false)
                    .isOnlineMode;

            if (isOnline) {
              // MODO ONLINE: Navegación Directa a Tienda Global (Virtual)
              // Creamos una tienda virtual en vuelo para acceder al catálogo global
              final virtualStore = MallStore(
                id: 'virtual_global',
                name: 'Tienda Global',
                description:
                    'Catálogo de poderes disponibles para el evento online.',
                imageUrl:
                    'asset/images/personajesgrupal.png', // Placeholder Cyberpunk
                qrCodeData: 'SKIP_QR',
                products: [], // Lista vacía fuerza a cargar el catálogo completo por defecto en StoreDetailScreen
              );

              Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) => StoreDetailScreen(store: virtualStore)));
            } else {
              // MODO PRESENCIAL: Flujo normal (Lista de Tiendas -> QR)
              Navigator.push(context,
                  MaterialPageRoute(builder: (_) => const MallScreen()));
            }
          },
          label: Text(Provider.of<AppModeProvider>(context).isOnlineMode
              ? 'Mall'
              : 'Ir al Mall'),
          icon: const Icon(Icons.store),
          backgroundColor: AppTheme.accentGold,
          foregroundColor:
              Colors.black, // Ensure text is visible on gold background
        ),
      ),
    );
  }

  /// Lógica centralizada para usar items (Ataque vs Defensa)
  Future<void> _handleItemUse(
      BuildContext context, PowerItem item, String myPlayerId) async {
    final gameProvider = Provider.of<GameProvider>(context, listen: false);
    final effectProvider =
        Provider.of<PowerEffectManager>(context, listen: false);
    final playerProvider = Provider.of<PlayerProvider>(context, listen: false);
    final myGamePlayerId = playerProvider.currentPlayer?.gamePlayerId;

    debugPrint('InventoryScreen: _handleItemUse called for ${item.id}');
    if (myGamePlayerId == null)
      debugPrint('InventoryScreen: ⚠️ myGamePlayerId is NULL');

    // Lista de IDs considerados ofensivos/sabotaje
    // Lo ideal es mover esto a una propiedad `isOffensive` en tu modelo PowerItem
    final offensiveItems = [
      'freeze',
      'black_screen',
      'life_steal',
      'blur_screen'
    ];
    final isOffensive = offensiveItems.contains(item.id);

    // Requisito: blur_screen NO debe pedir seleccionar rival.
    // Se envía a todos los rivales del evento (excluyéndote a ti mismo).
    // Internamente, el provider envía el ataque global y no requiere target real.
    if (item.id == 'blur_screen') {
      try {
        if (myGamePlayerId == null || myGamePlayerId.isEmpty) {
          showGameSnackBar(
            context,
            title: 'Sin gamePlayerId',
            message: 'Aún no entras al evento activo',
            isError: true,
          );
          return;
        }

        await _executePower(
          item,
          myGamePlayerId,
          'todos los rivales',
          isOffensive: true,
          effectProvider: effectProvider,
          gameProvider: gameProvider,
        );
      } catch (e) {
        debugPrint('Error enviando blur_screen a todos: $e');
        if (!mounted) return; // Prevent context usage after dispose
        showGameSnackBar(
          context,
          title: 'Error',
          message: 'Error enviando Pantalla Borrosa: $e',
          isError: true,
        );
      }
      return;
    }

    if (isOffensive) {
      try {
        // --- MODO ATAQUE: SELECCIONAR RIVAL ---

        // 1. Obtener lista de candidatos (Rivales)
        List<dynamic> candidates = [];
        final eventId = widget.eventId ?? gameProvider.currentEventId;

        if (eventId != null) {
          // Si estamos en un evento, SOLO mostrar participantes del ranking
          // Esto asegura que se muestren en orden de ranking y solo los del evento
          if (gameProvider.leaderboard.isEmpty &&
              gameProvider.currentEventId == eventId) {
            debugPrint('InventoryScreen: Leaderboard empty, fetching...');
            await gameProvider.fetchLeaderboard();
          }
          candidates = gameProvider.leaderboard;
        } else {
          candidates = gameProvider.leaderboard;
        }

        // 2. Filtrar: Excluirme a mí mismo
        final rivals = candidates.where((p) {
          final String pId = (p is Player) ? p.id : (p['id'] ?? '');

          // USAR EL GETTER DEL MODELO: p.isInvisible leerá el status 'invisible' de la vista
          final bool isTargetInvisible =
              (p is Player) ? p.isInvisible : (p['status'] == 'invisible');
          final bool isMe = pId == myPlayerId;

          // Solo se muestran si NO son el usuario actual y NO están invisibles
          return !isMe && !isTargetInvisible;
        }).toList();

        debugPrint(
            'InventoryScreen: Rivals found: ${rivals.length}. Candidates: ${candidates.length}');

        if (rivals.isEmpty) {
          showGameSnackBar(context,
              title: 'Sin Víctimas',
              message: 'No hay otros jugadores disponibles para sabotear.',
              isError: true);
          return;
        }

        showModalBottomSheet(
          context: context,
          backgroundColor: currentCard,
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          builder: (modalContext) {
            return Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  margin: const EdgeInsets.symmetric(vertical: 12),
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.white24,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const Padding(
                  padding: EdgeInsets.all(16.0),
                  child: Text(
                    'SELECCIONA TU VÍCTIMA',
                    style: TextStyle(
                      color: AppTheme.accentGold,
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                    ),
                  ),
                ),
                Flexible(
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: rivals.length,
                    itemBuilder: (context, index) {
                      final rival = rivals[index];
                      return ListTile(
                        leading: Container(
                          width: 40,
                          height: 40,
                          decoration:
                              const BoxDecoration(shape: BoxShape.circle),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(20),
                            child: Builder(
                              builder: (context) {
                                final avatarId = rival.avatarId;
                                final avatarUrl = rival.avatarUrl;

                                if (avatarId != null && avatarId.isNotEmpty) {
                                  return Image.asset(
                                    'assets/images/avatars/$avatarId.png',
                                    fit: BoxFit.cover,
                                    errorBuilder: (_, __, ___) => const Icon(
                                        Icons.person,
                                        color: Colors.white70),
                                  );
                                }

                                if (avatarUrl.isNotEmpty &&
                                    avatarUrl.startsWith('http')) {
                                  return Image.network(
                                    avatarUrl,
                                    fit: BoxFit.cover,
                                    errorBuilder: (_, __, ___) => const Icon(
                                        Icons.person,
                                        color: Colors.white70),
                                  );
                                }

                                return const Icon(Icons.person,
                                    color: Colors.white70);
                              },
                            ),
                          ),
                        ),
                        title: Text(rival.name,
                            style: TextStyle(color: currentText)),
                        subtitle: Text('${rival.totalXP} XP',
                            style: TextStyle(color: currentTextSec)),
                        trailing: const Icon(Icons.bolt,
                            color: AppTheme.secondaryPink),
                        onTap: () {
                          final targetGp = rival.gamePlayerId;
                          if (targetGp == null || targetGp.isEmpty) {
                            showGameSnackBar(context,
                                title: 'Sin gamePlayerId',
                                message: 'El rival no tiene gamePlayerId',
                                isError: true);
                            return;
                          }
                          debugPrint(
                              'InventoryScreen: 🟢 TARGET SELECTED via BottomSheet: ${rival.name} ($targetGp)');
                          Navigator.pop(modalContext);
                          _executePower(item, targetGp, rival.name,
                              isOffensive: true,
                              effectProvider: effectProvider,
                              gameProvider: gameProvider);
                        },
                      );
                    },
                  ),
                ),
                const SizedBox(height: 20),
              ],
            );
          },
        );
      } catch (e) {
        debugPrint("Error cargando rivales: $e");
        showGameSnackBar(context,
            title: 'Error',
            message: 'Error cargando rivales: $e',
            isError: true);
      }
    } else {
      // --- MODO DEFENSA/BUFF: USAR EN MÍ MISMO ---
      if (myGamePlayerId == null || myGamePlayerId.isEmpty) {
        showGameSnackBar(context,
            title: 'Sin gamePlayerId',
            message: 'Aún no entras al evento activo',
            isError: true);
        return;
      }
      _executePower(item, myGamePlayerId, "Mí mismo",
          isOffensive: false,
          effectProvider: effectProvider,
          gameProvider: gameProvider);
    }
  }

  Future<void> _executePower(
      PowerItem item, String targetGamePlayerId, String targetName,
      {required bool isOffensive,
      required PowerEffectManager effectProvider,
      required GameProvider gameProvider}) async {
    final playerProvider = Provider.of<PlayerProvider>(context, listen: false);

    debugPrint(
        'InventoryScreen: ⚡ _executePower START for ${item.id} on $targetName');

    // Check if mounted before setState
    if (!mounted) {
      debugPrint(
          'InventoryScreen: ⚠️ widget unmounted before _executePower could start');
      return;
    }

    setState(() => _isLoading = true);

    PowerUseResult result = PowerUseResult.error;
    try {
      debugPrint('InventoryScreen: Calling playerProvider.usePower...');
      // Ejecutar lógica en backend
      result = await playerProvider.usePower(
        powerSlug: item.id,
        targetGamePlayerId: targetGamePlayerId,
        effectProvider: effectProvider,
        gameProvider: gameProvider,
      );
    } catch (e) {
      debugPrint('Error executing power: $e');
      result = PowerUseResult.error;
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }

    // CRITICAL: Exit if widget was disposed during async operation
    if (!mounted) return;

    // Map result to a success boolean without changing logic
    final bool success = result == PowerUseResult.success;

    if (success) {
      final suppressed =
          effectProvider.lastDefenseAction == DefenseAction.stealFailed;
      if (suppressed) {
        // No mostramos mensajes ni confirmación de 'ataque enviado' porque
        // el servidor indicó que no había vidas para robar (no se envió efecto).
        return;
      }
      if (isOffensive) {
        showDialog(
          context: context,
          barrierDismissible: true,
          builder: (_) => const _AttackSuccessDialog(targetName: ''),
        );
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(isOffensive
              ? '¡Ataque enviado correctamente a $targetName!'
              : '¡${item.name} activado correctamente!'),
          backgroundColor: AppTheme.successGreen,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } else if (result == PowerUseResult.reflected) {
      // Si fue reflejado, NO mostramos mensaje de éxito ni error.
      // El "Toast" de retorno (ReturnSuccessEffect) ya se encargará de informar al usuario.
      debugPrint("Feedback de ataque suprimido por reflejo (Return).");
    } else if (result == PowerUseResult.blocked) {
      // El feedback visual ("¡ATAQUE BLOQUEADO!") ya es manejado por SabotageOverlay
      // via effectProvider.notifyAttackBlocked(), así que solo evitamos el mensaje de error.
      debugPrint(
          "InventoryScreen: Ataque bloqueado, suprimiendo error genérico.");
    } else if (result == PowerUseResult.gameFinished) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
              '⚠️ No puedes usar poderes porque ya terminaste la carrera.'),
          backgroundColor: Colors.grey,
        ),
      );
    } else if (result == PowerUseResult.targetFinished) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('⚠️ El objetivo ya terminó la carrera.'),
          backgroundColor: Colors.grey,
        ),
      );
    } else {
      final errorMsg = playerProvider.lastPowerError ??
          'Error: No se pudo usar el objeto (¿Sin munición o error de conexión?)';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(errorMsg),
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
          const Icon(
            Icons.shopping_bag_outlined,
            size: 80,
            color: AppTheme.accentGold,
          ),
          const SizedBox(height: 20),
          Text(
            'Inventario vacío',
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
              color: AppTheme.accentGold,
              fontWeight: FontWeight.bold,
              shadows: [
                const Shadow(
                  color: Colors.black,
                  offset: Offset(1, 1),
                  blurRadius: 4,
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          const Text(
            'Visita La Tiendita para comprar poderes',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
              shadows: [
                Shadow(
                  color: Colors.black,
                  offset: Offset(1, 1),
                  blurRadius: 4,
                ),
              ],
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class _AttackSuccessDialog extends StatefulWidget {
  final PowerItem? item;
  final String targetName;
  const _AttackSuccessDialog({this.item, required this.targetName});

  @override
  State<_AttackSuccessDialog> createState() => _AttackSuccessDialogState();
}

class _AttackSuccessDialogState extends State<_AttackSuccessDialog>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  late Animation<double> _opacityAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1500));
    _scaleAnimation = TweenSequence<double>([
      TweenSequenceItem(
          tween: Tween(begin: 0.0, end: 1.5)
              .chain(CurveTween(curve: Curves.elasticOut)),
          weight: 40),
      TweenSequenceItem(
          tween: Tween(begin: 1.5, end: 1.2)
              .chain(CurveTween(curve: Curves.easeInOut)),
          weight: 20),
      TweenSequenceItem(
          tween: Tween(begin: 1.2, end: 5.0)
              .chain(CurveTween(curve: Curves.fastOutSlowIn)),
          weight: 40),
    ]).animate(_controller);

    _opacityAnimation = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0.0, end: 1.0), weight: 20),
      TweenSequenceItem(tween: ConstantTween(1.0), weight: 60),
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 0.0), weight: 20),
    ]).animate(_controller);

    _controller.forward().then((_) {
      if (mounted) Navigator.pop(context);
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          return Opacity(
            opacity: _opacityAnimation.value,
            child: Transform.scale(
              scale: _scaleAnimation.value,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(widget.item?.icon ?? '⚡',
                      style: const TextStyle(fontSize: 80)),
                  const SizedBox(height: 10),
                  Material(
                    color: Colors.transparent,
                    child: Text(
                      widget.item == null
                          ? '¡ATAQUE ENVIADO!'
                          : '¡${widget.item!.id == "extra_life" || widget.item!.id == "shield" ? "USADO" : "LANZADO"}!',
                      style: const TextStyle(
                        color: AppTheme.accentGold,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 2,
                      ),
                    ),
                  ),
                  const SizedBox(height: 5),
                  Material(
                    color: Colors.transparent,
                    child: Text(
                      widget.targetName.isEmpty
                          ? ''
                          : 'Objetivo: ${widget.targetName}',
                      style: const TextStyle(color: Colors.white, fontSize: 10),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
