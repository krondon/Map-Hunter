import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../core/theme/app_theme.dart';
import '../../providers/game_provider.dart';

class GameOverOverlay extends StatelessWidget {
  final String title;
  final String message;
  final VoidCallback? onRetry;
  final VoidCallback? onGoToShop;
  final VoidCallback onExit;
  final bool isVictory;

  const GameOverOverlay({
    super.key,
    required this.title,
    required this.message,
    this.onRetry,
    this.onGoToShop,
    required this.onExit,
    this.isVictory = false,
    this.bannerUrl,
  });

  final String? bannerUrl;

  @override
  Widget build(BuildContext context) {
    // 2. Implementación del Bloqueo de Interfaz (UI Hardening)
    // El Container con color bloquea los toques al fondo, pero permite interacción con los botones hijos.
    return Positioned.fill(
      child: Container(
        color: Colors.black87, // Barrier color
        child: Center(
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 30),
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: AppTheme.cardBg,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: isVictory ? AppTheme.successGreen : AppTheme.dangerRed,
                width: 2,
              ),
              boxShadow: [
                BoxShadow(
                  color:
                      (isVictory ? AppTheme.successGreen : AppTheme.dangerRed)
                          .withOpacity(0.3),
                  blurRadius: 20,
                  spreadRadius: 5,
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (bannerUrl != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.network(
                        bannerUrl!,
                        height: 60,
                        width: double.infinity,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => const SizedBox(),
                      ),
                    ),
                  ),

                Icon(
                  isVictory
                      ? Icons.emoji_events
                      : Icons.sentiment_very_dissatisfied,
                  size: 60,
                  color: isVictory ? AppTheme.successGreen : AppTheme.dangerRed,
                ),
                const SizedBox(height: 16),
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color:
                        isVictory ? AppTheme.successGreen : AppTheme.dangerRed,
                    letterSpacing: 1.5,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
                Text(
                  message,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),

                // Lives info wrapper if retrying
                // (Lives info removed to prevent overflow and redundancy)

                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    // Exit Button
                    Expanded(
                      child: OutlinedButton(
                        onPressed: onExit,
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.white70,
                          side: const BorderSide(color: Colors.white24),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                        child: const Text("SALIR"),
                      ),
                    ),

                    const SizedBox(width: 10),

                    if (onGoToShop != null)
                      Expanded(
                        child: ElevatedButton(
                          onPressed: onGoToShop,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.secondaryPink,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                          child: const Text("TIENDA",
                              style: TextStyle(fontWeight: FontWeight.bold)),
                        ),
                      ),

                    if (onRetry != null) ...[
                      const SizedBox(width: 10),
                      // Retry Button
                      Expanded(
                        child: ElevatedButton(
                          onPressed: onRetry,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.accentGold,
                            foregroundColor: Colors.black,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                          child: const Text("REINTENTAR",
                              style: TextStyle(fontWeight: FontWeight.bold)),
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
