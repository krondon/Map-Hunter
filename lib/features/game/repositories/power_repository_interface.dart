import 'package:supabase_flutter/supabase_flutter.dart';

abstract class PowerRepository {
  /// Stream of active powers targeting the player
  Stream<List<Map<String, dynamic>>> getActivePowersStream({required String targetId});

  /// Stream of powers cast BY the player (for outgoing effects/reflection)
  Stream<List<Map<String, dynamic>>> getOutgoingPowersStream({required String casterId});

  /// Stream of combat events (shield blocks, reflections, etc.)
  Stream<List<Map<String, dynamic>>> getCombatEventsStream({required String targetId});

  /// Stream of specific game player updates (for is_protected sync)
  Stream<Map<String, dynamic>?> getGamePlayerStream({required String playerId});

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

  /// Deactivates the current defense power for the given player.
  /// Clears is_protected and removes expired defense rows from active_powers.
  Future<void> deactivateDefense({required String gamePlayerId});

  /// Fetches the name of a player/spectator from their gamePlayerId.
  /// Needed for gift notifications when the sender is not in the local leaderboard (spectators).
  Future<String?> getGifterName({required String gamePlayerId});
}
