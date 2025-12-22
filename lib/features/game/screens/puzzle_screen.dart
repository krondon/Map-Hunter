import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/game_provider.dart';
import '../../auth/providers/player_provider.dart';
import '../../../core/theme/app_theme.dart';
import '../models/clue.dart';
import '../widgets/race_track_widget.dart';
import '../../../shared/widgets/sabotage_overlay.dart';
import '../../../shared/models/player.dart'; // Import Player model

// --- Imports de Minijuegos Existentes ---
import '../widgets/minigames/sliding_puzzle_minigame.dart';
import '../widgets/minigames/tic_tac_toe_minigame.dart';
import '../widgets/minigames/hangman_minigame.dart';

// --- Imports de NUEVOS Minijuegos ---
import '../widgets/minigames/tetris_minigame.dart';
import '../widgets/minigames/find_difference_minigame.dart';
import '../widgets/minigames/flags_minigame.dart';
import '../widgets/minigames/minesweeper_minigame.dart';
import '../widgets/minigames/snake_minigame.dart';
import '../widgets/minigames/block_fill_minigame.dart';
import '../widgets/minigame_countdown_overlay.dart';

// --- Import del Servicio de Penalización ---
import '../services/penalty_service.dart';
import 'winner_celebration_screen.dart';
import '../widgets/animated_lives_widget.dart';
import '../widgets/loss_flash_overlay.dart';
import '../widgets/success_celebration_dialog.dart';

class PuzzleScreen extends StatefulWidget {
  final Clue clue;

  const PuzzleScreen({super.key, required this.clue});

  @override
  State<PuzzleScreen> createState() => _PuzzleScreenState();
}

class _PuzzleScreenState extends State<PuzzleScreen>
    with WidgetsBindingObserver {
  final PenaltyService _penaltyService = PenaltyService();
  bool _legalExit = false;
  bool _isNavigatingToWinner = false; // Flag to prevent double navigation

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // Bandera arriba: El jugador está intentando jugar.
    // Si sale sin _finishLegally, el servicio sabrá que fue un abandono forzoso.
    _penaltyService.attemptStartGame();

    // Verificar vidas al iniciar
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkLives();

      // --- ESCUCHA DE FIN DE CARRERA EN TIEMPO REAL ---
      Provider.of<GameProvider>(context, listen: false)
          .addListener(_checkRaceCompletion);
    });
  }

  void _checkRaceCompletion() async {
    if (!mounted || _isNavigatingToWinner) return;
    final gameProvider = Provider.of<GameProvider>(context, listen: false);
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

  Future<void> _checkLives() async {
    final gameProvider = Provider.of<GameProvider>(context, listen: false);
    final playerProvider = Provider.of<PlayerProvider>(context, listen: false);

    if (playerProvider.currentPlayer != null) {
      await gameProvider.fetchLives(playerProvider.currentPlayer!.id);
      if (gameProvider.lives <= 0) {
        if (!mounted) return;
        _showNoLivesDialog();
      }
    }
  }

  void _showNoLivesDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.cardBg,
        title: const Text("¡Sin vidas!", style: TextStyle(color: Colors.white)),
        content: const Text(
            "Te has quedado sin vidas. Necesitas comprar más en la tienda para continuar jugando.",
            style: TextStyle(color: Colors.white70)),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context); // Close dialog
              Navigator.pop(context); // Close screen
            },
            child: const Text("Entendido"),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    // Limpiar listener de fin de carrera
    try {
      Provider.of<GameProvider>(context, listen: false)
          .removeListener(_checkRaceCompletion);
    } catch (_) {}
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // LEAVER BUSTER: Si minimiza (paused) y no ha salido legalmente, lo sacamos.
    // Esto previene trampas de salir al home del móvil para buscar respuestas.
    if (state == AppLifecycleState.paused && !_legalExit) {
      if (mounted) {
        Navigator.of(context).pop(); // Cierre forzoso = Penalización latente
      }
    }
  }

  // Helper para marcar salida legal (Ganar o Rendirse)
  Future<void> _finishLegally() async {
    _legalExit = true;
    await _penaltyService.markGameFinishedLegally();
  }

  @override
  Widget build(BuildContext context) {
    // TAREA 4: Bloqueo de Acceso si no hay vidas
    final gameProvider = Provider.of<GameProvider>(context);
    // Mantener rebuilds si cambia el perfil del jugador, sin usar la variable.
    final _ = context.watch<PlayerProvider>();

    // --- STATUS OVERLAYS (Handled Globally) ---

    if (gameProvider.lives <= 0) {
      // Retornar contenedor negro con aviso
      // Nota: El diálogo _showNoLivesDialog ya se muestra en initState/checkLives,
      // pero aquí aseguramos que no se renderice el juego.
      return Container(
        color: Colors.black,
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.heart_broken,
                  color: AppTheme.dangerRed, size: 64),
              const SizedBox(height: 20),
              const Text(
                "¡SIN VIDAS!",
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  decoration: TextDecoration.none,
                ),
              ),
              const SizedBox(height: 10),
              const Text(
                "No puedes jugar sin vidas.",
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 16,
                  decoration: TextDecoration.none,
                ),
              ),
              const SizedBox(height: 30),
              ElevatedButton(
                onPressed: () => Navigator.of(context).pop(),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.dangerRed,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 30, vertical: 12),
                ),
                child:
                    const Text("Salir", style: TextStyle(color: Colors.white)),
              ),
            ],
          ),
        ),
      );
    }

    Widget gameWidget;
    // Pasamos _finishLegally a TODOS los hijos para que avisen antes de cerrar o ganar
    switch (widget.clue.puzzleType) {
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
    }

    return gameWidget;
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
    builder: (context) => AlertDialog(
      backgroundColor: AppTheme.cardBg,
      title: const Text('¿Rendirse?', style: TextStyle(color: Colors.white)),
      content: const Text(
        '¡Lástima! Si te rindes, NO podrás desbloquear la siguiente pista porque no resolviste este desafío.',
        style: TextStyle(color: Colors.white70),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        ElevatedButton(
          onPressed: () async {
            // RENDICIÓN = SALIDA LEGAL (Aunque perdedora)
            if (onLegalExit != null) {
              onLegalExit();
            }

            Navigator.pop(context); // Dialog
            Navigator.pop(context); // PuzzleScreen

            // Deduct life logic
            final playerProvider =
                Provider.of<PlayerProvider>(context, listen: false);
            final gameProvider =
                Provider.of<GameProvider>(context, listen: false);
            
            if (playerProvider.currentPlayer != null) {
               await gameProvider.loseLife(playerProvider.currentPlayer!.id);
            }

            // No llamamos a skipCurrentClue(), simplemente salimos.
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text(
                      'Te has rendido. Puedes volver a intentarlo cuando estés listo.'),
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

class CodeBreakerWidget extends StatefulWidget {
  final Clue clue;
  final VoidCallback onFinish;
  const CodeBreakerWidget(
      {super.key, required this.clue, required this.onFinish});

  @override
  State<CodeBreakerWidget> createState() => _CodeBreakerWidgetState();
}

class _CodeBreakerWidgetState extends State<CodeBreakerWidget> {
  String _enteredCode = "";
  bool _isError = false;

  void _onDigitPress(String digit) {
    if (_enteredCode.length < 4) {
      setState(() {
        _enteredCode += digit;
        _isError = false;
      });
    }
  }

  void _onDelete() {
    if (_enteredCode.isNotEmpty) {
      setState(() {
        _enteredCode = _enteredCode.substring(0, _enteredCode.length - 1);
      });
    }
  }

  void _checkCode() {
    final expected = widget.clue.riddleAnswer?.trim() ?? "";
    if (_enteredCode == expected) {
      // ÉXITO: LLAMAR CALLBACK LEGAL
      widget.onFinish();
      _showSuccessDialog(context, widget.clue);
    } else {
      setState(() {
        _isError = true;
        _enteredCode = "";
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('❌ Código Incorrecto'),
          backgroundColor: AppTheme.dangerRed,
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return _buildMinigameScaffold(
      context,
      widget.clue,
      widget.onFinish,
      SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  colors: [
                    AppTheme.primaryPurple.withOpacity(0.3),
                    AppTheme.secondaryPink.withOpacity(0.3)
                  ],
                ),
              ),
              child: const Icon(Icons.lock_outline,
                  size: 35, color: AppTheme.accentGold),
            ),
            const SizedBox(height: 10),
            const Text('CAJA FUERTE',
                style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                    letterSpacing: 2)),
            const SizedBox(height: 8),
            Text(widget.clue.riddleQuestion ?? "Ingresa el código de 4 dígitos",
                style: const TextStyle(color: Colors.white70, fontSize: 12),
                textAlign: TextAlign.center),
            const SizedBox(height: 15),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(4, (index) {
                final hasDigit = index < _enteredCode.length;
                return Container(
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  width: 45,
                  height: 50,
                  decoration: BoxDecoration(
                    color: hasDigit
                        ? AppTheme.successGreen.withOpacity(0.2)
                        : Colors.black.withOpacity(0.3),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                        color: _isError
                            ? AppTheme.dangerRed
                            : (hasDigit ? AppTheme.successGreen : Colors.grey),
                        width: 2),
                  ),
                  child: Center(
                      child: Text(hasDigit ? _enteredCode[index] : '',
                          style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              color: _isError
                                  ? AppTheme.dangerRed
                                  : Colors.white))),
                );
              }),
            ),
            const SizedBox(height: 15),
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                childAspectRatio: 1.5,
                crossAxisSpacing: 10,
                mainAxisSpacing: 10,
              ),
              itemCount: 12,
              itemBuilder: (context, index) {
                if (index == 9)
                  return _buildKey(
                      icon: Icons.backspace_outlined,
                      onTap: _onDelete,
                      color: AppTheme.warningOrange);
                if (index == 10)
                  return _buildKey(text: '0', onTap: () => _onDigitPress('0'));
                if (index == 11)
                  return _buildKey(
                      icon: Icons.check_circle,
                      onTap: _enteredCode.length == 4 ? _checkCode : null,
                      color: AppTheme.successGreen);
                final digit = '${index + 1}';
                return _buildKey(
                    text: digit, onTap: () => _onDigitPress(digit));
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildKey(
      {String? text,
      IconData? icon,
      required VoidCallback? onTap,
      Color? color}) {
    return Material(
      color: AppTheme.cardBg,
      borderRadius: BorderRadius.circular(10),
      elevation: 3,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            gradient: onTap != null
                ? LinearGradient(colors: [
                    AppTheme.primaryPurple.withOpacity(0.2),
                    AppTheme.secondaryPink.withOpacity(0.2)
                  ])
                : null,
          ),
          child: Center(
            child: text != null
                ? Text(text,
                    style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: color ?? Colors.white))
                : Icon(icon, color: color ?? Colors.white, size: 20),
          ),
        ),
      ),
    );
  }
}

class ImageTriviaWidget extends StatefulWidget {
  final Clue clue;
  final VoidCallback onFinish;
  const ImageTriviaWidget(
      {super.key, required this.clue, required this.onFinish});
  @override
  State<ImageTriviaWidget> createState() => _ImageTriviaWidgetState();
}

class _ImageTriviaWidgetState extends State<ImageTriviaWidget> {
  final TextEditingController _controller = TextEditingController();
  bool _showHint = false;

  void _checkAnswer() {
    final userAnswer = _controller.text.trim().toLowerCase();
    final correctAnswer = widget.clue.riddleAnswer?.trim().toLowerCase() ?? "";
    if (userAnswer == correctAnswer ||
        (correctAnswer.isNotEmpty &&
            userAnswer.contains(correctAnswer.split(' ').first))) {
      // ÉXITO: LLAMAR CALLBACK LEGAL
      widget.onFinish();
      _showSuccessDialog(context, widget.clue);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('❌ Incorrecto'), backgroundColor: AppTheme.dangerRed));
    }
  }

  @override
  Widget build(BuildContext context) {
    return _buildMinigameScaffold(
      context,
      widget.clue,
      widget.onFinish,
      SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            const Icon(Icons.image_outlined,
                size: 35, color: AppTheme.secondaryPink),
            const SizedBox(height: 8),
            const Text('DESAFÍO VISUAL',
                style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.white)),
            const SizedBox(height: 15),
            Container(
              decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                        color: AppTheme.primaryPurple.withOpacity(0.5),
                        blurRadius: 15)
                  ]),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.network(
                  widget.clue.minigameUrl ?? 'https://via.placeholder.com/400',
                  height: 180,
                  width: double.infinity,
                  fit: BoxFit.cover,
                  errorBuilder: (ctx, err, stack) => Container(
                      height: 180,
                      color: AppTheme.cardBg,
                      child: const Center(
                          child:
                              Icon(Icons.broken_image, color: Colors.white38))),
                ),
              ),
            ),
            const SizedBox(height: 15),
            Text(widget.clue.riddleQuestion ?? "¿Qué es esto?",
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.bold),
                textAlign: TextAlign.center),
            const SizedBox(height: 12),
            TextField(
              controller: _controller,
              style: const TextStyle(color: Colors.white, fontSize: 14),
              textAlign: TextAlign.center,
              decoration: InputDecoration(
                hintText: 'Tu respuesta...',
                hintStyle: const TextStyle(color: Colors.white38),
                filled: true,
                fillColor: AppTheme.cardBg,
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide.none),
              ),
            ),
            const SizedBox(height: 12),
            if (_showHint)
              Container(
                  padding: const EdgeInsets.all(10),
                  margin: const EdgeInsets.only(bottom: 10),
                  decoration: BoxDecoration(
                      color: AppTheme.accentGold.withOpacity(0.1),
                      border: Border.all(color: AppTheme.accentGold),
                      borderRadius: BorderRadius.circular(8)),
                  child: Text(widget.clue.hint,
                      style: const TextStyle(color: Colors.white70))),
            Row(children: [
              Expanded(
                  child: OutlinedButton(
                      onPressed: () => setState(() => _showHint = !_showHint),
                      child: Text(_showHint ? "Ocultar" : "Pista"))),
              const SizedBox(width: 10),
              Expanded(
                  flex: 2,
                  child: ElevatedButton(
                      onPressed: _checkAnswer,
                      style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.successGreen),
                      child: const Text("VERIFICAR")))
            ]),
          ],
        ),
      ),
    );
  }
}

class WordScrambleWidget extends StatefulWidget {
  final Clue clue;
  final VoidCallback onFinish;
  const WordScrambleWidget(
      {super.key, required this.clue, required this.onFinish});
  @override
  State<WordScrambleWidget> createState() => _WordScrambleWidgetState();
}

class _WordScrambleWidgetState extends State<WordScrambleWidget> {
  late List<String> _shuffledLetters;
  String _currentWord = "";

  @override
  void initState() {
    super.initState();
    final answer = widget.clue.riddleAnswer?.toUpperCase() ?? "TREASURE";
    _shuffledLetters = answer.split('')..shuffle();
  }

  void _onLetterTap(String letter) {
    setState(() {
      _currentWord += letter;
      _shuffledLetters.remove(letter);
    });
  }

  void _onReset() {
    setState(() {
      _currentWord = "";
      _shuffledLetters = (widget.clue.riddleAnswer?.toUpperCase() ?? "TREASURE")
          .split('')
        ..shuffle();
    });
  }

  void _checkAnswer() {
    if (_currentWord == widget.clue.riddleAnswer?.toUpperCase()) {
      // ÉXITO: LLAMAR CALLBACK LEGAL
      widget.onFinish();
      _showSuccessDialog(context, widget.clue);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('❌ Incorrecto'), backgroundColor: AppTheme.dangerRed));
      _onReset();
    }
  }

  @override
  Widget build(BuildContext context) {
    return _buildMinigameScaffold(
      context,
      widget.clue,
      widget.onFinish,
      SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Column(
          children: [
            const Icon(Icons.shuffle, size: 40, color: AppTheme.secondaryPink),
            const SizedBox(height: 8),
            const Text('PALABRA MISTERIOSA',
                style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.white)),
            const SizedBox(height: 15),
            Container(
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 15),
              decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppTheme.accentGold, width: 2)),
              child: Text(
                  _currentWord
                      .padRight(widget.clue.riddleAnswer?.length ?? 8, '_')
                      .split('')
                      .join(' '),
                  style: const TextStyle(
                      color: AppTheme.accentGold,
                      fontSize: 20,
                      letterSpacing: 4,
                      fontWeight: FontWeight.bold)),
            ),
            const SizedBox(height: 20),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              alignment: WrapAlignment.center,
              children: _shuffledLetters
                  .map((letter) => GestureDetector(
                        onTap: () => _onLetterTap(letter),
                        child: Container(
                            width: 45,
                            height: 45,
                            decoration: BoxDecoration(
                                gradient: const LinearGradient(colors: [
                                  AppTheme.primaryPurple,
                                  AppTheme.secondaryPink
                                ]),
                                borderRadius: BorderRadius.circular(8)),
                            child: Center(
                                child: Text(letter,
                                    style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 20,
                                        fontWeight: FontWeight.bold)))),
                      ))
                  .toList(),
            ),
            const SizedBox(height: 20),
            Row(children: [
              Expanded(
                  child: OutlinedButton(
                      onPressed: _onReset, child: const Text("Reiniciar"))),
              const SizedBox(width: 10),
              Expanded(
                  flex: 2,
                  child: ElevatedButton(
                      onPressed: _currentWord.length ==
                              (widget.clue.riddleAnswer?.length ?? 0)
                          ? _checkAnswer
                          : null,
                      style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.successGreen),
                      child: const Text("COMPROBAR"))),
            ]),
          ],
        ),
      ),
    );
  }
}

// --- LOGICA DE VICTORIA COMPARTIDA ---

void _showSuccessDialog(BuildContext context, Clue clue) async {
  final gameProvider = Provider.of<GameProvider>(context, listen: false);
  final playerProvider = Provider.of<PlayerProvider>(context, listen: false);

  showDialog(
    context: context,
    barrierDismissible: false,
    builder: (ctx) => const Center(
      child: CircularProgressIndicator(color: AppTheme.accentGold),
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

  if (context.mounted) {
    Navigator.pop(context);
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

      // Wait for leaderboard if needed? (Cant await easily here without bigger refactor, better safegaurd default)
      if (gameProvider.leaderboard.isNotEmpty) {
        final index =
            gameProvider.leaderboard.indexWhere((p) => p.id == currentPlayerId);
        playerPosition =
            index >= 0 ? index + 1 : gameProvider.leaderboard.length + 1;
      } else {
        playerPosition = 999; // Safe default
      }

      // Navigate to winner celebration screen
      if (context.mounted) {
        // Get event ID from the current clue
        // We need to pass the event ID - assuming we can get it from somewhere
        // For now, navigate with position and completed clues
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(
            builder: (_) => WinnerCelebrationScreen(
              eventId: gameProvider.currentEventId ?? '',
              playerPosition: playerPosition,
              totalCluesCompleted: gameProvider.completedClues,
            ),
          ),
          (route) => route.isFirst, // Remove all routes except first
        );
      }
      return; // Don't show normal success dialog
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

  if (!context.mounted) return;

  final clues = gameProvider.clues;
  final currentIdx = clues.indexWhere((c) => c.id == clue.id);
  Clue? nextClue;
  if (currentIdx != -1 && currentIdx + 1 < clues.length) {
    nextClue = clues[currentIdx + 1];
  }
  final showNextStep = nextClue != null && nextClue.isLocked;

  showDialog(
    context: context,
    barrierDismissible: false,
    builder: (dialogContext) => SuccessCelebrationDialog(
      clue: clue,
      showNextStep: showNextStep,
      onMapReturn: () {
        Navigator.of(dialogContext).pop();
        Future.delayed(const Duration(milliseconds: 100), () {
          if (context.mounted) {
            Navigator.of(context).pop();
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
      body: Container(
        decoration: const BoxDecoration(gradient: AppTheme.darkGradient),
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
                            IconButton(
                              icon: const Icon(Icons.arrow_back,
                                  color: Colors.white, size: 20),
                              onPressed: () => Navigator.pop(context),
                            ),
                            const Spacer(),

                            // INDICADOR DE VIDAS CON ANIMACIÓN
                            AnimatedLivesWidget(lives: game.lives),
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
