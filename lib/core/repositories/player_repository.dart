import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../interfaces/i_player_repository.dart';

/// Supabase implementation of the player repository.
/// 
/// This repository encapsulates all Supabase operations for player profiles
/// and game_players, enabling the PlayerProvider to be infrastructure-agnostic.
class SupabasePlayerRepository implements IPlayerRepository {
  final SupabaseClient _client;
  final Map<String, RealtimeChannel> _channels = {};
  final Map<String, StreamController> _controllers = {};

  SupabasePlayerRepository({SupabaseClient? client})
      : _client = client ?? Supabase.instance.client;

  @override
  Future<Map<String, dynamic>?> fetchProfile(String userId) async {
    try {
      final response = await _client
          .from('profiles')
          .select()
          .eq('id', userId)
          .maybeSingle();

      return response;
    } catch (e) {
      debugPrint('[PlayerRepo] Error fetching profile: $e');
      return null;
    }
  }

  @override
  Future<void> updateAvatar(String userId, String avatarId) async {
    try {
      await _client
          .from('profiles')
          .update({'avatar_id': avatarId})
          .eq('id', userId);
      
      debugPrint('[PlayerRepo] Avatar updated for user $userId');
    } catch (e) {
      debugPrint('[PlayerRepo] Error updating avatar: $e');
      rethrow;
    }
  }

  @override
  Future<Map<String, dynamic>?> fetchGamePlayer({
    required String userId,
    String? eventId,
    String? gamePlayerId,
  }) async {
    try {
      // If we have a specific gamePlayerId, fetch directly
      if (gamePlayerId != null) {
        return await _client
            .from('game_players')
            .select('id, lives, status, event_id')
            .eq('id', gamePlayerId)
            .maybeSingle();
      }

      // If we have an eventId, filter by it
      if (eventId != null) {
        return await _client
            .from('game_players')
            .select('id, lives, status, event_id')
            .eq('user_id', userId)
            .eq('event_id', eventId)
            .maybeSingle();
      }

      // Otherwise get the most recent
      return await _client
          .from('game_players')
          .select('id, lives, status, event_id')
          .eq('user_id', userId)
          .order('joined_at', ascending: false)
          .limit(1)
          .maybeSingle();
    } catch (e) {
      debugPrint('[PlayerRepo] Error fetching game player: $e');
      return null;
    }
  }

  @override
  Future<List<Map<String, dynamic>>> fetchPowers(String gamePlayerId) async {
    try {
      final List<dynamic> response = await _client
          .from('player_powers')
          .select('quantity, powers!inner(slug)')
          .eq('game_player_id', gamePlayerId)
          .gt('quantity', 0);

      return response.map((item) {
        final powerDetails = item['powers'];
        return {
          'slug': powerDetails?['slug'] ?? '',
          'quantity': item['quantity'] ?? 0,
        };
      }).toList();
    } catch (e) {
      debugPrint('[PlayerRepo] Error fetching powers: $e');
      return [];
    }
  }

  @override
  Future<String?> checkStatus(String userId) async {
    try {
      final response = await _client
          .from('profiles')
          .select('status')
          .eq('id', userId)
          .maybeSingle();

      return response?['status'] as String?;
    } catch (e) {
      debugPrint('[PlayerRepo] Error checking status: $e');
      return null;
    }
  }

  @override
  StreamSubscription<Map<String, dynamic>> subscribeToProfile({
    required String userId,
    required void Function(Map<String, dynamic>) onProfileChange,
  }) {
    final channelId = 'profile:$userId';
    
    final controller = StreamController<Map<String, dynamic>>.broadcast();
    _controllers[channelId] = controller;

    // Unsubscribe from existing channel if any
    _channels[channelId]?.unsubscribe();

    debugPrint('[PlayerRepo] Subscribing to profile for user $userId');

    final channel = _client
        .channel(channelId)
        .onPostgresChanges(
          event: PostgresChangeEvent.update,
          schema: 'public',
          table: 'profiles',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'id',
            value: userId,
          ),
          callback: (payload) {
            final record = payload.newRecord;
            debugPrint('[PlayerRepo] Profile update received');
            controller.add(record);
            onProfileChange(record);
          },
        )
        .subscribe();

    _channels[channelId] = channel;

    return controller.stream.listen((_) {});
  }

  @override
  StreamSubscription<List<Map<String, dynamic>>> subscribeToGamePlayers({
    required String userId,
    required void Function(List<Map<String, dynamic>>) onGamePlayerChange,
  }) {
    final channelId = 'game_players:$userId';
    
    final controller = StreamController<List<Map<String, dynamic>>>.broadcast();
    _controllers[channelId] = controller;

    // Unsubscribe from existing channel if any
    _channels[channelId]?.unsubscribe();

    debugPrint('[PlayerRepo] Subscribing to game_players for user $userId');

    final channel = _client
        .channel(channelId)
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'game_players',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'user_id',
            value: userId,
          ),
          callback: (payload) {
            final record = payload.newRecord;
            debugPrint('[PlayerRepo] GamePlayers update received');
            // Wrap single record in list for consistency
            final list = record.isNotEmpty ? [record] : <Map<String, dynamic>>[];
            controller.add(list);
            onGamePlayerChange(list);
          },
        )
        .subscribe();

    _channels[channelId] = channel;

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

    debugPrint('[PlayerRepo] All subscriptions cleared');
  }

  @override
  void dispose() {
    unsubscribeAll();
  }
}
