import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:treasure_hunt_rpg/features/game/providers/game_provider.dart';
import 'package:treasure_hunt_rpg/features/auth/providers/player_provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/animated_cyber_background.dart';
import '../widgets/clue_card.dart';
import '../../../shared/widgets/progress_header.dart';
import '../widgets/race_track_widget.dart';
import '../widgets/no_lives_widget.dart';
import '../../game/models/clue.dart'; // Import para usar tipo Clue
import 'qr_scanner_screen.dart'; // Needed for _showUnlockClueDialog
import 'winner_celebration_screen.dart'; // Import for celebration screen

// Duplicate import removed (animated_cyber_background already imported above)
import '../../../shared/widgets/exit_protection_wrapper.dart'; // Protection
import '../services/clue_navigator_service.dart'; // New Service
import 'puzzle_screen.dart';
import 'waiting_room_screen.dart'; // NEW IMPORT
import '../providers/power_effect_provider.dart'; // SHIELD FIX

class CluesScreen extends StatefulWidget {
  // 1. Recibimos el ID del evento obligatorio
  final String eventId;

  const CluesScreen({super.key, required this.eventId});

  @override
  State<CluesScreen> createState() => _CluesScreenState();
}

class _CluesScreenState extends State<CluesScreen> {
  // Store reference to avoid unsafe lookup in dispose
  GameProvider? _gameProviderRef;
  
  @override
  void initState() {
    super.initState();
    // Check if user has seen the story introduction
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final prefs = await SharedPreferences.getInstance();
      final String storyKey = 'has_seen_asthoria_story_v3_${widget.eventId}';
      final hasSeenStory = prefs.getBool(storyKey) ?? false;

      debugPrint(
          "DEBUG: Checking story intro. hasSeenStory: $hasSeenStory for event: ${widget.eventId}");

      // Continue with normal initialization
      if (mounted) {
        final gameProvider = Provider.of<GameProvider>(context, listen: false);
        _gameProviderRef = gameProvider; // Store reference
        final playerProvider = Provider.of<PlayerProvider>(context,
            listen: false); // Necesitamos esto

        // ADDED: Listener para interrupción inmediata si el juego termina mientras estamos aquí
        gameProvider.addListener(_onGameProviderChange);

        // ⚠️ CRÍTICO: Usar .userId, NO .id (que devuelve gamePlayerId)
        final userId = playerProvider.currentPlayer?.userId;

        // 1. PASAR EL userId ES VITAL para que se carguen las 2 vidas reales
        await gameProvider.fetchClues(
          eventId: widget.eventId,
          userId: userId, // ✅ Ahora usa el userId correcto de la tabla profiles
        );

        // 2. LUEGO comprobar si la carrera ya terminó en el servidor
        await gameProvider.checkRaceStatus();

        // 3. Si ya terminó GLOBALMENTE, redirigir a Winner
        if (gameProvider.isRaceCompleted && mounted) {
          _navigateToWinnerScreen();
          return;
        }

        // 3.5 Si NO terminó globalmente, pero YO ya terminé todo -> Waiting Room
        if (gameProvider.hasCompletedAllClues && mounted) {
           _navigateToWaitingRoom();
           return;
        }

        // 4. FINALMENTE iniciar el polling de ranking
        gameProvider.startLeaderboardUpdates();

        // 5. SHIELD CONSISTENCY FIX: Iniciar escucha de eventos de poderes
        final powerEffectProvider = Provider.of<PowerEffectProvider>(context, listen: false);
        final gamePlayerId = playerProvider.currentPlayer?.gamePlayerId;
        
        if (gamePlayerId != null) {
          debugPrint("🛡️ CluesScreen: Initializing PowerEffectProvider for $gamePlayerId");
          powerEffectProvider.startListening(gamePlayerId, eventId: widget.eventId);
        } else {
           debugPrint("⚠️ CluesScreen: gamePlayerId is NULL. Attempting to sync inventory to recover it...");
           // Intento de recuperación: Sync de inventario trae el ID
           await playerProvider.syncRealInventory(effectProvider: powerEffectProvider);
        }
      }
    });
  }

  @override
  void dispose() {
    // Importante: Eliminar listener y detener actualizaciones al salir
    // Use stored reference to avoid unsafe Provider.of during dispose
    _gameProviderRef?.removeListener(_onGameProviderChange);
    _gameProviderRef?.stopLeaderboardUpdates();
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

  bool _isNavigating = false;

  void _navigateToWinnerScreen(
      {bool clearStack = false, int? prizeAmount}) async {
    if (_isNavigating) return; // Prevent double navigation
    _isNavigating = true;

    final gameProvider = Provider.of<GameProvider>(context, listen: false);
    final playerProvider = Provider.of<PlayerProvider>(context, listen: false);

    // Show loading dialog
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(
        child: CircularProgressIndicator(),
      ),
    );

    debugPrint("🏆 Navigating to Winner Screen... Syncing Wallet...");

    // Wait for UI to sync (short delay)
    await Future.delayed(const Duration(seconds: 2));

    // Forzar recarga del perfil (Wallet)
    debugPrint(
        "📊 Balance BEFORE reload: ${playerProvider.currentPlayer?.clovers}");
    await playerProvider.reloadProfile();
    debugPrint(
        "🏆 Wallet Synced. New Balance: ${playerProvider.currentPlayer?.clovers}");

    // Get prize: use parameter first, fallback to GameProvider, then persistence
    int? prizeWon = prizeAmount ?? gameProvider.currentPrizeWon;

    // If still null, try loading from persistence
    if (prizeWon == null && widget.eventId != null) {
      final prefs = await SharedPreferences.getInstance();
      prizeWon = prefs.getInt('prize_won_${widget.eventId}');
      debugPrint("🏆 Prize loaded from persistence: $prizeWon");
    }

    debugPrint("🏆 Prize to Pass: $prizeWon");
    debugPrint(
        "📊 Current Leaderboard Size: ${gameProvider.leaderboard.length}");
    if (gameProvider.leaderboard.isNotEmpty) {
      debugPrint(
          "📊 Top 3: ${gameProvider.leaderboard.take(3).map((p) => '${p.name} (${p.totalXP} XP)').join(', ')}");
    }

    // PERSIST PRIZE AMOUNT for later retrieval
    if (prizeWon != null && prizeWon > 0) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt('prize_won_${widget.eventId}', prizeWon);
      debugPrint("💾 Prize persisted: $prizeWon for event ${widget.eventId}");
    } else {
      debugPrint("⚠️ No prize to persist (prizeWon=$prizeWon)");
    }

    if (!mounted) return;

    // Cerrar diálogo de carga
    Navigator.pop(context);

    // Calculates position locally as a fallback
    final position = _getPlayerPosition();
    final completedClues = gameProvider.completedClues;
    debugPrint(
        "🎯 Calculated position: $position (from leaderboard size: ${gameProvider.leaderboard.length})");

    final route = MaterialPageRoute(
      builder: (_) => WinnerCelebrationScreen(
        eventId: widget.eventId,
        playerPosition: position,
        totalCluesCompleted: completedClues,
        prizeWon: prizeWon, // PASS PRIZE CORRECTLY
      ),
    );

    if (clearStack) {
      // Si es interrupción forzada, borramos TODO el historial
      Navigator.of(context).pushAndRemoveUntil(route, (route) => false);
    } else {
      // Reemplazo normal
      Navigator.of(context).pushReplacement(route);
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

  void _navigateToWaitingRoom() {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => WaitingRoomScreen(eventId: widget.eventId),
      ),
    );
  }

  // NUEVO MÉTODO: Muestra la pista en modo "Solo Lectura"
  void _showCompletedClueDialog(BuildContext context, dynamic clue) {
    final isDarkMode = true /* always dark UI */;
    final Color currentCard = isDarkMode ? AppTheme.dSurface1 : AppTheme.lSurface1;
    final Color currentText = isDarkMode ? Colors.white : const Color(0xFF1A1A1D);

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A1D),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
          side: const BorderSide(color: AppTheme.secondaryPink, width: 1.5),
        ),
        title: Text(clue.title ?? 'Pista Completada', 
          style: const TextStyle(color: Colors.white, fontFamily: 'Orbitron', fontWeight: FontWeight.bold, fontSize: 18)),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                "¡Ya completaste este desafío!",
                style: TextStyle(fontWeight: FontWeight.bold, color: Colors.green, fontSize: 14),
              ),
              const SizedBox(height: 12),
              Text(clue.description ?? 'Sin descripción', 
                style: const TextStyle(color: Colors.white70, fontSize: 13)),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("CERRAR", style: TextStyle(color: AppTheme.secondaryPink, fontWeight: FontWeight.bold)),
          )
        ],
      ),
    );
  }

  // REMOVED: _handleClueAction - Now using ClueActionHandler.handle() or ClueNavigatorService
  // The executeAction method was removed from Clue model to comply with SRP.

  // Estado local para recordar qué pistas ya se escanearon en esta sesión
  final Set<String> _scannedClues = {};

  @override
  Widget build(BuildContext context) {
    final gameProvider = Provider.of<GameProvider>(context);
    final isDarkMode = Provider.of<PlayerProvider>(context).isDarkMode;
    final Color currentText = Colors.white; // Reverted to dark theme colors
    final Color currentTextSec = Colors.white70;

    return ExitProtectionWrapper(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: AnimatedCyberBackground(
          child: Stack(
            children: [
              Positioned.fill(
                child: Image.asset(
                  isDarkMode ? 'assets/images/fotogrupalnoche.png' : 'assets/images/personajesgrupal.png',
                  fit: BoxFit.cover,
                  alignment: Alignment.center,
                ),
              ),
              SafeArea(
                child: Column(
                children: [
                  SafeArea(
                    bottom: false,
                    child: Container(),
                  ),
                  const ProgressHeader(),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Consumer<GameProvider>(
                      builder: (context, game, _) {
                        return RaceTrackWidget(
                          leaderboard: game.leaderboard,
                          currentPlayerId:
                              Provider.of<PlayerProvider>(context, listen: false)
                                      .currentPlayer
                                      ?.userId ??
                                  '',
                          totalClues: game.clues.length,
                        );
                      },
                    ),
                  ),
                  Expanded(
                    child: gameProvider.isLoading
                        ? Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const CircularProgressIndicator(color: AppTheme.accentGold),
                                const SizedBox(height: 16),
                                Text(
                                  'Cargando...',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    shadows: [
                                      Shadow(color: AppTheme.accentGold.withOpacity(0.5), blurRadius: 10),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          )
                        : gameProvider.errorMessage != null
                            ? Center(
                                child: SingleChildScrollView(
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      const Icon(Icons.error_outline,
                                          size: 60, color: Colors.red),
                                      const SizedBox(height: 16),
                                      Text(
                                        'Error al cargar pistas',
                                        style: Theme.of(context).textTheme.titleLarge,
                                      ),
                                      const SizedBox(height: 8),
                                      Padding(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 32),
                                        child: Text(
                                          gameProvider.errorMessage!,
                                          textAlign: TextAlign.center,
                                          style: TextStyle(color: currentTextSec),
                                        ),
                                      ),
                                      const SizedBox(height: 24),
                                      ElevatedButton(
                                        onPressed: () => gameProvider.fetchClues(
                                            eventId: widget.eventId),
                                        child: const Text('Reintentar'),
                                      ),
                                    ],
                                  ),
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
                                          color: currentText.withOpacity(0.2),
                                        ),
                                        const SizedBox(height: 20),
                                        Text(
                                          'No hay pistas disponibles',
                                          style: Theme.of(context)
                                              .textTheme
                                              .headlineMedium
                                              ?.copyWith(
                                                color: currentTextSec,
                                              ),
                                        ),
                                        const SizedBox(height: 10),
                                        ElevatedButton(
                                          onPressed: () {
                                            gameProvider.fetchClues(
                                                eventId: widget.eventId);
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
                                      final int currentIndex =
                                          gameProvider.currentClueIndex;
                                      final bool isPast = index < currentIndex;
                                      final bool isFuture = index > currentIndex;
                                      final bool isCurrent = index == currentIndex;

                                      if (isCurrent) {
                                        debugPrint(
                                            "DEBUG: Clue $index (Current) - isLocked: ${clue.isLocked}, isCompleted: ${clue.isCompleted}, scanned: ${_scannedClues.contains(clue.id)}");
                                      }

                                      final bool showLockIcon =
                                          isFuture || (isCurrent && clue.isLocked);

                                      return ClueCard(
                                        clue: clue,
                                        isLocked: showLockIcon,
                                        onTap: () async {
                                          if (isFuture) {
                                            ScaffoldMessenger.of(context)
                                                .showSnackBar(
                                              const SnackBar(
                                                  content: Text(
                                                      "Debes completar la pista anterior primero.")),
                                            );
                                            return;
                                          }

                                          if (isPast ||
                                              (isCurrent && clue.isCompleted)) {
                                            _showCompletedClueDialog(context, clue);
                                            return;
                                          }

                                          if (isCurrent) {
                                            final player =
                                                Provider.of<PlayerProvider>(context,
                                                        listen: false)
                                                    .currentPlayer;
                                            final gameProvider =
                                                Provider.of<GameProvider>(context,
                                                    listen: false);

                                            if (player?.role == 'spectator') {
                                              Navigator.push(
                                                context,
                                                MaterialPageRoute(
                                                    builder: (_) =>
                                                        PuzzleScreen(clue: clue)),
                                              );
                                              return;
                                            }

                                            if ((player?.lives ?? 0) <= 0 ||
                                                gameProvider.lives <= 0) {
                                              Navigator.push(
                                                  context,
                                                  MaterialPageRoute(
                                                      builder: (_) => const Scaffold(
                                                          backgroundColor:
                                                              Colors.black,
                                                          body: NoLivesWidget())));
                                              return;
                                            }

                                            ClueNavigatorService.navigateToClue(
                                                context, clue);
                                          }
                                        },
                                      );
                                    },
                                  ),
                  ),
                ],
              ),
            ),
            ],
          ),
        ),
      ),
    );
  }

  // --- NUEVO DIÁLOGO DE DESBLOQUEO ---
  void _showUnlockClueDialog(BuildContext context, Clue clue) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A1D),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
          side: const BorderSide(color: AppTheme.secondaryPink, width: 1.5),
        ),
        title: const Row(
          children: [
            Icon(Icons.lock_open_rounded, color: AppTheme.secondaryPink),
            SizedBox(width: 12),
            Text(
              "DESBLOQUEAR",
              style: TextStyle(
                color: Colors.white,
                fontFamily: 'Orbitron',
                fontWeight: FontWeight.bold,
                fontSize: 18,
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              "Para acceder a esta misión, debes encontrar el código QR en la ubicación real.",
              style: TextStyle(color: Colors.white70, fontSize: 13),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.secondaryPink,
                  foregroundColor: Colors.black,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  elevation: 0,
                ),
                onPressed: () async {
                  final isAutoUnlocked = await clue.checkUnlockRequirements();
                  if (isAutoUnlocked) {
                    Navigator.pop(context);
                    _unlockAndProceed(clue);
                    return;
                  }
                  Navigator.pop(context);
                  final scannedCode = await Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const QRScannerScreen()),
                  );
                  if (scannedCode != null) {
                    if (scannedCode.toString().contains(clue.id) ||
                        scannedCode.toString().startsWith("CLUE:") ||
                        scannedCode.toString() == "DEV_SKIP_CODE") {
                      _unlockAndProceed(clue);
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text("Código QR incorrecto para esta misión."),
                        ),
                      );
                    }
                  }
                },
                icon: const Icon(Icons.qr_code_scanner),
                label: const Text(
                  "ESCANEAR QR",
                  style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 1.0),
                ),
              ),
            ),
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
    ClueNavigatorService.navigateToClue(context, clue);
  }
}
