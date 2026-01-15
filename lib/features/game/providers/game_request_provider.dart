import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/game_request.dart';
import '../../../shared/models/player.dart';

/// Resultado de enviar una solicitud.
enum SubmitRequestResult {
  /// Solicitud enviada exitosamente
  submitted,
  /// Ya existe una solicitud para este evento
  alreadyRequested,
  /// El usuario ya es jugador de este evento
  alreadyPlayer,
  /// Error al enviar la solicitud
  error,
}

class GameRequestProvider extends ChangeNotifier {
  List<GameRequest> _requests = [];
  final _supabase = Supabase.instance.client;

  List<GameRequest> get requests => _requests;

  /// Envía una solicitud de acceso a un evento.
  /// 
  /// Verifica primero si el usuario ya es un game_player o ya tiene una solicitud.
  /// Retorna el resultado de la operación.
  Future<SubmitRequestResult> submitRequest(Player player, String eventId) async {
    try {
      // IMPORTANTE: Usar player.userId para consultas de BD, no player.id (que puede ser gamePlayerId)
      final String userId = player.userId;

      // PASO 1: Verificar si ya es un game_player para este evento
      final existingPlayer = await _supabase
          .from('game_players')
          .select('id')
          .eq('user_id', userId)
          .eq('event_id', eventId)
          .maybeSingle();

      if (existingPlayer != null) {
        debugPrint('GameRequestProvider: User is already a game_player for this event');
        return SubmitRequestResult.alreadyPlayer;
      }

      // PASO 2: Verificar si ya tiene una solicitud para este evento
      final existingRequest = await _supabase
          .from('game_requests')
          .select('id, status')
          .eq('user_id', userId)
          .eq('event_id', eventId)
          .maybeSingle();

      if (existingRequest != null) {
        debugPrint('GameRequestProvider: User already has a request for this event');
        return SubmitRequestResult.alreadyRequested;
      }

      // PASO 3: Crear nueva solicitud
      await _supabase.from('game_requests').insert({
        'user_id': userId,
        'event_id': eventId,
        'status': 'pending',
      });
      
      debugPrint('GameRequestProvider: Request submitted successfully');
      notifyListeners();
      return SubmitRequestResult.submitted;
    } catch (e) {
      debugPrint('GameRequestProvider: Error submitting request: $e');
      return SubmitRequestResult.error;
    }
  }


void clearLocalRequests() {
  _requests = []; // Vacía la lista local
  notifyListeners();
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
