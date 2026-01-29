import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/power_effect_provider.dart';
import '../../../../core/theme/app_theme.dart';

class ShieldBadge extends StatelessWidget {
  const ShieldBadge({super.key});

  @override
  Widget build(BuildContext context) {
    // Escuchar cambios en el escudo (usando nuevo patrón boolean)
    final isShieldActive = context.select<PowerEffectProvider, bool>(
      (provider) => provider.isShieldArmed,
    );

    if (!isShieldActive) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(right: 8.0),
      child: Tooltip(
        message: 'Escudo Activo: Bloqueará el próximo ataque',
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: Colors.cyan.withOpacity(0.2),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.cyanAccent.withOpacity(0.6)),
            boxShadow: [
              BoxShadow(
                color: Colors.cyanAccent.withOpacity(0.2),
                blurRadius: 8,
                spreadRadius: 2,
              )
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.shield_moon, color: Colors.cyanAccent, size: 16),
              const SizedBox(width: 4),
              // Optional: Add text label if space permits, e.g. "PROTECTED"
            ],
          ),
        ),
      ),
    );
  }
}
