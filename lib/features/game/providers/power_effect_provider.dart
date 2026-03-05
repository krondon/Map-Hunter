import 'dart:async';
import 'dart:collection';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../strategies/power_strategy_factory.dart';
import '../../game/repositories/power_repository_interface.dart';
import '../../mall/models/power_item.dart';
import '../../../core/services/effect_timer_service.dart';
import '../../../core/services/feedback_event_queue.dart';

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
  StreamSubscription? _gamePlayerSubscription; // Fix 3.1: stored to prevent zombie listeners
  StreamSubscription<EffectEvent>?
      _timerEventSubscription; // NEW: Listen for timer expirations
  Timer? _defenseFeedbackTimer;
  Timer?
      _effectsDebounceTimer; // [PERFORMANCE] Debounce for active_powers bursts

  /// Canal de Broadcast de Supabase para recibir combat_events con baja latencia (~50ms).
  /// Complementa _combatEventsSubscription (Postgres Changes, ~300ms) como fast-path.
  /// Los triggers DB (trg_combat_event_broadcast) alimentan este canal.
  RealtimeChannel? _broadcastChannel;

  /// IDs de combat_events ya procesados vía Broadcast. Evita reprocess desde Postgres Changes.
  /// Mapa de ID → timestamp de procesamiento. Entradas expiran en 5s (mayor que ~300ms de PG Changes).
  final Map<String, DateTime> _broadcastProcessedIds = {};

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

  // --- SEQUENTIAL COMBAT PROCESSING QUEUE (Fix 3.5) ---
  final Queue<Map<String, dynamic>> _combatEventProcessingQueue = Queue();
  bool _isProcessingCombatQueue = false;

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

  /// Cola de feedback con garantía de entrega.
  /// Reemplaza el BroadcastStream anterior que descartaba eventos
  /// cuando el usuario navegaba a otra pantalla (no había listeners activos).
  final FeedbackEventQueue<PowerFeedbackEvent> _feedbackQueue =
      FeedbackEventQueue(maxSize: 20, ttl: const Duration(seconds: 10));

  @override
  Stream<PowerFeedbackEvent> get feedbackStream => _feedbackQueue.stream;

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
      _gamePlayerSubscription?.cancel();
      _gamePlayerSubscription = null;
      _broadcastChannel?.unsubscribe();
      _broadcastChannel = null;
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
    _purgeBroadcastIds(); // Clean stale dedup entries on new session

    debugPrint(
        '🛡️ PowerEffectProvider STARTING LISTENING: localId=$myGamePlayerId, eventId=$eventId');

    // 0. Listen for Game Player Updates (PROTECTION STATE) - DEFENSE MUTUAL EXCLUSIVITY FIX
    _gamePlayerSubscription?.cancel(); // Fix 3.1: Cancel previous before creating new
    _gamePlayerSubscription = _repository.getGamePlayerStream(playerId: myGamePlayerId).listen(
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
    // [PERFORMANCE] Debounce: Con 50+ jugadores atacando, el stream puede
    // disparar muchos eventos en ráfaga. Agrupamos en ventana de 150ms
    // y procesamos solo el estado más reciente.
    List<Map<String, dynamic>>? _pendingEffectsData;
    _subscription = _repository
        .getActivePowersStream(targetId: myGamePlayerId)
        .listen((List<Map<String, dynamic>> data) async {
      _pendingEffectsData = data;
      _effectsDebounceTimer?.cancel();
      _effectsDebounceTimer =
          Timer(const Duration(milliseconds: 150), () async {
        if (_pendingEffectsData != null) {
          await _processEffects(_pendingEffectsData!);
          _pendingEffectsData = null;
        }
      });
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
      // OPTIMIZACIÓN: Filtrar eventos que ya fueron procesados via Broadcast
      // para evitar procesamiento redundante del mismo evento.
      final fresh = data.where((e) {
        final id = e['id']?.toString();
        return id == null || !_isBroadcastProcessed(id);
      }).toList();
      await _handleCombatEvents(fresh);
    }, onError: (e) {
      debugPrint('PowerEffectProvider combat_events stream error: $e');
    });

    // 3b. Canal de Broadcast (fast-path ~50ms) para combat_events y power_applied.
    // Los triggers DB alimentan este canal. Si llega aquí primero, marcamos el ID
    // como procesado para que el Postgres Changes (3a) lo ignore.
    _broadcastChannel?.unsubscribe();
    _broadcastChannel = _repository
        .getCombatBroadcastChannel(gamePlayerId: myGamePlayerId)
        .onBroadcast(
          event: 'combat_event',
          callback: (payload) async {
            final data = payload as Map<String, dynamic>?;
            if (data == null) return;

            final id = data['id']?.toString();
            if (id != null) {
              if (_isBroadcastProcessed(id)) return; // Ya procesado (TTL check)
              _broadcastProcessedIds[id] = DateTime.now();
            }

            debugPrint(
                '⚡ [BROADCAST] combat_event recibido (fast-path): ${data['result_type']}');
            await _enqueueCombatEvent(data);
          },
        );
    _broadcastChannel!.subscribe();

    // 4. Listen for Timer Expiration Events (CRITICAL for UI unlock + defense deactivation)
    _timerEventSubscription?.cancel();
    _timerEventSubscription = _timerService.effectStream.listen((event) {
      if (event.type == EffectEventType.expired ||
          event.type == EffectEventType.removed) {
        debugPrint(
            '🔓 [UI-UNLOCK] Removiendo bloqueo de pantalla para efecto: ${event.slug}');

        // Solo desactivamos server-side si expira INVISIBILIDAD (único poder de defensa temporal).
        // Escudo y devolución nunca deben expirar por tiempo local — solo por combat_event.
        if (event.slug == 'invisibility' &&
            event.slug == _activeDefenseSlug &&
            _isProtected) {
          debugPrint(
              '🛡️ [DEFENSE-EXPIRE] Invisibility expired. Calling deactivate_defense RPC.');
          deactivateDefense();
        }

        // Notify listeners so SabotageOverlay can react immediately
        notifyListeners();
      }
    });
  }

  /// Fix 3.2: Procesa un lote completo de eventos encolando cada uno para
  /// procesamiento FIFO secuencial. Reemplaza el acceso a data.first previo.
  Future<void> _handleCombatEvents(List<Map<String, dynamic>> data) async {
    for (final event in data) {
      await _enqueueCombatEvent(event);
    }
  }

  /// Fix 3.5: Garantiza procesamiento FIFO secuencial de combat_events.
  /// Mientras un evento se procesa, los nuevos se encolan y esperan su turno,
  /// eliminando race conditions en las animaciones de combate.
  Future<void> _enqueueCombatEvent(Map<String, dynamic> event) async {
    _combatEventProcessingQueue.add(event);
    if (!_isProcessingCombatQueue) {
      _isProcessingCombatQueue = true;
      while (_combatEventProcessingQueue.isNotEmpty) {
        final next = _combatEventProcessingQueue.removeFirst();
        await _processSingleCombatEvent(next);
      }
      _isProcessingCombatQueue = false;
    }
  }

  /// Procesa un único combat_event con todas las validaciones y lógica de estado.
  Future<void> _processSingleCombatEvent(Map<String, dynamic> event) async {
    final createdAtStr = event['created_at'];
    if (createdAtStr == null) return;

    // FILTER: Event ID
    if (_listeningForEventId != null) {
      final evGameId = event['event_id']?.toString();
      if (evGameId != null && evGameId != _listeningForEventId) {
        debugPrint(
            '[COMBAT] 🛑 Ignoring event from different event_id: $evGameId (Expected: $_listeningForEventId)');
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

      _isProtected = false;
      _activeDefenseSlug = null;
      _removeEffect('shield');
      _ignoreShieldUntil = DateTime.now().add(const Duration(seconds: 5));

      debugPrint('[COMBAT]    - Protected After Update: $_isProtected');

      // Fix 3.3: _registerDefenseAction ya encola shieldBroken feedback internamente.
      // Se eliminó la llamada redundante a _feedbackQueue.add() que causaba doble animación.
      _registerDefenseAction(DefenseAction.shieldBroken);
      debugPrint('[COMBAT] 🛡️ Shield broken feedback emitted (via _registerDefenseAction)');
    } else if (resultType == 'reflected') {
      final targetId = event['target_id']?.toString();
      if (targetId == _listeningForId) {
        debugPrint('[COMBAT] ↩️ RETURN ACTIVATED! Syncing local state.');

        _isProtected = false;
        _activeDefenseSlug = null;
        _removeEffect('return');

        final attackerId = event['attacker_id']?.toString();
        final pSlug = event['power_slug']?.toString();

        _returnedAgainstCasterId = attackerId;
        _returnedPowerSlug = pSlug;

        _registerDefenseAction(DefenseAction.returned);

        _feedbackQueue.add(PowerFeedbackEvent(
          PowerFeedbackType.returnSuccess,
          message: '¡Ataque devuelto exitosamente!',
          relatedPlayerName: attackerId,
        ));
      }
    } else if (resultType == 'success' && powerSlug == 'life_steal') {
      final targetId = event['target_id']?.toString();
      if (targetId == _listeningForId) {
        debugPrint('[COMBAT] 🩸 LIFE STEAL detected via Combat Event!');
        final attackerId = event['attacker_id']?.toString();
        final eId = event['id']?.toString();

        setPendingEffectContext(eId, attackerId);
        _powerStrategyFactory.get('life_steal').onActivate(this);
        setPendingEffectContext(null, null);

        _feedbackQueue.add(PowerFeedbackEvent(
          PowerFeedbackType.lifeStolen,
          relatedPlayerName: attackerId,
        ));
      }
    } else if (resultType == 'gifted') {
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

      _feedbackQueue.add(PowerFeedbackEvent(
        PowerFeedbackType.giftReceived,
        message: '¡$gifterName te ha regalado un $powerDisplayName!',
        relatedPlayerName: gifterName,
      ));
    }
  }

  /// Fix 3.6: Verifica si un ID fue procesado vía Broadcast con expiración por TTL (5s).
  /// El PG Changes path llega ~300ms después del Broadcast, por lo que 5s de TTL
  /// garantiza deduplicación sin retener entradas indefinidamente.
  bool _isBroadcastProcessed(String id) {
    final ts = _broadcastProcessedIds[id];
    if (ts == null) return false;
    if (DateTime.now().difference(ts) > const Duration(seconds: 5)) {
      _broadcastProcessedIds.remove(id);
      return false;
    }
    return true;
  }

  /// Elimina entradas expiradas del mapa de deduplicación (TTL = 5s).
  void _purgeBroadcastIds() {
    final cutoff = DateTime.now().subtract(const Duration(seconds: 5));
    _broadcastProcessedIds.removeWhere((_, ts) => ts.isBefore(cutoff));
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

      // active_powers es una tabla de estado actual: solo contiene filas activas en este momento.
      // No aplicamos filtro de tiempo por created_at aquí porque un escudo o devolución aplicado
      // hace 10 minutos es igual de válido que uno aplicado hace 1 segundo.
      // El filtro de sesión se aplica únicamente en _processSingleCombatEvent (tabla histórica).

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

      // Solo desactivamos la defensa por lista vacía si es un poder TEMPORAL (invisibilidad).
      // Escudo y devolución son event-driven: si active_powers está vacío pero is_protected=true,
      // confiamos en el stream de game_players como fuente de verdad y NO auto-desactivamos.
      // Desactivar aquí el escudo/devolución por lista vacía es exactamente el bug reportado.
      if (_isProtected && _activeDefenseSlug == 'invisibility') {
        debugPrint(
            '🛡️ [FAIL-SAFE] Invisibility expired server-side (Protected=True, ActivePowers=0). Deactivating...');
        deactivateDefense();
      } else if (_isProtected && _activeDefenseSlug != null) {
        debugPrint(
            '🛡️ [INTEGRITY] No active powers, but $_activeDefenseSlug is event-driven — keeping protection until combat_event breaks it.');
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
      // Escudo y devolución son event-driven: solo se rompen por combat_event (shield_blocked/reflected),
      // NUNCA por tiempo. Se deben aplicar aunque expires_at del DB haya pasado.
      final bool isTimelessDefense = slug == 'shield' || slug == 'return';

      // HANDLED VIA COMBAT EVENTS (To ensure correct timing)
      if (isLifeSteal) continue;

      // Los poderes estándar expirados (blur, freeze, etc.) se descartan.
      // Escudo y devolución se procesan siempre (event-driven, no time-driven).
      if (isExpired && !isLifeSteal && !isTimelessDefense) continue;

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
        _feedbackQueue.add(PowerFeedbackEvent(PowerFeedbackType.attackBlocked));
        continue;
      }

      // --- 5. STANDARD EFFECT APPLICATION ---
      // isTimelessDefense (shield/return) se aplican incluso si isExpired, los demás no.
      if (isExpired && !isTimelessDefense) continue;

      // Special check: If this is shield, and we broke it this batch, skip.
      if (slug == 'shield' && shieldBrokenInBatch) continue;

      if (!isEffectActive(slug)) {
        final strategy = _powerStrategyFactory.get(slug);
        strategy.onActivate(this);
      }

      // Escudo y devolución usan timer local de 365 días (event-driven, no time-driven).
      // La invisibilidad usa la duración real del DB.
      applyEffect(
          slug: slug,
          duration: isTimelessDefense
              ? const Duration(days: 365)
              : duration,
          effectId: effectId,
          casterId: casterId,
          expiresAt: isTimelessDefense
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
      _feedbackQueue.add(PowerFeedbackEvent(
        PowerFeedbackType.shieldBroken,
        message: 'Shield broken',
      ));
      debugPrint(
          '[SHIELD] 🛡️💥 Shield broken feedback event queued (guaranteed delivery)');
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
    _feedbackQueue.add(PowerFeedbackEvent(
      PowerFeedbackType.returnRejection,
      relatedPlayerName: byPlayerName,
    ));
    notifyListeners();
  }

  void notifyAttackBlocked() {
    _registerDefenseAction(DefenseAction.attackBlockedByEnemy);
    _feedbackQueue.add(PowerFeedbackEvent(
      PowerFeedbackType.attackBlocked,
    ));
    notifyListeners();
  }

  void notifyStealFailed() {
    _registerDefenseAction(DefenseAction.stealFailed);
    _feedbackQueue.add(PowerFeedbackEvent(
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
    _feedbackQueue
        .clear(); // Descartar eventos pendientes de la sesión anterior
    _broadcastProcessedIds.clear();
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
    _gamePlayerSubscription?.cancel(); // Fix 3.1: prevent zombie listeners
    _timerEventSubscription?.cancel();
    _defenseFeedbackTimer?.cancel();
    _broadcastChannel?.unsubscribe();
    _broadcastChannel = null;
    _clearAllEffects();
    _feedbackQueue.dispose(); // Cleanup feedback queue
    super.dispose();
  }
}

// REMOVED: _ActiveEffect class - moved to EffectTimerService (SRP compliance)
