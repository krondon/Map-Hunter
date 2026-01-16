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

  String? _lastError;
  String? get lastError => _lastError;

  /// Envía una solicitud de acceso a un evento.
  /// 
  /// Verifica primero si el usuario ya es un game_player o ya tiene una solicitud.
  /// Retorna el resultado de la operación.
  Future<SubmitRequestResult> submitRequest(Player player, String eventId) async {
    try {
      _lastError = null; // Reset error
      // IMPORTANTE: Usar player.userId para consultas de BD, no player.id (que puede ser gamePlayerId)
      final String userId = player.userId;
      debugPrint('[REQUEST_SUBMIT] 🎯 START: userId=$userId, eventId=$eventId');

      // PASO 1: Verificar si ya es un game_player para este evento
      debugPrint('[REQUEST_SUBMIT] 🔍 Step 1: Checking if already game_player...');
      final existingPlayer = await _supabase
          .from('game_players')
          .select('id')
          .eq('user_id', userId)
          .eq('event_id', eventId)
          .maybeSingle();

      if (existingPlayer != null) {
        debugPrint('[REQUEST_SUBMIT] ⚠️ RESULT: User is already a game_player. Aborting.');
        return SubmitRequestResult.alreadyPlayer;
      }

      // PASO 2: Verificar si ya tiene una solicitud para este evento
      debugPrint('[REQUEST_SUBMIT] 🔍 Step 2: Checking existing request...');
      final existingRequest = await _supabase
          .from('game_requests')
          .select('id, status')
          .eq('user_id', userId)
          .eq('event_id', eventId)
          .maybeSingle();

      if (existingRequest != null) {
        debugPrint('[REQUEST_SUBMIT] ⚠️ RESULT: Already has request (status: ${existingRequest['status']}). Aborting.');
        return SubmitRequestResult.alreadyRequested;
      }

      // PASO 3: Crear nueva solicitud
      debugPrint('[REQUEST_SUBMIT] ✏️ Step 3: Inserting new request...');
      final insertData = {
        'user_id': userId,
        'event_id': eventId,
        'status': 'pending',
      };
      debugPrint('[REQUEST_SUBMIT] 📦 Insert payload: $insertData');
      
      await _supabase.from('game_requests').insert(insertData);
      
      debugPrint('[REQUEST_SUBMIT] ✅ SUCCESS: Request submitted successfully');
      notifyListeners();
      return SubmitRequestResult.submitted;
    } on PostgrestException catch (e) {
      // Captura específica de errores de Supabase
      debugPrint('[REQUEST_SUBMIT] ❌ PostgrestException:');
      debugPrint('[REQUEST_SUBMIT]   - Code: ${e.code}');
      debugPrint('[REQUEST_SUBMIT]   - Message: ${e.message}');
      debugPrint('[REQUEST_SUBMIT]   - Details: ${e.details}');
      _lastError = e.message; // Capture specific DB error
      return SubmitRequestResult.error;
    } catch (e, stackTrace) {
      debugPrint('[REQUEST_SUBMIT] ❌ ERROR: $e');
      debugPrint('[REQUEST_SUBMIT] Stack trace: $stackTrace');
      _lastError = e.toString(); // Capture generic error
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

  /// Returns a map with 'isParticipant' (bool) and 'status' (String?)
  /// to check both participation and ban status
  Future<Map<String, dynamic>> isPlayerParticipant(String playerId, String eventId) async {
    try {
      final data = await _supabase
          .from('game_players')
          .select('status')
          .eq('user_id', playerId)
          .eq('event_id', eventId)
          .maybeSingle();
          
      if (data != null) {
        return {
          'isParticipant': true,
          'status': data['status'] as String?,
        };
      }
      return {'isParticipant': false, 'status': null};
    } catch (e) {
      debugPrint('Error checking player participation: $e');
      return {'isParticipant': false, 'status': null};
    }
  }

  /// Get player status for a specific event
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
      debugPrint('Error getting player status: $e');
      return null;
    }
  }

  /// Obtiene el estado específico del jugador en la competencia (active, banned, etc.)
  Future<String?> getGamePlayerStatus(String playerId, String eventId) async {
    try {
      final data = await _supabase
          .from('game_players')
          .select('status')
          .eq('user_id', playerId)
          .eq('event_id', eventId)
          .maybeSingle();
          
      if (data == null) return null;
      return data['status'] as String?;
    } catch (e) {
      debugPrint('Error getting player status: $e');
      return null;
    }
  }

  Future<void> fetchAllRequests() async {
    try {
      debugPrint('[FETCH_REQUESTS] 🔍 Fetching all requests...');
      
      final data = await _supabase
          .from('game_requests')
          .select('*, profiles(name, email), events(title)')
          .order('created_at', ascending: false);
      
      debugPrint('[FETCH_REQUESTS] 📦 Raw data received: ${(data as List).length} rows');
      
      // Debug: Print first item to check structure
      if ((data as List).isNotEmpty) {
        debugPrint('[FETCH_REQUESTS] First request sample: ${data[0]}');
      } else {
        debugPrint('[FETCH_REQUESTS] ⚠️ WARNING: No requests found in database!');
      }

      _requests = (data as List).map((json) => GameRequest.fromJson(json)).toList();
      
      debugPrint('[FETCH_REQUESTS] ✅ Parsed requests: ${_requests.length}');
      debugPrint('[FETCH_REQUESTS] Event IDs present: ${_requests.map((r) => r.eventId).toSet()}');
      
      notifyListeners();
    } on PostgrestException catch (e) {
      debugPrint('[FETCH_REQUESTS] ❌ PostgrestException:');
      debugPrint('[FETCH_REQUESTS]   - Code: ${e.code}');
      debugPrint('[FETCH_REQUESTS]   - Message: ${e.message}');
      debugPrint('[FETCH_REQUESTS]   - Details: ${e.details}');
    } catch (e) {
      debugPrint('[FETCH_REQUESTS] ❌ Error fetching requests: $e');
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
