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
      debugPrint(
          '[LIVES_DEBUG] GameServiceRPC: lose_life params -> p_user_id: $userId, p_event_id: $eventId');

      // 1. Intentar por RPC
      final response = await _supabase.rpc('lose_life', params: {
        'p_user_id': userId,
        'p_event_id': eventId,
      }).catchError((e) {
        debugPrint(
            '[LIVES_DEBUG] RPC Error caught: $e. Switching to Fallback.');
        return null;
      });

      if (response != null) {
        debugPrint(
            '[LIVES_DEBUG] GameServiceRPC: Success. Response: $response');
        return response as int;
      }

      // 2. FALLBACK: Actualización Directa (Si RPC falla o da null)
      debugPrint('[LIVES_DEBUG] Executing DIRECT UPDATE Fallback...');

      // Obtener vidas actuales para calcular nuevo valor
      final row = await _supabase
          .from('game_players')
          .select('lives')
          .eq('user_id', userId)
          .eq('event_id', eventId)
          .single();

      final int currentLives = row['lives'] as int;
      final int newLives = currentLives > 0 ? currentLives - 1 : 0;

      // Forzar update directo
      await _supabase
          .from('game_players')
          .update({'lives': newLives})
          .eq('user_id', userId)
          .eq('event_id', eventId);

      debugPrint('[LIVES_DEBUG] Direct Update Success. New Lives: $newLives');
      return newLives;
    } catch (e) {
      debugPrint(
          '[LIVES_DEBUG] CRITICAL ERROR deleting life (both RPC and Direct failed): $e');
      rethrow;
    }
  }

  /// Obtiene el leaderboard de un evento y lo enriquece con datos de perfiles (Avatars)
  Future<List<Player>> getLeaderboard(String eventId) async {
    try {
      // 1. Obtener la lista base del ranking desde la tabla game_players (reemplaza vista faltante)
      final List<dynamic> leaderboardData = await _supabase
          .from('game_players')
          .select('user_id, completed_clues:completed_clues_count')
          .eq('event_id', eventId)
          .neq('status', 'spectator') // Excluir espectadores
          .order('completed_clues_count', ascending: false)
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
        if (json['total_xp'] == null)
          json['total_xp'] = json['completed_clues'];

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
    Function(bool isCompleted, String source) onRaceCompleted,
    {VoidCallback? onProgressUpdate} // Nuevo callback opcional para actualizaciones
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
            // Notificar que hubo progreso (para refrescar UI)
            if (onProgressUpdate != null) {
              onProgressUpdate();
            }

            final newRecord = payload.newRecord;
            if (totalClues > 0) {
              final int completed = newRecord['completed_clues_count'] ??
                  newRecord['completed_clues'] ??
                  0;
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
          body: {'eventId': eventId}, method: HttpMethod.post);

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
  Future<Map<String, dynamic>?> completeClue(String clueId, String answer,
      {String? eventId}) async {
    try {
      final response =
          await _supabase.functions.invoke('game-play/complete-clue',
              body: {
                'clueId': clueId,
                'answer': answer,
              },
              method: HttpMethod.post);

      if (response.status == 200) {
        final data = response.data as Map<String, dynamic>?;

        // AUTO-DISTRIBUTE PRIZES IF RACE COMPLETED
        if (data != null && data['raceCompleted'] == true) {
          print("🏁 Race Completed by Winner! Attempting auto-distribution...");

          // Use provided eventId, fallback to response, then null
          final eventIdToUse = eventId ?? data['eventId'];
          final prize = await _attemptAutoDistribution(eventIdToUse);

          if (prize > 0) {
            // Inject prize into response so UI knows
            final newData = Map<String, dynamic>.from(data);
            newData['prizeAmount'] = prize;
            return newData;
          }
        }

        return data;
      }
      return null;
    } catch (e) {
      debugPrint('Error completing clue: $e');
      return null;
    }
  }

  /// Intento de distribución automática de premios.
  /// Retorna la cantidad ganada por el usuario actual (si alguna).
  Future<int> _attemptAutoDistribution(String? eventId) async {
    debugPrint("🏆 _attemptAutoDistribution CALLED with eventId: $eventId");

    if (eventId == null) {
      debugPrint("❌ eventId is NULL - aborting distribution");
      return 0;
    }

    int myPrize = 0;

    try {
      debugPrint("🏆 Auto-Distribution STARTED for event: $eventId");

      // 1. Obtener Entry Fee
      debugPrint("🏆 Fetching entry fee...");
      final eventResponse = await _supabase
          .from('events')
          .select('entry_fee')
          .eq('id', eventId)
          .single();
      final int entryFee = eventResponse['entry_fee'] ?? 0;
      debugPrint("🏆 Entry Fee: $entryFee");

      // 2. Contar Participantes (Active + Banned/Suspended/Eliminated)
      // Usamos RPC para saltar RLS y obtener conteo real
      int count = 0;
      try {
        count = await _supabase.rpc('get_event_participants_count',
            params: {'target_event_id': eventId});
      } catch (e) {
        debugPrint(
            "⚠️ RPC get_event_participants_count failed: $e. Using fallback.");
        count = await _supabase
            .from('game_players')
            .count(CountOption.exact)
            .eq('event_id', eventId)
            .inFilter('status',
                ['active', 'completed', 'banned', 'suspended', 'eliminated']);
      }

      debugPrint("🏆 Participants Count (RPC): $count");

      // 3. Calcular Bote (70%)
      final double totalCollection = (count * entryFee).toDouble();
      final double totalPot = totalCollection * 0.70;
      debugPrint("🏆 Total Pot: $totalPot");

      if (totalPot <= 0) {
        debugPrint("🏆 Pot is 0. Aborting.");
        return 0;
      }

      // 4. Obtener Leaderboard
      // Necesitamos el leaderboard actualizado.
      final List<dynamic> leaderboardResponse = await _supabase
          .from('game_players')
          .select(
              'user_id, status, completed_clues_count, finish_time, profiles(name, avatar_id, avatar_url)')
          .eq('event_id', eventId)
          .inFilter(
              'status', ['active', 'completed']) // CRÍTICO: Incluir 'completed'
          .order('completed_clues_count', ascending: false)
          .order('finish_time', ascending: true) // Desempate por tiempo
          .limit(3);

      debugPrint(
          "🏆 Leaderboard Candidates Found: ${leaderboardResponse.length}");

      if (leaderboardResponse.isEmpty) return 0;

      // 5. Determinar Tiers
      double p1Share = 0.0;
      double p2Share = 0.0;
      double p3Share = 0.0;

      if (count < 5) {
        p1Share = 1.00;
        debugPrint("🏆 Tier 1 (<5 participants)");
      } else if (count < 10) {
        p1Share = 0.70;
        p2Share = 0.30;
        debugPrint("🏆 Tier 2 (5-9 participants)");
      } else {
        p1Share = 0.50;
        p2Share = 0.30;
        p3Share = 0.20;
        debugPrint("🏆 Tier 3 (10+ participants)");
      }

      final myUserId = _supabase.auth.currentUser?.id;
      debugPrint("🏆 My User ID: $myUserId");

      // 6. Distribuir (Intentar premiar a todos, capturando errores individuales)

      // 1er Lugar
      if (leaderboardResponse.isNotEmpty && p1Share > 0) {
        final p1 = leaderboardResponse[0];
        final amount = (totalPot * p1Share).round();
        final userId = p1['user_id'];
        debugPrint(
            "🏆 1st Place: $userId (Amount: $amount). Status: ${p1['status']}");

        if (userId == myUserId) {
          myPrize = amount;
          debugPrint("✅ 1st Place is ME!");
        }

        await _addToWalletSafe(
          userId,
          amount,
          eventId: eventId,
          position: 1,
          potTotal: totalPot,
          participantsCount: count,
          entryFee: entryFee,
        );
      }

      // 2do Lugar
      if (leaderboardResponse.length > 1 && p2Share > 0) {
        final p2 = leaderboardResponse[1];
        final amount = (totalPot * p2Share).round();
        final userId = p2['user_id'];
        debugPrint("🏆 2nd Place: $userId (Amount: $amount)");

        if (userId == myUserId) myPrize = amount;
        await _addToWalletSafe(
          userId,
          amount,
          eventId: eventId,
          position: 2,
          potTotal: totalPot,
          participantsCount: count,
          entryFee: entryFee,
        );
      }

      // 3er Lugar
      if (leaderboardResponse.length > 2 && p3Share > 0) {
        final p3 = leaderboardResponse[2];
        final amount = (totalPot * p3Share).round();
        final userId = p3['user_id'];
        debugPrint("🏆 3rd Place: $userId (Amount: $amount)");

        if (userId == myUserId) myPrize = amount;
        await _addToWalletSafe(
          userId,
          amount,
          eventId: eventId,
          position: 3,
          potTotal: totalPot,
          participantsCount: count,
          entryFee: entryFee,
        );
      }

      // Marcar evento como completado
      await _supabase.from('events').update({
        'status': 'completed',
        'completed_at': DateTime.now().toIso8601String()
      }).eq('id', eventId);

      debugPrint("🏆 Auto-Distribution Completed. My Prize Won: $myPrize");
    } catch (e) {
      debugPrint("⚠️ Auto-Distribution Logic Error: $e");
    }
    return myPrize;
  }

  /// Helper seguro para añadir saldo (RPC para saltar RLS).
  /// Registra la distribución en prize_distributions para auditoría.
  Future<void> _addToWalletSafe(
    String userId,
    int amount, {
    required String eventId,
    required int position,
    required double potTotal,
    required int participantsCount,
    required int entryFee,
  }) async {
    bool rpcSuccess = false;
    String? errorMsg;

    try {
      debugPrint(
          "💰 RPC: Awarding $amount to $userId (Position: $position)...");

      // Call RPC to add clovers
      await _supabase.rpc('add_clovers',
          params: {'target_user_id': userId, 'amount': amount});

      debugPrint("✅ RPC Success.");
      rpcSuccess = true;
    } catch (e) {
      debugPrint("❌ RPC Failed: $e");
      errorMsg = e.toString();

      // Fallback: Direct update (will likely fail if not self or RLS blocks)
      try {
        debugPrint("💰 Fallback: Direct update...");
        final res = await _supabase
            .from('profiles')
            .select('clovers')
            .eq('id', userId)
            .single();
        final current = res['clovers'] ?? 0;
        await _supabase
            .from('profiles')
            .update({'clovers': current + amount}).eq('id', userId);
        debugPrint("✅ Fallback Success.");
        rpcSuccess = true;
        errorMsg = null;
      } catch (e2) {
        debugPrint("❌ Fallback Failed: $e2");
        errorMsg = "RPC: $e, Fallback: $e2";
      }
    }

    // ALWAYS record the distribution attempt in database for auditing
    try {
      await _supabase.from('prize_distributions').insert({
        'event_id': eventId,
        'user_id': userId,
        'position': position,
        'amount': amount,
        'pot_total': potTotal,
        'participants_count': participantsCount,
        'entry_fee': entryFee,
        'rpc_success': rpcSuccess,
        'error_message': errorMsg,
      });
      debugPrint("📝 Prize distribution recorded in database.");
    } catch (e) {
      debugPrint("⚠️ Failed to record distribution: $e");
      // Non-fatal - prize was already awarded (or attempted)
    }
  }

  /// Salta una pista.
  Future<bool> skipClue(String clueId) async {
    try {
      final response = await _supabase.functions.invoke('game-play/skip-clue',
          body: {
            'clueId': clueId,
          },
          method: HttpMethod.post);

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
          .select(
              'id, power_slug, target_id, caster_id, expires_at, created_at')
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
      debugPrint(
          'GameService: Game initialized for user $userId in event $eventId');
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
