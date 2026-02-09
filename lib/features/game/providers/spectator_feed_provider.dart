import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class GameFeedEvent {
  final String id;
  final String playerName;
  final String action;
  final String detail;
  final DateTime timestamp;
  final String? icon;
  final String? type; // 'power', 'clue', 'life', 'join', 'shop'

  GameFeedEvent({
    required this.id,
    required this.playerName,
    required this.action,
    required this.detail,
    required this.timestamp,
    this.icon,
    this.type,
  });
}

class SpectatorFeedProvider extends ChangeNotifier {
  final SupabaseClient _supabase = Supabase.instance.client;
  final List<GameFeedEvent> _events = [];
  final String _eventId;

  RealtimeChannel? _powersSubscription;
  RealtimeChannel? _playersSubscription;
  RealtimeChannel? _purchasesSubscription;

  List<GameFeedEvent> get events => _events;

  SpectatorFeedProvider(this._eventId) {
    _init();
  }

  void _init() {
    _subscribeToPowers();
    _subscribeToPlayerProgress();
    _subscribeToPurchases();
    _fetchInitialEvents();
  }

  Future<void> _fetchInitialEvents() async {
    // Fetch recent active powers as starting events
    try {
      final powers = await _supabase
          .from('active_powers')
          .select(
              'id, power_slug, caster_id, target_id, expires_at, created_at, caster:caster_id(profiles(name)), target:target_id(profiles(name))')
          .eq('event_id', _eventId)
          .order('created_at', ascending: false)
          .limit(10);

      for (var p in powers) {
        final casterName =
            (p['caster']?['profiles'] as Map?)?['name'] ?? 'Alguien';
        final targetName =
            (p['target']?['profiles'] as Map?)?['name'] ?? 'Alguien';
        final slug = p['power_slug'] as String;

        _addEvent(
            GameFeedEvent(
              id: p['id'].toString(),
              playerName: casterName,
              action: 'USÓ UN PODER',
              detail:
                  '$casterName lanzó ${_getTranslatedPowerName(slug)} contra $targetName',
              timestamp: DateTime.parse(p['created_at']),
              type: 'power',
              icon: _getPowerIcon(slug),
            ),
            notify: false);
      }
      notifyListeners();
    } catch (e) {
      debugPrint('Error fetching initial feed: $e');
    }
  }

  void _subscribeToPowers() {
    _powersSubscription = _supabase
        .channel('public:active_powers:feed:$_eventId')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'active_powers',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'event_id',
            value: _eventId,
          ),
          callback: (payload) async {
            final record = payload.newRecord;
            final casterId = record['caster_id']?.toString();
            final targetId = record['target_id']?.toString();
            final slug = record['power_slug']?.toString() ?? 'Poder';

            // caster_id and target_id are game_player_ids, not user_ids
            final casterName = await _getPlayerNameFromGamePlayerId(casterId);
            final targetName = await _getPlayerNameFromGamePlayerId(targetId);

            _addEvent(GameFeedEvent(
              id: record['id'].toString(),
              playerName: casterName,
              action: 'USÓ UN PODER',
              detail:
                  '$casterName activó ${_getTranslatedPowerName(slug)} sobre $targetName',
              timestamp: DateTime.now(),
              type: 'power',
              icon: _getPowerIcon(slug),
            ));
          },
        )
        .subscribe();
  }

  Future<int> _calculateRank(int cluesCompleted) async {
    try {
      final res = await _supabase
          .from('game_players')
          .count()
          .eq('event_id', _eventId)
          .gt('completed_clues_count', cluesCompleted);
      return res + 1;
    } catch (_) {
      return 0;
    }
  }

  void _subscribeToPlayerProgress() {
    _playersSubscription = _supabase
        .channel('public:game_players:feed:$_eventId')
        .onPostgresChanges(
          event: PostgresChangeEvent.update,
          schema: 'public',
          table: 'game_players',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'event_id',
            value: _eventId,
          ),
          callback: (payload) async {
            final oldRecord = payload.oldRecord;
            final newRecord = payload.newRecord;

            final oldClues = oldRecord['completed_clues_count'] as int? ?? 0;
            final newClues = newRecord['completed_clues_count'] as int? ?? 0;
            final oldLives = oldRecord['lives'] as int? ?? 0;
            final newLives = newRecord['lives'] as int? ?? 0;

            if (newClues > oldClues) {
              final playerName =
                  await _getPlayerName(newRecord['user_id']?.toString());
              final rank = await _calculateRank(newClues);
              final rankStr = rank > 0 ? ' (Va $rankº)' : '';

              _addEvent(GameFeedEvent(
                id: 'clue_${newRecord['id']}_$newClues',
                playerName: playerName,
                action: '¡AVANCE DE CARRERA!',
                detail: '$playerName completó la pista #$newClues$rankStr',
                timestamp: DateTime.now(),
                type: 'clue',
                icon: '🚀',
              ));
            }

            if (newLives < oldLives) {
              final playerName =
                  await _getPlayerName(newRecord['user_id']?.toString());
              _addEvent(GameFeedEvent(
                id: 'life_${newRecord['id']}_$newLives',
                playerName: playerName,
                action: '¡DAÑO RECIBIDO!',
                detail: '$playerName perdió una vida (Le quedan $newLives)',
                timestamp: DateTime.now(),
                type: 'life',
                icon: '💔',
              ));
            }
          },
        )
        .subscribe();
  }

  void _subscribeToPurchases() {
    _purchasesSubscription = _supabase
        .channel('public:player_powers:feed:$_eventId')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'player_powers',
          callback: (payload) async {
            final record = payload.newRecord;
            final oldRecord = payload.oldRecord;

            final newQty = record['quantity'] as int? ?? 0;
            final oldQty =
                (oldRecord != null) ? (oldRecord['quantity'] as int? ?? 0) : 0;

            if (newQty > oldQty) {
              final gamePlayerId = record['game_player_id']?.toString();
              if (gamePlayerId == null) return;

              final eventIdOfGP = await _getEventOfPlayer(gamePlayerId);
              if (eventIdOfGP != _eventId) return;

              final userId = await _getUserIdOfPlayer(gamePlayerId);
              final playerName = await _getPlayerName(userId);

              final powerId = record['power_id']?.toString();
              final powerName = await _getPowerNameTranslatedFromId(powerId);

              _addEvent(GameFeedEvent(
                id: 'buy_${record['id']}_${DateTime.now().millisecondsSinceEpoch}',
                playerName: playerName,
                action: 'ADQUIRIÓ UN ITEM',
                detail: '$playerName ha comprado $powerName',
                timestamp: DateTime.now(),
                type: 'shop',
                icon: '🛍️',
              ));
            }
          },
        )
        .subscribe();
  }

  final Map<String, String> _gpEventCache = {};
  Future<String?> _getEventOfPlayer(String gamePlayerId) async {
    if (_gpEventCache.containsKey(gamePlayerId))
      return _gpEventCache[gamePlayerId];
    try {
      final res = await _supabase
          .from('game_players')
          .select('event_id')
          .eq('id', gamePlayerId)
          .maybeSingle();
      final eid = res?['event_id']?.toString();
      if (eid != null) _gpEventCache[gamePlayerId] = eid;
      return eid;
    } catch (_) {
      return null;
    }
  }

  final Map<String, String?> _gpUserCache = {};
  Future<String?> _getUserIdOfPlayer(String gamePlayerId) async {
    if (_gpUserCache.containsKey(gamePlayerId))
      return _gpUserCache[gamePlayerId];
    try {
      final res = await _supabase
          .from('game_players')
          .select('user_id')
          .eq('id', gamePlayerId)
          .maybeSingle();
      final uid = res?['user_id']?.toString();
      _gpUserCache[gamePlayerId] = uid;
      return uid;
    } catch (_) {
      return null;
    }
  }

  final Map<String, String> _powerNameCache = {};
  Future<String> _getPowerNameTranslatedFromId(String? powerId) async {
    if (powerId == null) return 'un objeto';
    if (_powerNameCache.containsKey(powerId)) return _powerNameCache[powerId]!;
    try {
      final res = await _supabase
          .from('powers')
          .select('slug, name')
          .eq('id', powerId)
          .maybeSingle();
      if (res == null) return 'un objeto';

      final slug = res['slug']?.toString();
      final dbName = res['name']?.toString() ?? 'un objeto';

      String finalName = dbName;
      if (slug != null) {
        final translated = _getTranslatedPowerName(slug);
        // Only use translation if it's one of our known Spanish terms, otherwise fallback to DB name
        if (translated != slug.toUpperCase()) {
          finalName = translated;
        }
      }

      _powerNameCache[powerId] = finalName;
      return finalName;
    } catch (_) {
      return 'un objeto';
    }
  }

  void _addEvent(GameFeedEvent event, {bool notify = true}) {
    _events.insert(0, event);
    if (_events.length > 50) _events.removeLast();
    if (notify) notifyListeners();
  }

  final Map<String, String> _nameCache = {};
  Future<String> _getPlayerName(String? userId) async {
    if (userId == null) return 'Alguien';
    if (_nameCache.containsKey(userId)) return _nameCache[userId]!;

    try {
      final res = await _supabase
          .from('profiles')
          .select('name')
          .eq('id', userId)
          .maybeSingle();
      final name = res?['name'] ?? 'Jugador';
      _nameCache[userId] = name;
      return name;
    } catch (e) {
      return 'Jugador';
    }
  }

  /// Gets player name from game_player_id by first resolving to user_id
  Future<String> _getPlayerNameFromGamePlayerId(String? gamePlayerId) async {
    if (gamePlayerId == null) return 'Alguien';

    // First get user_id from game_player_id
    final userId = await _getUserIdOfPlayer(gamePlayerId);

    // Then get name from user_id
    return await _getPlayerName(userId);
  }

  String _getPowerIcon(String slug) {
    switch (slug) {
      case 'freeze':
        return '❄️';
      case 'shield':
        return '🛡️';
      case 'invisibility':
        return '👻';
      case 'life_steal':
        return '🧛';
      case 'blur_screen':
        return '🌫️';
      case 'return':
        return '🔄';
      case 'black_screen':
        return '🕶️';
      default:
        return '⚡';
    }
  }

  String _getTranslatedPowerName(String slug) {
    switch (slug) {
      case 'freeze':
        return 'Congelar';
      case 'shield':
        return 'Escudo';
      case 'invisibility':
        return 'Invisible';
      case 'life_steal':
        return 'Robar Vida';
      case 'blur_screen':
        return 'Difuminar';
      case 'return':
        return 'Retornar';
      case 'black_screen':
        return 'Pantalla Negra';
      default:
        return slug.toUpperCase();
    }
  }

  @override
  void dispose() {
    _powersSubscription?.unsubscribe();
    _playersSubscription?.unsubscribe();
    _purchasesSubscription?.unsubscribe();
    super.dispose();
  }
}
