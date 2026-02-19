import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../auth/services/auth_service.dart';
import '../../../shared/models/player.dart';
import '../models/admin_stats.dart';
import '../models/audit_log.dart';

/// Servicio de administración que encapsula la lógica de gestión de usuarios.
///
/// Implementa DIP al recibir [SupabaseClient] por constructor en lugar
/// de depender de variables globales.
class AdminService {
  final SupabaseClient _supabase;
  final AuthService _authService;

  AdminService({
    required SupabaseClient supabaseClient,
    required AuthService authService,
  })  : _supabase = supabaseClient,
        _authService = authService;

  /// Obtiene estadísticas generales para el dashboard.
  Future<AdminStats> fetchGeneralStats() async {
    try {
      // 1. Count Users (Profiles)
      final usersCount =
          await _supabase.from('profiles').count(CountOption.exact);

      // 2. Count Events
      final eventsCount =
          await _supabase.from('events').count(CountOption.exact);

      // 3. Count Pending Requests
      final requestsCount = await _supabase
          .from('game_requests')
          .select('*')
          .eq('status', 'pending')
          .count(CountOption.exact);

      return AdminStats(
        activeUsers: usersCount,
        createdEvents: eventsCount,
        pendingRequests: requestsCount.count,
      );
    } catch (e) {
      debugPrint('AdminService: Error fetching stats: $e');
      rethrow;
    }
  }

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

  Future<void> toggleGameBanUser(
      String userId, String eventId, bool ban) async {
    debugPrint(
        'AdminService: toggleGameBanUser (RPC-V2-SUSPENDED) CALLED. User: $userId, Event: $eventId, Ban: $ban');
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
        throw Exception(
            "La función RPC retornó false (no se encontró el registro o falló)");
      }
    } catch (e) {
      debugPrint('AdminService: Error toggling game ban via RPC: $e');
      rethrow;
    }
  }

  /// Obtiene un mapa de {userId: status} para todos los participantes de un evento.
  Future<Map<String, String>> fetchEventParticipantStatuses(
      String eventId) async {
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

  /// Distribuye los premios del bote acumulado a los ganadores.
  ///
  /// Retorna un mapa con los resultados de la distribución.
  /// Distribuye los premios del bote acumulado a los ganadores (Server-Side RPC).
  ///
  /// Retorna un mapa con los resultados de la distribución.
  Future<Map<String, dynamic>> distributeCompetitionPrizes(
      String eventId) async {
    try {
      debugPrint(
          'AdminService: Distributing prizes via RPC for event $eventId');

      final response = await _supabase.rpc(
        'distribute_event_prizes',
        params: {'p_event_id': eventId},
      );

      debugPrint('AdminService: RPC Response: $response');

      final data = response as Map<String, dynamic>;

      // Mapear respuesta del RPC al formato esperado por la UI si es necesario
      return {
        'success': data['success'] ?? false,
        'message': data['message'] ??
            (data['success'] ? 'Distribución completada' : 'Error desconocido'),
        'pot': data['distributable_pot'] ?? 0.0,
        'results': data['results'] ?? [],
        'winners_count': data['winners_count'] ?? 0,
      };
    } catch (e) {
      debugPrint('AdminService: Error distributing prizes via RPC: $e');
      return {
        'success': false,
        'message': 'Error de conexión o RPC: $e',
        'pot': 0.0
      };
    }
  }

  // Helper para obtener ranking (reutiliza lógica similar a GameService pero simplificada)
  Future<List<dynamic>> _gameLeaderboard(String eventId) async {
    return await _supabase
        .from('event_leaderboard')
        .select()
        .eq('event_id', eventId)
        .order('completed_clues', ascending: false, nullsFirst: false)
        .order('last_completion_time', ascending: true)
        .limit(3);
  }

  Future<void> _addToWallet(String userId, int amount) async {
    if (amount <= 0) return;
    // Fetch current
    final res = await _supabase
        .from('profiles')
        .select('clovers')
        .eq('id', userId)
        .single();
    final int current = res['clovers'] ?? 0;
    // Update
    await _supabase
        .from('profiles')
        .update({'clovers': current + amount}).eq('id', userId);
  }

  Future<bool> checkPrizeDistributionStatus(String eventId) async {
    try {
      final count = await _supabase
          .from('prize_distributions')
          .count(CountOption.exact)
          .eq('event_id', eventId)
          .eq('rpc_success', true);

      return count > 0;
    } catch (e) {
      debugPrint('AdminService: Error checking prize distribution status: $e');
      return false; // Assume false on error to not block UI
    }
  }

  /// Obtiene todos los perfiles con rol de 'admin'.
  Future<List<Player>> fetchAdmins() async {
    try {
      debugPrint('AdminService: Fetching admins...');
      final response = await _supabase
          .from('profiles')
          .select()
          .eq('role', 'admin')
          .order('name', ascending: true);

      final data = response as List;
      debugPrint('AdminService: Found ${data.length} admins.');
      return data.map((json) => Player.fromJson(json)).toList();
    } catch (e) {
      debugPrint('AdminService: Error fetching admins: $e');
      return [];
    }
  }

  /// Recupera los logs de auditoría con paginación y filtros opcionales.
  Future<List<AuditLog>> getAuditLogs({
    int limit = 20,
    int offset = 0,
    String? actionType,
    String? adminId,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    try {
      // 1. Start with select (PostgrestFilterBuilder)
      var query =
          _supabase.from('admin_audit_logs').select('*, profiles(email)');

      // 2. Apply filters
      if (actionType != null && actionType.isNotEmpty) {
        query = query.eq('action_type', actionType);
      }

      if (adminId != null && adminId.isNotEmpty) {
        query = query.eq('admin_id', adminId);
      }

      if (startDate != null) {
        query = query.gte('created_at', startDate.toIso8601String());
      }

      if (endDate != null) {
        query = query.lte('created_at', endDate.toIso8601String());
      }

      // 3. Apply sort and pagination (Returns PostgrestTransformBuilder)
      final transformQuery = query
          .order('created_at', ascending: false)
          .range(offset, offset + limit - 1);

      final response = await transformQuery;
      final data = response as List;

      return data.map((json) => AuditLog.fromJson(json)).toList();
    } catch (e) {
      debugPrint('AdminService: Error fetching audit logs: $e');
      return [];
    }
  }
}
