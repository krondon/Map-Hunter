import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'power_response.dart';

class SpectatorHelper {
  static Future<PowerUseResponse> executeSpectatorPower({
    required SupabaseClient supabase,
    required String casterId,
    required String targetId,
    required String powerSlug,
    String? eventId,
  }) async {
    debugPrint('SpectatorHelper: ⚠️ DEPRECATED CALL. Use RPC instead. 👻 Spectator Sabotage: $powerSlug against $targetId');

    try {
      // 1. Check/Decrement Ammo
      final paid = await _decrementPowerBySlug(supabase, powerSlug, casterId);
      if (!paid) {
        return PowerUseResponse.error('No tienes munición para este sabotaje');
      }

      // 2. Insert effect directly
      final now = DateTime.now().toUtc();
      final duration = await _getPowerDuration(supabase, powerSlug);
      final expiresAt = now.add(duration).toIso8601String();

      final powerRes = await supabase
          .from('powers')
          .select('id')
          .eq('slug', powerSlug)
          .maybeSingle();

      if (powerRes != null) {
        await supabase.from('active_powers').insert({
          'target_id': targetId,
          'caster_id': casterId,
          'power_id': powerRes['id'],
          'power_slug': powerSlug,
          'expires_at': expiresAt,
          if (eventId != null) 'event_id': eventId,
        });
        return PowerUseResponse.success();
      } else {
        return PowerUseResponse.error('Poder no encontrado');
      }
    } catch (e) {
      debugPrint('SpectatorHelper error: $e');
      return PowerUseResponse.error('Error ejecutando sabotaje');
    }
  }

  static Future<bool> _decrementPowerBySlug(
      SupabaseClient supabase, String powerSlug, String gamePlayerId) async {
    final powerRes = await supabase
        .from('powers')
        .select('id')
        .eq('slug', powerSlug)
        .maybeSingle();

    if (powerRes == null || powerRes['id'] == null) return false;
    final String powerId = powerRes['id'];

    final existing = await supabase
        .from('player_powers')
        .select('id, quantity')
        .eq('game_player_id', gamePlayerId)
        .eq('power_id', powerId)
        .maybeSingle();

    if (existing == null) return false;
    final int currentQty = (existing['quantity'] as num?)?.toInt() ?? 0;
    if (currentQty <= 0) return false;

    final updated = await supabase
        .from('player_powers')
        .update({'quantity': currentQty - 1})
        .eq('id', existing['id'])
        .eq('quantity', currentQty) // Optimistic Lock
        .select();

    return updated.isNotEmpty;
  }

  static Future<Duration> _getPowerDuration(
      SupabaseClient supabase, String powerSlug) async {
    final row = await supabase
        .from('powers')
        .select('duration')
        .eq('slug', powerSlug)
        .maybeSingle();

    final seconds = (row?['duration'] as num?)?.toInt() ?? 0;
    return seconds <= 0 ? Duration.zero : Duration(seconds: seconds);
  }
}
