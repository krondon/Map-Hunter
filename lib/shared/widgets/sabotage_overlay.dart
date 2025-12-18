import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:provider/provider.dart';
import '../../features/auth/providers/player_provider.dart';
import '../../core/theme/app_theme.dart';

class SabotageOverlay extends StatefulWidget {
  final Widget child;

  const SabotageOverlay({super.key, required this.child});

  @override
  State<SabotageOverlay> createState() => _SabotageOverlayState();
}

class _SabotageOverlayState extends State<SabotageOverlay> with SingleTickerProviderStateMixin {
  late AnimationController _flashController;
  bool _isNewSabotage = false;
  String? _lastStatusId;

  @override
  void initState() {
    super.initState();
    _flashController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
  }

  @override
  void dispose() {
    _flashController.dispose();
    super.dispose();
  }

  void _triggerFlash() {
    _flashController.forward(from: 0.0).then((_) => _flashController.reverse());
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<PlayerProvider>(
      builder: (context, playerProvider, _) {
        final player = playerProvider.currentPlayer;
        
        // Determinar status actual
        String? currentStatus;
        if (player != null) {
          if (player.isFrozen) currentStatus = 'frozen';
          else if (player.isBlinded) currentStatus = 'blinded';
          else if (player.isSlowed) currentStatus = 'slowed';
        }

        // Detectar si el estatus cambió para disparar animación
        if (currentStatus != null && currentStatus != _lastStatusId) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _triggerFlash();
          });
          _lastStatusId = currentStatus;
        } else if (currentStatus == null) {
          _lastStatusId = null;
        }

        // Lógica de cámara lenta
        if (player != null && player.isSlowed) {
          timeDilation = 3.0; 
        } else {
          timeDilation = 1.0; 
        }

        final bool hasSabotage = currentStatus != null;

        return Stack(
          children: [
            widget.child,
            
            // Capa de Blinded (Pantalla Negra)
            if (player != null && player.isBlinded)
              _buildSabotageLayer(
                color: Colors.black.withOpacity(0.99), // Casi opaco total
                icon: Icons.visibility_off,
                title: '¡PANTALLA NEGRA!',
                subtitle: 'Alguien ha saboteado tu vista temporalmente.',
                accentColor: AppTheme.dangerRed,
              ),

            // Capa de Frozen (Congelado)
            if (player != null && player.isFrozen)
              _buildSabotageLayer(
                color: const Color(0xFF00BFFF).withOpacity(0.85), // Deep Sky Blue robusto
                icon: Icons.ac_unit,
                title: '¡CONGELADO!',
                subtitle: 'Tu pantalla se ha convertido en un bloque de hielo.',
                accentColor: Colors.white,
              ),

            // Capa de Slowed (Cámara Lenta) - Overlay Parcial (Bordes)
            if (player != null && player.isSlowed)
              IgnorePointer( // No bloquea interacción, solo molesta visualmente
                child: Container(
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.orange.withOpacity(0.5), width: 10),
                  ),
                  child: Align(
                    alignment: Alignment.topCenter,
                    child: Container(
                      margin: const EdgeInsets.only(top: 50),
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                      decoration: BoxDecoration(
                        color: Colors.orange,
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: const [BoxShadow(blurRadius: 10, color: Colors.black26)]
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.directions_run, color: Colors.white), 
                          SizedBox(width: 8), 
                          Text("CÁMARA LENTA", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold))
                        ],
                      ),
                    ),
                  ),
                ),
              ),


            // Efecto de Flash / Alerta al recibir sabotaje (NUNCA debe bloquear clicks)
            IgnorePointer(
              child: FadeTransition(
                opacity: _flashController,
                child: Container(
                  color: Colors.red.withOpacity(0.4),
                  child: const Center(
                    child: Icon(Icons.warning_amber_rounded, size: 120, color: Colors.white),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildSabotageLayer({
    required Color color,
    required IconData icon,
    required String title,
    required String subtitle,
    required Color accentColor,
  }) {
    return AbsorbPointer(
      absorbing: true, // Bloquea todos los toques para que no pasen al app de abajo
      child: Container(
        color: color,
        width: double.infinity,
        height: double.infinity,
        child: Material(
          color: Colors.transparent,
          child: Center(
            child: TweenAnimationBuilder<double>(
            tween: Tween(begin: 0.8, end: 1.0),
            duration: const Duration(milliseconds: 500),
            curve: Curves.elasticOut,
            builder: (context, scale, child) {
              return Transform.scale(
                scale: scale,
                child: child,
              );
            },
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, size: 90, color: accentColor),
                const SizedBox(height: 24),
                Text(
                  title,
                  style: TextStyle(
                    color: accentColor,
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 3,
                  ),
                ),
                const SizedBox(height: 12),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 40),
                  child: Text(
                    subtitle,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 18,
                    ),
                  ),
                ),
                const SizedBox(height: 50),
                const CircularProgressIndicator(color: Colors.white30),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}
}
