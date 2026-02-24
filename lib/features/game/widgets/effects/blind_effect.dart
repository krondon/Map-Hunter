import 'package:flutter/material.dart';
import 'effect_timer.dart';

class BlindEffect extends StatelessWidget {
  final DateTime? expiresAt;
  const BlindEffect({super.key, this.expiresAt});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.black,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.visibility_off_rounded,
              color: Colors.white,
              size: 80,
              shadows: [
                Shadow(color: Colors.redAccent, blurRadius: 20),
              ],
            ),
            const SizedBox(height: 24),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.05),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.white10),
              ),
              child: const Text(
                "¡TE HAN CEGADO!",
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 26,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 2,
                  decoration: TextDecoration.none, // Quita subrayado amarillo
                ),
              ),
            ),
            if (expiresAt != null) ...[
              const SizedBox(height: 40),
              EffectTimer(expiresAt: expiresAt!),
            ],
          ],
        ),
      ),
    );
  }
}
