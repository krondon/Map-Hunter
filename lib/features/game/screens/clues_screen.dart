import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../providers/game_provider.dart';
import '../../auth/providers/player_provider.dart'; // IMPORT AGREGADO
import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/animated_cyber_background.dart';
import '../widgets/clue_card.dart';
import '../../../shared/widgets/progress_header.dart';
import '../widgets/race_track_widget.dart';
import 'qr_scanner_screen.dart';
import 'geolocation_screen.dart';
import '../../mall/screens/shop_screen.dart';
import 'puzzle_screen.dart';
import '../../game/models/clue.dart'; // Import para usar tipo Clue
import 'clue_finder_screen.dart'; // Import nuevo
import 'winner_celebration_screen.dart'; // Import for celebration screen
import 'story_intro_screen.dart'; // Import for story introduction
import '../../../shared/widgets/animated_cyber_background.dart';

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
    // Check if user has seen the story introduction
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final prefs = await SharedPreferences.getInstance();
      final String storyKey = 'has_seen_asthoria_story_v3_${widget.eventId}';
      final hasSeenStory = prefs.getBool(storyKey) ?? false;
      
      debugPrint("DEBUG: Checking story intro. hasSeenStory: $hasSeenStory for event: ${widget.eventId}");
      
      if (!hasSeenStory && mounted) {
        // Show story introduction
        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => StoryIntroScreen(
              onComplete: () {
                Navigator.pop(context);
              },
            ),
          ),
        );
        
        // Mark as seen
        await prefs.setBool(storyKey, true);
      }
      
      // Continue with normal initialization
      if (mounted) {
        final gameProvider = Provider.of<GameProvider>(context, listen: false);
        final playerProvider = Provider.of<PlayerProvider>(context, listen: false); // Necesitamos esto
        
        // ADDED: Listener para interrupción inmediata si el juego termina mientras estamos aquí
        gameProvider.addListener(_onGameProviderChange);
        
        // Obtenemos el ID real del usuario
        final userId = playerProvider.currentPlayer?.id;

        // 1. PASAR EL userId ES VITAL para que se carguen las 2 vidas reales
        await gameProvider.fetchClues(
          eventId: widget.eventId, 
          userId: userId, // ✅ Agregado
        );
        
        // 2. LUEGO comprobar si la carrera ya terminó en el servidor
        await gameProvider.checkRaceStatus();
        
        // 3. Si ya terminó, redirigir
        if (gameProvider.isRaceCompleted && mounted) {
          _navigateToWinnerScreen();
          return;
        }
        
        // 4. FINALMENTE iniciar el polling de ranking
        gameProvider.startLeaderboardUpdates();
      }
    });
  }

  @override
  void dispose() {
    // Importante: Eliminar listener y detener actualizaciones al salir
    final gameProvider = Provider.of<GameProvider>(context, listen: false);
    gameProvider.removeListener(_onGameProviderChange); // Clean up listener
    gameProvider.stopLeaderboardUpdates();
    super.dispose();
  }

  void _onGameProviderChange() {
    if (!mounted) return;
    final gameProvider = Provider.of<GameProvider>(context, listen: false);
    
    // Si la carrera se completó, forzamos navegación inmediata
    if (gameProvider.isRaceCompleted) {
      debugPrint("⛔ RACE COMPLETED DETECTED IN REALTIME - NAVIGATING AWAY");
      // Importante: Removemos el listener antes de navegar para evitar llamadas dobles
      gameProvider.removeListener(_onGameProviderChange);
      _navigateToWinnerScreen(clearStack: true);
    }
  }
  
  void _navigateToWinnerScreen({bool clearStack = false}) async {
    final gameProvider = Provider.of<GameProvider>(context, listen: false);
    final playerProvider = Provider.of<PlayerProvider>(context, listen: false);
    
    // Get player's position and completed clues
    final position = _getPlayerPosition();
    final completedClues = gameProvider.completedClues;
    
    if (mounted) {
      final route = MaterialPageRoute(
        builder: (_) => WinnerCelebrationScreen(
          eventId: widget.eventId,
          playerPosition: position,
          totalCluesCompleted: completedClues,
        ),
      );

      if (clearStack) {
         // Si es interrupción forzada, borramos TODO el historial hasta llegar aquí y reemplazamos
         Navigator.of(context).pushAndRemoveUntil(route, (route) => false);
      } else {
         // Comportamiento original (solo reemplazar esta vista)
         Navigator.of(context).pushReplacement(route);
      }
    }
  }
  
  int _getPlayerPosition() {
    final gameProvider = Provider.of<GameProvider>(context, listen: false);
    final playerProvider = Provider.of<PlayerProvider>(context, listen: false);
    final currentPlayerId = playerProvider.currentPlayer?.id ?? '';
    
    final leaderboard = gameProvider.leaderboard;
    if (leaderboard.isEmpty) return 0; // Default to 0 (Unranked) instead of 1
    
    final index = leaderboard.indexWhere((p) => p.id == currentPlayerId);
    return index >= 0 ? index + 1 : leaderboard.length + 1;
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
          MaterialPageRoute(builder: (_) => QRScannerScreen(expectedClueId: clueId)),
        );
        break;
      case 'geolocation':
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ClueFinderScreen(
              clue: Provider.of<GameProvider>(context, listen: false)
                  .clues
                  .firstWhere((c) => c.id == clueId),
            ),
          ),
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

  // Estado local para recordar qué pistas ya se escanearon en esta sesión
  final Set<String> _scannedClues = {};

  @override
  Widget build(BuildContext context) {
    final gameProvider = Provider.of<GameProvider>(context);
    
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: AnimatedCyberBackground(
        child: Column(
          children: [
            SafeArea(
              bottom: false,
              child: Container(), // Empty bridge for column spacing
            ),

            
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

                            if (isCurrent) {
                              print("DEBUG: Clue $index (Current) - isLocked: ${clue.isLocked}, isCompleted: ${clue.isCompleted}, scanned: ${_scannedClues.contains(clue.id)}");
                            }

                            // DETERMINAR SI SE MUESTRA EL CANDADO VISUALMENTE
                            // Una pista está bloqueada visualmente si es futura O si es la actual y aún tiene isLocked true
                            final bool showLockIcon = isFuture || (isCurrent && clue.isLocked);

                            return ClueCard(
                              clue: clue,
                              // Usamos showLockIcon para que la UI pinte el candado correctamente
                              isLocked: showLockIcon, 
                              onTap: () async {
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
                                  // 1. Verificamos si ya fue escaneada/encontrada
                                  if (!_scannedClues.contains(clue.id)) {
                                    // 2. Si NO fue encontrada -> Ir a pantalla de Frio/Caliente
                                    final bool? success = await Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) => ClueFinderScreen(clue: clue),
                                      ),
                                    );
                                    
                                    // 3. Si regresó con éxito (Encontró y Escaneó)
                                    if (success == true) {
                                       _unlockAndProceed(clue);
                                    }
                                    return; 
                                  } else {
                                    // 4. YA escaneada -> Jugar
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

  // --- NUEVO DIÁLOGO DE DESBLOQUEO ---
  void _showUnlockClueDialog(BuildContext context, Clue clue) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.cardBg,
        title: const Row(
          children: [
            Icon(Icons.lock, color: AppTheme.accentGold),
            SizedBox(width: 10),
            Text("Desbloquear Misión", style: TextStyle(color: Colors.white)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              "Para acceder a esta misión, debes encontrar el código QR en la ubicación real.",
              style: TextStyle(color: Colors.white70),
            ),
            const SizedBox(height: 20),
            // Opción 1: Escanear
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.accentGold,
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
                onPressed: () async {
                  Navigator.pop(context); // Cerrar diálogo
                  final scannedCode = await Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const QRScannerScreen()),
                  );
                  
                  if (scannedCode != null) {
                     // Formato esperado: CLUE:{eventId}:{clueId}
                     // O simplemente el ID de la pista si es un código simple
                     // Aquí asumimos validación básica
                     if (scannedCode.toString().contains(clue.id) || scannedCode.toString().startsWith("CLUE:")) {
                        // ÉXITO
                        _unlockAndProceed(clue);
                     } else {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text("Código QR incorrecto para esta misión.")),
                        );
                     }
                  }
                },
                icon: const Icon(Icons.qr_code_scanner),
                label: const Text("ESCANEAR QR"),
              ),
            ),
            const SizedBox(height: 10),
            const Divider(color: Colors.white24),
            const SizedBox(height: 10),
          ],
        ),
      ),
    );
  }

  void _unlockAndProceed(Clue clue) {
    setState(() {
      _scannedClues.add(clue.id);
    });
    
    final gameProvider = Provider.of<GameProvider>(context, listen: false);
    gameProvider.unlockClue(clue.id);
    
    // Navegar al minijuego correspondiente
    _handleClueAction(context, clue.id, clue.type.toString().split('.').last);
  }

}