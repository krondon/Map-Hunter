import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/game_provider.dart';
import '../../auth/providers/player_provider.dart';

class MinigameLogicHelper {
  /// Ejecuta la lógica centralizada de pérdida de vida:
  /// 1. Llama al backend (GameProvider)
  /// 2. Actualiza forzosamente el estado local (PlayerProvider)
  /// 3. Inicia la sincronización en background
  /// Retorna la cantidad definitiva de vidas restantes.
  static Future<int> executeLoseLife(BuildContext context) async {
    // 1. Capturar providers INMEDIATAMENTE antes de cualquier async
    final gameProvider = Provider.of<GameProvider>(context, listen: false);
    final playerProvider = Provider.of<PlayerProvider>(context, listen: false);
    final messenger = ScaffoldMessenger.maybeOf(context);

    if (playerProvider.currentPlayer == null) return 0;
    final userId = playerProvider.currentPlayer!.userId;

    // 2. Backend + Source of Truth
    // Ejecutamos la llamada al servidor
    final newLives = await gameProvider.loseLife(userId);

    // 3. Actualización Local (Critical Path)
    playerProvider.updateLocalLives(newLives);

    // 4. Sincronización (Solo si el contexto sigue vivo)
    if (context.mounted) {
      playerProvider.refreshProfile(eventId: gameProvider.currentEventId);
    } else {
      debugPrint(
          'MinigameLogicHelper: Context unmounted during lifecycle. Skipping refresh.');
    }

    return newLives;
  }
}
