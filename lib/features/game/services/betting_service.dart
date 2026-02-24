import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class BettingService {
  final SupabaseClient _supabase;

  BettingService(this._supabase);

  /// Realiza apuestas masivas para un usuario en un evento.
  /// Retorna el resultado del RPC.
  Future<Map<String, dynamic>> placeBetsBatch({
    required String eventId,
    required String userId,
    required List<String> racerIds,
  }) async {
    try {
      final response = await _supabase.rpc('place_bets_batch', params: {
        'p_event_id': eventId,
        'p_user_id': userId,
        'p_racer_ids': racerIds,
      });

      return Map<String, dynamic>.from(response);
    } catch (e) {
      debugPrint('BettingService: Error placing bets: $e');
      return {'success': false, 'message': 'Error de conexión: $e'};
    }
  }

  /// Obtiene las apuestas activas de un usuario en un evento.
  Future<List<Map<String, dynamic>>> fetchUserBets(
      String eventId, String userId) async {
    try {
      final response = await _supabase
          .from('bets')
          .select('id, racer_id, amount, created_at, profiles:racer_id(name)')
          .eq('event_id', eventId)
          .eq('user_id', userId);

      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      debugPrint('BettingService: Error fetching user bets: $e');
      // Uncomment to see error in UI if needed, or inspecting logs.
      // throw e; 
      return [];
    }
  }
  /// Obtiene el monto total apostado en el evento (POTE).
  /// Usa el RPC `get_event_betting_stats` (SECURITY DEFINER) para obtener
  /// datos agregados sin necesidad de leer filas individuales de `bets`.
  Future<int> getEventBettingPot(String eventId) async {
    try {
      final response = await _supabase.rpc(
        'get_event_betting_stats',
        params: {'p_event_id': eventId},
      );
      final data = Map<String, dynamic>.from(response);
      return (data['total_pot'] as num?)?.toInt() ?? 0;
    } catch (e) {
      debugPrint('BettingService: Error fetching pot via RPC: $e');
      return 0;
    }
  }

  /// Realtime subscription to bets table to update pot.
  RealtimeChannel subscribeToBets(String eventId, Function() callback) {
    return _supabase
        .channel('bets_updates:$eventId')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'bets',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'event_id',
            value: eventId,
          ),
          callback: (payload) => callback(),
        )
        .subscribe();
  }


  /// Obtiene las ganancias del usuario en un evento.
  /// Retorna un mapa con {won: bool, amount: int}.
  Future<Map<String, dynamic>> getUserEventWinnings(String eventId, String userId) async {
    try {
      final response = await _supabase.rpc('get_user_event_winnings', params: {
        'p_event_id': eventId,
        'p_user_id': userId,
      });
      return Map<String, dynamic>.from(response);
    } catch (e) {
      debugPrint('BettingService: Error getting winnings: $e');
      return {'won': false, 'amount': 0};
    }
  }

  /// Obtiene el número total de apuestas en un evento.
  /// Usa el RPC seguro para no depender de lectura directa de `bets`.
  Future<int> getTotalBetsCount(String eventId) async {
    try {
      final response = await _supabase.rpc(
        'get_event_betting_stats',
        params: {'p_event_id': eventId},
      );
      final data = Map<String, dynamic>.from(response);
      return (data['total_bets'] as num?)?.toInt() ?? 0;
    } catch (e) {
      debugPrint('BettingService: Error counting bets: $e');
      return 0;
    }
  }

  /// Obtiene todas las apuestas de un evento enriquecidas con nombres de
  /// apostadores y participantes (racers). Usa un RPC con SECURITY DEFINER
  /// para que el admin pueda ver todas las apuestas sin restricción de RLS.
  Future<List<Map<String, dynamic>>> fetchEnrichedEventBets(String eventId) async {
    try {
      final response = await _supabase.rpc(
        'get_event_bets_enriched',
        params: {'p_event_id': eventId},
      );

      if (response is List) {
        return List<Map<String, dynamic>>.from(
          response.map((e) => Map<String, dynamic>.from(e)),
        );
      }
      return [];
    } catch (e) {
      debugPrint('BettingService: Error fetching enriched bets: $e');
      return [];
    }
  }
}
