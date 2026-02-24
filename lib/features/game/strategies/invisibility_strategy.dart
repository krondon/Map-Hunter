import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../providers/power_effect_provider.dart';
import 'power_strategy.dart';

import 'package:supabase_flutter/supabase_flutter.dart';
import 'power_response.dart';

class InvisibilityStrategy implements PowerStrategy {
  final SupabaseClient _supabase;

  InvisibilityStrategy(this._supabase);

  @override
  String get slug => 'invisibility';

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
    debugPrint("👻 Invisibilidad activada - Eres indetectable.");
    HapticFeedback.lightImpact();
    
    // FIX: Arm invisibility in the unified defense state machine
    // This sets _isProtected=true and _activeDefenseSlug='invisibility'
    provider.armInvisibility();
  }

  @override
  void onTick(PowerEffectProvider provider) {}

  @override
  void onDeactivate(PowerEffectProvider provider) {
     debugPrint("InvisibilityStrategy.onDeactivate");
  }
}
