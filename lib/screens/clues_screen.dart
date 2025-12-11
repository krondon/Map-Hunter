import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/game_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/clue_card.dart';
import '../widgets/progress_header.dart';
import '../widgets/race_track_widget.dart';
import 'qr_scanner_screen.dart';
import 'geolocation_screen.dart';
import 'shop_screen.dart';

class CluesScreen extends StatelessWidget {
  const CluesScreen({super.key});

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
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Minijuego en desarrollo')),
        );
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
                                onPressed: () => gameProvider.fetchClues(),
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
                                  gameProvider.fetchClues();
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
                      final isLocked = index > 0 && !gameProvider.clues[index - 1].isCompleted;
                      
                      return ClueCard(
                        clue: clue,
                        isLocked: isLocked,
                        onTap: () {
                          if (!isLocked && !clue.isCompleted) {
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
