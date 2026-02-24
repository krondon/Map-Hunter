import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../providers/power_effect_provider.dart';
import 'power_strategy.dart';
import 'power_response.dart';

class ReturnStrategy implements PowerStrategy {
  final SupabaseClient _supabase;

  ReturnStrategy(this._supabase);

  @override
  String get slug => 'return';

  @override
  Future<PowerUseResponse> execute({
    required String casterId,
    required String targetId,
    List<RivalInfo>? rivals,
    String? eventId,
    bool isSpectator = false,
  }) async {
    final response = await _supabase.rpc('use_power_mechanic', params: {
      'p_caster_id': casterId,
      'p_target_id': targetId, // Fix: Target the intended recipient (Self or Other)
      'p_power_slug': slug,
    });
    return PowerUseResponse.fromRpcResponse(response);
  }

  @override
  void onActivate(PowerEffectProvider provider) {
    debugPrint("↩️ Return activado - Tu próximo ataque será reflejado");
    HapticFeedback.mediumImpact();
    provider.armReturn();
  }

  @override
  void onTick(PowerEffectProvider provider) {}

  @override
  void onDeactivate(PowerEffectProvider provider) {
    debugPrint("ReturnStrategy.onDeactivate");
  }
}
