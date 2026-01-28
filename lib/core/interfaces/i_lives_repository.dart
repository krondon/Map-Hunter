/// Lives repository interface for game player lives management.
/// 
/// This interface abstracts the data source for player lives,
/// enabling both real-time subscriptions and CRUD operations
/// without coupling to Supabase directly.
library;

import 'dart:async';

/// Callback type for lives change events.
typedef LivesChangeCallback = void Function(int newLives);

/// Contract for lives repository implementations.
/// 
/// Implementations:
/// - SupabaseLivesRepository (production)
/// - MockLivesRepository (testing)
abstract class ILivesRepository {
  
  /// Fetch current lives for a player in an event.
  /// 
  /// [eventId] The event context.
  /// [userId] The user to query.
  /// Returns the number of lives, or null if not found.
  Future<int?> fetchLives({
    required String eventId,
    required String userId,
  });

  /// Decrement lives for a player.
  /// 
  /// [eventId] The event context.
  /// [userId] The user losing a life.
  /// Returns the new lives count after decrement.
  Future<int> loseLife({
    required String eventId,
    required String userId,
  });

  /// Reset lives to a specific value.
  /// 
  /// [eventId] The event context.
  /// [userId] The user to reset.
  /// [lives] The new lives value (default: 3).
  Future<void> resetLives({
    required String eventId,
    required String userId,
    int lives = 3,
  });

  /// Subscribe to real-time lives changes.
  /// 
  /// [eventId] The event context.
  /// [userId] The user to subscribe to.
  /// [onLivesChange] Callback when lives change.
  /// Returns a StreamSubscription that must be cancelled when done.
  StreamSubscription<int> subscribeToLives({
    required String eventId,
    required String userId,
    required LivesChangeCallback onLivesChange,
  });

  /// Unsubscribe from all active subscriptions.
  void unsubscribeAll();

  /// Dispose the repository and clean up resources.
  void dispose();
}
