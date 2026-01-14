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
