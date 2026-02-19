import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../features/auth/providers/player_provider.dart';
import '../../features/game/providers/game_provider.dart';
import '../utils/global_keys.dart';
import '../../features/game/screens/scenarios_screen.dart';
import '../models/player.dart';

/// Monitor que detecta si la sesión de juego actual ha sido invalidada
/// (por ejemplo, si un admin reinicia el evento y borra la inscripción del jugador)
class GameSessionMonitor extends StatefulWidget {
  final Widget child;

  const GameSessionMonitor({
    super.key,
    required this.child,
  });

  // Static constant to avoid rebuilds of the child if not needed
  static final GlobalKey<NavigatorState> monitorNavigatorKey =
      GlobalKey<NavigatorState>();

  @override
  State<GameSessionMonitor> createState() => _GameSessionMonitorState();
}

class _GameSessionMonitorState extends State<GameSessionMonitor> {
  String? _lastGamePlayerId;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    final playerProvider = Provider.of<PlayerProvider>(context);

    // [FIX] Guard: If user is logged out, skip all session checks.
    // This prevents accessing GameProvider during logout teardown,
    // which was contributing to the _dependents.isEmpty crash.
    if (playerProvider.currentPlayer == null) {
      _lastGamePlayerId = null;
      return;
    }

    final gameProvider = Provider.of<GameProvider>(context, listen: false);
    final currentGamePlayerId = playerProvider.currentPlayer?.gamePlayerId;
    final isBanned =
        playerProvider.currentPlayer?.status == PlayerStatus.banned;

    debugPrint('🕒 GameSessionMonitor: Checking session...');
    debugPrint('   - Last ID: $_lastGamePlayerId');
    debugPrint('   - Current ID: $currentGamePlayerId');
    debugPrint('   - Is Banned: $isBanned');

    bool shouldKick = false;

    if (_lastGamePlayerId != null && currentGamePlayerId == null) {
      // SOLO expulsar si el evento que se perdió es el que estamos jugando actualmente
      final currentPlayingEventId = gameProvider.currentEventId;
      final lostSessionEventId = playerProvider.currentPlayer?.currentEventId;

      debugPrint("🕒 GameSessionMonitor: 🚫 PÉRDIDA DE SESIÓN DETECTADA.");
      debugPrint("   - Prev GP ID: $_lastGamePlayerId");
      debugPrint("   - Curr GP ID: null");
      debugPrint("   - Current Playing Event: $currentPlayingEventId");

      // Si el usuario ya no tiene currentEventId (porque se borró su GP),
      // pero el monitorNavigator tiene un evento activo, es sospechoso.
      if (currentPlayingEventId != null) {
        shouldKick = true;
      }
    }

    // Caso 2: El status cambió a BANNED (Baneo detectado por Stream)
    // ONLY kick banned users if they have an active gamePlayerId (they're trying to play)
    // Banned users with gamePlayerId == null are spectators and should NOT be kicked
    if (isBanned &&
        currentGamePlayerId != null &&
        (gameProvider.isGameActive || gameProvider.currentEventId != null)) {
      debugPrint(
          "🕒 GameSessionMonitor: 🚫 STATUS BANNED DETECTADO (with active gamePlayerId).");
      shouldKick = true;
    }

    if (shouldKick) {
      debugPrint("🕒 GameSessionMonitor: ⚡ Iniciando expulsión del jugador...");
      _handleGameReset();
    }

    _lastGamePlayerId = currentGamePlayerId;
  }

  void _handleGameReset() {
    // 2. Notificar al usuario, Redirigir y Limpiar estado
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // CRITICAL: Exit early if widget was disposed
      if (!mounted) return;

      // Limpiar estado del GameProvider de manera segura fuera del ciclo de build
      context.read<GameProvider>().resetState();

      if (rootNavigatorKey.currentState != null &&
          rootNavigatorKey.currentContext != null) {
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
                    "Has sido baneado de la competencia.",
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
