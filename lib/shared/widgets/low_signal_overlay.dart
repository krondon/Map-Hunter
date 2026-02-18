import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';

/// Overlay visual que se muestra cuando hay señal baja.
/// Incluye un contador regresivo de 10 segundos.
class LowSignalOverlay extends StatefulWidget {
  final int secondsRemaining;
  final VoidCallback? onTimeout;

  const LowSignalOverlay({
    super.key,
    required this.secondsRemaining,
    this.onTimeout,
  });

  @override
  State<LowSignalOverlay> createState() => _LowSignalOverlayState();
}

class _LowSignalOverlayState extends State<LowSignalOverlay>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const Color currentOrange = Color(0xFFFF9800);
    const Color cardBg = Color(0xFF151517);

    return Material(
      color: Colors.black.withOpacity(0.85),
      child: SafeArea(
        child: Center(
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 40),
            padding: const EdgeInsets.all(4), // Espacio para el efecto de doble borde
            decoration: BoxDecoration(
              color: currentOrange.withOpacity(0.2), // Tono naranja suave exterior
              borderRadius: BorderRadius.circular(28),
              border: Border.all(color: currentOrange.withOpacity(0.5), width: 1),
            ),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
              decoration: BoxDecoration(
                color: cardBg,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                  color: currentOrange,
                  width: 2,
                ),
                boxShadow: [
                  BoxShadow(
                    color: currentOrange.withOpacity(0.1),
                    blurRadius: 20,
                    spreadRadius: 2,
                  ),
                ],
              ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Icono Satélite + WiFi (Ajustado para evitar colisión)
                SizedBox(
                  height: 120,
                  width: 140, // Más ancho para dar espacio a la derecha
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      // Satélite inclinado
                      Transform.rotate(
                        angle: -0.15,
                        child: const Icon(
                          Icons.satellite_alt_rounded,
                          size: 90,
                          color: Color(0xFFFF9800),
                        ),
                      ),
                      // WiFi movido bien a la derecha y arriba
                      const Positioned(
                        top: -5,
                        right: 5,
                        child: Icon(
                          Icons.wifi,
                          size: 38,
                          color: Color(0xFFFF9800),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 24),

                // Título
                const Text(
                  'CONEXIÓN INESTABLE',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.5,
                  ),
                ),

                const SizedBox(height: 8),

                // Mensaje
                Text(
                  'Intentando reconectar ...',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.4),
                    fontSize: 14,
                    fontWeight: FontWeight.w300,
                  ),
                ),

                const SizedBox(height: 32),

                // Contador con círculo oscuro (como en la imagen)
                Container(
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.3),
                    shape: BoxShape.circle,
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    '${widget.secondsRemaining}s',
                    style: const TextStyle(
                      color: Color(0xFFFF9800),
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),

                const SizedBox(height: 16),

                // Barra de progreso naranja
                SizedBox(
                  width: 180,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: LinearProgressIndicator(
                      value: widget.secondsRemaining / 25.0,
                      minHeight: 10,
                      backgroundColor: Colors.white.withOpacity(0.1),
                      valueColor: const AlwaysStoppedAnimation<Color>(
                        Color(0xFFFF9800),
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 40),

                // Advertencia Inferior Estilizada
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 16,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFF721C24).withOpacity(0.2),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: const Color(0xFFE33E5D).withOpacity(0.4),
                    ),
                  ),
                  child: Column(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(color: const Color(0xFFE33E5D)),
                        ),
                        child: const Icon(
                          Icons.warning_amber_rounded,
                          color: Color(0xFFE33E5D),
                          size: 20,
                        ),
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        'Serás desconectado si no se recupera la conexión',
                        style: TextStyle(
                          color: Color(0xFFE33E5D),
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}
}
