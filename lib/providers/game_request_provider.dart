import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/game_request.dart';
import '../models/player.dart';

class GameRequestProvider extends ChangeNotifier {
  List<GameRequest> _requests = [];
  final _supabase = Supabase.instance.client;

  List<GameRequest> get requests => _requests;

  Future<void> submitRequest(Player player, String eventId) async {
    try {
      // Check if request already exists
      final existing = await _supabase
          .from('game_requests')
          .select()
          .eq('user_id', player.id)
          .eq('event_id', eventId)
          .maybeSingle();

      if (existing != null) {
        // Already requested
        return;
      }

      // Insert request
      await _supabase.from('game_requests').insert({
        'user_id': player.id,
        'event_id': eventId,
        'status': 'pending',
      });
      
      notifyListeners();
    } catch (e) {
      debugPrint('Error submitting request: $e');
      rethrow;
    }
  }

  Future<GameRequest?> getRequestForPlayer(String playerId, String eventId) async {
    try {
      final data = await _supabase
          .from('game_requests')
          .select('*, events(title)')
          .eq('user_id', playerId)
          .eq('event_id', eventId)
          .maybeSingle();
      
      if (data == null) return null;
      
      return GameRequest.fromJson(data);
    } catch (e) {
      debugPrint('Error getting request: $e');
      return null;
    }
  }

  Future<bool> isPlayerParticipant(String playerId, String eventId) async {
    try {
      final data = await _supabase
          .from('event_participants')
          .select()
          .eq('user_id', playerId)
          .eq('event_id', eventId)
          .maybeSingle();
          
      return data != null;
    } catch (e) {
      return false;
    }
  }

  Future<void> fetchAllRequests() async {
    try {
      final data = await _supabase
          .from('game_requests')
          .select('*, profiles(name, email), events(title)')
          .order('created_at', ascending: false);
      
      // Debug: Print first item to check structure
      if ((data as List).isNotEmpty) {
        debugPrint('First request data: ${data[0]}');
      }

      _requests = (data as List).map((json) => GameRequest.fromJson(json)).toList();
      notifyListeners();
    } catch (e) {
      debugPrint('Error fetching requests: $e');
    }
  }

  Future<void> approveRequest(String requestId) async {
    try {
      final response = await _supabase.functions.invoke('admin-actions/approve-request', 
        body: {'requestId': requestId},
        method: HttpMethod.post
      );

      if (response.status != 200) {
        throw Exception('Failed to approve request: ${response.data}');
      }

      // Refresh list
      await fetchAllRequests();
    } catch (e) {
      debugPrint('Error approving request: $e');
      rethrow;
    }
  }
  
  Future<void> rejectRequest(String requestId) async {
    try {
      await _supabase
          .from('game_requests')
          .update({'status': 'rejected'})
          .eq('id', requestId);
          
      await fetchAllRequests();
    } catch (e) {
      debugPrint('Error rejecting request: $e');
      rethrow;
    }
  }
}
