import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../features/auth/providers/player_provider.dart';
import '../../features/game/providers/game_provider.dart';
import '../utils/global_keys.dart';
import '../../features/game/screens/scenarios_screen.dart';

/// Monitor que detecta si la sesión de juego actual ha sido invalidada
/// (por ejemplo, si un admin reinicia el evento y borra la inscripción del jugador)
class GameSessionMonitor extends StatefulWidget {
  final Widget child;

  const GameSessionMonitor({super.key, required this.child});

  @override
  State<GameSessionMonitor> createState() => _GameSessionMonitorState();
}

class _GameSessionMonitorState extends State<GameSessionMonitor> {
  String? _lastGamePlayerId;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final playerProvider = Provider.of<PlayerProvider>(context);
    final gameProvider = Provider.of<GameProvider>(context, listen: false);
    
    final currentGamePlayerId = playerProvider.currentPlayer?.gamePlayerId;

    // Detectar transición de TENER inscripción a NO TENERLA
    if (_lastGamePlayerId != null && currentGamePlayerId == null) {
      debugPrint("GameSessionMonitor: Pérdida de sesión de juego detectada.");
      
      // Si el juego estaba activo localmente, lo limpiamos
      if (gameProvider.isGameActive || gameProvider.currentEventId != null) {
        _handleGameReset();
      }
    }

    _lastGamePlayerId = currentGamePlayerId;
  }

  void _handleGameReset() {
    // 1. Limpiar estado del GameProvider
    context.read<GameProvider>().resetState();
    
    // 2. Notificar al usuario y Redirigir
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (rootNavigatorKey.currentState != null) {
        // Volver a la pantalla de escenarios (o la raíz de la app)
        rootNavigatorKey.currentState!.pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const ScenariosScreen()),
          (route) => route.isFirst,
        );

        ScaffoldMessenger.of(rootNavigatorKey.currentContext!).showSnackBar(
          SnackBar(
            content: const Row(
              children: [
                Icon(Icons.info_outline, color: Colors.white),
                SizedBox(width: 12),
                Expanded(
                  child: Text(
                    "El evento ha sido reiniciado por un administrador.",
                    style: TextStyle(color: Colors.white),
                  ),
                ),
              ],
            ),
            backgroundColor: Colors.orange.shade800,
            duration: const Duration(seconds: 5),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return widget.child;
  }
}
