import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../providers/power_effect_provider.dart';
import 'power_strategy.dart';
import 'power_response.dart';

import 'spectator_helper.dart';

class GenericPowerStrategy implements PowerStrategy {
  final SupabaseClient _supabase;
  final String _slug;

  GenericPowerStrategy(this._supabase, this._slug);

  @override
  String get slug => _slug;

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

    final response = await _supabase.rpc('use_power_mechanic', params: {
      'p_caster_id': casterId,
      'p_target_id': targetId,
      'p_power_slug': slug,
    });
    return PowerUseResponse.fromRpcResponse(response);
  }

  @override
  void onActivate(PowerEffectProvider provider) {
    debugPrint("GenericPowerStrategy($slug).onActivate");
  }

  @override
  void onTick(PowerEffectProvider provider) {}

  @override
  void onDeactivate(PowerEffectProvider provider) {
    debugPrint("GenericPowerStrategy($slug).onDeactivate");
  }
}
