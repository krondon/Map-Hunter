import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/theme/app_theme.dart';

class ExitProtectionWrapper extends StatelessWidget {
  final Widget child;
  final String title;
  final String message;
  final bool enableProtection;

  const ExitProtectionWrapper({
    super.key,
    required this.child,
    this.title = "¿Salir del Evento?",
    this.message = "Si sales ahora, podrías perder tu progreso o tu posición en el ranking.",
    this.enableProtection = true,
  });

  @override
  Widget build(BuildContext context) {
    if (!enableProtection) return child;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;

        final shouldExit = await showDialog<bool>(
          context: context,
          builder: (context) {
            const Color currentRed = Color(0xFFE33E5D);
            const Color cardBg = Color(0xFF151517);

            return Dialog(
              backgroundColor: Colors.transparent,
              insetPadding: const EdgeInsets.symmetric(horizontal: 40),
              child: Container(
                padding: const EdgeInsets.all(4), // Espacio para el efecto de doble borde
                decoration: BoxDecoration(
                  color: currentRed.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(28),
                  border: Border.all(color: currentRed.withOpacity(0.5), width: 1),
                ),
                child: Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: cardBg,
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: currentRed, width: 2),
                    boxShadow: [
                      BoxShadow(
                        color: currentRed.withOpacity(0.1),
                        blurRadius: 20,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(color: currentRed, width: 2),
                        ),
                        child: const Icon(
                          Icons.warning_amber_rounded,
                          color: currentRed,
                          size: 32,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        title,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        message,
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: Colors.white70, fontSize: 14),
                      ),
                      const SizedBox(height: 24),
                      Row(
                        children: [
                          Expanded(
                            child: TextButton(
                              onPressed: () => Navigator.pop(context, false),
                              child: const Text(
                                'CANCELAR',
                                style: TextStyle(color: Colors.white54, fontWeight: FontWeight.bold),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: ElevatedButton(
                              onPressed: () => Navigator.pop(context, true),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: currentRed,
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              child: const Text(
                                'SALIR',
                                style: TextStyle(fontWeight: FontWeight.bold),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );

        if (shouldExit == true && context.mounted) {
          Navigator.pop(context);
        }
      },
      child: child,
    );
  }
}
