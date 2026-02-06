import 'dart:async';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../strategies/power_strategy_factory.dart';
import '../../mall/models/power_item.dart';

enum PowerFeedbackType { lifeStolen, shieldBroken, attackBlocked, defenseSuccess, returned, stealFailed }

class PowerFeedbackEvent {
  final PowerFeedbackType type;
  final String message;
  final String? relatedPlayerName;
  
  PowerFeedbackEvent(this.type, {this.message = '', this.relatedPlayerName});
}

/// Provider encargado de escuchar y gestionar los efectos de poderes en tiempo real.
///
/// Funciona escuchando la tabla `active_powers` de Supabase.
///
/// Responsabilidades:
/// - Detectar ataques dirigidos al jugador (`startListening`).
/// - Gestionar la duración y expiración de los efectos visuales.
/// - Lógica de defensa (Escudos y Reflejo/Return).
/// - Coordinar efectos especiales como Life Steal.
class PowerEffectProvider extends ChangeNotifier {
  StreamSubscription? _subscription;
  StreamSubscription? _casterSubscription; 
  StreamSubscription? _combatEventsSubscription; 
  Timer? _expiryTimer;
  Timer? _defenseFeedbackTimer;

  String? _listeningForId;
  String? get listeningForId => _listeningForId;
  
  bool _isManualCasting = false;
  bool _returnArmed = false;
  bool _shieldArmed = false;
  
  DateTime? _sessionStartTime; 

  Future<bool> Function(String powerSlug, String targetGamePlayerId)? _returnHandler;
  Future<void> Function(String effectId, String? casterGamePlayerId, String targetGamePlayerId)? _lifeStealVictimHandler;
  
  DefenseAction? _lastDefenseAction;
  DateTime? _lastDefenseActionAt;

  final Set<String> _processedEffectIds = {};
  
  String? _returnedByPlayerName;
  String? get returnedByPlayerName => _returnedByPlayerName;

  String? _returnedAgainstCasterId;
  String? get returnedAgainstCasterId => _returnedAgainstCasterId;

  String? _returnedPowerSlug;
  String? get returnedPowerSlug => _returnedPowerSlug;

  final Map<String, String> _powerIdToSlugCache = {};
  final Map<String, Duration> _powerSlugToDurationCache = {};
  
  String? _cachedShieldPowerId;

  final StreamController<PowerFeedbackEvent> _feedbackStreamController = StreamController<PowerFeedbackEvent>.broadcast();
  Stream<PowerFeedbackEvent> get feedbackStream => _feedbackStreamController.stream;

  final Map<String, _ActiveEffect> _activeEffects = {};

  String? get activePowerSlug => _activeEffects.isNotEmpty ? _activeEffects.keys.last : null;
  String? get activeEffectId => _activeEffects.isNotEmpty ? _activeEffects.values.last.effectId : null;
  String? get activeEffectCasterId => _activeEffects.isNotEmpty ? _activeEffects.values.last.casterId : null;
  DateTime? get activePowerExpiresAt => _activeEffects.isNotEmpty ? _activeEffects.values.last.expiresAt : null;

  bool isEffectActive(String slug) => _activeEffects.containsKey(slug);
  
  bool isPowerActive(PowerType type) {
    switch (type) {
      case PowerType.blind: return isEffectActive('black_screen');
      case PowerType.freeze: return isEffectActive('freeze');
      case PowerType.blur: return isEffectActive('blur_screen');
      case PowerType.lifeSteal: return isEffectActive('life_steal');
      case PowerType.stealth: return isEffectActive('invisibility');
      case PowerType.shield: return isEffectActive('shield');
      default: return false;
    }
  }
  
  DateTime? getPowerExpiration(String slug) => _activeEffects[slug]?.expiresAt;
  
  DateTime? getPowerExpirationByType(PowerType type) {
    switch (type) {
      case PowerType.blind: return getPowerExpiration('black_screen');
      case PowerType.freeze: return getPowerExpiration('freeze');
      case PowerType.blur: return getPowerExpiration('blur_screen');
      case PowerType.lifeSteal: return getPowerExpiration('life_steal');
      case PowerType.stealth: return getPowerExpiration('invisibility');
      case PowerType.shield: return getPowerExpiration('shield');
      default: return null;
    }
  }
  
  String? _pendingEffectId;
  String? _pendingCasterId;

  String? get pendingEffectId => _pendingEffectId;
  String? get pendingCasterId => _pendingCasterId;
  Future<void> Function(String, String?, String)? get lifeStealVictimHandler => _lifeStealVictimHandler;

  DefenseAction? get lastDefenseAction => _lastDefenseAction;
  DateTime? get lastDefenseActionAt => _lastDefenseActionAt;

  void setPendingEffectContext(String? effectId, String? casterId) {
    _pendingEffectId = effectId;
    _pendingCasterId = casterId;
  }

  void markEffectAsProcessed(String id) => _processedEffectIds.add(id);
  bool isEffectProcessed(String id) => _processedEffectIds.contains(id);

  void setActiveEffectCasterId(String? id) {}

  SupabaseClient? get _supabaseClient {
    try { return Supabase.instance.client; } catch (_) { return null; }
  }

  bool get isReturnArmed => _returnArmed;
  bool get isShieldArmed => _shieldArmed;

  void setManualCasting(bool value) => _isManualCasting = value;

  void setShielded(bool value, {String? sourceSlug}) {
     if (value) armShield();
     else {
        _shieldArmed = false;
        notifyListeners();
     }
  }

  void armReturn() {
    _returnArmed = true;
    notifyListeners();
  }

  Future<void> armShield() async {
    _shieldArmed = true;
    debugPrint('🛡️ Shield ARMED - Ready to block one attack');
    try {
      final duration = await _getPowerDurationFromDb(powerSlug: 'shield');
      if (_cachedShieldPowerId == null) {
         try {
           final pRes = await _supabaseClient?.from('powers').select('id').eq('slug', 'shield').maybeSingle();
           _cachedShieldPowerId = pRes?['id']?.toString();
         } catch(e) { debugPrint('🛡️ FAILED to cache Shield ID: $e'); }
      }
      final expiresAt = DateTime.now().toUtc().add(duration);
      applyEffect(slug: 'shield', duration: duration, expiresAt: expiresAt);
    } catch (e) {
      final duration = const Duration(minutes: 2);
      applyEffect(slug: 'shield', duration: duration, expiresAt: DateTime.now().toUtc().add(duration));
    }
    notifyListeners();
  }

  void configureReturnHandler(Future<bool> Function(String powerSlug, String targetGamePlayerId) handler) {
    _returnHandler = handler;
  }

  void configureLifeStealVictimHandler(Future<void> Function(String effectId, String? casterGamePlayerId, String targetGamePlayerId) handler) {
    _lifeStealVictimHandler = handler;
  }

  String? _listeningForEventId;
  String? get listeningForEventId => _listeningForEventId;

  void startListening(String? myGamePlayerId, {String? eventId, bool forceRestart = false}) {
    debugPrint('[DEBUG] 📡 PowerEffectProvider.startListening() CALLED');
    debugPrint('[DEBUG]    myGamePlayerId: $myGamePlayerId');
    debugPrint('[DEBUG]    eventId: $eventId');
    
    final supabase = _supabaseClient;
    if (supabase == null) {
      _clearAllEffects();
      _subscription?.cancel();
      _casterSubscription?.cancel();
      _combatEventsSubscription?.cancel();
      return;
    }

    if (myGamePlayerId == null || myGamePlayerId.isEmpty) {
      _clearAllEffects();
      _subscription?.cancel();
      _casterSubscription?.cancel();
       _combatEventsSubscription?.cancel();
      return;
    }

    if (myGamePlayerId == _listeningForId && eventId == _listeningForEventId && _subscription != null && !forceRestart) {
      debugPrint('[DEBUG] ⏭️ Already listening for $myGamePlayerId (Event: $eventId), skipping restart.');
      return;
    }
    
    _clearAllEffects(); 

    _listeningForId = myGamePlayerId;
    _listeningForEventId = eventId;
    _sessionStartTime = DateTime.now().toUtc();
    _processedEffectIds.clear();

    // 1. Listen for Active Powers
    // NOTE: We filter event_id client-side to avoid SupabaseStreamBuilder typing issues
    _subscription = supabase
        .from('active_powers')
        .stream(primaryKey: ['id'])
        .eq('target_id', myGamePlayerId)
        .listen((List<Map<String, dynamic>> data) async {
          await _processEffects(data);
        }, onError: (e) {
          debugPrint('PowerEffectProvider active_powers stream error: $e');
        });

    // 2. Listen for Outgoing Powers
    _casterSubscription = supabase
        .from('active_powers')
        .stream(primaryKey: ['id'])
        .eq('caster_id', myGamePlayerId)
        .listen((List<Map<String, dynamic>> data) async {
          await _processOutgoingEffects(data);
        }, onError: (e) {
          debugPrint('PowerEffectProvider outgoing stream error: $e');
        });

    // 3. Listen for Combat Events
    _combatEventsSubscription = supabase
        .from('combat_events')
        .stream(primaryKey: ['id'])
        .eq('target_id', myGamePlayerId)
        .order('created_at', ascending: false) // Latest first
        .limit(1)
        .listen((List<Map<String, dynamic>> data) {
           _handleCombatEvents(data);
        }, onError: (e) {
           debugPrint('PowerEffectProvider combat_events stream error: $e');
        });
  }

  void _handleCombatEvents(List<Map<String, dynamic>> data) {
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
         debugPrint('[COMBAT] 🛑 Ignoring event from different event_id: $eventId (Expected: $_listeningForEventId)');
         return;
      }
    }
    
    final createdAt = DateTime.parse(createdAtStr);
    if (_sessionStartTime != null && createdAt.isBefore(_sessionStartTime!)) return;
    
    // Idempotency check for events (using ID)
    final eventId = event['id']?.toString();
    if (eventId != null) {
      if (_processedEffectIds.contains(eventId)) return;
      _processedEffectIds.add(eventId);
    }

    final resultType = event['result_type'];
    final powerSlug = event['power_slug'];

    debugPrint('[COMBAT] ⚔️ Event Received: $resultType (Power: $powerSlug)');

    if (resultType == 'shield_blocked') {
        // Server confirmed shield blocked an attack
        _shieldArmed = false; // Sync local state
        _removeEffect('shield'); // Remove icon
        
        _registerDefenseAction(DefenseAction.shieldBroken);
        _feedbackStreamController.add(PowerFeedbackEvent(
            PowerFeedbackType.shieldBroken
        ));
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
         debugPrint("REFLEJO DETECTADO (Stream Outgoing): $slug lanzado automáticamente.");
      }
    }
  }

  /// Aplica un efecto y gestiona su temporizador
  void applyEffect({
    required String slug,
    required Duration duration,
    String? effectId,
    String? casterId,
    required DateTime expiresAt,
  }) {
    // 🛡️ RACE CONDITION FIX:
    // If we stopped listening (user left game), do NOT apply new effects.
    // This prevents async packets from "zombie" streams applying effects after exit.
    if (_listeningForId == null) {
       debugPrint('[DEBUG] 🛑 applyEffect BLOCKED: Not listening for any player.');
       return;
    }

    // Si ya existe, cancelamos su timer anterior (reset duration logic)
    _activeEffects[slug]?.timer.cancel();

    // Nueva variable timer
    final timer = Timer(duration, () {
      _removeEffect(slug);
    });

    _activeEffects[slug] = _ActiveEffect(
      slug: slug,
      effectId: effectId,
      casterId: casterId,
      expiresAt: expiresAt,
      timer: timer
    );
    
    debugPrint('[DEBUG] ✨ Effect Applied/Renewed: $slug (expires in ${duration.inSeconds}s)');
    notifyListeners();
  }

  void _removeEffect(String slug) {
    if (_activeEffects.containsKey(slug)) {
      _activeEffects[slug]?.timer.cancel();
      _activeEffects.remove(slug);
      debugPrint('[DEBUG] 🗑️ Effect Removed: $slug');
      notifyListeners();
    }
  }

  void _clearAllEffects() {
    for (var effect in _activeEffects.values) {
      effect.timer.cancel();
    }
    _activeEffects.clear();
    notifyListeners();
  }

  Future<void> _processEffects(List<Map<String, dynamic>> data) async {
    final supabase = _supabaseClient;
    if (supabase == null) return;

    // Filter logic (same as before)
    final filtered = data.where((effect) {
      final targetId = effect['target_id'];
      final createdAtStr = effect['created_at'];
      if (_listeningForId == null || targetId != _listeningForId) return false;
      
       // 2. Event ID Check (New)
      if (_listeningForEventId != null) {
        final effectEventId = effect['event_id']?.toString();
        // Strict filtering: If listening for specific event, effect must match.
        // If effect has 'null' event_id, we might accept it? Or reject?
        // Assuming offensive powers always have event_id.
        if (effectEventId != null && effectEventId != _listeningForEventId) {
             return false;
        }
      }

      if (_sessionStartTime != null && createdAtStr != null) {
         final createdAt = DateTime.parse(createdAtStr);
         final adjustedSessionStart = _sessionStartTime!.subtract(const Duration(seconds: 5));
         if (createdAt.isBefore(adjustedSessionStart)) return false;
      }
      return true;
    }).toList();

    // Shield Check (Concurrent/One-Shot Logic)
    // We check if 'shield' is active in _activeEffects.
    // If so, and we receive an OFFENSIVE effect, we block it and break the shield.
    
    final isShieldUp = isPowerActive(PowerType.shield);
    
    // We need to identify if ANY of the incoming valid effects is offensive.
    // AND if we haven't processed it yet (though Filtered list implies they are relevant).
    
    // Return Logic (Priority)
    // We look for ONE offensive effect to return.
    // If multiple arrive, we pick one, return it, and theoretically consume it.
    // But since this is a concurrent system, maybe we can return one and suffer the others?
    // Following existing logic: Return takes priority over applying effects.

    if (filtered.isEmpty) {
       // Check if we need to clear effects that might have been removed from DB?
       // With concurrent timers, effects clear themselves locally.
       // But if an effect is manually deleted from DB (e.g. by admin), we might want to sync.
       // For now, local timers are robust enough for duration.
       // However, to strictly follow DB state for "cancellations":
       // We could check if any active effect is NOT in the incoming data.
       return;
    }
    
    // We iterate over ALL filtered events (not just valid/future ones)
    // This allows us to catch "Life Steal" events that might be slightly expired 
    // due to network lag, but should still trigger if not processed yet.
    // Standard durational effects (blind/freeze) will still be skipped if expired.
    
    final now = DateTime.now().toUtc();

    for (final effect in filtered) {
       final slug = await _resolveEffectSlug(effect);
       if (slug == null) continue;
       
       final effectId = effect['id']?.toString();
       final casterId = effect['caster_id']?.toString();
       final expiresAt = DateTime.parse(effect['expires_at']);
       final duration = expiresAt.difference(now);
       final bool isExpired = duration <= Duration.zero;
       
       final bool isLifeSteal = slug == 'life_steal';
       
       // Validity check for defenses:
       // Must be active OR be life_steal (which we verify via idempotency later, but for defense it counts as "incoming")
       // If it's a standard effect and it's expired, we ignore it completely (ghost effect).
       if (isExpired && !isLifeSteal) continue;

       final bool isOffensive = slug == 'black_screen' || 
                                slug == 'freeze' || 
                                slug == 'blur_screen' ||
                                isLifeSteal;

       // --- 1. RETURN MECHANISM (Highest Priority) ---
       if (_returnArmed && isOffensive) {
          final bool isSelf = casterId == _listeningForId;
          
          if (!isSelf && casterId != null) {
            _returnArmed = false;
            _registerDefenseAction(DefenseAction.returned);
            
            _returnedAgainstCasterId = casterId;
            _returnedPowerSlug = slug;

            // Delete incoming
            if (effectId != null) {
               try {
                  await supabase.from('active_powers').delete().eq('id', effectId);
               } catch (_) {}
            }

            // Reflect
            try {
               final reflectDuration = await _getPowerDurationFromDb(powerSlug: slug);
               final exp = DateTime.now().toUtc().add(reflectDuration).toIso8601String();
               final payload = {
                  'target_id': casterId,
                  'caster_id': _listeningForId,
                  'power_slug': slug,
                  'expires_at': exp,
               };
               if (effect['event_id'] != null) payload['event_id'] = effect['event_id'];
               await supabase.from('active_powers').insert(payload);
            } catch (_) {}

            notifyListeners();
            return; // Stop processing any other effects if we returned one
          }
       }

       // --- SHIELD SYNC (Server-Side Removal) ---
       // If shield is active locally, but missing from the incoming stream, 
       // it means the server consumed it (or it expired/was removed).
       // We must remove it locally to update the UI immediately.
       if (_shieldArmed && isEffectActive('shield')) {
           bool shieldInStream = filtered.any((e) {
               final s = e['power_slug'] ?? e['slug']; // handle both formats
               return s == 'shield';
           });
           
           if (!shieldInStream) {
               debugPrint('[SHIELD] 🛡️ Shield missing from stream (consumed/expired) -> Removing local effect.');
               _shieldArmed = false;
               _removeEffect('shield');
           }
       }
       
       // --- INTERCEPTION LOGIC ---
       // Shield interception is now handled Server-Side (execute_combat_power.sql).
       // The attack is blocked at the DB level and never reaches active_powers.
       // Feedback is handled via _combatEventsSubscription.
       // We only keep Return interception here because it requires client-side Reflection logic 
       // (until that is also moved to server).

       // --- HANDLE INCOMING FEEDBACK (As Attacker) ---
       if (slug == 'shield_feedback') {
           _registerDefenseAction(DefenseAction.attackBlockedByEnemy);
           _feedbackStreamController.add(PowerFeedbackEvent(
              PowerFeedbackType.attackBlocked
           ));
           continue; 
       }
       
       // --- 4. LIFE STEAL PROCESSING (If not blocked/returned) ---
       if (isLifeSteal) {
          if (effectId != null) {
             if (isEffectProcessed(effectId)) continue; // Idempotencia
             markEffectAsProcessed(effectId);
          }
          
          setPendingEffectContext(effectId, casterId);
          final strategy = PowerStrategyFactory.get('life_steal');
          strategy?.onActivate(this);
          setPendingEffectContext(null, null);
          
          _feedbackStreamController.add(PowerFeedbackEvent(
              PowerFeedbackType.lifeStolen,
              relatedPlayerName: casterId,
          ));
          continue; 
       }

       // --- 5. STANDARD EFFECT APPLICATION ---
       // Only if !isExpired (checked at top)
       if (isExpired) continue; // Redundant but safe

       if (!isEffectActive(slug)) {
          final strategy = PowerStrategyFactory.get(slug);
          strategy?.onActivate(this); 
       }

       applyEffect(
         slug: slug,
         duration: duration,
         effectId: effectId,
         casterId: casterId,
         expiresAt: expiresAt
       );
    }
  }

  Future<String?> _resolveEffectSlug(Map<String, dynamic> effect) async {
    final explicit = effect['power_slug'] ?? effect['slug'];
    if (explicit != null) return explicit.toString();

    final powerId = effect['power_id'];
    if (powerId == null) return null;
    final powerIdStr = powerId.toString();
    final cached = _powerIdToSlugCache[powerIdStr];
    if (cached != null) return cached;

    final supabase = _supabaseClient;
    if (supabase == null) return null;

    try {
      final res = await supabase
          .from('powers')
          .select('slug')
          .eq('id', powerIdStr)
          .maybeSingle();
      final slug = res?['slug']?.toString();
      if (slug != null && slug.isNotEmpty) {
        _powerIdToSlugCache[powerIdStr] = slug;
      }
      return slug;
    } catch (_) {
      return null;
    }
  }

  Future<Duration> _getPowerDurationFromDb({required String powerSlug}) async {
    final cached = _powerSlugToDurationCache[powerSlug];
    if (cached != null) return cached;

    final supabase = _supabaseClient;
    if (supabase == null) return Duration.zero;

    try {
      final row = await supabase
          .from('powers')
          .select('duration')
          .eq('slug', powerSlug)
          .maybeSingle();

      final seconds = (row?['duration'] as num?)?.toInt() ?? 0;
      final duration =
          seconds <= 0 ? Duration.zero : Duration(seconds: seconds);
      _powerSlugToDurationCache[powerSlug] = duration;
      return duration;
    } catch (e) {
      debugPrint('_getPowerDurationFromDb($powerSlug) error: $e');
      return Duration.zero;
    }
  }

  void _clearEffect() {
     // Deprecated internal method, mapping to clearAll for safety or ignore
     _clearAllEffects();
  }

  void clearActiveEffect() {
    _clearAllEffects();
  }

  void _registerDefenseAction(DefenseAction action) {
    _defenseFeedbackTimer?.cancel();
    _lastDefenseAction = action;
    _lastDefenseActionAt = DateTime.now();
    notifyListeners();

    // Duración diferenciada: Returned es un evento más importante => 4s
    final duration = action == DefenseAction.returned 
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

  bool _isShieldSlug(String? slug) {
    if (slug == null) return false;
    return slug == 'shield';
  }

  void notifyPowerReturned(String byPlayerName) {
    _returnedByPlayerName = byPlayerName;
    _registerDefenseAction(DefenseAction.returned);
    _feedbackStreamController.add(PowerFeedbackEvent(
      PowerFeedbackType.returned,
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

  Future<void> _sendShieldFeedback(String targetId) async {
     final supabase = _supabaseClient;
     if (supabase == null) return;
     
     // USAR ID CACHEADO O FAIL LOUDLY
     final powerId = _cachedShieldPowerId;
     
     if (powerId == null) {
       debugPrint('🛑 CRITICAL ERROR: Cannot send Shield Feedback - Missing Power ID!');
       debugPrint('   Ensure armShield() was called or DB has slug "shield".');
       return;
     }

     try {
       // Insert a short-lived effect for feedback
       final duration = const Duration(seconds: 3);
       final expiresAt = DateTime.now().toUtc().add(duration).toIso8601String();
       
       await supabase.from('active_powers').insert({
          'target_id': targetId, // Attacker is now target of feedback
          'caster_id': _listeningForId, // Me
          'power_id': powerId,
          'power_slug': 'shield_feedback', // Special slug
          'expires_at': expiresAt,
       });
       debugPrint('[SHIELD] 📨 Feedback sent to attacker $targetId (using power_id: $powerId)');
     } catch (e) {
       debugPrint('[SHIELD] ⚠️ Failed to send feedback: $e');
     }
  }

  /// Resets the provider state, stopping all listeners and clearing effects.
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
  void dispose() {
    _subscription?.cancel();
    _casterSubscription?.cancel();
    _defenseFeedbackTimer?.cancel();
    _clearAllEffects();
    _feedbackStreamController.close(); // Cleanup Stream
    super.dispose();
  }
}

class _ActiveEffect {
  final String slug;
  final String? effectId;
  final String? casterId;
  final DateTime expiresAt;
  final Timer timer;

  _ActiveEffect({
    required this.slug,
    required this.effectId,
    required this.casterId,
    required this.expiresAt,
    required this.timer,
  });
}

enum DefenseAction { shieldBlocked, returned, stealFailed, shieldBroken, attackBlockedByEnemy }
