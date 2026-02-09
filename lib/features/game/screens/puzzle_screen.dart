import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/game_provider.dart';
import '../../auth/providers/player_provider.dart';
import '../../../core/theme/app_theme.dart';
import '../models/clue.dart';
import '../widgets/race_track_widget.dart';
import '../../../shared/widgets/sabotage_overlay.dart';
import '../../../shared/models/player.dart'; // Import Player model
import '../providers/connectivity_provider.dart';
import '../../mall/models/power_item.dart';
import '../widgets/effects/blur_effect.dart';
import '../providers/power_interfaces.dart';
// --- Imports de Minijuegos Existentes ---
import '../widgets/minigames/sliding_puzzle_minigame.dart';
import '../widgets/minigames/tic_tac_toe_minigame.dart';
import '../widgets/minigames/hangman_minigame.dart';

// --- Imports de NUEVOS Minijuegos ---
import '../widgets/minigames/tetris_minigame.dart';
import '../widgets/effects/shield_badge.dart'; // NEW IMPORT
import '../widgets/minigames/find_difference_minigame.dart';
import '../widgets/minigames/flags_minigame.dart';
import '../widgets/minigames/minesweeper_minigame.dart';
import '../widgets/minigames/snake_minigame.dart';
import '../widgets/minigames/block_fill_minigame.dart';
import '../widgets/minigames/code_breaker_widget.dart';
import '../widgets/minigames/image_trivia_widget.dart';
import '../widgets/minigames/word_scramble_widget.dart';
import '../widgets/minigame_countdown_overlay.dart';
import 'scenarios_screen.dart';
import '../../game/providers/game_request_provider.dart';

// --- Import del Servicio de Penalización ---
import '../../mall/screens/mall_screen.dart';
import '../utils/minigame_logic_helper.dart';
import 'winner_celebration_screen.dart';
import '../widgets/animated_lives_widget.dart';
import '../widgets/loss_flash_overlay.dart';
import '../widgets/success_celebration_dialog.dart';
import '../../../shared/widgets/time_stamp_animation.dart';

import '../../../shared/widgets/animated_cyber_background.dart';
import '../../../shared/widgets/loading_indicator.dart';
import '../widgets/no_lives_widget.dart';

class PuzzleScreen extends StatefulWidget {
  final Clue clue;

  const PuzzleScreen({super.key, required this.clue});

  @override
  State<PuzzleScreen> createState() => _PuzzleScreenState();
}

class _PuzzleScreenState extends State<PuzzleScreen> {
  // PenaltyService removed as requested
  bool _legalExit = false;
  bool _isNavigatingToWinner = false; // Flag to prevent double navigation
  bool _showBriefing = false; // Deshabilitado como se solicitó
  
  // Safe Provider Access
  late GameProvider _gameProvider;
  late ConnectivityProvider _connectivityProvider; 
  bool _isActive = true;

  @override
  void initState() {
    super.initState();
    // Cache provider for safe disposal
    _gameProvider = Provider.of<GameProvider>(context, listen: false);
    _connectivityProvider = Provider.of<ConnectivityProvider>(context, listen: false);

    // Penalty logic removed
    
    // Verificar vidas al iniciar
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkLives();
      _checkBanStatus(); // Check ban on entry

      // --- SYNC PLAYER PROVIDER WITH CURRENT EVENT ---
      // Fix for issue where PlayerProvider loads "latest" (potentially banned) event 
      // instead of the current active event.
      final gameProvider = Provider.of<GameProvider>(context, listen: false);
      final playerProvider = Provider.of<PlayerProvider>(context, listen: false);
      final eventId = gameProvider.currentEventId;
      
      if (eventId != null && playerProvider.currentPlayer != null) {
         // Sync strict: If IDs don't match, force refresh for THIS event
         if (playerProvider.currentPlayer?.currentEventId != eventId) {
             debugPrint("PuzzleScreen: Syncing PlayerProvider to event $eventId...");
             playerProvider.refreshProfile(eventId: eventId);
         }
      }

      // --- MARCAR ENTRADA A MINIJUEGO PARA CONNECTIVITY ---
      if (eventId != null) {
          context.read<ConnectivityProvider>().enterMinigame(eventId);
      }

      // --- ESCUCHA DE FIN DE CARRERA EN TIEMPO REAL ---
      // --- ESCUCHA DE FIN DE CARRERA EN TIEMPO REAL ---
      Provider.of<GameProvider>(context, listen: false)
          .addListener(_checkRaceCompletion);
      
      // MOVED: _checkGlobalLivesGameOver monitoring is now started inside _checkLives
      // to avoid race conditions during initialization.
    });
  }

  /// Begins monitoring global lives for in-game changes.
  /// This should only be called AFTER we have verified the user has lives to start with.
  void _startLivesMonitoring() {
    if (!mounted) return;
    try {
      final gameProvider = Provider.of<GameProvider>(context, listen: false);
      // Remove first just in case to avoid duplicates
      gameProvider.removeListener(_checkGlobalLivesGameOver);
      gameProvider.addListener(_checkGlobalLivesGameOver);
    } catch (e) {
      debugPrint("Error starting lives monitoring: $e");
    }
  }

  /// Monitorea si las vidas globales llegan a 0 durante el juego.
  /// Si detecta 0 vidas (por ej. Life Steal enemigo), cierra el minijuego.
  void _checkGlobalLivesGameOver() {
    if (!mounted || !_isActive || _legalExit) return;
    
    // Use stored provider or safely access context if active
    final gameProvider = _gameProvider;
    
    // Si las vidas globales llegaron a 0, forzar salida
    if (gameProvider.lives <= 0) {
      debugPrint('[LIVES_MONITOR] 🔴 Global lives reached 0. Forcing minigame exit.');
      _finishLegally(); // Marcar como salida legal para evitar penalización
      
      if (!mounted) return;
      
      // Mostrar diálogo explicativo
      // Mostrar diálogo explicativo
      // showDialog(
      //   context: context,
      //   barrierDismissible: false,
      //   builder: (ctx) => AlertDialog(
      //     backgroundColor: AppTheme.cardBg,
      //     title: const Text('¡Sin Vidas!', style: TextStyle(color: Colors.white)),
      //     content: const Text(
      //       'Te has quedado sin vidas. No puedes continuar en este minijuego.',
      //       style: TextStyle(color: Colors.white70),
      //     ),
      //     actions: [
      //       ElevatedButton(
      //         onPressed: () {
      //           Navigator.pop(ctx); // Cerrar diálogo
      //           if (mounted) {
      //             Navigator.pop(context); // Cerrar minijuego
      //           }
      //         },
      //         style: ElevatedButton.styleFrom(backgroundColor: AppTheme.dangerRed),
      //         child: const Text('Entendido'),
      //       ),
      //     ],
      //   ),
      // );
    }
  }

  void _checkRaceCompletion() async {
    if (!mounted || !_isActive || _isNavigatingToWinner) return;
    
    final gameProvider = _gameProvider;
    // For PlayerProvider, we still need context or also cache it? 
    // Usually PlayerProvider is less volatile, but to be safe we check active first.
    // Since we returned if !_isActive, access to context should be 'safer', 
    // but caching is best. For now we rely on _isActive check.
    if (!context.mounted) return;
    final playerProvider = Provider.of<PlayerProvider>(context, listen: false);

    // Si la carrera terminó (alguien ganó) y yo no he terminado todo
    if (gameProvider.isRaceCompleted && !gameProvider.hasCompletedAllClues) {
      _isNavigatingToWinner = true; // Set flag
      _finishLegally(); // Quitamos penalización

      final currentPlayerId = playerProvider.currentPlayer?.id ?? '';
      List<Player> leaderboard = gameProvider.leaderboard;

      // Si el leaderboard está vacío, intentamos traerlo una vez más para asegurar la posición
      if (leaderboard.isEmpty) {
        await gameProvider.fetchLeaderboard(silent: true);
        leaderboard = gameProvider.leaderboard;
      }

      int position = 0; // Default to 0 (Unranked) instead of 1
      if (leaderboard.isNotEmpty) {
        final index = leaderboard.indexWhere((p) => p.id == currentPlayerId);
        position = index >= 0 ? index + 1 : leaderboard.length + 1;
      } else {
        // Fallback si falla todo: Posición muy alta para no decir "Campeón"
        position = 999;
      }

      if (!mounted) return;

      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(
          builder: (_) => WinnerCelebrationScreen(
            eventId: gameProvider.currentEventId ?? '',
            playerPosition: position,
            totalCluesCompleted: gameProvider.completedClues,
          ),
        ),
        (route) => route.isFirst,
      );
    }
  }

  // Check for ban status (Per-competition kick)
  Future<void> _checkBanStatus() async {
     final playerProvider = Provider.of<PlayerProvider>(context, listen: false);
     final gameProvider = Provider.of<GameProvider>(context, listen: false);
     final requestProvider = Provider.of<GameRequestProvider>(context, listen: false);

     final userId = playerProvider.currentPlayer?.userId;
     final eventId = gameProvider.currentEventId;

     if (userId != null && eventId != null) {
        final status = await requestProvider.getGamePlayerStatus(userId, eventId);
        if (status == 'banned') {
          if (!mounted) return;
          _handleBanKick();
        }
     }
  }

  void _handleBanKick() {
     // Prevent multiple kicks
     if (_legalExit) return; 
     _legalExit = true; // Treat as exit to prevent loops

     showDialog(
          context: context,
          barrierDismissible: false,
          builder: (ctx) => AlertDialog(
            backgroundColor: AppTheme.cardBg,
            title: const Text('⛔ Acceso Denegado', style: TextStyle(color: AppTheme.dangerRed)),
            content: const Text(
              'Has sido baneado de esta competencia por un administrador.',
              style: TextStyle(color: Colors.white),
            ),
            actions: [
              TextButton(
                  onPressed: () {
                      // Kick to Scenarios Screen (List of competitions)
                      Navigator.of(context).pushAndRemoveUntil(
                          MaterialPageRoute(builder: (_) => ScenariosScreen()),
                          (route) => false 
                      );
                  },
                  child: const Text('Entendido')
              )
            ],
          ),
      );
  }

  Future<void> _checkLives() async {
    // Usamos listen: false para obtener el estado MÁS RECIENTE, no suscribirnos
    final gameProvider = Provider.of<GameProvider>(context, listen: false);
    final playerProvider = Provider.of<PlayerProvider>(context, listen: false);

    // 1. Verificación preliminar con source-of-truth visual (PlayerProvider)
    if (playerProvider.currentPlayer != null && playerProvider.currentPlayer!.lives > 0) {
      // Si el perfil dice que tenemos vidas, CONFIAMOS EN ÉL y no bloqueamos.
      // Solo verificamos si GameProvider está desincronizado
      if (gameProvider.lives <= 0) {
        debugPrint("SYNC: Forzando actualización de vidas en GameProvider...");
        // Intentamos sincronizar pero SIN bloquear UI
        await gameProvider.fetchLives(playerProvider.currentPlayer!.userId);
      }
      
      // Safe to monitor now
      _startLivesMonitoring();
      return; 
    }

    // 2. Si PlayerProvider dice 0 o es null, verificamos con GameProvider (Server)
    if (playerProvider.currentPlayer != null) {
      await gameProvider.fetchLives(playerProvider.currentPlayer!.userId);
      
      // Volvemos a leer PlayerProvider por si acaso se actualizó en background
      final freshPlayerLives = playerProvider.currentPlayer?.lives ?? 0;
      
      if (gameProvider.lives <= 0 && freshPlayerLives <= 0) {
        if (!mounted) return;
        // _showNoLivesDialog();
        // DO NOT start monitoring if we are dead.
      } else {
        debugPrint("SYNC INFO: Vidas encontradas (Game: ${gameProvider.lives}, Player: $freshPlayerLives). Juego permitido.");
        // Lives found, start monitoring
        _startLivesMonitoring();
      }
    }
  }

  // void _showNoLivesDialog() {
  //   showDialog(
  //     context: context,
  //     barrierDismissible: false,
  //     builder: (context) => AlertDialog(
  //       backgroundColor: AppTheme.cardBg,
  //       title: const Text("¡Sin vidas!", style: TextStyle(color: Colors.white)),
  //       content: const Text(
  //           "Te has quedado sin vidas. Necesitas comprar más en la tienda para continuar jugando.",
  //           style: TextStyle(color: Colors.white70)),
  //       actions: [
  //         TextButton(
  //           onPressed: () {
  //             Navigator.pop(context); // Close dialog
  //             Navigator.pop(context); // Close screen
  //           },
  //           child: const Text("Entendido"),
  //         ),
  //         ElevatedButton(
  //           onPressed: () {
  //             Navigator.pop(context); 
  //             Navigator.pop(context);
  //             Navigator.push(context, MaterialPageRoute(builder: (_) => const MallScreen()));
  //           },
  //           style: ElevatedButton.styleFrom(backgroundColor: AppTheme.accentGold),
  //           child: const Text("Comprar Vidas", style: TextStyle(color: Colors.black)),
  //         ),
  //       ],
  //     ),
  //   );
  // }

  @override
  void deactivate() {
    _isActive = false;
    super.deactivate();
  }

  @override
  void dispose() {
    // WidgetsBinding.instance.removeObserver(this); // Removed
    
    // --- MARCAR SALIDA DEL MINIJUEGO PARA CONNECTIVITY ---
    try {
      _connectivityProvider.exitMinigame();
    } catch (_) {}
    
    // Limpiar listener de fin de carrera usando la referencia CACHEADA
    try {
      _gameProvider.removeListener(_checkRaceCompletion);
    } catch (_) {}
    
    // Limpiar listener de monitoreo de vidas
    try {
      _gameProvider.removeListener(_checkGlobalLivesGameOver);
    } catch (_) {}
    
    super.dispose();
  }

  // didChangeAppLifecycleState removed to disable leaver penalty

  // Helper para marcar salida legal (Ganar o Rendirse)
  Future<void> _finishLegally() async {
    setState(() => _legalExit = true);
    // await _penaltyService.markGameFinishedLegally(); // Removed
  }

  @override
  Widget build(BuildContext context) {
    final gameProvider = Provider.of<GameProvider>(context);
    final player = context.watch<PlayerProvider>().currentPlayer;
    final isSpectator = player?.role == 'spectator';

    // --- STATUS OVERLAYS (Handled Globally) ---
    if (isSpectator) {
      // Spectators bypass lives check but see read-only UI
    } else {
      // 2. Si el PlayerProvider (Visual) dice que NO tenemos vidas, bloqueamos INMEDIATAMENTE.
      //    Ya no confiamos ciegamente en el servidor si la UI local dice 0.
      //    La lógica "stricter" solicitada: Si CUALQUIERA dice 0, no pasas.
      bool forcedBlock = false;
      
      // Check Status for realtime kick
      if (player != null && player.status == PlayerStatus.banned) {
         // Schedule kick if not already doing it
         WidgetsBinding.instance.addPostFrameCallback((_) => _checkBanStatus());
         forcedBlock = true; // Block UI
      }

      if (player != null && player.lives <= 0) {
        forcedBlock = true;
      }

      if ((gameProvider.lives <= 0 || forcedBlock) && !_legalExit) {
        // Usar el widget reutilizable que contiene el diseño exacto solicitado
        return const NoLivesWidget();
      }
    }

    Widget gameWidget;
    // Cast seguro solicitado
    final onlineClue = widget.clue is OnlineClue ? widget.clue as OnlineClue : widget.clue;
    // Nota: Si pasamos PhysicalClue, usará el fallback de los getters virtuales.
    
    // Pasamos _finishLegally a TODOS los hijos para que avisen antes de cerrar o ganar
    switch (onlineClue.puzzleType) {
      case PuzzleType.slidingPuzzle:
        gameWidget =
            SlidingPuzzleWrapper(clue: widget.clue, onFinish: _finishLegally);
        break;
      case PuzzleType.ticTacToe:
        gameWidget =
            TicTacToeWrapper(clue: widget.clue, onFinish: _finishLegally);
        break;
      case PuzzleType.hangman:
        gameWidget =
            HangmanWrapper(clue: widget.clue, onFinish: _finishLegally);
        break;
      case PuzzleType.tetris:
        gameWidget = TetrisWrapper(clue: widget.clue, onFinish: _finishLegally);
        break;
      case PuzzleType.findDifference:
        gameWidget =
            FindDifferenceWrapper(clue: widget.clue, onFinish: _finishLegally);
        break;
      case PuzzleType.flags:
        gameWidget = FlagsWrapper(clue: widget.clue, onFinish: _finishLegally);
        break;
      case PuzzleType.minesweeper:
        gameWidget =
            MinesweeperWrapper(clue: widget.clue, onFinish: _finishLegally);
        break;
      case PuzzleType.snake:
        gameWidget = SnakeWrapper(clue: widget.clue, onFinish: _finishLegally);
        break;
      case PuzzleType.blockFill:
        gameWidget =
            BlockFillWrapper(clue: widget.clue, onFinish: _finishLegally);
        break;
      case PuzzleType.codeBreaker:
        gameWidget =
            CodeBreakerWrapper(clue: widget.clue, onFinish: _finishLegally);
        break;
      case PuzzleType.imageTrivia:
        gameWidget =
            ImageTriviaWrapper(clue: widget.clue, onFinish: _finishLegally);
        break;
       case PuzzleType.wordScramble:
        gameWidget =
            WordScrambleWrapper(clue: widget.clue, onFinish: _finishLegally);
        break;
      default:
        gameWidget = const Center(child: Text("Minijuego no implementado"));
    }



    // WRAPPER DE SEGURIDAD: Evitar salir sin penalización
    return PopScope(
      canPop: _legalExit || isSpectator,
      onPopInvoked: (didPop) async {
        if (didPop || _legalExit || isSpectator) return;
        
        // Si intenta salir con Back, mostramos el diálogo de rendición (que cobra vida)
        showSkipDialog(context, _finishLegally);
      },
      child: Stack(
        children: [
          IgnorePointer(
            ignoring: isSpectator, // Bloquea interacción con el juego
            child: gameWidget,
          ),
          if (isSpectator)
            Positioned.fill(
              child: Container(
                color: Colors.black.withOpacity(0.1), // Sutil oscurecimiento
              ),
            ),
        ],
      ),
    );
  }
}

// ... (Rest of file content: helper functions and wrappers) ...
// NOTE: I am not replacing the whole file, just the beginning and ending part involving _buildMinigameScaffold
// But replace_file_content does replace whole blocks. I need to be careful.
// Wait, replace_file_content replaces a CONTIGUOUS BLOCK.
// I need to replace from imports to the end of _buildMinigameScaffold if I want to do it all in one go, but the file is large.
// I will use multi_replace_file_content to be safer and precise.

// --- FUNCIONES HELPER GLOBALES ---

void showClueSelector(BuildContext context, Clue currentClue) {
  final gameProvider = Provider.of<GameProvider>(context, listen: false);
  final availableClues = gameProvider.clues.where((c) => !c.isLocked).toList();

  showDialog(
    context: context,
    builder: (context) => AlertDialog(
      backgroundColor: AppTheme.cardBg,
      title: const Text('Cambiar Pista', style: TextStyle(color: Colors.white)),
      content: SizedBox(
        width: double.maxFinite,
        child: ListView.builder(
          shrinkWrap: true,
          itemCount: availableClues.length,
          itemBuilder: (context, index) {
            final clue = availableClues[index];
            final isCurrentClue = clue.id == currentClue.id;

            return ListTile(
              leading: Icon(
                clue.isCompleted ? Icons.check_circle : Icons.circle_outlined,
                color: clue.isCompleted
                    ? AppTheme.successGreen
                    : AppTheme.accentGold,
              ),
              title: Text(
                clue.title,
                style: TextStyle(
                  color: isCurrentClue ? AppTheme.secondaryPink : Colors.white,
                  fontWeight:
                      isCurrentClue ? FontWeight.bold : FontWeight.normal,
                ),
              ),
              subtitle: Text(
                clue.description,
                style: const TextStyle(color: Colors.white70, fontSize: 11),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              trailing: isCurrentClue
                  ? const Icon(Icons.arrow_forward,
                      color: AppTheme.secondaryPink)
                  : null,
              onTap: isCurrentClue
                  ? null
                  : () {
                      gameProvider.switchToClue(clue.id);

                      Navigator.pop(context); // Close dialog
                      Navigator.pop(context); // Close current PuzzleScreen

                      // Navigate to new puzzle screen
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => PuzzleScreen(clue: clue),
                        ),
                      );
                    },
            );
          },
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
      ],
    ),
  );
}

/// Diálogo de rendición actualizado para manejar la salida legal
void showSkipDialog(BuildContext context, VoidCallback? onLegalExit) {
  showDialog(
    context: context,
    builder: (dialogContext) => AlertDialog(
      backgroundColor: AppTheme.cardBg,
      title: const Text('¿Rendirse?', style: TextStyle(color: Colors.white)),
      content: const Text(
        '¡Lástima! Si te rindes, NO podrás desbloquear la siguiente pista porque no resolviste este desafío.',
        style: TextStyle(color: Colors.white70),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dialogContext),
          child: const Text('Cancelar'),
        ),
        ElevatedButton(
          onPressed: () async {
            // RENDICIÓN = SALIDA LEGAL
            if (onLegalExit != null) {
              onLegalExit();
            }

            // Usamos dialogContext para cerrar el diálogo
            Navigator.pop(dialogContext); 
            // Usamos context (el argumento original de la función) para cerrar el PuzzleScreen
            if (context.mounted) {
               Navigator.pop(context);
            }

            // Deduct life logic
            final playerProvider =
                Provider.of<PlayerProvider>(context, listen: false);
            final gameProvider =
                Provider.of<GameProvider>(context, listen: false);
            
            if (playerProvider.currentPlayer != null) {
               // USAR HELPER CENTRALIZADO
               await MinigameLogicHelper.executeLoseLife(context);
            }

            // No llamamos a skipCurrentClue(), simplemente salimos.
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text(
                      'Te has rendido (-1 Vida). Puedes volver a intentarlo cuando estés listo.'),
                  backgroundColor: AppTheme.warningOrange,
                  duration: Duration(seconds: 3),
                ),
              );
            }
          },
          style: ElevatedButton.styleFrom(backgroundColor: AppTheme.dangerRed),
          child: const Text('Rendirse'),
        ),
      ],
    ),
  );
}

// --- WIDGETS INTEGRADOS (Con soporte de onFinish) ---

// --- LOGICA DE VICTORIA COMPARTIDA ---

void _showSuccessDialog(BuildContext context, Clue clue) async {
  final gameProvider = Provider.of<GameProvider>(context, listen: false);
  final playerProvider = Provider.of<PlayerProvider>(context, listen: false);
  
  // [FIX] Capturar Navigator ANTES de cualquier operación async
  // Esto garantiza que podamos navegar incluso si el context padre cambia
  final navigator = Navigator.of(context);
  final rootOverlay = Overlay.of(context);

  showDialog(
    context: context,
    barrierDismissible: false,
    builder: (ctx) => const Center(
      child: LoadingIndicator(),
    ),
  );

  bool success = false;

  try {
    if (clue.id.startsWith('demo_')) {
      gameProvider.completeLocalClue(clue.id);
      success = true;
    } else {
      debugPrint('--- COMPLETING CLUE: ${clue.id} (XP: ${clue.xpReward}, Coins: ${clue.coinReward}) ---');
      success =
          await gameProvider.completeCurrentClue(clue.riddleAnswer ?? "WIN");
      debugPrint('--- CLUE COMPLETION RESULT: $success ---');
    }
  } catch (e) {
    debugPrint("Error completando pista: $e");
    success = false;
  }

  // [FIX] Cerrar spinner usando navigator capturado
  if (navigator.mounted) {
    navigator.pop();
  }

  if (success) {
    if (playerProvider.currentPlayer != null) {
      debugPrint('--- REFRESHING PROFILE START ---');
      await playerProvider.refreshProfile();
      debugPrint('--- REFRESHING PROFILE END. New Coins: ${playerProvider.currentPlayer?.coins} ---');
    }

    // Check if race was completed or if player completed all clues
    if (gameProvider.isRaceCompleted || gameProvider.hasCompletedAllClues) {
      // Get player position
      int playerPosition = 0; // Default 0
      final currentPlayerId = playerProvider.currentPlayer?.id ?? '';

      if (gameProvider.leaderboard.isNotEmpty) {
        final index =
            gameProvider.leaderboard.indexWhere((p) => p.id == currentPlayerId);
        playerPosition =
            index >= 0 ? index + 1 : gameProvider.leaderboard.length + 1;
      } else {
        playerPosition = 999; // Safe default
      }

      // Navigate to winner celebration screen using captured navigator
      if (navigator.mounted) {
        navigator.pushAndRemoveUntil(
          MaterialPageRoute(
            builder: (_) => WinnerCelebrationScreen(
              eventId: gameProvider.currentEventId ?? '',
              playerPosition: playerPosition,
              totalCluesCompleted: gameProvider.completedClues,
            ),
          ),
          (route) => route.isFirst,
        );
      }
      return;
    }
  } else {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content:
                Text('Error al guardar el progreso. Verifica tu conexión.'),
            backgroundColor: AppTheme.dangerRed),
      );
    }
    return;
  }

  // [FIX] Verificar navigator en vez de context para robustez
  if (!navigator.mounted) {
    debugPrint('WARN: Navigator not mounted before TimeStampAnimation');
    return;
  }

  // 1. Mostrar la Animación del Sello Temporal
  // [FIX] Usar Completer para asegurar que onComplete se ejecute una sola vez
  bool sealCompleted = false;
  await showGeneralDialog(
    context: context,
    barrierDismissible: false,
    pageBuilder: (dialogContext, _, __) => Scaffold(
      backgroundColor: Colors.black.withOpacity(0.85),
      body: TimeStampAnimation(
        index: ((clue.sequenceIndex - 1) % 9) + 1,
        onComplete: () {
          if (!sealCompleted && dialogContext.mounted) {
            sealCompleted = true;
            Navigator.pop(dialogContext);
          }
        },
      ),
    ),
  );

  // [FIX] ELIMINADO: Early return por context.mounted
  // El diálogo de celebración DEBE mostrarse siempre después del sello
  // Usamos navigator capturado en vez de context

  // 2. Determinar si hay siguiente pista
  final clues = gameProvider.clues;
  final currentIdx = clues.indexWhere((c) => c.id == clue.id);
  Clue? nextClue;
  if (currentIdx != -1 && currentIdx + 1 < clues.length) {
    nextClue = clues[currentIdx + 1];
  }
  final showNextStep = nextClue != null;

  // 3. Mostrar el panel de celebración - OBLIGATORIO después del sello
  // [FIX] Usar navigator capturado para garantizar visualización
  if (!navigator.mounted) {
    debugPrint('WARN: Navigator not mounted for SuccessCelebrationDialog');
    return;
  }

  await showDialog(
    context: navigator.context,
    barrierDismissible: false,
    builder: (dialogContext) => SuccessCelebrationDialog(
      clue: clue,
      showNextStep: showNextStep,
      totalClues: clues.length,
      onMapReturn: () {
        Navigator.of(dialogContext).pop();
        Future.delayed(const Duration(milliseconds: 100), () {
          if (navigator.mounted) {
            navigator.pop();
          }
        });
      },
    ),
  );
}

// --- WRAPPERS ACTUALIZADOS CON ONFINISH ---

class SlidingPuzzleWrapper extends StatelessWidget {
  final Clue clue;
  final VoidCallback onFinish;
  const SlidingPuzzleWrapper(
      {super.key, required this.clue, required this.onFinish});
  @override
  Widget build(BuildContext context) => _buildMinigameScaffold(
      context,
      clue,
      onFinish,
      SlidingPuzzleMinigame(
          clue: clue,
          onSuccess: () {
            onFinish();
            _showSuccessDialog(context, clue);
          }));
}

class TicTacToeWrapper extends StatelessWidget {
  final Clue clue;
  final VoidCallback onFinish;
  const TicTacToeWrapper(
      {super.key, required this.clue, required this.onFinish});
  @override
  Widget build(BuildContext context) => _buildMinigameScaffold(
      context,
      clue,
      onFinish,
      TicTacToeMinigame(
          clue: clue,
          onSuccess: () {
            onFinish();
            _showSuccessDialog(context, clue);
          }));
}

class HangmanWrapper extends StatelessWidget {
  final Clue clue;
  final VoidCallback onFinish;
  const HangmanWrapper({super.key, required this.clue, required this.onFinish});
  @override
  Widget build(BuildContext context) => _buildMinigameScaffold(
      context,
      clue,
      onFinish,
      HangmanMinigame(
          clue: clue,
          onSuccess: () {
            onFinish();
            _showSuccessDialog(context, clue);
          }));
}

class TetrisWrapper extends StatelessWidget {
  final Clue clue;
  final VoidCallback onFinish;
  const TetrisWrapper({super.key, required this.clue, required this.onFinish});
  @override
  Widget build(BuildContext context) => _buildMinigameScaffold(
      context,
      clue,
      onFinish,
      TetrisMinigame(
          clue: clue,
          onSuccess: () {
            onFinish();
            _showSuccessDialog(context, clue);
          }));
}

class FlagsWrapper extends StatelessWidget {
  final Clue clue;
  final VoidCallback onFinish;
  const FlagsWrapper({super.key, required this.clue, required this.onFinish});
  @override
  Widget build(BuildContext context) => _buildMinigameScaffold(
      context,
      clue,
      onFinish,
      FlagsMinigame(
          clue: clue,
          onSuccess: () {
            onFinish();
            _showSuccessDialog(context, clue);
          }));
}

class MinesweeperWrapper extends StatelessWidget {
  final Clue clue;
  final VoidCallback onFinish;
  const MinesweeperWrapper(
      {super.key, required this.clue, required this.onFinish});
  @override
  Widget build(BuildContext context) => _buildMinigameScaffold(
      context,
      clue,
      onFinish,
      MinesweeperMinigame(
          clue: clue,
          onSuccess: () {
            onFinish();
            _showSuccessDialog(context, clue);
          }));
}

class SnakeWrapper extends StatelessWidget {
  final Clue clue;
  final VoidCallback onFinish;
  const SnakeWrapper({super.key, required this.clue, required this.onFinish});
  @override
  Widget build(BuildContext context) => _buildMinigameScaffold(
      context,
      clue,
      onFinish,
      SnakeMinigame(
          clue: clue,
          onSuccess: () {
            onFinish();
            _showSuccessDialog(context, clue);
          }));
}

class BlockFillWrapper extends StatelessWidget {
  final Clue clue;
  final VoidCallback onFinish;
  const BlockFillWrapper(
      {super.key, required this.clue, required this.onFinish});
  @override
  Widget build(BuildContext context) => _buildMinigameScaffold(
      context,
      clue,
      onFinish,
      BlockFillMinigame(
          clue: clue,
          onSuccess: () {
            onFinish();
            _showSuccessDialog(context, clue);
          }));
}

// Para FindDifference, asumo que existe un wrapper similar o debes crearlo si no existe en el archivo original
class FindDifferenceWrapper extends StatelessWidget {
  final Clue clue;
  final VoidCallback onFinish;
  const FindDifferenceWrapper(
      {super.key, required this.clue, required this.onFinish});
  @override
  Widget build(BuildContext context) => _buildMinigameScaffold(
      context,
      clue,
      onFinish,
      FindDifferenceMinigame(
          clue: clue,
          onSuccess: () {
            onFinish();
            _showSuccessDialog(context, clue);
          }));
}

class CodeBreakerWrapper extends StatelessWidget {
  final Clue clue;
  final VoidCallback onFinish;
  const CodeBreakerWrapper(
      {super.key, required this.clue, required this.onFinish});
  @override
  Widget build(BuildContext context) => _buildMinigameScaffold(
      context,
      clue,
      onFinish,
      CodeBreakerWidget(
          clue: clue,
          onSuccess: () {
            onFinish();
            _showSuccessDialog(context, clue);
          }));
}

class ImageTriviaWrapper extends StatelessWidget {
  final Clue clue;
  final VoidCallback onFinish;
  const ImageTriviaWrapper(
      {super.key, required this.clue, required this.onFinish});
  @override
  Widget build(BuildContext context) => _buildMinigameScaffold(
      context,
      clue,
      onFinish,
      ImageTriviaWidget(
          clue: clue,
          onSuccess: () {
            onFinish();
            _showSuccessDialog(context, clue);
          }));
}

class WordScrambleWrapper extends StatelessWidget {
  final Clue clue;
  final VoidCallback onFinish;
  const WordScrambleWrapper(
      {super.key, required this.clue, required this.onFinish});
  @override
  Widget build(BuildContext context) => _buildMinigameScaffold(
      context,
      clue,
      onFinish,
      WordScrambleWidget(
          clue: clue,
          onSuccess: () {
            onFinish();
            _showSuccessDialog(context, clue);
          }));
}

// --- SCAFFOLD COMPARTIDO ACTUALIZADO (Soporta onFinish para Rendición Legal) ---

String _getMinigameInstruction(Clue clue) {
  switch (clue.puzzleType) {
    case PuzzleType.slidingPuzzle:
      return "Ordena los números (1 al 8)";
    case PuzzleType.ticTacToe:
      return "Gana a la Vieja";
    case PuzzleType.hangman:
      return "Adivina la palabra";
    case PuzzleType.tetris:
      return "Completa las líneas";
    case PuzzleType.findDifference:
      return "Encuentra el icono extra y toca ese cuadro";
    case PuzzleType.flags:
      return "Adivina las banderas";
    case PuzzleType.minesweeper:
      return "Limpia las minas";
    case PuzzleType.snake:
      return "Maneja la culebrita";
    case PuzzleType.blockFill:
      return "Rellena los bloques";
    case PuzzleType.codeBreaker:
      return "Descifra el código";
    case PuzzleType.imageTrivia:
      return "Adivina la imagen";
    case PuzzleType.wordScramble:
      return "Ordena las letras";
    default:
      // Si es un tipo estándar, verificamos por el título o descripción
      if (clue.riddleQuestion?.contains("código") ?? false) return "Descifra el código";
      if (clue.minigameUrl != null && clue.minigameUrl!.isNotEmpty) return "Adivina la imagen";
      return "¡Resuelve el desafío!";
  }
}

Widget _buildMinigameScaffold(
    BuildContext context, Clue clue, VoidCallback onFinish, Widget child) {
  final player = Provider.of<PlayerProvider>(context).currentPlayer;

  // Envolvemos el minijuego en el countdown
  final instruction = _getMinigameInstruction(clue);
  final wrappedChild = MinigameCountdownOverlay(
    instruction: instruction,
    child: child,
  );

  return SabotageOverlay(
    child: Scaffold(
      backgroundColor: Colors.transparent,
      body: Container(
        decoration: const BoxDecoration(
          gradient: AppTheme.darkGradient,
        ),
        child: SafeArea(
          child: Consumer<GameProvider>(
            builder: (context, game, _) {
              return Stack(
                children: [
                  Column(
                    children: [
                       // AppBar Personalizado
                      Padding(
                        padding: const EdgeInsets.all(12),
                        child: Row(
                          children: [
                            if (player?.role == 'spectator')
                              IconButton(
                                icon: const Icon(Icons.arrow_back, color: Colors.white),
                                onPressed: () => Navigator.pop(context),
                              ),
                            const Spacer(),

                            if (player?.role != 'spectator') ...[
                              // INDICADOR DE VIDAS CON ANIMACIÓN
                              const ShieldBadge(), // NEW SHIELD WIDGET
                            AnimatedLivesWidget(),
                              const SizedBox(width: 10),

                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: AppTheme.accentGold.withOpacity(0.2),
                                  borderRadius: BorderRadius.circular(15),
                                  border: Border.all(color: AppTheme.accentGold),
                                ),
                                child: Row(
                                  children: [
                                    const Icon(Icons.star,
                                        color: AppTheme.accentGold, size: 12),
                                    const SizedBox(width: 4),
                                    Text(
                                      '+${clue.xpReward} XP',
                                      style: const TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 10),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 8),
                              IconButton(
                                icon: const Icon(Icons.flag,
                                    color: AppTheme.dangerRed, size: 20),
                                tooltip: 'Rendirse',
                                onPressed: () =>
                                    showSkipDialog(context, onFinish),
                              ),
                            ] else
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                decoration: BoxDecoration(
                                  color: Colors.blue.withOpacity(0.2),
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(color: Colors.blueAccent),
                                ),
                                child: const Row(
                                  children: [
                                    Icon(Icons.visibility, color: Colors.blueAccent, size: 14),
                                    SizedBox(width: 6),
                                    Text(
                                      'MODO ESPECTADOR',
                                      style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                                    ),
                                  ],
                                ),
                              ),
                          ],
                        ),
                      ),

                      // Mapa de Progreso
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: RaceTrackWidget(
                          leaderboard: game.leaderboard,
                          currentPlayerId: player?.id ?? '',
                          totalClues: game.clues.length,
                          onSurrender: () => showSkipDialog(context, onFinish),
                          compact: clue.puzzleType == PuzzleType.tetris || clue.puzzleType == PuzzleType.hangman,
                        ),
                      ),

                      const SizedBox(height: 10),

                      Expanded(
                        child: IgnorePointer(
                          ignoring: player != null && player.isFrozen,
                          child: wrappedChild, // Usamos el hijo con countdown
                        ),
                      ),
                    ],
                  ),

                  // EFECTO BLUR (Inyectado aquí)
                  // EFECTO BLUR (Inyectado aquí)
                  if (context.watch<PowerEffectReader>().isPowerActive(PowerType.blur))
                    Builder(
                      builder: (context) {
                         final expiry = context.read<PowerEffectReader>().getPowerExpirationByType(PowerType.blur);
                         if (expiry != null) {
                           return Positioned.fill(
                             child: BlurScreenEffect(expiresAt: expiry),
                           );
                         }
                         return const SizedBox.shrink();
                      }
                    ),

                  // Efecto Visual de Daño (Flash Rojo) al perder vida
                  LossFlashOverlay(lives: game.lives),
                ],
              );
            },
          ),
        ),
      ),
    ),
  );
}

// --- WIDGETS DE SOPORTE PARA ANIMACIONES MOVIDOS A ARCHIVOS EXTERNOS ---
