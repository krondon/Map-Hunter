import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../shared/models/player.dart';

/// Race state for spectator/player consumption.
class RaceState {
  final bool isCompleted;
  final String? winnerId;
  final String? winnerName;
  final List<Player> leaderboard;
  final int totalClues;
  final DateTime timestamp;

  const RaceState({
    required this.isCompleted,
    this.winnerId,
    this.winnerName,
    required this.leaderboard,
    required this.totalClues,
    required this.timestamp,
  });

  factory RaceState.initial() => RaceState(
    isCompleted: false,
    leaderboard: [],
    totalClues: 0,
    timestamp: DateTime.now(),
  );

  RaceState copyWith({
    bool? isCompleted,
    String? winnerId,
    String? winnerName,
    List<Player>? leaderboard,
    int? totalClues,
  }) => RaceState(
    isCompleted: isCompleted ?? this.isCompleted,
    winnerId: winnerId ?? this.winnerId,
    winnerName: winnerName ?? this.winnerName,
    leaderboard: leaderboard ?? this.leaderboard,
    totalClues: totalClues ?? this.totalClues,
    timestamp: DateTime.now(),
  );
}

/// Service for streaming race state to players and spectators.
/// 
/// Extracted from GameProvider to enable spectator mode.
/// Exposes a reactive Stream that both players and spectators can subscribe to.
class GameStreamService {
  final SupabaseClient _client;
  
  RealtimeChannel? _raceChannel;
  Timer? _leaderboardTimer;
  
  final _raceStateController = StreamController<RaceState>.broadcast();
  RaceState _currentState = RaceState.initial();
  String? _currentEventId;

  GameStreamService({SupabaseClient? client})
      : _client = client ?? Supabase.instance.client;

  /// Stream of race state updates.
  /// Spectators and players can both subscribe to this.
  Stream<RaceState> get raceStateStream => _raceStateController.stream;

  /// Current race state (for initial sync).
  RaceState get currentState => _currentState;

  /// Current event ID being tracked.
  String? get currentEventId => _currentEventId;

  /// Start tracking a race.
  Future<void> startTracking({
    required String eventId,
    required int totalClues,
  }) async {
    if (_currentEventId == eventId) return;

    // Cleanup previous
    await stopTracking();

    _currentEventId = eventId;
    _currentState = RaceState.initial().copyWith(totalClues: totalClues);
    _emitState();

    debugPrint('[GameStreamService] Starting tracking for event $eventId');

    // Subscribe to realtime race updates
    _subscribeToRaceStatus(eventId, totalClues);

    // Start leaderboard polling
    _startLeaderboardPolling(eventId, totalClues);

    // Initial fetch
    await _fetchLeaderboard(eventId, totalClues);
  }

  /// Stop tracking and clean up resources.
  Future<void> stopTracking() async {
    _leaderboardTimer?.cancel();
    _leaderboardTimer = null;
    
    await _raceChannel?.unsubscribe();
    _raceChannel = null;
    
    _currentEventId = null;
    debugPrint('[GameStreamService] Stopped tracking');
  }

  /// Force refresh leaderboard.
  Future<void> refreshLeaderboard() async {
    if (_currentEventId == null) return;
    await _fetchLeaderboard(_currentEventId!, _currentState.totalClues);
  }

  /// Dispose the service.
  void dispose() {
    stopTracking();
    _raceStateController.close();
  }

  // --- Private Methods ---

  void _subscribeToRaceStatus(String eventId, int totalClues) {
    _raceChannel = _client
        .channel('race_status:$eventId')
        .onPostgresChanges(
          event: PostgresChangeEvent.update,
          schema: 'public',
          table: 'game_players',
          callback: (payload) {
            final record = payload.newRecord;
            final completedClues = record['clues_completed'] as int? ?? 0;
            
            if (completedClues >= totalClues && totalClues > 0) {
              final winnerId = record['user_id']?.toString();
              _currentState = _currentState.copyWith(
                isCompleted: true,
                winnerId: winnerId,
              );
              _emitState();
              debugPrint('[GameStreamService] Race completed! Winner: $winnerId');
            }
          },
        )
        .subscribe();
  }

  void _startLeaderboardPolling(String eventId, int totalClues) {
    _leaderboardTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      _fetchLeaderboard(eventId, totalClues);
    });
  }

  Future<void> _fetchLeaderboard(String eventId, int totalClues) async {
    try {
      final response = await _client
          .from('game_players')
          .select('id, user_id, clues_completed, lives, profiles(name, avatar_id)')
          .eq('event_id', eventId)
          .order('clues_completed', ascending: false)
          .order('created_at', ascending: true);

      final players = <Player>[];
      bool raceCompleted = false;
      String? winnerId;
      String? winnerName;

      for (final row in response as List) {
        final profile = row['profiles'] as Map<String, dynamic>?;
        final completedClues = row['clues_completed'] as int? ?? 0;
        
        final player = Player(
          userId: row['user_id']?.toString() ?? '',
          name: profile?['name']?.toString() ?? 'Jugador Desconocido',
          email: '', // Not needed for leaderboard
          avatarId: profile?['avatar_id']?.toString(),
          totalXP: completedClues,
          lives: row['lives'] as int? ?? 0,
          gamePlayerId: row['id']?.toString(),
        );
        players.add(player);

        // Check for winner
        if (completedClues >= totalClues && totalClues > 0 && !raceCompleted) {
          raceCompleted = true;
          winnerId = player.userId;
          winnerName = player.name;
        }
      }

      _currentState = _currentState.copyWith(
        leaderboard: players,
        isCompleted: raceCompleted,
        winnerId: winnerId,
        winnerName: winnerName,
      );
      _emitState();

    } catch (e) {
      debugPrint('[GameStreamService] Error fetching leaderboard: $e');
    }
  }

  void _emitState() {
    if (!_raceStateController.isClosed) {
      _raceStateController.add(_currentState);
    }
  }
}
