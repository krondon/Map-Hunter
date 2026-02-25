import 'dart:async';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../strategies/power_strategy_factory.dart';
import '../../game/repositories/power_repository_interface.dart';
import '../../mall/models/power_item.dart';
import '../../../core/services/effect_timer_service.dart';

import 'power_interfaces.dart';

// EXPORT TO MAINTAIN BACKWARD COMPATIBILITY
export 'power_interfaces.dart';

/// Provider encargado de escuchar y gestionar los efectos de poderes en tiempo real.
///
/// Funciona escuchando la tabla `active_powers` de Supabase.
///
/// Responsabilidades:
/// - Detectar ataques dirigidos al jugador (`startListening`).
/// - Gestionar la duración y expiración de los efectos visuales.
/// - Lógica de defensa (Escudos y Reflejo/Return).
/// - Coordinar efectos especiales como Life Steal.
class PowerEffectProvider extends ChangeNotifier
    implements PowerEffectReader, PowerEffectManager {
  // --- DEPENDENCY INJECTION (Phase 1 Refactoring) ---
  // --- DEPENDENCY INJECTION (Phase 1 Refactoring) ---
  final PowerRepository _repository;
  final EffectTimerService _timerService;
  final PowerStrategyFactory _powerStrategyFactory;

  /// Constructor with required dependencies.
  ///
  /// [repository] - Injected Repository for data access.
  /// [timerService] - Injected EffectTimerService for timer management (SRP).
  /// [strategyFactory] - Injected Factory for power strategies.
  PowerEffectProvider({
    required PowerRepository repository,
    required EffectTimerService timerService,
    required PowerStrategyFactory strategyFactory,
  })  : _repository = repository,
        _timerService = timerService,
        _powerStrategyFactory = strategyFactory;

  // --- EXPOSE TIMER SERVICE FOR STRATEGIES ---
  EffectTimerService get timerService => _timerService;

  @override
  Stream<EffectEvent> get effectStream => _timerService.effectStream;

  StreamSubscription? _subscription;
  StreamSubscription? _casterSubscription;
  StreamSubscription? _combatEventsSubscription;
  StreamSubscription<EffectEvent>?
      _timerEventSubscription; // NEW: Listen for timer expirations
  Timer? _defenseFeedbackTimer;

  String? _listeningForId;
  String? get listeningForId => _listeningForId;

  bool _isManualCasting = false;
  bool _isProtected = false;
  String? _activeDefenseSlug; // 'shield', 'return', or 'invisibility'
  DateTime? _shieldLastArmedAt; // Grace period for optimistic UI

  DateTime? _sessionStartTime;

  Future<void> Function(String effectId, String? casterGamePlayerId,
      String targetGamePlayerId)? _lifeStealVictimHandler;

  DefenseAction? _lastDefenseAction;
  DateTime? _lastDefenseActionAt;

  final Set<String> _processedEffectIds = {};

  String? _returnedByPlayerName;
  String? get returnedByPlayerName => _returnedByPlayerName;

  String? _returnedAgainstCasterId;
  String? get returnedAgainstCasterId => _returnedAgainstCasterId;

  String? _returnedPowerSlug;
  String? get returnedPowerSlug => _returnedPowerSlug;

  // --- MUTUAL EXCLUSIVITY FOR DEFENSE POWERS ---
  // FIX: Single source of truth from game_players.is_protected
  bool get isDefenseActive => _isProtected;

  String? get activeDefensePower => _isProtected ? _activeDefenseSlug : null;

  bool canActivateDefensePower(String powerSlug) {
    // STRICT EXCLUSIVITY: If any defense is active, NO defense power can be used.
    if (_isProtected) return false;
    return true;
  }

  String? _cachedShieldPowerId;
  DateTime? _ignoreShieldUntil;

  final StreamController<PowerFeedbackEvent> _feedbackStreamController =
      StreamController<PowerFeedbackEvent>.broadcast();
  Stream<PowerFeedbackEvent> get feedbackStream =>
      _feedbackStreamController.stream;

  // --- DELEGATED TO EffectTimerService ---
  String? get activePowerSlug => _timerService.activeEffectSlugs.isNotEmpty
      ? _timerService.activeEffectSlugs.last
      : null;
  String? get activeEffectId => activePowerSlug != null
      ? _timerService.getEffectId(activePowerSlug!)
      : null;
  String? get activeEffectCasterId => activePowerSlug != null
      ? _timerService.getCasterId(activePowerSlug!)
      : null;
  DateTime? get activePowerExpiresAt => activePowerSlug != null
      ? _timerService.getExpiration(activePowerSlug!)
      : null;

  bool isEffectActive(String slug) {
    if (slug == 'shield') return _isProtected && _activeDefenseSlug == 'shield';
    if (slug == 'return') return _isProtected && _activeDefenseSlug == 'return';
    if (slug == 'invisibility')
      return _isProtected && _activeDefenseSlug == 'invisibility';
    return _timerService.isActive(slug);
  }

  bool isPowerActive(PowerType type) {
    switch (type) {
      case PowerType.blind:
        return isEffectActive('black_screen');
      case PowerType.freeze:
        return isEffectActive('freeze');
      case PowerType.blur:
        return isEffectActive('blur_screen');
      case PowerType.lifeSteal:
        return isEffectActive('life_steal');
      case PowerType.stealth:
        return isEffectActive('invisibility');
      case PowerType.shield:
        return isEffectActive('shield');
      default:
        return false;
    }
  }

  DateTime? getPowerExpiration(String slug) {
    if (slug == 'shield' && _isProtected && _activeDefenseSlug == 'shield')
      return null; // Infinite until broken
    if (slug == 'return' && _isProtected && _activeDefenseSlug == 'return')
      return null; // Infinite until triggered
    return _timerService.getExpiration(slug);
  }

  DateTime? getPowerExpirationByType(PowerType type) {
    switch (type) {
      case PowerType.blind:
        return getPowerExpiration('black_screen');
      case PowerType.freeze:
        return getPowerExpiration('freeze');
      case PowerType.blur:
        return getPowerExpiration('blur_screen');
      case PowerType.lifeSteal:
        return getPowerExpiration('life_steal');
      case PowerType.stealth:
        return getPowerExpiration('invisibility');
      case PowerType.shield:
        return getPowerExpiration('shield');
      default:
        return null;
    }
  }

  String? _pendingEffectId;
  String? _pendingCasterId;

  String? get pendingEffectId => _pendingEffectId;
  String? get pendingCasterId => _pendingCasterId;
  Future<void> Function(String, String?, String)? get lifeStealVictimHandler =>
      _lifeStealVictimHandler;

  DefenseAction? get lastDefenseAction => _lastDefenseAction;
  DateTime? get lastDefenseActionAt => _lastDefenseActionAt;

  void setPendingEffectContext(String? effectId, String? casterId) {
    _pendingEffectId = effectId;
    _pendingCasterId = casterId;
  }

  void markEffectAsProcessed(String id) => _processedEffectIds.add(id);
  bool isEffectProcessed(String id) => _processedEffectIds.contains(id);

  void setActiveEffectCasterId(String? id) {}

  // REMOVED: _supabaseClient getter - now using injected _supabase (DIP compliance)

  bool get isReturnArmed => _isProtected && _activeDefenseSlug == 'return';
  bool get isShieldArmed =>
      _isProtected &&
      (_activeDefenseSlug == 'shield' || _activeDefenseSlug == 'return');

  void setManualCasting(bool value) => _isManualCasting = value;

  void setShielded(bool value, {String? sourceSlug}) {
    if (value)
      armShield();
    else {
      _isProtected = false;
      _activeDefenseSlug = null;
      notifyListeners();
    }
  }

  void armReturn() {
    _activeDefenseSlug = 'return';
    notifyListeners();
  }

  Future<void> armShield() async {
    // FIX: Do NOT set _isProtected = true here.
    // Rely on game_players stream as Source of Truth.
    _activeDefenseSlug = 'shield';
    _shieldLastArmedAt = DateTime.now();
    notifyListeners();
  }

  void armInvisibility() {
    _activeDefenseSlug = 'invisibility';
    notifyListeners();
  }

  /// Deactivates the current defense power server-side.
  /// Called when a timed defense (invisibility) expires locally.
  @override
  Future<void> deactivateDefense() async {
    if (_listeningForId == null) return;
    debugPrint(
        '🛡️ [DEACTIVATE] Calling deactivate_defense RPC for $_listeningForId');
    _isProtected = false;
    _activeDefenseSlug = null;
    notifyListeners();
    await _repository.deactivateDefense(gamePlayerId: _listeningForId!);
  }

  void configureLifeStealVictimHandler(
      Future<void> Function(String effectId, String? casterGamePlayerId,
              String targetGamePlayerId)
          handler) {
    _lifeStealVictimHandler = handler;
  }

  String? _listeningForEventId;
  String? get listeningForEventId => _listeningForEventId;

  void startListening(String? myGamePlayerId,
      {String? eventId, bool forceRestart = false}) {
    debugPrint('[DEBUG] 📡 PowerEffectProvider.startListening() CALLED');
    debugPrint('[DEBUG]    myGamePlayerId: $myGamePlayerId');
    debugPrint('[DEBUG]    eventId: $eventId');

    if (myGamePlayerId == null || myGamePlayerId.isEmpty) {
      _clearAllEffects();
      _subscription?.cancel();
      _casterSubscription?.cancel();
      _combatEventsSubscription?.cancel();
      return;
    }

    if (myGamePlayerId == _listeningForId &&
        eventId == _listeningForEventId &&
        _subscription != null &&
        !forceRestart) {
      debugPrint(
          '[DEBUG] ⏭️ Already listening for $myGamePlayerId (Event: $eventId), skipping restart.');
      return;
    }

    _clearAllEffects();

    // FIX: Only clear processed IDs if the USER changes.
    // If we just switch events or restart listeners for the same user,
    // we must remember what we already processed (like LifeSteal) to avoid re-triggering.
    if (_listeningForId != myGamePlayerId) {
      _processedEffectIds.clear();
    }

    _listeningForId = myGamePlayerId;
    _listeningForEventId = eventId;
    _sessionStartTime = DateTime.now().toUtc();

    debugPrint(
        '🛡️ PowerEffectProvider STARTING LISTENING: localId=$myGamePlayerId, eventId=$eventId');

    // 0. Listen for Game Player Updates (PROTECTION STATE) - DEFENSE MUTUAL EXCLUSIVITY FIX
    _repository.getGamePlayerStream(playerId: myGamePlayerId).listen(
        (Map<String, dynamic>? player) {
      if (player != null) {
        // DEBUG: Check if column exists
        if (!player.containsKey('is_protected')) {
          debugPrint(
              '⚠️ [PROTECTION-SYNC] Payload missing is_protected column! Keys: ${player.keys.toList()}');
          return;
        }

        final bool isProtected = player['is_protected'] ?? false;

        // --- FAIL-SAFE: Self-Correction for Stuck State ---
        // If server says we are protected, but we have NO local record of an active defense slug
        // AND we have been running for a bit (to allow initial sync), we should double check.
        // Actually, a better check is: If isProtected=true, do we have an active power for it?
        // The active_powers stream should have told us.
        // We'll perform a "Reactive Integrity Check" here.

        if (isProtected) {
          // If we are protected, but locally we think we aren't, update local.
          // But wait! If we just started, we might not have the slug yet.
          // So we accept the protection first.
        }

        if (_isProtected != isProtected) {
          _isProtected = isProtected;

          if (!isProtected) {
            // Server cleared protection — reset defense slug
            _activeDefenseSlug = null;
            debugPrint(
                '🛡️ [PROTECTION-SYNC] Server disabled protection. Visuals cleared.');
          } else {
            // Server enabled protection.
            // If we don't have a slug yet, it might be coming in the active_powers stream.
            // But if 5 seconds pass and we still don't have a slug, it's a ghost state!
            /*
                   Timer(const Duration(seconds: 5), () {
                      if (_isProtected && _activeDefenseSlug == null) {
                          debugPrint('🛡️ [FAIL-SAFE] Detected stuck protection without active power! Attempting self-repair...');
                          deactivateDefense();
                      }
                   });
                   */
            // For now, let's trust the stream but log it.
            debugPrint(
                '🛡️ [PROTECTION-SYNC] Server enabled protection. Waiting for power slug match...');
          }

          notifyListeners();
          debugPrint(
              '🛡️ [PROTECTION-SYNC] Protected: $_isProtected, Slug: $_activeDefenseSlug');
        }

        // NEW: Immediate Integrity Check
        // If isProtected is TRUE, we expect an active defense power in the active_powers list.
        // We can't easily check that list here without caching it separately.
        // So we will trigger a check in _processEffects instead.
      } else {
        debugPrint(
            '🛡️ [STREAM] game_players returned NULL for id=$myGamePlayerId');
      }
    }, onError: (e) {
      debugPrint('🛑 PowerEffectProvider game_players stream error: $e');
    });

    // 1. Listen for Active Powers
    _subscription = _repository
        .getActivePowersStream(targetId: myGamePlayerId)
        .listen((List<Map<String, dynamic>> data) async {
      await _processEffects(data);
    }, onError: (e) {
      debugPrint('PowerEffectProvider active_powers stream error: $e');
    });

    // 2. Listen for Outgoing Powers
    _casterSubscription = _repository
        .getOutgoingPowersStream(casterId: myGamePlayerId)
        .listen((List<Map<String, dynamic>> data) async {
      await _processOutgoingEffects(data);
    }, onError: (e) {
      debugPrint('PowerEffectProvider outgoing stream error: $e');
    });

    // 3. Listen for Combat Events
    _combatEventsSubscription = _repository
        .getCombatEventsStream(targetId: myGamePlayerId)
        .listen((List<Map<String, dynamic>> data) async {
      await _handleCombatEvents(data);
    }, onError: (e) {
      debugPrint('PowerEffectProvider combat_events stream error: $e');
    });

    // 4. Listen for Timer Expiration Events (CRITICAL for UI unlock + defense deactivation)
    _timerEventSubscription?.cancel();
    _timerEventSubscription = _timerService.effectStream.listen((event) {
      if (event.type == EffectEventType.expired ||
          event.type == EffectEventType.removed) {
        debugPrint(
            '🔓 [UI-UNLOCK] Removiendo bloqueo de pantalla para efecto: ${event.slug}');

        // FIX: If a timed defense (invisibility) expires, clear is_protected server-side
        if (event.slug == _activeDefenseSlug && _isProtected) {
          debugPrint(
              '🛡️ [DEFENSE-EXPIRE] Timed defense "${event.slug}" expired, calling deactivate_defense RPC');
          deactivateDefense();
        }

        // Notify listeners so SabotageOverlay can react immediately
        notifyListeners();
      }
    });
  }

  Future<void> _handleCombatEvents(List<Map<String, dynamic>> data) async {
    if (data.isEmpty) return;

    // Check duplication/timing
    final event = data.first;
    final createdAtStr = event['created_at'];
    if (createdAtStr == null) return;

    // FILTER: Event ID
    if (_listeningForEventId != null) {
      final eventId = event['event_id']?.toString();
      // If event has an ID and it doesn't match our context, ignore it.
      if (eventId != null && eventId != _listeningForEventId) {
        debugPrint(
            '[COMBAT] 🛑 Ignoring event from different event_id: $eventId (Expected: $_listeningForEventId)');
        return;
      }
    }

    final createdAt = DateTime.parse(createdAtStr);
    if (_sessionStartTime != null && createdAt.isBefore(_sessionStartTime!))
      return;

    // Idempotency check for events (using ID)
    final eventId = event['id']?.toString();
    if (eventId != null) {
      if (_processedEffectIds.contains(eventId)) return;
      _processedEffectIds.add(eventId);
    }

    final resultType = event['result_type'];
    final powerSlug = event['power_slug'];

    debugPrint(
        '🛡️ [COMBAT-EVENT] Nuevo evento detectado: $resultType (Power: $powerSlug)');

    if (resultType == 'shield_blocked') {
      debugPrint('[COMBAT] 🛡️💥 SHIELD_BLOCKED event processed!');
      debugPrint(
          '[COMBAT]    - Protected Before: $_isProtected ($_activeDefenseSlug)');

      // Server confirmed shield blocked an attack
      _isProtected = false;
      _activeDefenseSlug = null;
      // Force remove effect locally in case stream hasn't updated yet
      _removeEffect('shield');
      _ignoreShieldUntil = DateTime.now().add(const Duration(seconds: 5));

      debugPrint('[COMBAT]    - Protected After Update: $_isProtected');

      _registerDefenseAction(DefenseAction.shieldBroken);
      _feedbackStreamController
          .add(PowerFeedbackEvent(PowerFeedbackType.shieldBroken));

      debugPrint('[COMBAT] 🛡️ Shield broken feedback emitted');
    } else if (resultType == 'reflected') {
      final targetId = event['target_id']?.toString();
      // If I am the target, it means *I* reflected the attack
      if (targetId == _listeningForId) {
        debugPrint('[COMBAT] ↩️ RETURN ACTIVATED! Syncing local state.');

        _isProtected = false;
        _activeDefenseSlug = null;
        _removeEffect('return');

        // EXTRACT DATA FOR FEEDBACK
        final attackerId = event['attacker_id']?.toString();
        final powerSlug = event['power_slug']?.toString();

        _returnedAgainstCasterId = attackerId;
        _returnedPowerSlug = powerSlug;

        // Trigger visual feedback (SabotageOverlay listens to DefenseAction.returned)
        _registerDefenseAction(DefenseAction.returned);

        // Emit positive feedback event (for toasts or other listeners)
        _feedbackStreamController.add(PowerFeedbackEvent(
          PowerFeedbackType.returnSuccess,
          message: '¡Ataque devuelto exitosamente!',
          relatedPlayerName: attackerId,
        ));
      }
    } else if (resultType == 'success' && powerSlug == 'life_steal') {
      final targetId = event['target_id']?.toString();
      // Check if I am the victim
      if (targetId == _listeningForId) {
        debugPrint('[COMBAT] 🩸 LIFE STEAL detected via Combat Event!');
        final attackerId = event['attacker_id']?.toString();
        final eventId =
            event['id']?.toString(); // Use combat event ID as reference

        // Trigger Visual Strategy
        setPendingEffectContext(eventId, attackerId);
        _powerStrategyFactory.get('life_steal').onActivate(this);
        setPendingEffectContext(null, null);

        // Emit Feedback Event
        _feedbackStreamController.add(PowerFeedbackEvent(
          PowerFeedbackType.lifeStolen,
          relatedPlayerName: attackerId,
        ));
      }
    } else if (resultType == 'gifted') {
      // A spectator (or another player) gifted us a defense power
      final attackerId = event['attacker_id']?.toString();
      final giftPowerSlug = event['power_slug']?.toString();

      debugPrint(
          '[COMBAT] 🎁 GIFT RECEIVED! Power: $giftPowerSlug from $attackerId');

      String gifterName = 'Un espectador';
      if (attackerId != null) {
        final name = await _repository.getGifterName(gamePlayerId: attackerId);
        if (name != null && name.isNotEmpty) {
          gifterName = name;
        }
      }

      final powerDisplayName = _getPowerDisplayName(giftPowerSlug);

      _feedbackStreamController.add(PowerFeedbackEvent(
        PowerFeedbackType.giftReceived,
        message: '¡$gifterName te ha regalado un $powerDisplayName!',
        relatedPlayerName: gifterName,
      ));
    }
  }

  /// Resolves a gifter's display name from their game_player_id.
  /// For spectators this may not resolve via leaderboard, so we fall back gracefully.
  String _resolveGifterName(String? gamePlayerId) {
    if (gamePlayerId == null || gamePlayerId.isEmpty) return 'Un espectador';
    // The name resolution will be done by SabotageOverlay's leaderboard lookup
    // or by the relatedPlayerName field. We return the ID for now.
    return gamePlayerId;
  }

  /// Maps a power slug to a user-friendly name in Spanish.
  String _getPowerDisplayName(String? slug) {
    switch (slug) {
      case 'shield':
        return 'Escudo';
      case 'return':
        return 'Reflejo';
      case 'invisibility':
        return 'Invisibilidad';
      default:
        return slug ?? 'poder';
    }
  }

  Future<void> _processOutgoingEffects(List<Map<String, dynamic>> data) async {
    // ... (Logica de reflejo saliente se mantiene igual, omitida por brevedad si no hay cambios funcionales solicitados aquí)
    // Para simplificar el refactor, mantenemos la lógica existente aquí.
    if (_isManualCasting) return;
    if (data.isEmpty) return;

    final now = DateTime.now().toUtc();
    for (final effect in data) {
      // FILTER: Event ID
      if (_listeningForEventId != null) {
        final evId = effect['event_id']?.toString();
        if (evId != null && evId != _listeningForEventId) continue;
      }

      final createdAtStr = effect['created_at'];
      final createdAt = DateTime.parse(createdAtStr);
      final ageSeconds = now.difference(createdAt).inSeconds;
      if (ageSeconds > 10) continue;

      final slug = await _resolveEffectSlug(effect);
      final bool isOffensive = slug == 'black_screen' ||
          slug == 'freeze' ||
          slug == 'life_steal' ||
          slug == 'blur_screen';

      if (isOffensive) {
        debugPrint(
            "REFLEJO DETECTADO (Stream Outgoing): $slug lanzado automáticamente.");
      }
    }
  }

  /// Aplica un efecto y gestiona su temporizador.
  ///
  /// DELEGATED to EffectTimerService (SRP compliance).
  Future<void> applyEffect({
    required String slug,
    required Duration duration,
    String? effectId,
    String? casterId,
    required DateTime expiresAt,
    Duration? dbDuration, // Optional: authoritative duration from database
  }) async {
    // 🛡️ RACE CONDITION FIX:
    // If we stopped listening (user left game), do NOT apply new effects.
    if (_listeningForId == null) {
      debugPrint(
          '[DEBUG] 🛑 applyEffect BLOCKED: Not listening for any player.');
      return;
    }

    // Delegate to EffectTimerService
    _timerService.applyEffect(
      slug: slug,
      localDuration: duration,
      dbDuration: dbDuration,
      expiresAt: expiresAt,
      effectId: effectId,
      casterId: casterId,
    );

    notifyListeners();
  }

  void _removeEffect(String slug) {
    debugPrint('[PowerEffectProvider] Removing effect: $slug');
    _timerService.removeEffect(slug);

    // Defense cleanup: if removing the active defense, clear protection
    if (slug == _activeDefenseSlug) {
      _isProtected = false;
      _activeDefenseSlug = null;
    }

    notifyListeners();
  }

  void _clearAllEffects() {
    _timerService.clearAll();
    notifyListeners();
  }

  Future<void> _processEffects(List<Map<String, dynamic>> data) async {
    // Filter logic (same as before)
    final filtered = data.where((effect) {
      final targetId = effect['target_id'];
      final createdAtStr = effect['created_at'];

      debugPrint(
          "[DEBUG] 📦 Evento Recibido - ID: ${effect['id']} | Creado en: $createdAtStr | Target: $targetId");

      // 1. Validar que sea para mí
      if (_listeningForId == null || targetId != _listeningForId) {
        debugPrint(
            "   ❌ Rechazado: Target no coincide (esperaba: $_listeningForId, recibió: $targetId)");
        return false;
      }

      // 2. Event ID Check
      if (_listeningForEventId != null) {
        final effectEventId = effect['event_id']?.toString();
        // Strict filtering: If listening for specific event, effect must match.
        if (effectEventId != null && effectEventId != _listeningForEventId) {
          debugPrint(
              "   ❌ Rechazado: Event ID no coincide (esperaba: $_listeningForEventId, recibió: $effectEventId)");
          return false;
        }
      }

      // 3. Validar que sea reciente (evitar animaciones al entrar)
      if (_sessionStartTime != null && createdAtStr != null) {
        final createdAt = DateTime.parse(createdAtStr);
        final sessionStart = _sessionStartTime!;
        // Increased tolerance to avoid clock skew issues
        const tolerance = Duration(hours: 2);
        final adjustedSessionStart = sessionStart.subtract(tolerance);
        debugPrint(
            "   🕐 Comparación de tiempo: Evento=$createdAt vs Sesión=$sessionStart (tolerancia: 2h)");
        if (createdAt.isBefore(adjustedSessionStart)) {
          debugPrint(
              "   ⚠️ Evento ignorado por ser ANTIGUO (${adjustedSessionStart.difference(createdAt).inSeconds}s antes del margen)");
          return false;
        }
      }

      return true;
    }).toList();

    // Shield Check (Concurrent/One-Shot Logic)
    // We check if 'shield' is active in _activeEffects.
    // If so, and we receive an OFFENSIVE effect, we block it and break the shield.

    // We need to identify if ANY of the incoming valid effects is offensive.
    // AND if we haven't processed it yet (though Filtered list implies they are relevant).

    // Return Logic (Priority)
    // We look for ONE offensive effect to return.
    // If multiple arrive, we pick one, return it, and theoretically consume it.
    // But since this is a concurrent system, maybe we can return one and suffer the others?
    // Following existing logic: Return takes priority over applying effects.

    if (filtered.isEmpty) {
      // --- FAIL-SAFE: Empty List Integrity Check ---
      // If we receive an empty list of active powers, but we are marked as PROTECTED,
      // it means the defense power has expired server-side (removed from active_powers)
      // but the is_protected flag might still be true if the cleanup job hasn't run yet.
      // OR if we just missed the expiration event.

      if (_isProtected && _activeDefenseSlug != null) {
        debugPrint(
            '🛡️ [INTEGRITY] No active powers found, but Protection is ON via "$_activeDefenseSlug". Checking expiration...');
        // If we have an active slug locally, check if it's expired locally too.
        // If the list is empty, it means DB has NO active powers for us.
        // THIS IS THE SMOKING GUN: Protected=True, ActivePowers=Empty.
        // We must clear the protection.

        debugPrint(
            '🛡️ [FAIL-SAFE] Ghost Protection Detected! (Protected=True, ActivePowers=0). Deactivating...');
        deactivateDefense(); // This calls RPC to set is_protected = false
      }
      return;
    }

    // We iterate over ALL filtered events (not just valid/future ones)
    // This allows us to catch "Life Steal" events that might be slightly expired
    // due to network lag, but should still trigger if not processed yet.
    // Standard durational effects (blind/freeze) will still be skipped if expired.

    final now = DateTime.now().toUtc();

    bool shieldBrokenInBatch = false;

    for (final effect in filtered) {
      final slug = await _resolveEffectSlug(effect);
      if (slug == null) continue;

      final effectId = effect['id']?.toString();
      final casterId = effect['caster_id']?.toString();
      final expiresAt = DateTime.parse(effect['expires_at']);
      final duration = expiresAt.difference(now);
      final bool isExpired = duration <= Duration.zero;

      final bool isLifeSteal = slug == 'life_steal';

      // HANDLED VIA COMBAT EVENTS (To ensure correct timing)
      if (isLifeSteal) continue;

      // Validity check for defenses:
      // Must be active OR be life_steal (which we verify via idempotency later, but for defense it counts as "incoming")
      // If it's a standard effect and it's expired, we ignore it completely (ghost effect).
      if (isExpired && !isLifeSteal) continue;

      // --- 0. PREVENT RE-APPLYING BROKEN SHIELD ---
      // Check if broken in this batch OR explicitly ignored due to recent break
      if (slug == 'shield') {
        if (shieldBrokenInBatch) {
          debugPrint(
              '[SHIELD] 🛑 Skipping shield application because it was broken in this batch.');
          continue;
        }
        if (_ignoreShieldUntil != null && _ignoreShieldUntil!.isAfter(now)) {
          debugPrint(
              '[SHIELD] 🛑 Skipping shield application (Ignored until $_ignoreShieldUntil)');
          continue;
        }
      }

      // --- BACKEND-AUTHORITATIVE COMBAT (Phase 2 Refactor) ---
      // Return and Shield interception are now handled entirely by the server
      // via `use_power_mechanic` RPC. The client only reacts to:
      // 1. `active_powers` stream for visual effects
      // 2. `combat_events` stream for feedback animations (shield_blocked, reflected)

      // --- SHIELD SYNC (Server-Side Removal) ---
      // [REFACTORED] Now handled by game_players stream via is_protected.
      // We DO NOT disable shield here based on active_powers presence.
      // The is_protected flag is the source of truth.

      /* 
       if (_shieldArmed && !shieldBrokenInBatch && isEffectActive('shield')) {
           // ... (Legacy logic removed) ...
       }
       */

      // --- INTERCEPTION LOGIC ---
      // Shield interception is now handled Server-Side (execute_combat_power.sql).
      // The attack is blocked at the DB level and never reaches active_powers.
      // Feedback is handled via _combatEventsSubscription.
      // We only keep Return interception here because it requires client-side Reflection logic
      // (until that is also moved to server).

      // --- HANDLE INCOMING FEEDBACK (As Attacker) ---
      if (slug == 'shield_feedback') {
        _registerDefenseAction(DefenseAction.attackBlockedByEnemy);
        _feedbackStreamController
            .add(PowerFeedbackEvent(PowerFeedbackType.attackBlocked));
        continue;
      }

      // --- 5. STANDARD EFFECT APPLICATION ---
      // Only if !isExpired (checked at top)
      if (isExpired) continue; // Redundant but safe

      // Special check: If this is shield, and we broke it this batch, skip (already handled by top check,
      // but applies to `applyEffect` too).
      if (slug == 'shield' && shieldBrokenInBatch) continue;

      if (!isEffectActive(slug)) {
        final strategy = _powerStrategyFactory.get(slug);
        strategy.onActivate(this);
      }

      applyEffect(
          slug: slug,
          duration: slug == 'shield'
              ? const Duration(days: 365)
              : duration, // FORCE LONG DURATION FOR SHIELD
          effectId: effectId,
          casterId: casterId,
          expiresAt: slug == 'shield'
              ? DateTime.now().add(const Duration(days: 365))
              : expiresAt);
    }
  }

  Future<String?> _resolveEffectSlug(Map<String, dynamic> effect) async {
    return _repository.resolveEffectSlug(effect);
  }

  Future<Duration> _getPowerDurationFromDb({required String powerSlug}) async {
    return _repository.getPowerDuration(powerSlug: powerSlug);
  }

  void clearActiveEffect() {
    _clearAllEffects();
  }

  void _registerDefenseAction(DefenseAction action) {
    _defenseFeedbackTimer?.cancel();
    _lastDefenseAction = action;
    _lastDefenseActionAt = DateTime.now();
    notifyListeners();

    // ⚡ CRITICAL: Emit feedback event for shield broken
    if (action == DefenseAction.shieldBroken) {
      _feedbackStreamController.add(PowerFeedbackEvent(
        PowerFeedbackType.shieldBroken,
        message: 'Shield broken',
      ));
      debugPrint('[SHIELD] 🛡️💥 Shield broken feedback event emitted');
    }

    // Duración diferenciada: Returned y ShieldBroken son eventos importantes => 4s
    final duration = (action == DefenseAction.returned ||
            action == DefenseAction.shieldBroken)
        ? const Duration(seconds: 4)
        : const Duration(seconds: 2);

    _defenseFeedbackTimer = Timer(duration, () {
      final elapsed =
          DateTime.now().difference(_lastDefenseActionAt ?? DateTime.now());
      if (elapsed.inMilliseconds >= duration.inMilliseconds) {
        _lastDefenseAction = null;
        _returnedAgainstCasterId = null;
        _returnedByPlayerName = null;
        _returnedPowerSlug = null;
        notifyListeners();
      }
    });
  }

  void notifyPowerReturned(String byPlayerName) {
    _returnedByPlayerName = byPlayerName;
    _registerDefenseAction(DefenseAction.returned);
    _feedbackStreamController.add(PowerFeedbackEvent(
      PowerFeedbackType.returnRejection,
      relatedPlayerName: byPlayerName,
    ));
    notifyListeners();
  }

  void notifyAttackBlocked() {
    _registerDefenseAction(DefenseAction.attackBlockedByEnemy);
    _feedbackStreamController.add(PowerFeedbackEvent(
      PowerFeedbackType.attackBlocked,
    ));
    notifyListeners();
  }

  void notifyStealFailed() {
    _registerDefenseAction(DefenseAction.stealFailed);
    _feedbackStreamController.add(PowerFeedbackEvent(
      PowerFeedbackType.stealFailed,
    ));
    notifyListeners();
  }

  /// Resets the provider state, stopping all listeners and clearing effects.
  @override
  void resetState() {
    debugPrint('[PowerEffectProvider] 🧹 Resetting State (Logout/Cleanup)');
    startListening(null, forceRestart: true);
    _clearAllEffects();
    _lastDefenseAction = null;
    _returnedByPlayerName = null;
    _returnedAgainstCasterId = null;
    _listeningForEventId = null;
    notifyListeners();
  }

  @override
  void stopListening() {
    startListening(null);
  }

  @override
  void dispose() {
    _subscription?.cancel();
    _casterSubscription?.cancel();
    _combatEventsSubscription?.cancel();
    _timerEventSubscription?.cancel(); // NEW: Cancel timer event subscription
    _defenseFeedbackTimer?.cancel();
    _clearAllEffects();
    _feedbackStreamController.close(); // Cleanup Stream
    super.dispose();
  }
}

// REMOVED: _ActiveEffect class - moved to EffectTimerService (SRP compliance)
