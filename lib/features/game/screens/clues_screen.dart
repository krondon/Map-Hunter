import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/game_provider.dart';
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
      Provider.of<GameProvider>(context, listen: false)
          .fetchClues(eventId: widget.eventId);
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
                  return RaceTrackWidget(
                    currentClueIndex: game.currentClueIndex,
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
                      
                      // LÓGICA DE FLUJO CORREGIDA:
                      // Usamos el índice actual del provider para determinar el estado
                      final int currentIndex = gameProvider.currentClueIndex;
                      
                      // 1. Completada: Si el índice de esta pista es menor al nivel actual
                      final bool isCompleted = index < currentIndex;
                      
                      // 2. Bloqueada: Si el índice es mayor al nivel actual
                      final bool isLocked = index > currentIndex;
                      
                      // 3. Actual (Jugable): Si es exactamente el nivel actual
                      final bool isPlayable = index == currentIndex;

                      return ClueCard(
                        clue: clue,
                        // Forzamos el estado visual de bloqueo basado en el flujo lineal
                        isLocked: isLocked, 
                        onTap: () {
                          if (isLocked) {
                            // Opción: Mostrar snackbar indicando que está bloqueado
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text("Debes completar la pista anterior primero.")),
                            );
                            return;
                          }

                          if (isCompleted) {
                            // CASO: Pista pasada -> Solo mostrar información (sin jugar)
                            _showCompletedClueDialog(context, clue);
                          } else if (isPlayable) {
                            // CASO: Pista actual -> Jugar / Escanear
                            _handleClueAction(context, clue.id, clue.type.toString().split('.').last);
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