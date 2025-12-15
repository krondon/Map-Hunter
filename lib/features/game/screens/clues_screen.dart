import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/game_provider.dart';
import '../../auth/providers/player_provider.dart'; // IMPORT AGREGADO
import '../../../core/theme/app_theme.dart';
import '../widgets/clue_card.dart';
import '../../../shared/widgets/progress_header.dart';
import '../widgets/race_track_widget.dart';
import 'qr_scanner_screen.dart';
import 'geolocation_screen.dart';
import '../../mall/screens/shop_screen.dart';
import 'puzzle_screen.dart';

class CluesScreen extends StatefulWidget {
  // 1. Recibimos el ID del evento obligatorio
  final String eventId;

  const CluesScreen({
    super.key, 
    required this.eventId
  });

  @override
  State<CluesScreen> createState() => _CluesScreenState();
}

class _CluesScreenState extends State<CluesScreen> {
  
  @override
  void initState() {
    super.initState();
    // 2. Llamamos al provider apenas carga la pantalla usando el ID recibido
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final gameProvider = Provider.of<GameProvider>(context, listen: false);
      gameProvider.fetchClues(eventId: widget.eventId);
      // Opcional: Cargar ranking inicial para que la pista no se vea vacía
      gameProvider.fetchLeaderboard(); 
    });
  }

  // NUEVO MÉTODO: Muestra la pista en modo "Solo Lectura"
  void _showCompletedClueDialog(BuildContext context, dynamic clue) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(clue.title ?? 'Pista Completada'), // Asumiendo que clue tiene title
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                "¡Ya completaste este desafío!",
                style: TextStyle(fontWeight: FontWeight.bold, color: Colors.green),
              ),
              const SizedBox(height: 10),
              Text(clue.description ?? 'Sin descripción'), // Asumiendo que clue tiene description
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("Cerrar"),
          )
        ],
      ),
    );
  }

  void _handleClueAction(BuildContext context, String clueId, String clueType) {
    switch (clueType) {
      case 'qrScan':
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => QRScannerScreen(clueId: clueId)),
        );
        break;
      case 'geolocation':
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => GeolocationScreen(clueId: clueId)),
        );
        break;
      case 'npcInteraction':
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const ShopScreen()),
        );
        break;
      case 'minigame':
        try {
          final gameProvider = Provider.of<GameProvider>(context, listen: false);
          final clue = gameProvider.clues.firstWhere(
            (c) => c.id == clueId,
            orElse: () => throw Exception('Clue not found'),
          );
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => PuzzleScreen(clue: clue)),
          );
        } catch (e) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error: No se pudo cargar el minijuego. $e'),
              backgroundColor: AppTheme.dangerRed,
            ),
          );
        }
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final gameProvider = Provider.of<GameProvider>(context);
    
    return Container(
      decoration: const BoxDecoration(
        gradient: AppTheme.darkGradient,
      ),
      child: SafeArea(
        child: Column(
          children: [
            // Header
            const ProgressHeader(),
            
            // Mini Mapa de Carrera (Mario Kart Style)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Consumer<GameProvider>(
                builder: (context, game, _) {
                  // CORRECCIÓN AQUI: Usamos los nuevos parámetros
                  return RaceTrackWidget(
                    leaderboard: game.leaderboard,
                    currentPlayerId: Provider.of<PlayerProvider>(context, listen: false).currentPlayer?.id ?? '',
                    totalClues: game.clues.length,
                  );
                },
              ),
            ),
            
            // Clues list
            Expanded(
              child: gameProvider.isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : gameProvider.errorMessage != null
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.error_outline, size: 60, color: Colors.red),
                              const SizedBox(height: 16),
                              Text(
                                'Error al cargar pistas',
                                style: Theme.of(context).textTheme.titleLarge,
                              ),
                              const SizedBox(height: 8),
                              Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 32),
                                child: Text(
                                  gameProvider.errorMessage!,
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(color: Colors.white70),
                                ),
                              ),
                              const SizedBox(height: 24),
                              ElevatedButton(
                                // Pasamos el ID nuevamente al reintentar por seguridad
                                onPressed: () => gameProvider.fetchClues(eventId: widget.eventId),
                                child: const Text('Reintentar'),
                              ),
                            ],
                          ),
                        )
                      : gameProvider.clues.isEmpty
                          ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.explore_off,
                                size: 80,
                                color: Colors.white.withOpacity(0.3),
                              ),
                              const SizedBox(height: 20),
                              Text(
                                'No hay pistas disponibles',
                                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                                  color: Colors.white54,
                                ),
                              ),
                              const SizedBox(height: 10),
                              ElevatedButton(
                                onPressed: () {
                                  // Pasamos el ID nuevamente al recargar
                                  gameProvider.fetchClues(eventId: widget.eventId);
                                },
                                child: const Text('Recargar'),
                              ),
                            ],
                          ),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.all(16),
                          itemCount: gameProvider.clues.length,
                          itemBuilder: (context, index) {
                            final clue = gameProvider.clues[index];
                            final int currentIndex = gameProvider.currentClueIndex;
                            
                            // ESTADOS:
                            // 1. Ya pasó: (índice menor al actual)
                            final bool isPast = index < currentIndex;
                            // 2. Futuro: (índice mayor al actual)
                            final bool isFuture = index > currentIndex;
                            // 3. Presente: (es el índice actual)
                            final bool isCurrent = index == currentIndex;

                            // DETERMINAR SI SE MUESTRA EL CANDADO VISUALMENTE
                            // Una pista está bloqueada visualmente si es futura O si es la actual y aún tiene isLocked true
                            final bool showLockIcon = isFuture || (isCurrent && clue.isLocked);

                            return ClueCard(
                              clue: clue,
                              // Usamos showLockIcon para que la UI pinte el candado correctamente
                              isLocked: showLockIcon, 
                              onTap: () {
                                // A. Si es una pista futura, bloqueamos
                                if (isFuture) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(content: Text("Debes completar la pista anterior primero.")),
                                  );
                                  return;
                                }

                                // B. Si es una pista pasada (completada), mostramos resumen
                                if (isPast || (isCurrent && clue.isCompleted)) {
                                  _showCompletedClueDialog(context, clue);
                                  return;
                                }

                                // C. Si es la pista ACTUAL (La misión activa)
                                if (isCurrent) {
                                  if (clue.isLocked) {
                                    // --- CORRECCIÓN CLAVE: SI ESTÁ BLOQUEADA, IR AL ESCÁNER QR ---
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(builder: (_) => QRScannerScreen(clueId: clue.id)),
                                    );
                                  } else {
                                    // --- SI YA ESTÁ DESBLOQUEADA, IR AL MINIJUEGO ---
                                    _handleClueAction(context, clue.id, clue.type.toString().split('.').last);
                                  }
                                }
                              },
                            );
                          },
                        ),
            
            ),
          ],
        ),
      ),
    );
  }
}