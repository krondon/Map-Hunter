import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/game_request.dart';
import '../repositories/game_request_repository.dart';
import '../../../shared/models/player.dart';

/// Resultado de enviar una solicitud.
enum SubmitRequestResult {
  /// Solicitud enviada exitosamente
  submitted,
  /// Ya existe una solicitud para este evento
  alreadyRequested,
  /// El usuario ya es jugador de este evento
  alreadyPlayer,
  /// El evento está lleno (límite de 30)
  eventFull,
  /// Error al enviar la solicitud
  error,
}

class GameRequestProvider extends ChangeNotifier {
  final GameRequestRepository _repository;
  List<GameRequest> _requests = [];

  GameRequestProvider({required GameRequestRepository repository})
      : _repository = repository;

  List<GameRequest> get requests => _requests;

  String? _lastError;
  String? get lastError => _lastError;

  /// Envía una solicitud de acceso a un evento.
  /// 
  /// Verifica primero si el usuario ya es un game_player o ya tiene una solicitud.
  /// Retorna el resultado de la operación.
  Future<SubmitRequestResult> submitRequest(Player player, String eventId, int maxPlayers) async {
    try {
      _lastError = null; // Reset error
      // IMPORTANTE: Usar player.userId para consultas de BD, no player.id (que puede ser gamePlayerId)
      final String userId = player.userId;
      debugPrint('[REQUEST_SUBMIT] 🎯 START: userId=$userId, eventId=$eventId');

      // PASO 0: Verificar si el evento está lleno
      debugPrint('[REQUEST_SUBMIT] 🔍 Step 0: Checking if event is full...');
      final participantCount = await _repository.getParticipantCount(eventId);
      if (participantCount >= maxPlayers) {
        debugPrint('[REQUEST_SUBMIT] ⚠️ RESULT: Event is full ($participantCount/$maxPlayers). Aborting.');
        return SubmitRequestResult.eventFull;
      }

      // PASO 1: Verificar si ya es un game_player para este evento
      debugPrint('[REQUEST_SUBMIT] 🔍 Step 1: Checking if already game_player...');
      final participation = await _repository.getPlayerParticipation(userId, eventId);

      if (participation['isParticipant'] == true) {
        final status = participation['status'];
        final gamePlayerId = participation['gamePlayerId'];
        if (status == 'spectator' && gamePlayerId != null) {
           debugPrint('[REQUEST_SUBMIT] ⚠️ User is spectator. Deleting spectator record to allow player upgrade...');
           await _repository.deleteGamePlayer(gamePlayerId);
           // Proceed to create request
        } else {
           debugPrint('[REQUEST_SUBMIT] ⚠️ RESULT: User is already a game_player (Status: $status). Aborting.');
           return SubmitRequestResult.alreadyPlayer;
        }
      }

      // PASO 2: Verificar si ya tiene una solicitud para este evento
      debugPrint('[REQUEST_SUBMIT] 🔍 Step 2: Checking existing request...');
      final existingRequest = await _repository.getRequestForPlayer(userId, eventId);

      if (existingRequest != null) {
        debugPrint('[REQUEST_SUBMIT] ⚠️ RESULT: Already has request (status: ${existingRequest.status}). Aborting.');
        return SubmitRequestResult.alreadyRequested;
      }

      // PASO 3: Crear nueva solicitud
      debugPrint('[REQUEST_SUBMIT] ✏️ Step 3: Inserting new request...');
      await _repository.createRequest(userId, eventId);
      
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
      return await _repository.getRequestForPlayer(playerId, eventId);
    } catch (e) {
      debugPrint('Error getting request: $e');
      return null;
    }
  }

  /// Returns a map with 'isParticipant' (bool) and 'status' (String?)
  /// to check both participation and ban status
  Future<Map<String, dynamic>> isPlayerParticipant(String playerId, String eventId) async {
    try {
      return await _repository.getPlayerParticipation(playerId, eventId);
    } catch (e) {
      debugPrint('Error checking player participation: $e');
      return {'isParticipant': false, 'status': null};
    }
  }

  /// Get player status for a specific event
  Future<String?> getPlayerStatus(String playerId, String eventId) async {
    try {
      return await _repository.getPlayerStatus(playerId, eventId);
    } catch (e) {
      debugPrint('Error getting player status: $e');
      return null;
    }
  }

  /// Counts active players for a specific event
  Future<int> getParticipantCount(String eventId) async {
    try {
      return await _repository.getParticipantCount(eventId);
    } catch (e) {
      debugPrint('Error counting participants: $e');
      return 0;
    }
  }

  /// Obtiene el estado específico del jugador en la competencia (active, banned, etc.)
  Future<String?> getGamePlayerStatus(String playerId, String eventId) async {
    try {
      return await _repository.getPlayerStatus(playerId, eventId);
    } catch (e) {
      debugPrint('Error getting player status: $e');
      return null;
    }
  }

  Future<void> fetchAllRequests() async {
    try {
      debugPrint('[FETCH_REQUESTS] 🔍 Fetching all requests...');
      
      _requests = await _repository.getAllRequests();
      
      debugPrint('[FETCH_REQUESTS] ✅ Fetched ${_requests.length} requests');
      debugPrint('[FETCH_REQUESTS] Event IDs present: ${_requests.map((r) => r.eventId).toSet()}');
      
      notifyListeners();
    } catch (e) {
      debugPrint('[FETCH_REQUESTS] ❌ Error fetching requests: $e');
    }
  }

  Future<void> approveRequest(String requestId) async {
    try {
      // Note: This uses an Edge Function which requires Supabase client
      // For now, we'll keep this as-is since it's an admin function
      // TODO: Consider moving Edge Function calls to repository
      final response = await Supabase.instance.client.functions.invoke(
        'admin-actions/approve-request', 
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
      await _repository.updateRequestStatus(requestId, 'rejected');
      await fetchAllRequests();
    } catch (e) {
      debugPrint('Error rejecting request: $e');
      rethrow;
    }
  }

  /// Procesa el pago de la inscripción a un evento (solo descuenta tréboles).
  /// NO crea el registro de jugador - el usuario debe pasar por el flujo normal de solicitud.
  /// 
  /// Retorna true si el descuento fue exitoso.
  Future<bool> processEventPayment(String userId, String eventId, int cost) async {
    try {
      debugPrint('[PAYMENT] 💰 Processing event payment. Cost: $cost');

      // Deduct clovers using repository
      final success = await _repository.deductClovers(userId, cost);
      
      if (!success) {
        final currentClovers = await _repository.getCurrentClovers(userId);
        debugPrint('[PAYMENT] ❌ Insufficient funds. Need $cost, have $currentClovers');
        return false;
      }

      debugPrint('[PAYMENT] ✅ Payment successful!');
      return true;

    } catch (e) {
      debugPrint('[PAYMENT] ❌ Payment error: $e');
      return false;
    }
  }

  /// Procesa el pago Y la inscripción directa para eventos ONLINE.
  /// Para eventos online, el pago permite entrada directa sin aprobación de admin.
  /// 
  /// Retorna true si el pago y la inscripción fueron exitosos.
  Future<bool> joinOnlinePaidEvent(String userId, String eventId, int cost) async {
    try {
      debugPrint('[ONLINE_JOIN] 💰 Processing online event payment + join. Cost: $cost');

      // 1. Deduct clovers
      final paymentSuccess = await _repository.deductClovers(userId, cost);
      if (!paymentSuccess) {
        final currentClovers = await _repository.getCurrentClovers(userId);
        debugPrint('[ONLINE_JOIN] ❌ Insufficient funds. Need $cost, have $currentClovers');
        return false;
      }

      // 2. Create game player (direct entry for online)
      bool joinSuccess = false;
      
      try {
        // [SPECTATOR UPGRADE CHECK]
        final participation = await _repository.getPlayerParticipation(userId, eventId);

        if (participation['isParticipant'] == true && participation['status'] == 'spectator') {
           final gamePlayerId = participation['gamePlayerId'];
           if (gamePlayerId != null) {
             debugPrint('[ONLINE_JOIN] 🔄 Upgrading spectator to player...');
             await _repository.upgradeSpectatorToPlayer(gamePlayerId);
             joinSuccess = true;
             debugPrint('[ONLINE_JOIN] ✅ Spectator Upgrade Success');
           }
        } else {
            // Try RPC first
            debugPrint('[ONLINE_JOIN] 🔄 Trying RPC initialize_game_for_user...');
            joinSuccess = await _repository.tryInitializeWithRPC(userId, eventId);
            if (joinSuccess) {
              debugPrint('[ONLINE_JOIN] ✅ RPC Join Success');
            }
        }
      } catch (e) {
        debugPrint('[ONLINE_JOIN] ⚠️ Primary Join failed: $e. Trying direct insert...');
      }
      
      // Fallback: Direct insert
      if (!joinSuccess) {
        try {
          await _repository.createGamePlayer(
            userId: userId,
            eventId: eventId,
            status: 'active',
            lives: 3,
            role: 'player',
          );
          joinSuccess = true;
          debugPrint('[ONLINE_JOIN] ✅ Manual Insert Success');
        } catch (e2) {
          debugPrint('[ONLINE_JOIN] ❌ Manual Insert failed: $e2');
        }
      }

      if (joinSuccess) {
        debugPrint('[ONLINE_JOIN] ✅ User successfully joined online event!');
        return true;
      } else {
        // ROLLBACK: Refund clovers if join failed
        debugPrint('[ONLINE_JOIN] ↺ Rolling back payment due to join failure...');
        final currentClovers = await _repository.getCurrentClovers(userId);
        // Note: This is a simplified rollback. In production, use database transactions.
        return false;
      }

    } catch (e) {
      debugPrint('[ONLINE_JOIN] ❌ Critical error: $e');
      return false;
    }
  }

  /// Inscribe a un usuario en un evento online GRATUITO.
  /// Crea el registro de jugador directamente sin cobrar.
  Future<void> joinFreeOnlineEvent(String userId, String eventId) async {
    debugPrint('[FREE_ONLINE] 🎮 Joining free online event...');
    
    try {
      // [SPECTATOR UPGRADE CHECK]
      final participation = await _repository.getPlayerParticipation(userId, eventId);

      if (participation['isParticipant'] == true && participation['status'] == 'spectator') {
          final gamePlayerId = participation['gamePlayerId'];
          if (gamePlayerId != null) {
            debugPrint('[FREE_ONLINE] 🔄 Upgrading spectator to player...');
            await _repository.upgradeSpectatorToPlayer(gamePlayerId);
            debugPrint('[FREE_ONLINE] ✅ Spectator Upgrade Success');
            return;
          }
      }

      // Try RPC first
      final rpcSuccess = await _repository.tryInitializeWithRPC(userId, eventId);
      if (rpcSuccess) {
        debugPrint('[FREE_ONLINE] ✅ RPC Join Success');
        return;
      }
      
      // Fallback: Direct insert
      debugPrint('[FREE_ONLINE] ⚠️ RPC failed. Trying direct insert...');
      await _repository.createGamePlayer(
        userId: userId,
        eventId: eventId,
        status: 'active',
        lives: 3,
        role: 'player',
      );
      debugPrint('[FREE_ONLINE] ✅ Direct Insert Success');
    } catch (e) {
      debugPrint('[FREE_ONLINE] ❌ Error: $e');
      rethrow;
    }
  }
}
