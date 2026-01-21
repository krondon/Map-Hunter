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
    return Material(
      color: Colors.black.withOpacity(0.75),
      child: SafeArea(
        child: Center(
          child: Container(
            margin: const EdgeInsets.all(32),
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: AppTheme.cardBg,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: Colors.orange.withOpacity(0.5),
                width: 2,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.orange.withOpacity(0.2),
                  blurRadius: 20,
                  spreadRadius: 5,
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Icono animado de señal baja
                AnimatedBuilder(
                  animation: _pulseController,
                  builder: (context, child) {
                    return Transform.scale(
                      scale: 1.0 + (_pulseController.value * 0.1),
                      child: Icon(
                        Icons.signal_wifi_statusbar_connected_no_internet_4,
                        size: 80,
                        color: Color.lerp(
                          Colors.orange,
                          Colors.red,
                          _pulseController.value,
                        ),
                      ),
                    );
                  },
                ),

                const SizedBox(height: 20),

                // Título
                const Text(
                  'CONEXIÓN INESTABLE',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.5,
                  ),
                ),

                const SizedBox(height: 12),

                // Mensaje
                Text(
                  'Intentando reconectar...',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.8),
                    fontSize: 16,
                  ),
                ),

                const SizedBox(height: 24),

                // Contador con barra de progreso
                _buildCountdownIndicator(),

                const SizedBox(height: 16),

                // Advertencia
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.red.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: Colors.red.withOpacity(0.3),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.warning_amber_rounded,
                        color: Colors.red.shade300,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Flexible(
                        child: Text(
                          'Serás desconectado si no se recupera',
                          style: TextStyle(
                            color: Colors.red.shade300,
                            fontSize: 13,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCountdownIndicator() {
    final progress = widget.secondsRemaining / 25.0;
    
    return Column(
      children: [
        // Número grande
        Text(
          '${widget.secondsRemaining}s',
          style: TextStyle(
            color: widget.secondsRemaining <= 5 
                ? Colors.red 
                : Colors.orange,
            fontSize: 36,
            fontWeight: FontWeight.bold,
          ),
        ),

        const SizedBox(height: 12),

        // Barra de progreso
        SizedBox(
          width: 200,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 8,
              backgroundColor: Colors.white.withOpacity(0.2),
              valueColor: AlwaysStoppedAnimation<Color>(
                widget.secondsRemaining <= 5 
                    ? Colors.red 
                    : Colors.orange,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
