/// Player repository interface for profile/game player operations.
/// 
/// This interface abstracts profile data operations from Supabase,
/// enabling the PlayerProvider to be infrastructure-agnostic.
library;

import 'dart:async';

/// Contract for player repository implementations.
/// 
/// Implementations:
/// - SupabasePlayerRepository (production)
/// - MockPlayerRepository (testing)
abstract class IPlayerRepository {
  
  /// Fetch the basic profile for a user.
  /// 
  /// [userId] The user to query.
  /// Returns the profile data map, or null if not found.
  Future<Map<String, dynamic>?> fetchProfile(String userId);

  /// Update the avatar for a user.
  /// 
  /// [userId] The user to update.
  /// [avatarId] The new avatar identifier.
  Future<void> updateAvatar(String userId, String avatarId);

  /// Fetch game player data for a user in a specific event.
  /// 
  /// [userId] The user to query.
  /// [eventId] Optional event to filter by.
  /// [gamePlayerId] Optional specific gamePlayer ID to fetch.
  /// Returns the game_player data map, or null if not found.
  Future<Map<String, dynamic>?> fetchGamePlayer({
    required String userId,
    String? eventId,
    String? gamePlayerId,
  });

  /// Fetch the user's powers inventory.
  /// 
  /// [gamePlayerId] The game player ID to query.
  /// Returns a list of {slug, quantity} maps.
  Future<List<Map<String, dynamic>>> fetchPowers(String gamePlayerId);

  /// Check the player status (active, banned, etc).
  /// 
  /// [userId] The user to query.
  /// Returns the status string.
  Future<String?> checkStatus(String userId);

  /// Subscribe to real-time profile changes.
  /// 
  /// [userId] The user to subscribe to.
  /// [onProfileChange] Callback when profile changes.
  /// Returns a StreamSubscription that must be cancelled when done.
  StreamSubscription<Map<String, dynamic>> subscribeToProfile({
    required String userId,
    required void Function(Map<String, dynamic>) onProfileChange,
  });

  /// Subscribe to real-time game_players changes for a user.
  /// 
  /// [userId] The user to subscribe to.
  /// [onGamePlayerChange] Callback when game_players change.
  StreamSubscription<List<Map<String, dynamic>>> subscribeToGamePlayers({
    required String userId,
    required void Function(List<Map<String, dynamic>>) onGamePlayerChange,
  });

  /// Unsubscribe from all active subscriptions.
  void unsubscribeAll();

  /// Dispose the repository and clean up resources.
  void dispose();
}
