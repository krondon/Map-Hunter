import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../features/game/providers/game_provider.dart';
import '../../features/game/providers/game_provider.dart';
import '../../features/game/providers/game_provider.dart';
import '../../features/game/providers/power_effect_provider.dart'; // Needed for casting references
import '../../features/game/providers/power_interfaces.dart';
import '../../features/game/widgets/effects/blind_effect.dart';
import '../../features/game/widgets/effects/freeze_effect.dart';

import '../../features/game/widgets/effects/blur_effect.dart';
import '../../features/game/widgets/effects/life_steal_effect.dart';
import '../../features/game/widgets/effects/return_success_effect.dart';
import '../../features/game/widgets/effects/return_rejection_effect.dart';
import '../../features/game/widgets/effects/invisibility_effect.dart';
import '../../features/game/widgets/effects/steal_failed_effect.dart';
import '../../features/game/widgets/effects/shield_break_effect.dart'; // Defender (Broken)
import '../../features/game/widgets/effects/shield_breaking_effect.dart'; // Attacker (Blocked)
import '../../features/game/widgets/effects/shield_active_effect.dart'; // NEW Shield Active Logic
import '../models/player.dart';
import '../../features/auth/providers/player_provider.dart';
import '../../features/mall/models/power_item.dart'; // Required for PowerType

import '../utils/global_keys.dart'; // Importar para navegación
import '../../features/game/widgets/minigames/game_over_overlay.dart';
import '../../features/mall/screens/mall_screen.dart';
import '../../core/services/effect_timer_service.dart'; // NEW: For timer expiration events

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

  // Gift received banner
  String? _giftBannerText;
  Timer? _giftBannerTimer;

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
  bool _showAttackBlockedAnimation = false;

  // Estado para bloquear pantalla si roban la última vida
  bool _showNoLivesFromSteal = false;

  // RETURN FEEDBACK STATE (Autonomous)
  bool _showReturnSuccessAnimation = false;
  String? _returnSuccessAttackerName;
  String? _returnSuccessPowerSlug;
  String _noLivesTitle = '¡SIN VIDAS!';
  String _noLivesMessage =
      '¡Te han robado tu última vida!\nNecesitas comprar más vidas para continuar.';
  bool _noLivesCanRetry = false;
  bool _noLivesShowShop = true;

  // NEW: Timer expiration subscription for guaranteed unlock
  StreamSubscription<EffectEvent>? _timerEventSubscription;

  // Cached provider references
  PowerEffectReader? _powerReaderRef;
  PowerEffectManager? _powerManagerRef;
  PlayerProvider? _playerProviderRef;
  GameProvider? _gameProviderRef;
  String? _lastKnownGamePlayerId;

  @override
  void initState() {
    super.initState();

    // Usamos PostFrameCallback para asegurar que los Providers estén disponibles
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;

      debugPrint(
          '[DEBUG] 🎭 SabotageOverlay.initState() - PostFrameCallback START');

      // Cache provider references
      _powerReaderRef = Provider.of<PowerEffectReader>(context, listen: false);
      _powerManagerRef =
          Provider.of<PowerEffectManager>(context, listen: false);
      _gameProviderRef = Provider.of<GameProvider>(context, listen: false);
      _playerProviderRef = Provider.of<PlayerProvider>(context, listen: false);

      debugPrint(
          '[DEBUG]    powerManager present: ${_powerManagerRef != null}');
      debugPrint(
          '[DEBUG]    playerProvider.gamePlayerId: ${_playerProviderRef?.currentPlayer?.gamePlayerId}');

      // Configurar el handler y listener
      // _configureLifeStealHandler(); // REMOVED: Event Driven now
      _tryStartListening();

      // Listener para Stream de Feedback
      _feedbackSubscription?.cancel();
      _feedbackSubscription =
          _powerReaderRef?.feedbackStream.listen(_handleFeedback);

      // Listener para manejar cambios de bloqueo de navegación
      _powerReaderRef?.addListener(_handlePowerChanges);

      // CRITICAL: Listener para detectar cuando gamePlayerId cambia
      _playerProviderRef?.addListener(_onPlayerChanged);

      // NEW: Subscribe to timer expiration events for GUARANTEED screen unlock
      _timerEventSubscription?.cancel();
      _timerEventSubscription = _powerReaderRef?.effectStream.listen((event) {
        // CRITICAL: Check mounted IMMEDIATELY before any state access
        if (!mounted) return;

        if (event.type == EffectEventType.expired ||
            event.type == EffectEventType.removed) {
          // Check if this was a blocking effect
          if (event.slug == 'freeze' || event.slug == 'black_screen') {
            debugPrint(
                '🔓 [UI-UNLOCK] SabotageOverlay: Efecto bloqueante expirado: ${event.slug}');

            // Use post-frame callback to ensure widget tree is stable
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (!mounted) return;
              _handlePowerChanges();
            });
          }
        }
      });
    });
  }

  void _onPlayerChanged() {
    // [FIX] Wrap in PostFrameCallback to avoid processing during build/teardown
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final newGamePlayerId = _playerProviderRef?.currentPlayer?.gamePlayerId;

      // Detectar cualquier cambio de ID
      if (newGamePlayerId != _lastKnownGamePlayerId) {
        debugPrint(
            '[DEBUG] 🔄 SabotageOverlay: gamePlayerId CHANGED: $_lastKnownGamePlayerId -> $newGamePlayerId');
        _lastKnownGamePlayerId = newGamePlayerId;

        // Si el nuevo ID es válido, iniciamos escucha.
        // Si es null/vacío (salió del juego), detenemos la escucha explícitamente.
        if (newGamePlayerId != null && newGamePlayerId.isNotEmpty) {
          _tryStartListening();
        } else {
          debugPrint(
              '[DEBUG] 🛑 SabotageOverlay: User left game (or null ID). STOPPING LISTENERS.');
          _powerManagerRef?.startListening(null, forceRestart: true);
          _isBlockingActive = false; // Reset blocking flag
        }
      }
    }); // Close PostFrameCallback
  }

  Future<String> _resolveNameWithFallback(String? attackerId) async {
    // 1. Try local leaderboard (Sync/Fast)
    String name = _resolvePlayerNameFromLeaderboard(attackerId);

    // 2. If ambiguous and we have an ID, try remote fetch (Async/Slow)
    if (name == 'Un espectador' &&
        attackerId != null &&
        attackerId.isNotEmpty) {
      final realName = await _gameProviderRef?.getPlayerName(attackerId);
      if (realName != null && realName.isNotEmpty) {
        return realName;
      }
    }
    return name;
  }

  void _handleFeedback(PowerFeedbackEvent event) async {
    if (!mounted) return;

    debugPrint('[OVERLAY] 📨 Feedback Event Received: ${event.type}');

    switch (event.type) {
      case PowerFeedbackType.lifeStolen:
        // 🛡️ User Constraint: Solo mostrar efecto si tiene vidas
        final currentLives = _playerProviderRef?.currentPlayer?.lives ?? 0;
        if (currentLives <= 0) {
          debugPrint(
              '[SabotageOverlay] 💀 Life Steal visual ignored (Lives: $currentLives)');
          return;
        }

        final attackerId = event.relatedPlayerName;

        // ⏳ AWAIT RESOLUTION BEFORE SHOWING UI (Prevent Flicker + Double Trigger Check)
        // If the same event arrives twice (idempotency check in provider should handle it,
        // but the async gap here could allow re-entry if provider emits twice for some reason).

        // To be 100% safe, we could track processed attackerIds for Life Steal within a short window here?
        // But let's trust the Provider idempotency for now.

        final resolvedName = await _resolveNameWithFallback(attackerId);
        if (!mounted) return;

        _lifeStealAnimationTimer?.cancel();
        setState(() {
          _showLifeStealAnimation = true;
          _lifeStealCasterName = resolvedName;
        });

        _showLifeStealBanner('¡$resolvedName te ha quitado una vida!');

        // Actualizar vidas del jugador y del GameProvider
        // para que puzzle_screen detecte el cambio
        _playerProviderRef?.refreshProfile();
        final userId = _playerProviderRef?.currentPlayer?.userId;
        if (userId != null) {
          _gameProviderRef?.fetchLives(userId);
        }

        _lifeStealAnimationTimer = Timer(const Duration(seconds: 4), () {
          if (mounted) {
            setState(() {
              _showLifeStealAnimation = false;
              _lifeStealCasterName = null;
            });

            // Verificar VIDAS después de actualizar
            final lives = _playerProviderRef?.currentPlayer?.lives ?? 0;
            if (lives <= 0) {
              setState(() {
                _showNoLivesFromSteal = true;
                _noLivesTitle = '¡SIN VIDAS!';
                _noLivesMessage =
                    '¡Te han robado tu última vida!\nNecesitas comprar más vidas para continuar.';
                _noLivesCanRetry = false;
                _noLivesShowShop = true;
              });
            }
          }
        });
        break;

      case PowerFeedbackType.shieldBroken:
        debugPrint('🛡️ [UI] SabotageOverlay received shieldBroken event');
        _triggerLocalDefenseAction(DefenseAction.shieldBroken);
        setState(() {
          _showShieldBreakAnimation = true;
        });
        break;

      case PowerFeedbackType.attackBlocked:
        _triggerLocalDefenseAction(DefenseAction.attackBlockedByEnemy);
        setState(() {
          _showAttackBlockedAnimation = true;
        });
        break;

      case PowerFeedbackType.defenseSuccess:
        // Generic success
        break;

      case PowerFeedbackType.returnSuccess:
        // Autonomous feedback logic (like Shield)
        final attackerId = event.relatedPlayerName;

        // ⏳ AWAIT RESOLUTION
        final attackerName = await _resolveNameWithFallback(attackerId);
        if (!mounted) return;

        final pProvider =
            Provider.of<PowerEffectReader>(context, listen: false);
        final slug = pProvider is PowerEffectProvider
            ? (pProvider as PowerEffectProvider).returnedPowerSlug
            : null;

        setState(() {
          _showReturnSuccessAnimation = true;
          _returnSuccessAttackerName = attackerName;
          _returnSuccessPowerSlug = slug;
        });

        // Set timer to hide return success card
        Timer(const Duration(seconds: 4), () {
          if (mounted) {
            setState(() {
              _showReturnSuccessAnimation = false;
              _returnSuccessAttackerName = null;
              _returnSuccessPowerSlug = null;
            });
          }
        });
        break;

      case PowerFeedbackType.returnRejection:
        _triggerLocalDefenseAction(DefenseAction.returned);
        break;

      case PowerFeedbackType.returned:
        _triggerLocalDefenseAction(DefenseAction.returned);
        break;

      case PowerFeedbackType.stealFailed:
        _triggerLocalDefenseAction(DefenseAction.stealFailed);
        break;

      case PowerFeedbackType.giftReceived:
        final giftMsg = event.message.isNotEmpty
            ? '🎁 ${event.message}'
            : '🎁 ¡Has recibido un regalo!';
        _showGiftBanner(giftMsg);
        _playerProviderRef?.refreshProfile();
        break;
    }
  }

  void _triggerLocalDefenseAction(DefenseAction action) {
    _localDefenseActionTimer?.cancel();
    setState(() {
      _localDefenseAction = action;
    });

    _localDefenseActionTimer = Timer(const Duration(seconds: 5), () {
      if (mounted) {
        setState(() {
          _localDefenseAction = null;
          _showShieldBreakAnimation = false;
          _showAttackBlockedAnimation = false;
        });
      }
    });
  }

  void _tryStartListening() {
    final powerManager = _powerManagerRef;
    final playerProvider = _playerProviderRef;
    if (powerManager == null || playerProvider == null) return;

    final currentGamePlayerId = playerProvider.currentPlayer?.gamePlayerId;
    final currentEventId = playerProvider.currentPlayer?.currentEventId;

    if (currentGamePlayerId != null && currentGamePlayerId.isNotEmpty) {
      debugPrint(
          '[DEBUG] 🔄 SabotageOverlay: Iniciando listener con gamePlayerId: $currentGamePlayerId, eventId: $currentEventId');
      _lastKnownGamePlayerId = currentGamePlayerId;
      powerManager.startListening(currentGamePlayerId,
          eventId: currentEventId, forceRestart: true);
    } else {
      debugPrint(
          '[DEBUG] ⚠️ SabotageOverlay: gamePlayerId aún es NULL, esperando cambio...');
    }
  }

  void _showGiftBanner(String message,
      {Duration duration = const Duration(seconds: 4)}) {
    _giftBannerTimer?.cancel();
    setState(() {
      _giftBannerText = message;
    });
    _giftBannerTimer = Timer(duration, () {
      if (!mounted) return;
      setState(() {
        _giftBannerText = null;
      });
    });
  }

  @override
  void dispose() {
    _lifeStealBannerTimer?.cancel();
    _lifeStealAnimationTimer?.cancel();
    _giftBannerTimer?.cancel();
    _feedbackSubscription?.cancel();
    _localDefenseActionTimer?.cancel();
    _timerEventSubscription?.cancel(); // NEW: Cancel timer event subscription

    // Remove listeners using cached references (safe, no context access)
    _powerReaderRef?.removeListener(_handlePowerChanges);
    _playerProviderRef?.removeListener(_onPlayerChanged);

    super.dispose();
  }

  void _handlePowerChanges() {
    // [FIX] Wrap in PostFrameCallback to avoid processing during build/teardown
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;

      // Use cached refs instead of context access
      final powerProvider = _powerReaderRef;
      final gameProvider = _gameProviderRef;
      final playerProvider = _playerProviderRef;

      if (powerProvider == null ||
          gameProvider == null ||
          playerProvider == null) return;

      // ⚡ HARD GATE: Si no hay gamePlayerId, NO BLOQUEAMOS NADA.
      // Esto previene que efectos "fantasma" que llegan justo al salir bloqueen la UI.
      final gpId = playerProvider.currentPlayer?.gamePlayerId;
      if (gpId == null || gpId.isEmpty) {
        if (_isBlockingActive) {
          debugPrint(
              "✅ DESBLOQUEANDO NAVEGACIÓN (Hard Gate triggered) - Skipping pop (AuthMonitor clears stack) ✅");
          _isBlockingActive = false;
        }
        return;
      }

      // Check concurrent blocking effects
      final isFreezeActive = powerProvider.isEffectActive('freeze');
      final isBlackScreenActive = powerProvider.isEffectActive('black_screen');

      debugPrint(
          '[UNBLOCK-CHECK] freeze=$isFreezeActive, black_screen=$isBlackScreenActive, _isBlockingActive=$_isBlockingActive');

      // Lista de efectos que deben congelar la navegación
      final shouldBlock = isFreezeActive || isBlackScreenActive;

      // Actualizar estado de congelamiento en GameProvider
      // AHORA: Tanto freeze como black_screen pausan los minijuegos
      // Actualizar estado de congelamiento en GameProvider
      // AHORA: Tanto freeze como black_screen pausan los minijuegos
      final shouldPause = isFreezeActive || isBlackScreenActive;
      if (gameProvider.isFrozen != shouldPause) {
        debugPrint(
            "⏸️ [PAUSE-SYNC] Setting isFrozen=$shouldPause (caused by sabotage)");
        gameProvider.setFrozen(shouldPause);
      }

      if (shouldBlock && !_isBlockingActive) {
        _isBlockingActive = true;
        debugPrint(
            "⛔ BLOQUEANDO NAVEGACIÓN por sabotaje (freeze/black_screen) ⛔");
        rootNavigatorKey.currentState?.push(_BlockingPageRoute()).then((_) {
          // Cuando la ruta se cierre (pop), actualizamos el estado
          // Esto maneja el caso donde el usuario pudiera cerrarlo (aunque no debería poder)
          if (mounted) {
            _isBlockingActive = false;
            debugPrint('🔓 [UI-UNLOCK] Ruta de bloqueo cerrada via .then()');
          }
        });
      } else if (!shouldBlock && _isBlockingActive) {
        debugPrint("✅ DESBLOQUEANDO NAVEGACIÓN ✅");
        _forcePopBlockingRoute();
      }
    }); // Close PostFrameCallback
  }

  /// Forces pop of blocking route with safety checks
  void _forcePopBlockingRoute() {
    if (!_isBlockingActive) return;

    final navigator = rootNavigatorKey.currentState;
    if (navigator != null && navigator.canPop()) {
      debugPrint('🔓 [UI-UNLOCK] Ejecutando pop de _BlockingPageRoute');
      navigator.pop();
    } else {
      debugPrint(
          '⚠️ [UI-UNLOCK] No se puede hacer pop, pero marcando _isBlockingActive=false');
    }
    _isBlockingActive = false;
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
      return 'Un espectador';

    // Use cached ref instead of context.read
    final gameProvider = _gameProviderRef;
    if (gameProvider == null) return 'Un espectador';

    final match = gameProvider.leaderboard.whereType<Player>().firstWhere(
          (p) =>
              p.gamePlayerId == casterGamePlayerId ||
              p.id == casterGamePlayerId,
          orElse: () => Player(
              userId: '', name: 'Un espectador', email: '', avatarUrl: ''),
        );
    return match.name.isNotEmpty ? match.name : 'Un espectador';
  }

  @override
  Widget build(BuildContext context) {
    // Usamos Consumer para escuchar cambios de forma segura en el árbol de widgets
    // Esto evita problemas de assertions durante reclasificación de ancestros (reparanting)
    return Consumer3<PowerEffectReader, PlayerProvider, GameProvider>(
      builder: (context, powerProvider, playerProvider, gameProvider, child) {
        // Usamos _localDefenseAction en lugar de activeDefenseAction del provider
        final defenseAction = _localDefenseAction;

        // Detectamos si el usuario actual es invisible según el PlayerProvider
        final isPlayerInvisible =
            playerProvider.currentPlayer?.isInvisible ?? false;

        // ⚡ HARD GATE: Si no hay gamePlayerId, NO mostramos NADA de sabotaje.
        final gpId = playerProvider.currentPlayer?.gamePlayerId;

        // [FIX] Validar también que estemos en una sesión de juego ACTIVA (GameProvider initialized)
        // Esto previene mostrar el escucho en Login, Lobby o Splash.
        final activeEventId = gameProvider.currentEventId;
        final playerEventId = playerProvider.currentPlayer?.currentEventId;

        // Requerimos:
        // 1. Tener gamePlayerId (Usuario logueado y provisionado)
        // 2. GameProvider debe tener un evento activo (Usuario entró a jugar)
        // 3. (Opcional) Coincidencia de evento para mayor seguridad

        if (gpId == null || activeEventId == null) {
          return child ?? const SizedBox();
        }

        // Concurrent Effect Checks
        final isBlackScreen = powerProvider.isEffectActive('black_screen');
        final isFreeze = powerProvider.isEffectActive('freeze');
        final isBlur = powerProvider.isEffectActive('blur_screen');
        final isInvisible = powerProvider.isEffectActive('invisibility');

        final activeSlug = powerProvider.activePowerSlug;
        final effectId = powerProvider.activeEffectId;

        // Blur Notification Logic
        final isNewBlur =
            activeSlug == 'blur_screen' && effectId != _lastBlurEffectId;

        if (isNewBlur) {
          // 🛡️ Prevent duplicate scheduling: Update tracking ID immediately
          _lastBlurEffectId = effectId;

          WidgetsBinding.instance.addPostFrameCallback((_) async {
            if (!mounted) return;
            final attackerId = powerProvider.activeEffectCasterId;

            // ⏳ AWAIT RESOLUTION
            final attackerName = await _resolveNameWithFallback(attackerId);
            if (!mounted) return;

            final bool isProtected = isPlayerInvisible || isInvisible;
            final String msg = isProtected
                ? '🌫️ ¡$attackerName intentó nublarte!'
                : '🌫️ ¡$attackerName te nubló la vista!';
            _showLifeStealBanner(msg);
          });
        }

        return Stack(
          children: [
            child ?? const SizedBox(),

            // ... resto de efectos usando las variables locales
            if (isBlackScreen)
              BlindEffect(
                  expiresAt: powerProvider.getPowerExpiration('black_screen')),

            if (isFreeze)
              FreezeEffect(
                  expiresAt: powerProvider.getPowerExpiration('freeze')),

            if (isBlur && !isPlayerInvisible && !isInvisible)
              BlurScreenEffect(
                  expiresAt:
                      powerProvider.getPowerExpirationByType(PowerType.blur) ??
                          DateTime.now().add(const Duration(seconds: 5))),

            if (defenseAction == DefenseAction.returned) ...[
              if (powerProvider.returnedByPlayerName != null)
                ReturnRejectionEffect(
                  returnedBy: powerProvider.returnedByPlayerName!,
                ),
            ],

            // INDEPENDENT RETURN SUCCESS FEEDBACK
            if (_showReturnSuccessAnimation)
              ReturnSuccessEffect(
                attackerName: _returnSuccessAttackerName ??
                    _resolvePlayerNameFromLeaderboard(_lastKnownGamePlayerId),
                powerSlug: _returnSuccessPowerSlug,
              ),

            if (_showLifeStealAnimation && _lifeStealCasterName != null)
              LifeStealEffect(
                key: ValueKey(_lifeStealCasterName),
                casterName: _lifeStealCasterName!,
              ),

            // Nuevo efecto de ESCUDO ACTIVO
            // Don't show active shield if it's currently breaking
            if (powerProvider.isEffectActive('shield') &&
                !_showShieldBreakAnimation)
              ShieldActiveEffect(
                  expiresAt: powerProvider.getPowerExpiration('shield')),

            if (isPlayerInvisible || isInvisible)
              InvisibilityEffect(
                  expiresAt: powerProvider.getPowerExpiration('invisibility')),

            if (defenseAction == DefenseAction.shieldBlocked ||
                defenseAction == DefenseAction.attackBlockedByEnemy)
              _DefenseFeedbackToast(action: defenseAction),

            if (_showShieldBreakAnimation) ...[
              ShieldBreakEffect(),
              _DefenseFeedbackToast(action: defenseAction),
            ],

            if (_showAttackBlockedAnimation) ...[
              ShieldBreakingEffect(
                title: '¡ATAQUE BLOQUEADO!',
                subtitle: 'El objetivo tenía un escudo activo',
              ),
              _DefenseFeedbackToast(action: defenseAction),
            ],

            if (defenseAction == DefenseAction.stealFailed)
              StealFailedEffect(
                key: ValueKey(
                  powerProvider.lastDefenseActionAt?.millisecondsSinceEpoch ??
                      0,
                ),
              ),

            if (_lifeStealBannerText != null)
              Positioned(
                top: 50,
                left: 12,
                right: 12,
                child: Material(
                  color: Colors.transparent,
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 200),
                    child: Container(
                      key: ValueKey(_lifeStealBannerText),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 12),
                      decoration: BoxDecoration(
                        color: Colors.red.shade900.withOpacity(0.92),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                            color: Colors.redAccent.withOpacity(0.6)),
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

            // 🎁 Gift Received Banner
            if (_giftBannerText != null)
              Positioned(
                top: 50,
                left: 12,
                right: 12,
                child: Material(
                  color: Colors.transparent,
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 200),
                    child: Container(
                      key: ValueKey(_giftBannerText),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 12),
                      decoration: BoxDecoration(
                        color: Colors.green.shade800.withOpacity(0.92),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                            color: Colors.greenAccent.withOpacity(0.6)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.card_giftcard, color: Colors.white),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              _giftBannerText!,
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

            if (_showNoLivesFromSteal) _buildGameOverOverlay(),
          ],
        );
      },
      child: widget.child,
    );
  }

  Widget _buildGameOverOverlay() {
    return GameOverOverlay(
      title: _noLivesTitle,
      message: _noLivesMessage,
      onRetry: _noLivesCanRetry
          ? () {
              setState(() {
                _showNoLivesFromSteal = false;
              });
            }
          : null,
      onExit: () {
        setState(() {
          _showNoLivesFromSteal = false;
        });
        rootNavigatorKey.currentState?.popUntil((route) => route.isFirst);
      },
      onGoToShop: _noLivesShowShop
          ? () async {
              setState(() {
                _showNoLivesFromSteal = false;
              });
              await rootNavigatorKey.currentState?.push(
                MaterialPageRoute(builder: (_) => const MallScreen()),
              );
              if (!mounted) return;
              await _playerProviderRef?.refreshProfile();
              final userId = _playerProviderRef?.currentPlayer?.userId;
              if (userId != null) {
                await _gameProviderRef?.fetchLives(userId);
              }
              final lives = _playerProviderRef?.currentPlayer?.lives ?? 0;
              setState(() {
                _showNoLivesFromSteal = true;
                if (lives > 0) {
                  _noLivesTitle = '¡VIDAS OBTENIDAS!';
                  _noLivesMessage =
                      'Ahora tienes $lives vidas.\nPuedes continuar jugando.';
                  _noLivesCanRetry = true;
                  _noLivesShowShop = false;
                } else {
                  _noLivesTitle = '¡SIN VIDAS!';
                  _noLivesMessage =
                      'Aún no tienes vidas.\nNecesitas comprar más vidas para continuar.';
                  _noLivesCanRetry = false;
                  _noLivesShowShop = true;
                }
              });
            }
          : null,
    );
  }
}

// Clase de ruta bloqueante transparente
class _BlockingPageRoute extends ModalRoute<void> {
  @override
  Color? get barrierColor =>
      Colors.transparent; // No añade color extra, los efectos ya cubren

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
