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
      debugPrint('[LIVES_DEBUG] GameServiceRPC: lose_life params -> p_user_id: $userId, p_event_id: $eventId');
      
      // 1. Intentar por RPC
      final response = await _supabase.rpc('lose_life', params: {
        'p_user_id': userId,
        'p_event_id': eventId,
      }).catchError((e) {
          debugPrint('[LIVES_DEBUG] RPC Error caught: $e. Switching to Fallback.');
          return null; 
      });
      
      if (response != null) {
        debugPrint('[LIVES_DEBUG] GameServiceRPC: Success. Response: $response');
        return response as int;
      }
      
      // 2. FALLBACK: Actualización Directa (Si RPC falla o da null)
      debugPrint('[LIVES_DEBUG] Executing DIRECT UPDATE Fallback...');
      
      // Obtener vidas actuales para calcular nuevo valor
      final row = await _supabase.from('game_players')
          .select('lives')
          .eq('user_id', userId)
          .eq('event_id', eventId)
          .single();
          
      final int currentLives = row['lives'] as int;
      final int newLives = currentLives > 0 ? currentLives - 1 : 0;
      
      // Forzar update directo
      await _supabase.from('game_players')
          .update({'lives': newLives})
          .eq('user_id', userId)
          .eq('event_id', eventId);
          
      debugPrint('[LIVES_DEBUG] Direct Update Success. New Lives: $newLives');
      return newLives;

    } catch (e) {
      debugPrint('[LIVES_DEBUG] CRITICAL ERROR deleting life (both RPC and Direct failed): $e');
      rethrow;
    }
  }

  /// Obtiene el leaderboard de un evento y lo enriquece con datos de perfiles (Avatars)
  Future<List<Player>> getLeaderboard(String eventId) async {
    try {
      // 1. Obtener la lista base del ranking desde la VISTA
      final List<dynamic> leaderboardData = await _supabase
          .from('event_leaderboard')
          .select()
          .eq('event_id', eventId)
          .order('completed_clues', ascending: false, nullsFirst: false)
          .order('last_completion_time', ascending: true)
          .limit(50);

      if (leaderboardData.isEmpty) return [];

      // 2. Extraer todos los userIDs para traer sus perfiles ACTUALIZADOS
      final List<String> userIds = leaderboardData
          .map((e) => (e['user_id'] ?? e['id'] ?? '').toString())
          .where((id) => id.isNotEmpty)
          .toList();

      Map<String, Map<String, dynamic>> profilesMap = {};
      if (userIds.isNotEmpty) {
        final List<dynamic> profilesData = await _supabase
            .from('profiles')
            .select('id, avatar_id, avatar_url, name')
            .inFilter('id', userIds);
        
        for (var p in profilesData) {
          profilesMap[p['id']] = p;
        }
      }

      // 3. Mapear y Fusionar (Leaderboard + Profiles)
      return leaderboardData.map((json) {
        final String uid = (json['user_id'] ?? json['id'] ?? '').toString();
        
        // Normalización de IDs obligatoria
        if (json['id'] == null) json['id'] = uid;
        if (json['total_xp'] == null) json['total_xp'] = json['completed_clues'];

        // Inyectar datos del perfil si existen
        if (profilesMap.containsKey(uid)) {
          final p = profilesMap[uid]!;
          json['avatar_id'] = p['avatar_id'];
          // Si el JSON base no tiene nombre, usa el del perfil
          if (json['name'] == null || json['name'].toString().isEmpty) {
            json['name'] = p['name'];
          }
        }
        
        return Player.fromJson(json);
      }).toList();

    } catch (e) {
      debugPrint('GameService: Error in getLeaderboard (enriched): $e');
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
          .select('id, power_slug, target_id, caster_id, expires_at, created_at')
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

