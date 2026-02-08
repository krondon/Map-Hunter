import 'dart:async';
import 'package:flutter/foundation.dart';
import '../../mall/models/power_item.dart';
import '../../../core/services/effect_timer_service.dart';

/// Enum for types of feedback the user receives from power interactions.
enum PowerFeedbackType { lifeStolen, shieldBroken, attackBlocked, defenseSuccess, returned, stealFailed, returnSuccess, returnRejection }

/// Event emitted when a power interaction occurs that requires user feedback.
class PowerFeedbackEvent {
  final PowerFeedbackType type;
  final String message;
  final String? relatedPlayerName;
  
  PowerFeedbackEvent(this.type, {this.message = '', this.relatedPlayerName});
}

/// Actions taken defensively against incoming powers.
enum DefenseAction { shieldBlocked, returned, stealFailed, shieldBroken, attackBlockedByEnemy }

/// Interface for consuming power state (ReadOnly).
/// Used by UI widgets to display active effects.
abstract class PowerEffectReader extends Listenable {
  Stream<EffectEvent> get effectStream;
  Stream<PowerFeedbackEvent> get feedbackStream;
  
  bool isEffectActive(String slug);
  bool isPowerActive(PowerType type);
  
  DateTime? getPowerExpiration(String slug);
  DateTime? getPowerExpirationByType(PowerType type);
  
  String? get activePowerSlug;
  String? get activeEffectId;
  String? get activeEffectCasterId;
  DateTime? get activePowerExpiresAt;

  // Feedback State
  bool get isReturnArmed;
  bool get isShieldArmed;
  DefenseAction? get lastDefenseAction;
  DateTime? get lastDefenseActionAt;
  
  // Specific Feedback Data
  String? get returnedByPlayerName;
  String? get returnedAgainstCasterId;
  String? get returnedPowerSlug;
  
  // Defense Exclusivity
  String? get activeDefensePower;
  bool get isDefenseActive;
  bool canActivateDefensePower(String slug);
}

/// Interface for managing power state (Write/Action).
/// Used by services and game logic to apply/modify effects.
abstract class PowerEffectManager implements PowerEffectReader {
  Future<void> applyEffect({
    required String slug,
    required Duration duration,
    String? effectId,
    String? casterId,
    required DateTime expiresAt,
    Duration? dbDuration,
  });

  void resetState();
  void stopListening();
  void startListening(String? myGamePlayerId, {String? eventId, bool forceRestart = false});
  
  void setManualCasting(bool value);
  void armReturn();
  Future<void> armShield();
  void setShielded(bool value, {String? sourceSlug});
  void clearActiveEffect();
  
  void configureLifeStealVictimHandler(Future<void> Function(String effectId, String? casterGamePlayerId, String targetGamePlayerId) handler);
  
  // Methods to notify about internal events (could be internal but exposed to strategies)
  void notifyPowerReturned(String byPlayerName);
  void notifyAttackBlocked();
  void notifyStealFailed();
}
