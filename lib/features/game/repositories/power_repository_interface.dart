import 'package:supabase_flutter/supabase_flutter.dart';

abstract class PowerRepository {
  /// Stream of active powers targeting the player
  Stream<List<Map<String, dynamic>>> getActivePowersStream({required String targetId});

  /// Stream of powers cast BY the player (for outgoing effects/reflection)
  Stream<List<Map<String, dynamic>>> getOutgoingPowersStream({required String casterId});

  /// Stream of combat events (shield blocks, reflections, etc.)
  Stream<List<Map<String, dynamic>>> getCombatEventsStream({required String targetId});

  /// Resolves a power slug from a power effect object/map
  Future<String?> resolveEffectSlug(Map<String, dynamic> effect);

  /// Gets the duration of a specific power from the database configuration
  Future<Duration> getPowerDuration({required String powerSlug});

  /// Validates if a specific combat event exists (used for Life Steal validation)
  Future<bool> validateCombatEvent({
    required String eventId,
    required String casterId,
    required String targetId,
    required String powerSlug,
  });
}
