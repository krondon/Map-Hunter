import 'dart:async';
import 'package:flutter/foundation.dart';

/// Event emitted when an effect's state changes.
enum EffectEventType { applied, removed, expired }

class EffectEvent {
  final EffectEventType type;
  final String slug;
  final String? effectId;
  final String? casterId;

  EffectEvent({
    required this.type,
    required this.slug,
    this.effectId,
    this.casterId,
  });
}

/// Represents an active effect with its timer.
class ActiveEffect {
  final String slug;
  final String? effectId;
  final String? casterId;
  final DateTime expiresAt;
  final Timer timer;

  ActiveEffect({
    required this.slug,
    this.effectId,
    this.casterId,
    required this.expiresAt,
    required this.timer,
  });
}

/// Service responsible for managing active effect timers.
/// 
/// Extracted from PowerEffectProvider to follow Single Responsibility Principle.
/// This class handles ONLY:
/// - Storing active effects
/// - Managing Timer objects
/// - Emitting events when effects change
/// 
/// Security Note: Local expiration times are validated against DB values
/// to prevent clients from shortening effect durations.
class EffectTimerService extends ChangeNotifier {
  final Map<String, ActiveEffect> _activeEffects = {};
  
  final StreamController<EffectEvent> _eventController = 
      StreamController<EffectEvent>.broadcast();
  
  /// Stream of effect events for UI notifications.
  Stream<EffectEvent> get effectStream => _eventController.stream;
  
  /// Returns all currently active effect slugs.
  Set<String> get activeEffectSlugs => _activeEffects.keys.toSet();
  
  /// Check if a specific effect is currently active.
  bool isActive(String slug) => _activeEffects.containsKey(slug);
  
  /// Get the expiration time for a specific effect.
  DateTime? getExpiration(String slug) => _activeEffects[slug]?.expiresAt;
  
  /// Get the effect ID for a specific effect (if available).
  String? getEffectId(String slug) => _activeEffects[slug]?.effectId;
  
  /// Get the caster ID for a specific effect (if available).
  String? getCasterId(String slug) => _activeEffects[slug]?.casterId;

  /// Applies an effect with the given parameters.
  /// 
  /// [slug] - Unique identifier for the effect type.
  /// [localDuration] - Duration calculated by the client.
  /// [dbDuration] - Duration from the database (authoritative). Optional.
  /// [expiresAt] - Absolute expiration timestamp.
  /// [effectId] - Database ID of this effect instance.
  /// [casterId] - ID of the player who cast the effect.
  /// 
  /// Security: If [dbDuration] is provided and [localDuration] is shorter,
  /// [dbDuration] is used to prevent clients from escaping effects early.
  void applyEffect({
    required String slug,
    required Duration localDuration,
    Duration? dbDuration,
    required DateTime expiresAt,
    String? effectId,
    String? casterId,
  }) {
    // SECURITY GUARD: Use the LONGER duration to prevent cheating.
    // If database says 30s but client calculates 10s, use 30s.
    Duration effectiveDuration = localDuration;
    if (dbDuration != null && dbDuration > localDuration) {
      debugPrint('[EffectTimerService] ⚠️ Security: Using DB duration ($dbDuration) instead of local ($localDuration)');
      effectiveDuration = dbDuration;
    }

    // Cancel existing timer if effect already active (reset behavior)
    _activeEffects[slug]?.timer.cancel();

    // Create new timer
    final timer = Timer(effectiveDuration, () {
      _onEffectExpired(slug);
    });

    _activeEffects[slug] = ActiveEffect(
      slug: slug,
      effectId: effectId,
      casterId: casterId,
      expiresAt: expiresAt,
      timer: timer,
    );

    debugPrint('[EffectTimerService] ✨ Effect applied: $slug (expires in ${effectiveDuration.inSeconds}s)');
    
    _eventController.add(EffectEvent(
      type: EffectEventType.applied,
      slug: slug,
      effectId: effectId,
      casterId: casterId,
    ));
    
    notifyListeners();
  }

  /// Removes an effect immediately (e.g., when blocked or consumed).
  void removeEffect(String slug) {
    final effect = _activeEffects[slug];
    if (effect != null) {
      effect.timer.cancel();
      _activeEffects.remove(slug);
      
      debugPrint('[EffectTimerService] 🗑️ Effect removed: $slug');
      
      _eventController.add(EffectEvent(
        type: EffectEventType.removed,
        slug: slug,
        effectId: effect.effectId,
        casterId: effect.casterId,
      ));
      
      notifyListeners();
    }
  }

  /// Clears all active effects. Used on logout/reset.
  void clearAll() {
    for (final effect in _activeEffects.values) {
      effect.timer.cancel();
    }
    _activeEffects.clear();
    debugPrint('[EffectTimerService] 🧹 All effects cleared');
    notifyListeners();
  }

  void _onEffectExpired(String slug) {
    final effect = _activeEffects[slug];
    if (effect != null) {
      _activeEffects.remove(slug);
      
      debugPrint('[EffectTimerService] ⏰ Effect expired: $slug');
      
      _eventController.add(EffectEvent(
        type: EffectEventType.expired,
        slug: slug,
        effectId: effect.effectId,
        casterId: effect.casterId,
      ));
      
      notifyListeners();
    }
  }

  @override
  void dispose() {
    for (final effect in _activeEffects.values) {
      effect.timer.cancel();
    }
    _activeEffects.clear();
    _eventController.close();
    super.dispose();
  }
}
