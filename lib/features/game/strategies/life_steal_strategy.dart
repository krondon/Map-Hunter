import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../providers/power_effect_provider.dart';
import 'power_strategy.dart';

class LifeStealStrategy implements PowerStrategy {
  @override
  String get slug => 'life_steal';

  @override
  void onActivate(PowerEffectProvider provider) async {
    // Contexto temporal se establece en provider antes de llamar aquí
    final effectId = provider.pendingEffectId;
    final casterId = provider.pendingCasterId;
    final myId = provider.listeningForId;
    final handler = provider.lifeStealVictimHandler;

    if (effectId != null && 
        myId != null && 
        !provider.isEffectProcessed(effectId) && 
        handler != null) {
          
      debugPrint("[DEBUG] 🩸 LIFE_STEAL detectado (Strategy):");
      debugPrint("[DEBUG]    Effect ID: $effectId");
      debugPrint("[DEBUG]    Caster ID: $casterId");

      // Feedback físico inmediato para la víctima
      HapticFeedback.heavyImpact();
      debugPrint("💔 Has sufrido Robo de Vida!");

      provider.markEffectAsProcessed(effectId);
      provider.setActiveEffectCasterId(casterId);
      
      await handler(effectId, casterId, myId);
      
      debugPrint("[DEBUG] ✅ LifeStealVictimHandler ejecutado exitosamente (Strategy)");
    }
  }

  @override
  void onTick(PowerEffectProvider provider) {}

  @override
  void onDeactivate(PowerEffectProvider provider) {
    debugPrint("LifeStealStrategy.onDeactivate");
  }
}
