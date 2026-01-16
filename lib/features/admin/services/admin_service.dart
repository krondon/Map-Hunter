import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../shared/models/player.dart';

/// Servicio de administración que encapsula la lógica de gestión de usuarios.
/// 
/// Implementa DIP al recibir [SupabaseClient] por constructor en lugar
/// de depender de variables globales.
class AdminService {
  final SupabaseClient _supabase;

  AdminService({required SupabaseClient supabaseClient})
      : _supabase = supabaseClient;

  /// Obtiene todos los jugadores registrados en el sistema.
  /// 
  /// Retorna una lista de [Player] ordenada por nombre.
  Future<List<Player>> fetchAllPlayers() async {
    try {
      final data = await _supabase
          .from('profiles')
          .select()
          .order('name', ascending: true);

      return (data as List).map((json) => Player.fromJson(json)).toList();
    } catch (e) {
      debugPrint('AdminService: Error fetching all players: $e');
      rethrow;
    }
  }

  /// Alterna el estado de baneo de un usuario.
  /// 
  /// [userId] - ID del usuario a modificar.
  /// [ban] - `true` para banear, `false` para activar.
  Future<void> toggleBanUser(String userId, bool ban) async {
    try {
      await _supabase.rpc(
        'toggle_ban',
        params: {
          'user_id': userId,
          'new_status': ban ? 'banned' : 'active',
        },
      );
    } catch (e) {
      debugPrint('AdminService: Error toggling ban: $e');
      rethrow;
    }
  }

  Future<void> toggleGameBanUser(String userId, String eventId, bool ban) async {
    debugPrint('AdminService: toggleGameBanUser (RPC-V2-SUSPENDED) CALLED. User: $userId, Event: $eventId, Ban: $ban');
    try {
      // Usamos la versión V2 NUCLEAR que desactiva triggers
      final success = await _supabase.rpc<bool>(
        'toggle_event_member_ban_v2',
        params: {
          'p_user_id': userId,
          'p_event_id': eventId,
          // CAMBIO CLAVE: Usamos 'suspended' en lugar de 'banned'
          'p_new_status': ban ? 'suspended' : 'active',
        },
      );
       
      debugPrint('AdminService: toggleGameBanUser RPC Result: $success');
      
      if (!success) {
        throw Exception("La función RPC retornó false (no se encontró el registro o falló)");
      }
    } catch (e) {
      debugPrint('AdminService: Error toggling game ban via RPC: $e');
      rethrow;
    }
  }
  
  /// Obtiene un mapa de {userId: status} para todos los participantes de un evento.
  Future<Map<String, String>> fetchEventParticipantStatuses(String eventId) async {
    try {
      final data = await _supabase
          .from('game_players')
          .select('user_id, status')
          .eq('event_id', eventId);
          
      final Map<String, String> result = {};
      for (var row in data) {
        if (row['user_id'] != null && row['status'] != null) {
          result[row['user_id'] as String] = row['status'] as String;
        }
      }
      return result;
    } catch (e) {
      debugPrint('AdminService: Error fetching event statuses: $e');
      return {};
    }
  }

  /// Elimina un usuario del sistema.
  /// 
  /// [userId] - ID del usuario a eliminar.
  Future<void> deleteUser(String userId) async {
    try {
      await _supabase.rpc('delete_user', params: {'user_id': userId});
    } catch (e) {
      debugPrint('AdminService: Error deleting user: $e');
      rethrow;
    }
  }
}
