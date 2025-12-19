import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../features/game/providers/power_effect_provider.dart';
import '../../../features/game/widgets/effects/blind_effect.dart';
import '../../../features/game/widgets/effects/freeze_effect.dart';
import '../../../features/game/widgets/effects/slow_motion_effect.dart';

class SabotageOverlay extends StatelessWidget {
  final Widget child;
  const SabotageOverlay({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    final powerProvider = Provider.of<PowerEffectProvider>(context);
    final activeSlug = powerProvider.activePowerSlug;

    return Stack(
      children: [
        child, // El juego base siempre debajo
        
        // Capas de sabotaje (se activan según el slug recibido de la DB)
        if (activeSlug == 'black_screen') const BlindEffect(),
        if (activeSlug == 'freeze') const FreezeEffect(),
        if (activeSlug == 'slow_motion') const SlowMotionEffect(),
      ],
    );
  }
}