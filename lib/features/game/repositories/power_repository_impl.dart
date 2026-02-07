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
        .limit(1);
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
}
