import 'package:flutter/material.dart';
import '../../../../core/theme/app_theme.dart';

/// Botón "RENDIRSE" con estilo cyberpunk de doble borde rojo.
/// Reutilizable en todos los minijuegos.
class CyberSurrenderButton extends StatelessWidget {
  final VoidCallback? onPressed;
  final bool disabled;

  const CyberSurrenderButton({
    super.key,
    required this.onPressed,
    this.disabled = false,
  });

  @override
  Widget build(BuildContext context) {
    final isDisabled = disabled || onPressed == null;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Container(
        padding: const EdgeInsets.all(2.5),
        decoration: BoxDecoration(
          color: AppTheme.dangerRed.withOpacity(isDisabled ? 0.05 : 0.12),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: AppTheme.dangerRed.withOpacity(isDisabled ? 0.15 : 0.35),
            width: 1,
          ),
        ),
        child: Container(
          decoration: BoxDecoration(
            color: const Color(0xFF1A1A1D).withOpacity(0.85),
            borderRadius: BorderRadius.circular(15),
            border: Border.all(
              color: AppTheme.dangerRed.withOpacity(isDisabled ? 0.25 : 0.6),
              width: 1.5,
            ),
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(15),
              onTap: isDisabled ? null : onPressed,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 14),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.flag_rounded,
                      color: isDisabled ? Colors.white30 : AppTheme.dangerRed,
                      size: 20,
                    ),
                    const SizedBox(width: 10),
                    Text(
                      "RENDIRSE",
                      style: TextStyle(
                        color: isDisabled ? Colors.white30 : AppTheme.dangerRed,
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
