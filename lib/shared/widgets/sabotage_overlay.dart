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
import '../../features/game/widgets/effects/shield_break_effect.dart'; // NEW IMPORT
import '../models/player.dart';
import '../../features/auth/providers/player_provider.dart';
import '../../features/mall/models/power_item.dart'; // Required for PowerType

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
  
  // EVENT DRIVEN STATE
  StreamSubscription<PowerFeedbackEvent>? _feedbackSubscription;
  DefenseAction? _localDefenseAction;
  Timer? _localDefenseActionTimer;
  bool _showShieldBreakAnimation = false;

  // Cached provider references to avoid context access in callbacks
  PowerEffectProvider? _powerProviderRef;
  PlayerProvider? _playerProviderRef;
  GameProvider? _gameProviderRef;
  String? _lastKnownGamePlayerId;

  @override
  void initState() {
    super.initState();

    // Usamos PostFrameCallback para asegurar que los Providers estén disponibles
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;

      debugPrint('[DEBUG] 🎭 SabotageOverlay.initState() - PostFrameCallback START');
      
      // Cache provider references
      _powerProviderRef = Provider.of<PowerEffectProvider>(context, listen: false);
      _gameProviderRef = Provider.of<GameProvider>(context, listen: false);
      _playerProviderRef = Provider.of<PlayerProvider>(context, listen: false);

      debugPrint('[DEBUG]    powerProvider.listeningForId: ${_powerProviderRef?.listeningForId}');
      debugPrint('[DEBUG]    playerProvider.gamePlayerId: ${_playerProviderRef?.currentPlayer?.gamePlayerId}');

      // Configurar el handler y listener
      // _configureLifeStealHandler(); // REMOVED: Event Driven now
      _tryStartListening();
      
      // Listener para Stream de Feedback
      _feedbackSubscription?.cancel();
      _feedbackSubscription = _powerProviderRef?.feedbackStream.listen(_handleFeedback);
      
      // Listener para manejar cambios de bloqueo de navegación
      _powerProviderRef?.addListener(_handlePowerChanges);
      
      // CRITICAL: Listener para detectar cuando gamePlayerId cambia
      _playerProviderRef?.addListener(_onPlayerChanged);
    });
  }

  void _onPlayerChanged() {
    if (!mounted) return;
    final newGamePlayerId = _playerProviderRef?.currentPlayer?.gamePlayerId;
    
    // Solo reconfigurar si el ID cambió a un valor válido
    if (newGamePlayerId != null && 
        newGamePlayerId.isNotEmpty && 
        newGamePlayerId != _lastKnownGamePlayerId) {
      debugPrint('[DEBUG] 🔄 SabotageOverlay: gamePlayerId CHANGED: $_lastKnownGamePlayerId -> $newGamePlayerId');
      _lastKnownGamePlayerId = newGamePlayerId;
      _tryStartListening();
    }
  }

  void _handleFeedback(PowerFeedbackEvent event) {
      if (!mounted) return;
      
      debugPrint('[OVERLAY] 📨 Feedback Event Received: ${event.type}');
      
      switch (event.type) {
        case PowerFeedbackType.lifeStolen:
            final attackerName = _resolvePlayerNameFromLeaderboard(event.relatedPlayerName);
            _lifeStealAnimationTimer?.cancel();
            setState(() {
              _showLifeStealAnimation = true;
              _lifeStealCasterName = attackerName;
            });
            
            _showLifeStealBanner('¡$attackerName te ha quitado una vida!');
            
            _lifeStealAnimationTimer = Timer(const Duration(seconds: 4), () {
              if (mounted) {
                setState(() {
                  _showLifeStealAnimation = false;
                  _lifeStealCasterName = null;
                });
              }
            });
            // Haptic
            // HapticFeedback.heavyImpact(); // Opcional si ya se hace en strategy
            break;
            
        case PowerFeedbackType.shieldBroken:
            _triggerLocalDefenseAction(DefenseAction.shieldBroken);
            setState(() {
               _showShieldBreakAnimation = true;
            });
            // La animación de escudo roto se maneja con el widget ShieldBreakEffect que tiene onComplete?
            // O simplemente lo mostramos por un tiempo.
            // El widget existente tiene su propio controller y onComplete.
            break;
            
        case PowerFeedbackType.attackBlocked:
             _triggerLocalDefenseAction(DefenseAction.attackBlockedByEnemy);
             break;
             
        case PowerFeedbackType.defenseSuccess:
             // Generic success
             break;
             
        case PowerFeedbackType.returned:
             _triggerLocalDefenseAction(DefenseAction.returned);
             break;
      }
  }

  void _triggerLocalDefenseAction(DefenseAction action) {
      _localDefenseActionTimer?.cancel();
      setState(() {
          _localDefenseAction = action;
      });
      
      _localDefenseActionTimer = Timer(const Duration(seconds: 3), () {
          if (mounted) {
              setState(() {
                  _localDefenseAction = null;
                  _showShieldBreakAnimation = false; 
              });
          }
      });
  }

  void _tryStartListening() {
    final powerProvider = _powerProviderRef;
    final playerProvider = _playerProviderRef;
    if (powerProvider == null || playerProvider == null) return;

    final currentGamePlayerId = playerProvider.currentPlayer?.gamePlayerId;
    if (currentGamePlayerId != null && currentGamePlayerId.isNotEmpty) {
      debugPrint('[DEBUG] 🔄 SabotageOverlay: Iniciando listener con gamePlayerId: $currentGamePlayerId');
      _lastKnownGamePlayerId = currentGamePlayerId;
      powerProvider.startListening(currentGamePlayerId, forceRestart: true);
    } else {
      debugPrint('[DEBUG] ⚠️ SabotageOverlay: gamePlayerId aún es NULL, esperando cambio...');
    }
  }

  @override
  void dispose() {
    _lifeStealBannerTimer?.cancel();
    _lifeStealAnimationTimer?.cancel();
    _feedbackSubscription?.cancel();
    _localDefenseActionTimer?.cancel();
    
    // Remove listeners using cached references (safe, no context access)
    _powerProviderRef?.removeListener(_handlePowerChanges);
    _playerProviderRef?.removeListener(_onPlayerChanged);
    
    super.dispose();
  }
  
  void _handlePowerChanges() {
    if (!mounted) return;
    
    // Use cached refs instead of context access
    final powerProvider = _powerProviderRef;
    final gameProvider = _gameProviderRef;
    if (powerProvider == null || gameProvider == null) return;
    
    // Check concurrent blocking effects
    final isFreezeActive = powerProvider.isEffectActive('freeze');
    final isBlackScreenActive = powerProvider.isEffectActive('black_screen');
    
    // Lista de efectos que deben congelar la navegación
    final shouldBlock = isFreezeActive || isBlackScreenActive;
    
    // Actualizar estado de congelamiento en GameProvider
    // AHORA: Tanto freeze como black_screen pausan los minijuegos
    final shouldPauseGame = shouldBlock;
    
    if (shouldPauseGame && !gameProvider.isFrozen) {
      gameProvider.setFrozen(true);
    } else if (!shouldPauseGame && gameProvider.isFrozen) {
      gameProvider.setFrozen(false);
    }

    if (shouldBlock && !_isBlockingActive) {
      _isBlockingActive = true;
      debugPrint("⛔ BLOQUEANDO NAVEGACIÓN por sabotaje (freeze/black_screen) ⛔");
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
    
    // Use cached ref instead of context.read
    final gameProvider = _gameProviderRef;
    if (gameProvider == null) return 'Un rival';
    
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
    // Usamos _localDefenseAction en lugar de activeDefenseAction del provider
    final defenseAction = _localDefenseAction;
    final playerProvider = Provider.of<PlayerProvider>(context);
    // Detectamos si el usuario actual es invisible según el PlayerProvider
    final isPlayerInvisible =
        playerProvider.currentPlayer?.isInvisible ?? false;
    
    // Concurrent Effect Checks
    final isBlackScreen = powerProvider.isEffectActive('black_screen');
    final isFreeze = powerProvider.isEffectActive('freeze');
    final isBlur = powerProvider.isEffectActive('blur_screen');
    final isInvisible = powerProvider.isEffectActive('invisibility');
    
    // RESTORED: Variables needed for legacy Blur check
    final activeSlug = powerProvider.activePowerSlug;
    final effectId = powerProvider.activeEffectId;

    // Banner blur_screen: Notificar quién te saboteó con visión borrosa
    // Mantenemos la lógica de estado persistente para BLUR ya que tiene duración
    // Pero la notificación podría moverse a evento también. Por ahora lo dejamos como estaba.
    // O mejor, eliminamos la lógica compleja de detección de cambio de ID si es posible.
    // El request pedía "Elimina comprobaciones de activePowerSlug".
    // Blur es un efecto de duración, así que 'isBlur' (line 265) sigue siendo válido para el efecto visual.
    // La notificación "XXX te nubló la vista" debería ser un evento, pero no tenemos evento 'blurApplied' todavía en el provider.
    // Dejaremos Blur como está por ahora, limpiando solo LifeSteal.
    
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

        // Capas de sabotaje (se activan concurrente)
        if (isBlackScreen) 
            BlindEffect(expiresAt: powerProvider.getPowerExpiration('black_screen')),
        
        if (isFreeze) 
            FreezeEffect(expiresAt: powerProvider.getPowerExpiration('freeze')),
            
        // blur_screen reutiliza el efecto visual de invisibility para los rivales.
         if (isBlur)
           BlurScreenEffect(expiresAt: powerProvider.getPowerExpirationByType(PowerType.blur) ?? DateTime.now().add(const Duration(seconds: 5))), 

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



        // --- ESTADOS BENEFICIOSOS (BUFFS) ---
        if (isPlayerInvisible || isInvisible)
          InvisibilityEffect(expiresAt: powerProvider.getPowerExpiration('invisibility')),

        if (defenseAction == DefenseAction.shieldBlocked || 
            defenseAction == DefenseAction.attackBlockedByEnemy)
          _DefenseFeedbackToast(action: defenseAction),

        if (_showShieldBreakAnimation) ...[
             ShieldBreakEffect(
               onComplete: () {
                  // Opcional: resetear estado si queremos, pero el timer lo hará.
               },
             ),
             _DefenseFeedbackToast(action: defenseAction),
        ],

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

    // Aquí solo llegamos si action == DefenseAction.shieldBlocked o shieldBroken, O attackBlockedByEnemy
    String message = '🛡️ ¡ATAQUE BLOQUEADO!';
    Color bgColor = Colors.black.withOpacity(0.9);
    
    if (action == DefenseAction.shieldBroken) {
        message = '🛡️💔 ¡ESCUDO ROTO!';
    } else if (action == DefenseAction.shieldBlocked) {
        message = '🛡️ ¡ATAQUE BLOQUEADO!';
    } else if (action == DefenseAction.attackBlockedByEnemy) {
        message = '⛔ ¡TU ATAQUE FUE BLOQUEADO!';
        bgColor = Colors.red.withOpacity(0.9);
    }

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
              color: bgColor,
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
