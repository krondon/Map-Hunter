import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../providers/power_effect_provider.dart';
import 'power_strategy.dart';

class ShieldStrategy implements PowerStrategy {
  @override
  String get slug => 'shield';

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
    provider.notifyListeners();
  }
}
