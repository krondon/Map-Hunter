import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../providers/power_effect_provider.dart';
import 'power_strategy.dart';

import 'package:supabase_flutter/supabase_flutter.dart';
import 'power_response.dart';

class ShieldStrategy implements PowerStrategy {
  final SupabaseClient _supabase;

  ShieldStrategy(this._supabase);

  @override
  String get slug => 'shield';

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
    debugPrint("🛡️ Escudo desplegado - Armando defensa de un solo uso");
    HapticFeedback.mediumImpact();

    // REFACTOR: Shield now uses boolean flag pattern like Return.
    // Single-use defense that consumes on first incoming attack.
    provider.armShield();
  }

  @override
  void onTick(PowerEffectProvider provider) {
    // Escudo no tiene tick específico, es un estado pasivo
  }

  @override
  void onDeactivate(PowerEffectProvider provider) {
    debugPrint("ShieldStrategy.onDeactivate");
    // No necesitamos setear state false explicitamente, el timer en provider lo remueve.
  }
}
