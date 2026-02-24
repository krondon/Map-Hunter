import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'power_repository_interface.dart';

class PowerRepositoryImpl implements PowerRepository {
  final SupabaseClient _supabase;
  final Map<String, String> _powerIdToSlugCache = {};
  final Map<String, Duration> _powerSlugToDurationCache = {};

  PowerRepositoryImpl({required SupabaseClient supabaseClient}) 
      : _supabase = supabaseClient;

  @override
  Stream<List<Map<String, dynamic>>> getActivePowersStream({required String targetId}) {
    return _supabase
        .from('active_powers')
        .stream(primaryKey: ['id'])
        .eq('target_id', targetId);
  }

  @override
  Stream<List<Map<String, dynamic>>> getOutgoingPowersStream({required String casterId}) {
    return _supabase
        .from('active_powers')
        .stream(primaryKey: ['id'])
        .eq('caster_id', casterId);
  }

  @override
  Stream<List<Map<String, dynamic>>> getCombatEventsStream({required String targetId}) {
    return _supabase
        .from('combat_events')
        .stream(primaryKey: ['id'])
        .eq('target_id', targetId)
        .order('created_at', ascending: false)
        .order('created_at', ascending: false); // Note: Keep existing weird ordering if it was there, or clean it up.
  }

  @override
  Stream<Map<String, dynamic>?> getGamePlayerStream({required String playerId}) {
    return _supabase
        .from('game_players')
        .stream(primaryKey: ['id'])
        .eq('id', playerId)
        .map((data) => data.isNotEmpty ? data.first : null);
  }

  @override
  Future<String?> resolveEffectSlug(Map<String, dynamic> effect) async {
    final explicit = effect['power_slug'] ?? effect['slug'];
    if (explicit != null) return explicit.toString();

    final powerId = effect['power_id'];
    if (powerId == null) return null;
    final powerIdStr = powerId.toString();
    
    // Check cache
    if (_powerIdToSlugCache.containsKey(powerIdStr)) {
      return _powerIdToSlugCache[powerIdStr];
    }

    try {
      final res = await _supabase
          .from('powers')
          .select('slug')
          .eq('id', powerIdStr)
          .maybeSingle();
          
      final slug = res?['slug']?.toString();
      if (slug != null && slug.isNotEmpty) {
        _powerIdToSlugCache[powerIdStr] = slug;
      }
      return slug;
    } catch (_) {
      return null;
    }
  }

  @override
  Future<Duration> getPowerDuration({required String powerSlug}) async {
    // Check cache
    if (_powerSlugToDurationCache.containsKey(powerSlug)) {
      return _powerSlugToDurationCache[powerSlug]!;
    }

    try {
      final row = await _supabase
          .from('powers')
          .select('duration')
          .eq('slug', powerSlug)
          .maybeSingle();

      final seconds = (row?['duration'] as num?)?.toInt() ?? 0;
      final duration = seconds <= 0 ? Duration.zero : Duration(seconds: seconds);
      _powerSlugToDurationCache[powerSlug] = duration;
      return duration;
    } catch (e) {
      debugPrint('[PowerRepository] getPowerDuration($powerSlug) error: $e');
      return Duration.zero;
    }
  }

  @override
  Future<bool> validateCombatEvent({
    required String eventId,
    required String casterId,
    required String targetId,
    required String powerSlug,
  }) async {
    try {
      final res = await _supabase
          .from('combat_events')
          .select('id')
          .eq('event_id', eventId)
          .eq('caster_id', casterId)
          .eq('target_id', targetId)
          .eq('power_slug', powerSlug)
          // Ensure we only look for recent events (e.g., last 2 minutes) to prevent replay of old events
          .gt('created_at', DateTime.now().toUtc().subtract(const Duration(minutes: 2)).toIso8601String())
          .limit(1)
          .maybeSingle();

      return res != null;
    } catch (e) {
      debugPrint('[PowerRepository] validateCombatEvent error: $e');
      return false; // Fail safe
    }
  }

  @override
  Future<void> deactivateDefense({required String gamePlayerId}) async {
    try {
      final result = await _supabase.rpc('deactivate_defense', params: {
        'p_game_player_id': gamePlayerId,
      });
      debugPrint('[PowerRepository] deactivateDefense result: $result');
    } catch (e) {
      debugPrint('[PowerRepository] deactivateDefense error: $e');
    }
  }

  @override
  Future<String?> getGifterName({required String gamePlayerId}) async {
    try {
      final res = await _supabase
          .from('game_players')
          .select('user_id, profiles(name)')
          .eq('id', gamePlayerId)
          .maybeSingle();
      
      if (res == null) return null;
      
      final profile = res['profiles'] as Map<String, dynamic>?;
      return profile?['name']?.toString();
    } catch (e) {
      debugPrint('[PowerRepository] getGifterName error: $e');
      return null;
    }
  }
}
