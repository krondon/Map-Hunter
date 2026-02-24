import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/game_request.dart';

/// Repository interface for game request operations
abstract class IGameRequestRepository {
  Future<GameRequest?> getRequestForPlayer(String playerId, String eventId);
  Future<Map<String, dynamic>> getPlayerParticipation(String playerId, String eventId);
  Future<List<Map<String, dynamic>>> getAllUserParticipations(String playerId);
  Future<String?> getPlayerStatus(String playerId, String eventId);
  Future<int> getParticipantCount(String eventId);
  Future<void> createRequest(String userId, String eventId);
  Future<void> updateRequestStatus(String requestId, String status);
  Future<void> deleteGamePlayer(String gamePlayerId);
  Future<void> createGamePlayer({
    required String userId,
    required String eventId,
    String status = 'active',
    int lives = 3,
    String role = 'player',
  });
  Future<void> upgradeSpectatorToPlayer(String gamePlayerId);
  /// Calls the atomic RPC approve_and_pay_event_entry (admin approval + payment).
  Future<Map<String, dynamic>> approveAndPayEntry(String requestId);
  /// Calls the atomic RPC join_online_paid_event (self-service for online events).
  Future<Map<String, dynamic>> joinOnlinePaidEventRPC(String userId, String eventId);
  /// Calls the atomic RPC join_online_free_event (create game_player and approved game_request).
  Future<Map<String, dynamic>> joinOnlineFreeEventRPC(String userId, String eventId);

  /// Calls secure_clover_payment RPC directly (generic atomic clover deduction).
  Future<Map<String, dynamic>> callSecureCloverPayment(String userId, int amount, String reason);
  Future<int> getCurrentClovers(String userId);
  Future<List<GameRequest>> getAllRequests();
}

/// Supabase implementation of game request repository
class GameRequestRepository implements IGameRequestRepository {
  final SupabaseClient _supabase;

  GameRequestRepository({required SupabaseClient supabaseClient})
      : _supabase = supabaseClient;

  @override
  Future<GameRequest?> getRequestForPlayer(String playerId, String eventId) async {
    try {
      final data = await _supabase
          .from('game_requests')
          .select('id, status')
          .eq('user_id', playerId)
          .eq('event_id', eventId)
          .maybeSingle();

      if (data == null) return null;
      
      return GameRequest(
        id: data['id'],
        userId: playerId,
        eventId: eventId,
        status: data['status'],
      );
    } catch (e) {
      debugPrint('GameRequestRepository: Error fetching request: $e');
      rethrow;
    }
  }

  @override
  Future<Map<String, dynamic>> getPlayerParticipation(String playerId, String eventId) async {
    try {
      final data = await _supabase
          .from('game_players')
          .select('id, status')
          .eq('user_id', playerId)
          .eq('event_id', eventId)
          .maybeSingle();

      if (data != null) {
        return {
          'isParticipant': true,
          'status': data['status'] as String?,
          'gamePlayerId': data['id'] as String?,
        };
      }
      return {'isParticipant': false, 'status': null, 'gamePlayerId': null};
    } catch (e) {
      debugPrint('GameRequestRepository: Error checking participation: $e');
      rethrow;
    }
  }

  @override
  Future<List<Map<String, dynamic>>> getAllUserParticipations(String playerId) async {
    try {
      final response = await _supabase
          .from('game_players')
          .select('event_id, id, status')
          .eq('user_id', playerId);
      return List<Map<String, dynamic>>.from(response as List);
    } catch (e) {
      debugPrint('GameRequestRepository: Error checking all participations: $e');
      rethrow;
    }
  }

  @override
  Future<String?> getPlayerStatus(String playerId, String eventId) async {
    try {
      final data = await _supabase
          .from('game_players')
          .select('status')
          .eq('user_id', playerId)
          .eq('event_id', eventId)
          .maybeSingle();

      return data?['status'] as String?;
    } catch (e) {
      debugPrint('GameRequestRepository: Error fetching player status: $e');
      rethrow;
    }
  }

  @override
  Future<int> getParticipantCount(String eventId) async {
    try {
      final response = await _supabase
          .from('game_players')
          .select('id')
          .eq('event_id', eventId)
          .neq('status', 'spectator')
          .count(CountOption.exact);

      return response.count ?? 0;
    } catch (e) {
      debugPrint('GameRequestRepository: Error counting participants: $e');
      rethrow;
    }
  }

  @override
  Future<void> createRequest(String userId, String eventId) async {
    try {
      await _supabase.from('game_requests').insert({
        'user_id': userId,
        'event_id': eventId,
        'status': 'pending',
      });
    } catch (e) {
      debugPrint('GameRequestRepository: Error creating request: $e');
      rethrow;
    }
  }

  @override
  Future<void> updateRequestStatus(String requestId, String status) async {
    try {
      await _supabase
          .from('game_requests')
          .update({'status': status})
          .eq('id', requestId);
    } catch (e) {
      debugPrint('GameRequestRepository: Error updating request: $e');
      rethrow;
    }
  }

  @override
  Future<void> deleteGamePlayer(String gamePlayerId) async {
    try {
      await _supabase
          .from('game_players')
          .delete()
          .eq('id', gamePlayerId);
    } catch (e) {
      debugPrint('GameRequestRepository: Error deleting game player: $e');
      rethrow;
    }
  }

  @override
  Future<void> createGamePlayer({
    required String userId,
    required String eventId,
    String status = 'active',
    int lives = 3,
    String role = 'player',
  }) async {
    try {
      await _supabase.from('game_players').insert({
        'user_id': userId,
        'event_id': eventId,
        'status': status,
        'lives': lives,
        'role': role,
        'joined_at': DateTime.now().toIso8601String(),
      });
    } catch (e) {
      debugPrint('GameRequestRepository: Error creating game player: $e');
      rethrow;
    }
  }

  @override
  Future<void> upgradeSpectatorToPlayer(String gamePlayerId) async {
    try {
      await _supabase.from('game_players').update({
        'status': 'active',
        'lives': 3,
        'role': 'player',
        'joined_at': DateTime.now().toIso8601String(),
      }).eq('id', gamePlayerId);
    } catch (e) {
      debugPrint('GameRequestRepository: Error upgrading spectator: $e');
      rethrow;
    }
  }

  @override
  Future<Map<String, dynamic>> approveAndPayEntry(String requestId) async {
    try {
      final result = await _supabase.rpc('approve_and_pay_event_entry', params: {
        'p_request_id': requestId,
      });
      return Map<String, dynamic>.from(result as Map);
    } catch (e) {
      debugPrint('GameRequestRepository: Error in approveAndPayEntry: $e');
      rethrow;
    }
  }

  @override
  Future<Map<String, dynamic>> joinOnlinePaidEventRPC(String userId, String eventId) async {
    try {
      final result = await _supabase.rpc('join_online_paid_event', params: {
        'p_user_id': userId,
        'p_event_id': eventId,
      });
      return Map<String, dynamic>.from(result as Map);
    } catch (e) {
      debugPrint('GameRequestRepository: Error in joinOnlinePaidEventRPC: $e');
      rethrow;
    }
  }

  @override
  Future<Map<String, dynamic>> joinOnlineFreeEventRPC(String userId, String eventId) async {
    try {
      final result = await _supabase.rpc('join_online_free_event', params: {
        'p_user_id': userId,
        'p_event_id': eventId,
      });
      return Map<String, dynamic>.from(result as Map);
    } catch (e) {
      debugPrint('GameRequestRepository: Error in joinOnlineFreeEventRPC: $e');
      rethrow;
    }
  }

  @override
  Future<Map<String, dynamic>> callSecureCloverPayment(String userId, int amount, String reason) async {
    try {
      final result = await _supabase.rpc('secure_clover_payment', params: {
        'p_user_id': userId,
        'p_amount': amount,
        'p_reason': reason,
      });
      return Map<String, dynamic>.from(result as Map);
    } catch (e) {
      debugPrint('GameRequestRepository: Error in callSecureCloverPayment: $e');
      rethrow;
    }
  }

  @override
  Future<int> getCurrentClovers(String userId) async {
    try {
      final profile = await _supabase
          .from('profiles')
          .select('clovers')
          .eq('id', userId)
          .single();

      return profile['clovers'] as int;
    } catch (e) {
      debugPrint('GameRequestRepository: Error fetching clovers: $e');
      rethrow;
    }
  }

  @override
  Future<List<GameRequest>> getAllRequests() async {
    try {
      final response = await _supabase
          .from('game_requests')
          .select('*, profiles(name, email), events(title)')
          .order('created_at', ascending: false);

      debugPrint('GameRequestRepository: Raw response count: ${(response as List).length}');

      return (response as List).map((data) {
        debugPrint('GameRequestRepository: Mapping request - ID: ${data['id']}, User: ${data['profiles']?['name']}, Event: ${data['events']?['title']}');
        
        return GameRequest(
          id: data['id'],
          userId: data['user_id'],
          eventId: data['event_id'],
          status: data['status'],
          createdAt: data['created_at'] != null 
              ? DateTime.parse(data['created_at']) 
              : null,
          userName: data['profiles']?['name'],
          userEmail: data['profiles']?['email'],
          eventName: data['events']?['title'],
        );
      }).toList();
    } catch (e) {
      debugPrint('GameRequestRepository: Error fetching all requests: $e');
      rethrow;
    }
  }

  /// Try to initialize game player using RPC
  Future<bool> tryInitializeWithRPC(String userId, String eventId) async {
    try {
      await _supabase.rpc('initialize_game_for_user', params: {
        'target_user_id': userId,
        'target_event_id': eventId,
      });
      return true;
    } catch (e) {
      debugPrint('GameRequestRepository: RPC initialization failed: $e');
      return false;
    }
  }
}
