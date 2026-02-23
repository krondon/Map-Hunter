import 'dart:ui';
import 'package:flutter/material.dart';
import '../../../../core/theme/app_theme.dart';

/// Overlay that appears when a minigame ends (win or lose).
/// Shows title, message, and action buttons (Retry, Shop, Exit).
class GameOverOverlay extends StatelessWidget {
  final String title;
  final String message;
  final bool isVictory;
  final String? bannerUrl;
  final VoidCallback? onRetry;
  final VoidCallback? onGoToShop;
  final VoidCallback? onExit;

  const GameOverOverlay({
    super.key,
    required this.title,
    required this.message,
    this.isVictory = false,
    this.bannerUrl,
    this.onRetry,
    this.onGoToShop,
    this.onExit,
  });

  @override
  Widget build(BuildContext context) {
    final accentColor = isVictory ? AppTheme.accentGold : AppTheme.dangerRed;

    return Positioned.fill(
      child: ClipRect(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
          child: Container(
            color: Colors.black.withOpacity(0.7),
            child: Center(
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 30),
                padding: const EdgeInsets.all(3),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(
                    color: accentColor.withOpacity(0.4),
                    width: 1,
                  ),
                  color: accentColor.withOpacity(0.08),
                ),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 32),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1A1A1D).withOpacity(0.95),
                    borderRadius: BorderRadius.circular(21),
                    border: Border.all(
                      color: accentColor.withOpacity(0.6),
                      width: 1.5,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: accentColor.withOpacity(0.15),
                        blurRadius: 30,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Icon
                      Icon(
                        isVictory ? Icons.emoji_events_rounded : Icons.warning_amber_rounded,
                        color: accentColor,
                        size: 52,
                      ),
                      const SizedBox(height: 16),

                      // Title
                      Text(
                        title,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: accentColor,
                          fontSize: 22,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1.5,
                        ),
                      ),
                      const SizedBox(height: 12),

                      // Message
                      Text(
                        message,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.85),
                          fontSize: 14,
                          height: 1.5,
                        ),
                      ),
                      const SizedBox(height: 28),

                      // Retry button
                      if (onRetry != null)
                        _buildButton(
                          label: 'REINTENTAR',
                          icon: Icons.refresh_rounded,
                          color: AppTheme.accentGold,
                          onTap: onRetry!,
                        ),

                      // Go to shop button
                      if (onGoToShop != null) ...[
                        const SizedBox(height: 12),
                        _buildButton(
                          label: 'IR A LA TIENDA',
                          icon: Icons.storefront_rounded,
                          color: AppTheme.accentGold,
                          onTap: onGoToShop!,
                        ),
                      ],

                      // Exit button
                      if (onExit != null) ...[
                        const SizedBox(height: 12),
                        _buildButton(
                          label: 'SALIR',
                          icon: Icons.exit_to_app_rounded,
                          color: Colors.white54,
                          onTap: onExit!,
                          subtle: true,
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildButton({
    required String label,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
    bool subtle = false,
  }) {
    return SizedBox(
      width: double.infinity,
      child: Container(
        padding: const EdgeInsets.all(2.5),
        decoration: BoxDecoration(
          color: color.withOpacity(subtle ? 0.05 : 0.12),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: color.withOpacity(subtle ? 0.15 : 0.35),
            width: 1,
          ),
        ),
        child: Container(
          decoration: BoxDecoration(
            color: const Color(0xFF1A1A1D).withOpacity(0.85),
            borderRadius: BorderRadius.circular(13),
            border: Border.all(
              color: color.withOpacity(subtle ? 0.25 : 0.6),
              width: 1.5,
            ),
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(13),
              onTap: onTap,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 14),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(icon, color: color, size: 20),
                    const SizedBox(width: 10),
                    Text(
                      label,
                      style: TextStyle(
                        color: color,
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                        letterSpacing: 1.0,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
