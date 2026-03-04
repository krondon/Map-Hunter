/// GUÍA DE PERFORMANCE: Uso Estratégico de Selector y RepaintBoundary
///
/// PROBLEMA ORIGINAL:
/// El árbol de widgets usa Consumer<GameProvider> a nivel de pantalla completa.
/// Con 50 jugadores y actualizaciones cada 2s, esto reconstruye TODA la pantalla
/// (incluyendo el mapa, el HUD, los poderes, etc.) en cada cambio del leaderboard.
///
/// SOLUCIÓN: Usar Selector para suscribirse únicamente a los datos específicos
/// que cada sub-widget necesita. Usar RepaintBoundary para aislar las animaciones.

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../shared/models/player.dart';
import '../../providers/game_provider.dart';
import '../../providers/power_interfaces.dart';

// ============================================================
// EJEMPLO 1: Widget de Podio con Selector
//
// ANTES (problemático):
// Consumer<GameProvider>(
//   builder: (ctx, game, _) => PodiumWidget(players: game.leaderboard),
// )
// → Se reconstruye cuando ANY propiedad de GameProvider cambia
//   (vidas, isLoading, clues, etc.)
//
// DESPUÉS (óptimo):
// ============================================================
class OptimizedPodiumWidget extends StatelessWidget {
  const OptimizedPodiumWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return Selector<GameProvider, List<Player>>(
      // Selector compara por igualdad la salida del selector.
      // Solo reconstruye este widget cuando la lista de jugadores CAMBIA.
      // Las vidas, el estado de carga, las pistas, etc. NO provocan rebuild.
      selector: (_, game) => game.leaderboard,
      shouldRebuild: (previous, next) =>
          // Comparación shallow: reconstruir solo si la referencia cambió.
          // Para comparación profunda, usar listEquals de flutter/foundation.dart
          previous.length != next.length ||
          previous != next,
      builder: (context, players, _) {
        // RepaintBoundary: aísla el repaint de las animaciones de ranking
        // en su propio Render Object, sin afectar al resto de la pantalla.
        return RepaintBoundary(
          child: _PodiumList(players: players),
        );
      },
    );
  }
}

class _PodiumList extends StatelessWidget {
  final List<Player> players;
  const _PodiumList({required this.players});

  @override
  Widget build(BuildContext context) {
    if (players.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    return ListView.builder(
      itemCount: players.length > 10 ? 10 : players.length, // Limitar a top 10
      itemBuilder: (ctx, i) => _PodiumEntry(player: players[i], rank: i + 1),
    );
  }
}

class _PodiumEntry extends StatelessWidget {
  final Player player;
  final int rank;
  const _PodiumEntry({required this.player, required this.rank});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: CircleAvatar(child: Text('$rank')),
      title: Text(player.name ?? ''),
    );
  }
}

// ============================================================
// EJEMPLO 2: Widget de Vidas aislado
//
// Las vidas cambian frecuentemente (ataques de LifeSteal, penalidades).
// Aislarlas evita que el cambio de vidas reconstruya el leaderboard.
// ============================================================
class LivesDisplay extends StatelessWidget {
  const LivesDisplay({super.key});

  @override
  Widget build(BuildContext context) {
    return Selector<GameProvider, int>(
      selector: (_, game) => game.lives,
      builder: (context, lives, _) {
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(
            lives,
            (_) => const Icon(Icons.favorite, color: Colors.red, size: 20),
          ),
        );
      },
    );
  }
}

// ============================================================
// EJEMPLO 3: Estado de Poderes aislado del HUD principal
//
// Los poderes se actualizan cada pocos segundos. Usar Selector para
// suscribirse solo al slug del poder activo, no a todo PowerEffectProvider.
// ============================================================
class ActivePowerIndicator extends StatelessWidget {
  const ActivePowerIndicator({super.key});

  @override
  Widget build(BuildContext context) {
    return Selector<PowerEffectReader, ({String? slug, DateTime? expiresAt})>(
      selector: (_, reader) => (
        slug: reader.activePowerSlug,
        expiresAt: reader.activePowerExpiresAt,
      ),
      builder: (context, powerState, _) {
        if (powerState.slug == null) return const SizedBox.shrink();

        return RepaintBoundary(
          child: _PowerTimer(
            slug: powerState.slug!,
            expiresAt: powerState.expiresAt,
          ),
        );
      },
    );
  }
}

class _PowerTimer extends StatelessWidget {
  final String slug;
  final DateTime? expiresAt;
  const _PowerTimer({required this.slug, this.expiresAt});

  @override
  Widget build(BuildContext context) {
    return Chip(
      label: Text(slug),
      backgroundColor: Colors.orange.withOpacity(0.8),
    );
  }
}

// ============================================================
// EJEMPLO 4: Cómo conectar FeedbackEventQueue en un widget overlay
//
// Este widget SIEMPRE está activo (hijo de SabotageOverlay que vive en root).
// Al navegar entre pantallas, este widget NO se destruye, garantizando que
// los eventos de feedback siempre tienen un listener activo.
// ============================================================
class FeedbackOverlayListener extends StatefulWidget {
  final Widget child;
  const FeedbackOverlayListener({super.key, required this.child});

  @override
  State<FeedbackOverlayListener> createState() =>
      _FeedbackOverlayListenerState();
}

class _FeedbackOverlayListenerState extends State<FeedbackOverlayListener> {
  // NOTA: SabotageOverlay ya gestiona _feedbackSubscription.
  // Este widget es un ejemplo de patrón correcto para NUEVOS overlays.

  @override
  Widget build(BuildContext context) => widget.child;
}

// ============================================================
// REGLAS DE ORO PARA ESTE PROYECTO
// ============================================================
//
// ✅ USA Selector<GameProvider, X> donde X es el dato MÍNIMO que tu widget necesita.
//
// ✅ USA RepaintBoundary en:
//    - Widgets de animación (timers de poderes, escudos, efectos)
//    - El listado del leaderboard
//    - Los overlays de feedback (SabotageOverlay)
//
// ✅ USA context.read<T>() (sin listen) en callbacks de botones y event handlers,
//    donde NO necesitas reconstrucción automática.
//
// ✅ USA StreamBuilder para streams efímeros (feedbackStream, effectStream)
//    en lugar de convertirlos a estado del Provider.
//
// ❌ EVITA Consumer<GameProvider> a nivel de Scaffold o pantalla completa.
//
// ❌ EVITA context.watch<T>() en widgets que tienen hijos pesados.
//    Úsalo solo en widgets "hoja" (leaf widgets).
//
// ❌ EVITA notifyListeners() desde dentro de microtasks/futures sin comprobar
//    que el Provider no haya sido disposed. Usa el patrón:
//    if (!_disposed) notifyListeners();
