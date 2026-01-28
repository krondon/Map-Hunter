import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../interfaces/i_lives_repository.dart';

/// Supabase implementation of the lives repository.
/// 
/// This repository encapsulates all Supabase realtime and CRUD operations
/// for player lives, enabling the GameProvider to be infrastructure-agnostic.
class SupabaseLivesRepository implements ILivesRepository {
  final SupabaseClient _client;
  final Map<String, RealtimeChannel> _channels = {};
  final Map<String, StreamController<int>> _controllers = {};

  SupabaseLivesRepository({SupabaseClient? client})
      : _client = client ?? Supabase.instance.client;

  @override
  Future<int?> fetchLives({
    required String eventId,
    required String userId,
  }) async {
    try {
      final response = await _client
          .from('game_players')
          .select('lives')
          .eq('event_id', eventId)
          .eq('user_id', userId)
          .maybeSingle();

      if (response == null) {
        debugPrint('[LivesRepo] No game_player found for user $userId in event $eventId');
        return null;
      }

      return response['lives'] as int?;
    } catch (e) {
      debugPrint('[LivesRepo] Error fetching lives: $e');
      return null;
    }
  }

  @override
  Future<int> loseLife({
    required String eventId,
    required String userId,
  }) async {
    try {
      // Fetch current lives
      final currentLives = await fetchLives(eventId: eventId, userId: userId) ?? 0;
      if (currentLives <= 0) return 0;

      final newLives = currentLives - 1;

      // Update in database
      await _client
          .from('game_players')
          .update({'lives': newLives})
          .eq('event_id', eventId)
          .eq('user_id', userId);

      debugPrint('[LivesRepo] Lives decremented: $currentLives -> $newLives');
      return newLives;
    } catch (e) {
      debugPrint('[LivesRepo] Error losing life: $e');
      rethrow;
    }
  }

  @override
  Future<void> resetLives({
    required String eventId,
    required String userId,
    int lives = 3,
  }) async {
    try {
      await _client
          .from('game_players')
          .update({'lives': lives})
          .eq('event_id', eventId)
          .eq('user_id', userId);

      debugPrint('[LivesRepo] Lives reset to $lives for user $userId');
    } catch (e) {
      debugPrint('[LivesRepo] Error resetting lives: $e');
      rethrow;
    }
  }

  @override
  StreamSubscription<int> subscribeToLives({
    required String eventId,
    required String userId,
    required LivesChangeCallback onLivesChange,
  }) {
    final channelId = 'lives:$userId:$eventId';
    
    // Create a StreamController for this subscription
    final controller = StreamController<int>.broadcast();
    _controllers[channelId] = controller;

    // Unsubscribe from existing channel if any
    _channels[channelId]?.unsubscribe();

    debugPrint('[LivesRepo] Subscribing to lives for user $userId in event $eventId');

    // Create new channel subscription
    final channel = _client
        .channel(channelId)
        .onPostgresChanges(
          event: PostgresChangeEvent.update,
          schema: 'public',
          table: 'game_players',
          callback: (payload) {
            final record = payload.newRecord;
            
            // Validate this is for our user and event
            final incomingUserId = record['user_id']?.toString().trim() ?? '';
            final incomingEventId = record['event_id']?.toString().trim() ?? '';
            
            if (incomingUserId == userId.trim() && incomingEventId == eventId.trim()) {
              final newLives = record['lives'] as int;
              debugPrint('[LivesRepo] Lives update received: $newLives');
              controller.add(newLives);
              onLivesChange(newLives);
            }
          },
        )
        .subscribe();

    _channels[channelId] = channel;

    // Return subscription that clients can cancel
    return controller.stream.listen((_) {});
  }

  @override
  void unsubscribeAll() {
    for (final channel in _channels.values) {
      channel.unsubscribe();
    }
    _channels.clear();

    for (final controller in _controllers.values) {
      controller.close();
    }
    _controllers.clear();

    debugPrint('[LivesRepo] All subscriptions cleared');
  }

  @override
  void dispose() {
    unsubscribeAll();
  }
}
