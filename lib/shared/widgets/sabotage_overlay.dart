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
  String? _lastBlurEffectId; // Track blur to avoid duplicate notifications
  
  // Control de animación LifeSteal (desacoplado de expiración en BD)
  bool _showLifeStealAnimation = false;
  String? _lifeStealCasterName;
  Timer? _lifeStealAnimationTimer;
  
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
      powerProvider.configureLifeStealVictimHandler((effectId, casterId, targetId) async {        
        // 1. Obtener IDs locales
        final myUserId = playerProvider.currentPlayer?.userId;
        final myGamePlayerId = playerProvider.currentPlayer?.gamePlayerId;

        debugPrint("[DEBUG] 💔 LifeStealVictimHandler DISPARADO");
        debugPrint("[DEBUG]    Effect ID: $effectId");
        debugPrint("[DEBUG]    Caster ID: $casterId");
        debugPrint("[DEBUG]    Target ID: $targetId");
        debugPrint("[DEBUG]    Mi GamePlayer ID: $myGamePlayerId");
        debugPrint("[DEBUG]    Mi User ID: $myUserId");

        // 2. VALIDACIÓN CRÍTICA DE VÍCTIMA
        // Si el target del evento no soy yo (por error de stream o broadcast), IGNORAR.
        if (myGamePlayerId != null && targetId != myGamePlayerId) {
           debugPrint("[DEBUG] 🚫 BLOQUEADO: Discrepancia de ID (Target: $targetId != Yo: $myGamePlayerId)");
           return;
        }

        if (myUserId == null) {
          debugPrint("[DEBUG] ⚠️ BLOQUEADO: myUserId es NULL");
          return;
        }

        debugPrint("[DEBUG] ✅ Validación pasada, ejecutando resta de vida...");

        // 3. ACTIVAR ANIMACIÓN LIFESTEAL (desacoplado de expiración BD)
        final attackerName = _resolvePlayerNameFromLeaderboard(casterId);
        _lifeStealAnimationTimer?.cancel();
        if (mounted) {
          setState(() {
            _showLifeStealAnimation = true;
            _lifeStealCasterName = attackerName;
          });
        }
        
        // Timer de 4 segundos para ocultar la animación
        _lifeStealAnimationTimer = Timer(const Duration(seconds: 4), () {
          if (mounted) {
            setState(() {
              _showLifeStealAnimation = false;
              _lifeStealCasterName = null;
            });
          }
        });

        // Esperamos 600ms para que el número de vida baje justo cuando
        // el corazón de la animación central empieza a romperse
        await Future.delayed(const Duration(milliseconds: 600));

        // ELIMINADO: La resta de vida ya se realiza en el Backend (SQL).
        // GameProvider se actualiza automáticamente vía Realtime (game_players stream).
        // No llamamos a loseLife() aquí para evitar DOBLE resta (Optimista + Backend).
        debugPrint(
            "[DEBUG] 💀 Visual Only: Animación de Life Steal iniciada. Esperando update de vidas por Realtime...");
      });
      
      // Listener para manejar cambios de bloqueo de navegación
      powerProvider.addListener(_handlePowerChanges);
    });
  }

  @override
  void dispose() {
    _lifeStealBannerTimer?.cancel();
    _lifeStealAnimationTimer?.cancel();
    // CRITICAL FIX: No acceder a context en dispose()
    // El listener se limpiará automáticamente cuando el provider sea destruido
    // o usamos una referencia guardada si la tuviéramos.
    // Por ahora, lo dejamos sin remover explícitamente ya que causa el error.
    super.dispose();
  }
  
  void _handlePowerChanges() {
    if (!mounted) return;
    final powerProvider = Provider.of<PowerEffectProvider>(context, listen: false);
    final activeSlug = powerProvider.activePowerSlug;
    
    // Lista de efectos que deben congelar la navegación
    final shouldBlock = activeSlug == 'freeze' || activeSlug == 'black_screen';
    
    // Actualizar estado de congelamiento en GameProvider
    // AHORA: Tanto freeze como black_screen pausan los minijuegos
    final gameProvider = Provider.of<GameProvider>(context, listen: false);
    final shouldPauseGame = activeSlug == 'freeze' || activeSlug == 'black_screen';
    
    if (shouldPauseGame && !gameProvider.isFrozen) {
      gameProvider.setFrozen(true);
    } else if (!shouldPauseGame && gameProvider.isFrozen) {
      gameProvider.setFrozen(false);
    }

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
              Player(userId: '', name: 'Un rival', email: '', avatarUrl: ''),
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

    // DEBUG: Ver qué slug está llegando
    if (activeSlug != null) {
      debugPrint("🌫️ SabotageOverlay: activeSlug = '$activeSlug'");
    }

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

    // Banner blur_screen: Notificar quién te saboteó con visión borrosa
    final isNewBlur =
        activeSlug == 'blur_screen' && effectId != _lastBlurEffectId;

    if (isNewBlur) {
      _lastBlurEffectId = effectId;
      final attackerName =
          _resolvePlayerNameFromLeaderboard(powerProvider.activeEffectCasterId);

      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _showLifeStealBanner('🌫️ ¡$attackerName te nubló la vista!');
      });
    }

    return Stack(
      children: [
        widget.child, // El juego base siempre debajo

        // Capas de sabotaje (se activan según el slug recibido de la DB)
        if (activeSlug == 'black_screen') BlindEffect(expiresAt: powerProvider.activePowerExpiresAt),
        if (activeSlug == 'freeze') FreezeEffect(expiresAt: powerProvider.activePowerExpiresAt),
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
        
        // LIFESTEAL: Usa estado local (desacoplado de expiración BD)
        if (_showLifeStealAnimation && _lifeStealCasterName != null)
          LifeStealEffect(
            key: ValueKey(_lifeStealCasterName),
            casterName: _lifeStealCasterName!,
          ),

        // blur_screen reutiliza el efecto visual de invisibility para los rivales.
        if (activeSlug == 'blur_screen')
          BlurScreenEffect(expiresAt: powerProvider.activePowerExpiresAt), 

        // --- ESTADOS BENEFICIOSOS (BUFFS) ---
        if (isPlayerInvisible || activeSlug == 'invisibility')
          InvisibilityEffect(expiresAt: powerProvider.activePowerExpiresAt),

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
            top: 50, // Bajado para evitar overlap con barra de estado
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
                            color: Colors.white,
                            fontWeight: FontWeight.w800,
                            fontSize: 14,
                            decoration: TextDecoration.none,
                          ),
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
        child: Material(
          color: Colors.transparent,
          child: Container(
            key: ValueKey(action),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.9),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white24, width: 1.2),
              boxShadow: const [
                BoxShadow(
                  color: Colors.black54,
                  blurRadius: 12,
                  offset: Offset(0, 6),
                ),
              ],
            ),
            child: Text(
              message,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w900,
                fontSize: 13,
                letterSpacing: 0.5,
                decoration: TextDecoration.none,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
