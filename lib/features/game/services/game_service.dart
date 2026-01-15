import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/clue.dart';
import '../models/power_effect.dart';
import '../../../shared/models/player.dart';

class GameService {
  final SupabaseClient _supabase;

  GameService(this._supabase);

  /// Obtiene las vidas de un jugador en un evento específico.
  /// Retorna el número de vidas o null si falla.
  Future<int?> fetchLives(String eventId, String userId) async {
    try {
      final response = await _supabase
          .from('game_players')
          .select('lives')
          .eq('event_id', eventId)
          .eq('user_id', userId)
          .maybeSingle();
      
      if (response != null && response['lives'] != null) {
        return response['lives'] as int;
      }
      return null;
    } catch (e) {
      debugPrint('Error fetching lives: $e');
      rethrow;
    }
  }

  /// Ejecuta la lógica de perder una vida en el servidor.
  /// Retorna el nuevo número de vidas confirmadas por el servidor.
  Future<int> loseLife(String eventId, String userId) async {
    try {
      final response = await _supabase.rpc('lose_life', params: {
        'p_user_id': userId,
        'p_event_id': eventId,
      });
      
      if (response != null) {
        return response as int;
      }
      throw Exception('Failed to lose life: null response');
    } catch (e) {
      debugPrint('Error perdiendo vida: $e');
      rethrow;
    }
  }

  /// Obtiene el leaderboard de un evento desde la vista o función fallback.
  Future<List<Player>> getLeaderboard(String eventId) async {
    try {
      // ✅ Consultamos la VISTA
      final List<dynamic> data = await _supabase
          .from('event_leaderboard')
          .select()
          .eq('event_id', eventId)
          .order('completed_clues', ascending: false)
          .order('last_completion_time', ascending: true)
          .limit(50);

      return data.map((json) {
        // Normalización de IDs
        if (json['id'] == null && json['user_id'] != null) {
          json['id'] = json['user_id'];
        } else if (json['id'] == null && json['player_id'] != null) {
          json['id'] = json['player_id'];
        }
        
        // Mapeo necesario para compatibilidad
        if (json['completed_clues'] != null) {
          json['total_xp'] = json['completed_clues'];
        }
        
        return Player.fromJson(json);
      }).toList();
    } catch (e) {
      debugPrint('Error fetching leaderboard: $e');
      // Intentar fallback si falla la vista
      return _getLeaderboardFallback(eventId);
    }
  }

  Future<List<Player>> _getLeaderboardFallback(String eventId) async {
    try {
      final response = await _supabase.functions.invoke(
        'game-play/get-leaderboard',
        body: {'eventId': eventId},
        method: HttpMethod.post,
      );

      if (response.status == 200) {
        final List<dynamic> data = response.data;
        return data.map((json) => Player.fromJson(json)).toList();
      }
      return [];
    } catch (e) {
      debugPrint('Error fallback leaderboard: $e');
      return [];
    }
  }

  /// Suscribe a los cambios de estado de la carrera.
  /// Retorna el canal de suscripción.
  RealtimeChannel subscribeToRaceStatus(
    String eventId, 
    int totalClues,
    Function(bool isCompleted, String source) onRaceCompleted
  ) {
    return _supabase
        .channel('public:race:$eventId')
        // 1. Escuchar cambios en jugadores (Progreso individual)
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'game_players',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'event_id',
            value: eventId,
          ),
          callback: (payload) {
            final newRecord = payload.newRecord;
            if (totalClues > 0) {
              final int completed = newRecord['completed_clues_count'] ?? newRecord['completed_clues'] ?? 0;
              if (completed >= totalClues) {
                onRaceCompleted(true, 'Realtime Subscription');
              }
            }
          },
        )
        // 2. Escuchar cambios en el evento (Finalización Global)
        .onPostgresChanges(
          event: PostgresChangeEvent.update,
          schema: 'public',
          table: 'events',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'id',
            value: eventId,
          ),
          callback: (payload) {
            final newRecord = payload.newRecord;
            if (newRecord['status'] == 'completed') {
               onRaceCompleted(true, 'Realtime Event Status');
            }
          },
        )
        .subscribe();
  }

  /// Obtiene las pistas de un evento.
  Future<List<Clue>> getClues(String eventId) async {
    try {
      final response = await _supabase.functions.invoke(
        'game-play/get-clues', 
        body: {'eventId': eventId},
        method: HttpMethod.post,
      );
      
      if (response.status == 200) {
        final List<dynamic> data = response.data;
        return data.map((json) => Clue.fromJson(json)).toList();
      }
      throw Exception('Failed to fetch clues: ${response.status}');
    } catch (e) {
      debugPrint('Error fetching clues: $e');
      rethrow;
    }
  }

  /// Inicia el juego para un evento.
  Future<void> startGame(String eventId) async {
    try {
      final response = await _supabase.functions.invoke('game-play/start-game', 
        body: {'eventId': eventId},
        method: HttpMethod.post
      );
      
      if (response.status != 200) {
        throw Exception('Failed to start game: ${response.status}');
      }
    } catch (e) {
      debugPrint('Error starting game: $e');
      rethrow;
    }
  }

  /// Completa una pista.
  /// Retorna un mapa con el resultado, incluyendo si la carrera se completó.
  Future<Map<String, dynamic>?> completeClue(String clueId, String answer) async {
    try {
      final response = await _supabase.functions.invoke('game-play/complete-clue', 
        body: {
          'clueId': clueId, 
          'answer': answer,
        },
        method: HttpMethod.post
      );
      
      if (response.status == 200) {
        return response.data as Map<String, dynamic>?;
      }
      return null;
    } catch (e) {
      debugPrint('Error completing clue: $e');
      return null;
    }
  }

  /// Salta una pista.
  Future<bool> skipClue(String clueId) async {
    try {
      final response = await _supabase.functions.invoke('game-play/skip-clue', 
        body: {
          'clueId': clueId,
        },
        method: HttpMethod.post
      );
      
      return response.status == 200;
    } catch (e) {
      debugPrint('Error skipping clue: $e');
      return false;
    }
  }

  /// Verifica el estado de la carrera en el servidor.
  Future<bool> checkRaceStatus(String eventId) async {
    try {
      final response = await _supabase.functions.invoke(
        'game-play/check-race-status',
        body: {'eventId': eventId},
        method: HttpMethod.post,
      );
      
      if (response.status == 200) {
        final data = response.data as Map<String, dynamic>?;
        if (data != null) {
          return data['isCompleted'] ?? false;
        }
      }
      return false;
    } catch (e) {
      debugPrint('Error checking race status: $e');
      return false;
    }
  }

  /// Obtiene los poderes activos en el evento.
  Future<List<PowerEffect>> getActivePowers(String eventId) async {
    try {
      final response = await _supabase
          .from('active_powers')
          .select('id, slug, power_slug, target_id, caster_id, expires_at, created_at')
          .eq('event_id', eventId)
          .gt('expires_at', DateTime.now().toUtc().toIso8601String());

      final List<dynamic> data = response as List<dynamic>;
      return data.map((e) => PowerEffect.fromMap(e)).toList();
    } catch (e) {
      debugPrint('Error fetching active powers: $e');
      return [];
    }
  }

  // ============================================================
  // GATEKEEPER: User Event Status Methods
  // ============================================================

  /// Verifica si el usuario está baneado.
  /// Retorna true si el usuario está baneado (status = 'banned').
  Future<bool> checkBannedStatus(String userId) async {
    try {
      final response = await _supabase
          .from('profiles')
          .select('status')
          .eq('id', userId)
          .maybeSingle();

      if (response != null) {
        final String? status = response['status'];
        return status == 'banned';
      }
      return false;
    } catch (e) {
      debugPrint('GameService: Error checking banned status: $e');
      return false;
    }
  }

  /// Obtiene el game_player activo más reciente para un usuario.
  /// Retorna un Map con {id, event_id, lives} o null si no existe.
  Future<Map<String, dynamic>?> getActiveGamePlayer(String userId) async {
    try {
      final response = await _supabase
          .from('game_players')
          .select('id, event_id, lives, completed_clues_count')
          .eq('user_id', userId)
          .order('joined_at', ascending: false)
          .limit(1)
          .maybeSingle();

      return response;
    } catch (e) {
      debugPrint('GameService: Error getting active game player: $e');
      return null;
    }
  }

  /// Obtiene la solicitud de juego más reciente para un usuario.
  /// Retorna un Map con {id, event_id, status} o null si no existe.
  Future<Map<String, dynamic>?> getLatestGameRequest(String userId) async {
    try {
      final response = await _supabase
          .from('game_requests')
          .select('id, event_id, status')
          .eq('user_id', userId)
          .order('created_at', ascending: false)
          .limit(1)
          .maybeSingle();

      return response;
    } catch (e) {
      debugPrint('GameService: Error getting latest game request: $e');
      return null;
    }
  }

  /// Inicializa el juego para un usuario aprobado.
  /// Llama al RPC initialize_game_for_user.
  Future<bool> initializeGameForUser(String userId, String eventId) async {
    try {
      await _supabase.rpc('initialize_game_for_user', params: {
        'target_user_id': userId,
        'target_event_id': eventId,
      });
      debugPrint('GameService: Game initialized for user $userId in event $eventId');
      return true;
    } catch (e) {
      debugPrint('GameService: Error initializing game for user: $e');
      return false;
    }
  }

  /// Verifica si un usuario ya es un game_player para un evento específico.
  Future<bool> isUserGamePlayer(String userId, String eventId) async {
    try {
      final response = await _supabase
          .from('game_players')
          .select('id')
          .eq('user_id', userId)
          .eq('event_id', eventId)
          .maybeSingle();

      return response != null;
    } catch (e) {
      debugPrint('GameService: Error checking if user is game player: $e');
      return false;
    }
  }
}

