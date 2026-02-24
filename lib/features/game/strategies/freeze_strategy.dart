import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../providers/power_effect_provider.dart';
import 'power_strategy.dart';
import 'power_response.dart';
import 'spectator_helper.dart';

class FreezeStrategy implements PowerStrategy {
  final SupabaseClient _supabase;

  FreezeStrategy(this._supabase);

  @override
  String get slug => 'freeze';

  @override
  Future<PowerUseResponse> execute({
    required String casterId,
    required String targetId,
    List<RivalInfo>? rivals,
    String? eventId,
    bool isSpectator = false,
  }) async {
    // Unified execution: All users (players & spectators) go through RPC
    // to ensure consistent validation and side-effects (e.g. shielding).

    // Freeze logic via RPC
    final response = await _supabase.rpc('use_power_mechanic', params: {
      'p_caster_id': casterId,
      'p_target_id': targetId,
      'p_power_slug': slug,
    });
    
    return PowerUseResponse.fromRpcResponse(response);
  }

  @override
  void onActivate(PowerEffectProvider provider) {
    debugPrint("FreezeStrategy.onActivate");
    // Freeze logic (Overlay) is handled by UI observing the slug.
  }

  @override
  void onTick(PowerEffectProvider provider) {}

  @override
  void onDeactivate(PowerEffectProvider provider) {
    debugPrint("FreezeStrategy.onDeactivate");
  }
}
