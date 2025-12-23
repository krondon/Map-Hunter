import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../features/game/providers/game_provider.dart';
import '../../features/game/providers/power_effect_provider.dart';
import '../../features/game/widgets/effects/blind_effect.dart';
import '../../features/game/widgets/effects/freeze_effect.dart';
import '../../features/game/widgets/effects/blur_effect.dart';
import '../../features/game/widgets/effects/life_steal_effect.dart';
import '../../features/game/widgets/effects/return_success_effect.dart';
import '../../features/game/widgets/effects/return_rejection_effect.dart';
import '../../features/game/widgets/effects/invisibility_effect.dart';
import '../../features/game/widgets/effects/steal_failed_effect.dart';
import '../models/player.dart';
import '../../features/auth/providers/player_provider.dart';

import '../utils/global_keys.dart'; // Importar para navegación

class SabotageOverlay extends StatefulWidget {
  final Widget child;
  const SabotageOverlay({super.key, required this.child});

  @override
  State<SabotageOverlay> createState() => _SabotageOverlayState();
}

class _SabotageOverlayState extends State<SabotageOverlay> {
  String? _lifeStealBannerText;
  Timer? _lifeStealBannerTimer;
  String? _lastLifeStealEffectId;
  
  // Control de bloqueo de navegación
  bool _isBlockingActive = false;

  @override
  void initState() {
    super.initState();

    // Usamos PostFrameCallback para asegurar que los Providers estén disponibles
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;

      final powerProvider =
          Provider.of<PowerEffectProvider>(context, listen: false);
      final gameProvider = Provider.of<GameProvider>(context, listen: false);
      final playerProvider =
          Provider.of<PlayerProvider>(context, listen: false);

      // Configuramos el handler que se dispara cuando detectamos un robo de vida
      powerProvider.configureLifeStealVictimHandler((effectId, casterId) async {
        final myId = playerProvider.currentPlayer?.id;
        if (myId == null) return;

        // Esperamos 600ms para que el número de vida baje justo cuando
        // el corazón de la animación central empieza a romperse
        await Future.delayed(const Duration(milliseconds: 600));

        // Esta llamada activa la resta optimista en GameProvider (_lives--)
        // lo que obliga al ProgressHeader a redibujarse con el nuevo valor.
        gameProvider.loseLife(myId);

        debugPrint(
            "Sincronización visual: Vida restada por ataque de $casterId");
      });
      
      // Listener para manejar cambios de bloqueo de navegación
      powerProvider.addListener(_handlePowerChanges);
    });
  }

  @override
  void dispose() {
    _lifeStealBannerTimer?.cancel();
    // Importante: remover listener
    // Como no guardamos la referencia al provider en una variable variable final,
    // intentar obtenerlo en dispose puede fallar si el contexto ya no es válido.
    // Lo ideal sería usar una referencia, pero en este patrón simple:
    // context.read<PowerEffectProvider>().removeListener(_handlePowerChanges);
    // (A veces lanza error si el widget se desmonta, así que lo envolvemos)
    try {
      if (mounted) {
        Provider.of<PowerEffectProvider>(context, listen: false)
            .removeListener(_handlePowerChanges);
      }
    } catch (_) {}
    super.dispose();
  }
  
  void _handlePowerChanges() {
    if (!mounted) return;
    final powerProvider = Provider.of<PowerEffectProvider>(context, listen: false);
    final activeSlug = powerProvider.activePowerSlug;
    
    // Lista de efectos que deben congelar la navegación
    final shouldBlock = activeSlug == 'freeze' || activeSlug == 'black_screen';

    if (shouldBlock && !_isBlockingActive) {
      _isBlockingActive = true;
      debugPrint("⛔ BLOQUEANDO NAVEGACIÓN por sabotaje ($activeSlug) ⛔");
      rootNavigatorKey.currentState?.push(_BlockingPageRoute()).then((_) {
        // Cuando la ruta se cierre (pop), actualizamos el estado
        // Esto maneja el caso donde el usuario pudiera cerrarlo (aunque no debería poder)
        if (mounted) {
           _isBlockingActive = false;
        }
      });
    } else if (!shouldBlock && _isBlockingActive) {
      debugPrint("✅ DESBLOQUEANDO NAVEGACIÓN ✅");
      rootNavigatorKey.currentState?.pop(); // Cierra _BlockingPageRoute
      _isBlockingActive = false;
    }
  }

  void _showLifeStealBanner(String message,
      {Duration duration = const Duration(seconds: 3)}) {
    _lifeStealBannerTimer?.cancel();
    setState(() {
      _lifeStealBannerText = message;
    });
    _lifeStealBannerTimer = Timer(duration, () {
      if (!mounted) return;
      setState(() {
        _lifeStealBannerText = null;
      });
    });
  }
  
  // ... resto de métodos ...
  String _resolvePlayerNameFromLeaderboard(String? casterGamePlayerId) {
    if (casterGamePlayerId == null || casterGamePlayerId.isEmpty)
      return 'Un rival';
    final gameProvider = context.read<GameProvider>();
    final match = gameProvider.leaderboard.whereType<Player>().firstWhere(
          (p) =>
              p.gamePlayerId == casterGamePlayerId ||
              p.id == casterGamePlayerId,
          orElse: () =>
              Player(id: '', name: 'Un rival', email: '', avatarUrl: ''),
        );
    return match.name.isNotEmpty ? match.name : 'Un rival';
  }

  @override
  Widget build(BuildContext context) {
    final powerProvider = Provider.of<PowerEffectProvider>(context);
    final activeSlug = powerProvider.activePowerSlug;
    final defenseAction = powerProvider.lastDefenseAction;
    final playerProvider = Provider.of<PlayerProvider>(context);
    // Detectamos si el usuario actual es invisible según el PlayerProvider
    final isPlayerInvisible =
        playerProvider.currentPlayer?.isInvisible ?? false;

    // Banner life_steal (Point B): sólo banner, no bloquea interacción.
    final effectId = powerProvider.activeEffectId;
    final isNewLifeSteal =
        activeSlug == 'life_steal' && effectId != _lastLifeStealEffectId;

    if (isNewLifeSteal) {
      _lastLifeStealEffectId = effectId;
      final attackerName =
          _resolvePlayerNameFromLeaderboard(powerProvider.activeEffectCasterId);

      // Opcional: El banner superior que ya tenías como backup
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _showLifeStealBanner('¡$attackerName te ha quitado una vida!');
      });
    }

    return Stack(
      children: [
        widget.child, // El juego base siempre debajo

        // Capas de sabotaje (se activan según el slug recibido de la DB)
        if (activeSlug == 'black_screen') const BlindEffect(),
        if (activeSlug == 'freeze') const FreezeEffect(),
        if (defenseAction == DefenseAction.returned) ...[
          if (powerProvider.returnedByPlayerName != null)
             ReturnRejectionEffect(
              returnedBy: powerProvider.returnedByPlayerName!,
            ),
          
          if (powerProvider.returnedAgainstCasterId != null)
            ReturnSuccessEffect(
              attackerName: _resolvePlayerNameFromLeaderboard(
                  powerProvider.returnedAgainstCasterId),
              powerSlug: powerProvider.returnedPowerSlug,
            ),
        ],
        
        if (activeSlug == 'life_steal')
          LifeStealEffect(
            key: ValueKey(effectId),
            casterName: _resolvePlayerNameFromLeaderboard(
                powerProvider.activeEffectCasterId),
          ),

        // blur_screen reutiliza el efecto visual de invisibility para los rivales.
        if (activeSlug == 'blur_screen')
          const BlurScreenEffect(), 

        // --- ESTADOS BENEFICIOSOS (BUFFS) ---
        if (isPlayerInvisible || activeSlug == 'invisibility')
          const InvisibilityEffect(),

        if (defenseAction == DefenseAction.shieldBlocked)
          _DefenseFeedbackToast(action: defenseAction),

        if (defenseAction == DefenseAction.stealFailed)
          StealFailedEffect(
            key: ValueKey(
              powerProvider.lastDefenseActionAt?.millisecondsSinceEpoch ?? 0,
            ),
          ),

        if (_lifeStealBannerText != null)
          Positioned(
            top: 12,
            left: 12,
            right: 12,
            child: Material(
              color: Colors.transparent,
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 200),
                child: Container(
                  key: ValueKey(_lifeStealBannerText),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  decoration: BoxDecoration(
                    color: Colors.red.shade900.withOpacity(0.92),
                    borderRadius: BorderRadius.circular(14),
                    border:
                        Border.all(color: Colors.redAccent.withOpacity(0.6)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.warning_amber_rounded,
                          color: Colors.white),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          _lifeStealBannerText!,
                          style: const TextStyle(
                              color: Colors.white, fontWeight: FontWeight.bold),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),

        // Feedback rápido para el atacante cuando su acción fue bloqueada o falló.
      ],
    );
  }
}

// Clase de ruta bloqueante transparente
class _BlockingPageRoute extends ModalRoute<void> {
  @override
  Color? get barrierColor => Colors.transparent; // No añade color extra, los efectos ya cubren

  @override
  bool get barrierDismissible => false;

  @override
  String? get barrierLabel => null;

  @override
  bool get maintainState => true;

  @override
  bool get opaque => false;

  @override
  Duration get transitionDuration => Duration.zero;

  @override
  Widget buildPage(BuildContext context, Animation<double> animation,
      Animation<double> secondaryAnimation) {
    // PopScope (o WillPopScope legado) atrapa el botón back
    return PopScope(
      canPop: false,
      onPopInvoked: (didPop) {
        // Si queremos, podemos mostrar un toast aquí diciendo "Estás congelado"
      },
      child: const SizedBox.expand(), // Bloquea touches si no está cubierto
    );
  }
}

class _DefenseFeedbackToast extends StatelessWidget {
  final DefenseAction? action;

  const _DefenseFeedbackToast({required this.action});

  @override
  Widget build(BuildContext context) {
    // Si la acción es 'returned', devolvemos shrink porque el mensaje detallado
    // (ReturnRejectionEffect) ya se está mostrando en el Stack principal.
    if (action == null ||
        action == DefenseAction.returned ||
        action == DefenseAction.stealFailed) {
      return const SizedBox.shrink();
    }

    // Aquí solo llegamos si action == DefenseAction.shieldBlocked
    const String message = '🛡️ ¡ATAQUE BLOQUEADO POR ESCUDO!';

    return Positioned(
      top: 16,
      right: 16,
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 200),
        transitionBuilder: (child, animation) => FadeTransition(
          opacity: animation,
          child: SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(0, -0.1),
              end: Offset.zero,
            ).animate(animation),
            child: child,
          ),
        ),
        child: Container(
          key: ValueKey(action),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.85),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Colors.white24),
            boxShadow: const [
              BoxShadow(
                color: Colors.black54,
                blurRadius: 8,
                offset: Offset(0, 4),
              ),
            ],
          ),
          child: Text(
            message,
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ),
    );
  }
}
