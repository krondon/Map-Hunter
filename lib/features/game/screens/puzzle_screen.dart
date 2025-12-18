import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/game_provider.dart';
import '../../auth/providers/player_provider.dart';
import '../../../core/theme/app_theme.dart';
import '../models/clue.dart';
import '../widgets/race_track_widget.dart';
import 'package:confetti/confetti.dart';

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

// --- Import del Servicio de Penalización ---
import '../services/penalty_service.dart';

class PuzzleScreen extends StatefulWidget {
  final Clue clue;

  const PuzzleScreen({super.key, required this.clue});

  @override
  State<PuzzleScreen> createState() => _PuzzleScreenState();
}

class _PuzzleScreenState extends State<PuzzleScreen> with WidgetsBindingObserver {
  final PenaltyService _penaltyService = PenaltyService();
  bool _legalExit = false;

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
    });
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
        content: const Text("Te has quedado sin vidas. Necesitas comprar más en la tienda para continuar jugando.", style: TextStyle(color: Colors.white70)),
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
              const Icon(Icons.heart_broken, color: AppTheme.dangerRed, size: 64),
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
                  padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 12),
                ),
                child: const Text("Salir", style: TextStyle(color: Colors.white)),
              ),
            ],
          ),
        ),
      );
    }

    // Pasamos _finishLegally a TODOS los hijos para que avisen antes de cerrar o ganar
    switch (widget.clue.puzzleType) {

      case PuzzleType.slidingPuzzle:
        return SlidingPuzzleWrapper(clue: widget.clue, onFinish: _finishLegally);
      case PuzzleType.ticTacToe:
        return TicTacToeWrapper(clue: widget.clue, onFinish: _finishLegally);
      case PuzzleType.hangman:
        return HangmanWrapper(clue: widget.clue, onFinish: _finishLegally);
      
      // --- JUEGOS NUEVOS ---
      case PuzzleType.tetris:
        return TetrisWrapper(clue: widget.clue, onFinish: _finishLegally);
      case PuzzleType.findDifference:
        // El wrapper existente debe modificarse para aceptar onFinish o envolverse aquí
        return FindDifferenceWrapper(clue: widget.clue, onFinish: _finishLegally); 
      case PuzzleType.flags:
        return FlagsWrapper(clue: widget.clue, onFinish: _finishLegally);
      case PuzzleType.minesweeper:
        return MinesweeperWrapper(clue: widget.clue, onFinish: _finishLegally);
      case PuzzleType.snake:
        return SnakeWrapper(clue: widget.clue, onFinish: _finishLegally);
      case PuzzleType.blockFill:
        return BlockFillWrapper(clue: widget.clue, onFinish: _finishLegally);
    }
  }
}

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
                color: clue.isCompleted ? AppTheme.successGreen : AppTheme.accentGold,
              ),
              title: Text(
                clue.title,
                style: TextStyle(
                  color: isCurrentClue ? AppTheme.secondaryPink : Colors.white,
                  fontWeight: isCurrentClue ? FontWeight.bold : FontWeight.normal,
                ),
              ),
              subtitle: Text(
                clue.description,
                style: const TextStyle(color: Colors.white70, fontSize: 11),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              trailing: isCurrentClue 
                ? const Icon(Icons.arrow_forward, color: AppTheme.secondaryPink) 
                : null,
              onTap: isCurrentClue ? null : () {
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
            
            final gameProvider = Provider.of<GameProvider>(context, listen: false);
            await gameProvider.skipCurrentClue(); // Lógica de saltar pista en Provider

            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('No se desbloqueó la siguiente pista. Intenta resolver otro desafío.'),
                backgroundColor: AppTheme.warningOrange,
                duration: Duration(seconds: 3),
              ),
            );
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
  const CodeBreakerWidget({super.key, required this.clue, required this.onFinish});

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
                  colors: [AppTheme.primaryPurple.withOpacity(0.3), AppTheme.secondaryPink.withOpacity(0.3)],
                ),
              ),
              child: const Icon(Icons.lock_outline, size: 35, color: AppTheme.accentGold),
            ),
            const SizedBox(height: 10),
            const Text('CAJA FUERTE', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white, letterSpacing: 2)),
            const SizedBox(height: 8),
            Text(widget.clue.riddleQuestion ?? "Ingresa el código de 4 dígitos", style: const TextStyle(color: Colors.white70, fontSize: 12), textAlign: TextAlign.center),
            const SizedBox(height: 15),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(4, (index) {
                final hasDigit = index < _enteredCode.length;
                return Container(
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  width: 45, height: 50,
                  decoration: BoxDecoration(
                    color: hasDigit ? AppTheme.successGreen.withOpacity(0.2) : Colors.black.withOpacity(0.3),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: _isError ? AppTheme.dangerRed : (hasDigit ? AppTheme.successGreen : Colors.grey), width: 2),
                  ),
                  child: Center(child: Text(hasDigit ? _enteredCode[index] : '', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: _isError ? AppTheme.dangerRed : Colors.white))),
                );
              }),
            ),
            const SizedBox(height: 15),
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3, childAspectRatio: 1.5, crossAxisSpacing: 10, mainAxisSpacing: 10,
              ),
              itemCount: 12,
              itemBuilder: (context, index) {
                if (index == 9) return _buildKey(icon: Icons.backspace_outlined, onTap: _onDelete, color: AppTheme.warningOrange);
                if (index == 10) return _buildKey(text: '0', onTap: () => _onDigitPress('0'));
                if (index == 11) return _buildKey(icon: Icons.check_circle, onTap: _enteredCode.length == 4 ? _checkCode : null, color: AppTheme.successGreen);
                final digit = '${index + 1}';
                return _buildKey(text: digit, onTap: () => _onDigitPress(digit));
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildKey({String? text, IconData? icon, required VoidCallback? onTap, Color? color}) {
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
            gradient: onTap != null ? LinearGradient(colors: [AppTheme.primaryPurple.withOpacity(0.2), AppTheme.secondaryPink.withOpacity(0.2)]) : null,
          ),
          child: Center(
            child: text != null
                ? Text(text, style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: color ?? Colors.white))
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
  const ImageTriviaWidget({super.key, required this.clue, required this.onFinish});
  @override
  State<ImageTriviaWidget> createState() => _ImageTriviaWidgetState();
}

class _ImageTriviaWidgetState extends State<ImageTriviaWidget> {
  final TextEditingController _controller = TextEditingController();
  bool _showHint = false;

  void _checkAnswer() {
    final userAnswer = _controller.text.trim().toLowerCase();
    final correctAnswer = widget.clue.riddleAnswer?.trim().toLowerCase() ?? "";
    if (userAnswer == correctAnswer || (correctAnswer.isNotEmpty && userAnswer.contains(correctAnswer.split(' ').first))) {
      // ÉXITO: LLAMAR CALLBACK LEGAL
      widget.onFinish();
      _showSuccessDialog(context, widget.clue);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('❌ Incorrecto'), backgroundColor: AppTheme.dangerRed));
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
            const Icon(Icons.image_outlined, size: 35, color: AppTheme.secondaryPink),
            const SizedBox(height: 8),
            const Text('DESAFÍO VISUAL', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
            const SizedBox(height: 15),
            Container(
              decoration: BoxDecoration(borderRadius: BorderRadius.circular(12), boxShadow: [BoxShadow(color: AppTheme.primaryPurple.withOpacity(0.5), blurRadius: 15)]),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.network(
                  widget.clue.minigameUrl ?? 'https://via.placeholder.com/400',
                  height: 180, width: double.infinity, fit: BoxFit.cover,
                  errorBuilder: (ctx, err, stack) => Container(height: 180, color: AppTheme.cardBg, child: const Center(child: Icon(Icons.broken_image, color: Colors.white38))),
                ),
              ),
            ),
            const SizedBox(height: 15),
            Text(widget.clue.riddleQuestion ?? "¿Qué es esto?", style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold), textAlign: TextAlign.center),
            const SizedBox(height: 12),
            TextField(
              controller: _controller,
              style: const TextStyle(color: Colors.white, fontSize: 14), textAlign: TextAlign.center,
              decoration: InputDecoration(
                hintText: 'Tu respuesta...', hintStyle: const TextStyle(color: Colors.white38),
                filled: true, fillColor: AppTheme.cardBg,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
              ),
            ),
            const SizedBox(height: 12),
            if (_showHint) Container(padding: const EdgeInsets.all(10), margin: const EdgeInsets.only(bottom: 10), decoration: BoxDecoration(color: AppTheme.accentGold.withOpacity(0.1), border: Border.all(color: AppTheme.accentGold), borderRadius: BorderRadius.circular(8)), child: Text(widget.clue.hint, style: const TextStyle(color: Colors.white70))),
            Row(children: [
              Expanded(child: OutlinedButton(onPressed: () => setState(() => _showHint = !_showHint), child: Text(_showHint ? "Ocultar" : "Pista"))),
              const SizedBox(width: 10),
              Expanded(flex: 2, child: ElevatedButton(onPressed: _checkAnswer, style: ElevatedButton.styleFrom(backgroundColor: AppTheme.successGreen), child: const Text("VERIFICAR")))
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
  const WordScrambleWidget({super.key, required this.clue, required this.onFinish});
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
      _shuffledLetters = (widget.clue.riddleAnswer?.toUpperCase() ?? "TREASURE").split('')..shuffle();
    });
  }

  void _checkAnswer() {
    if (_currentWord == widget.clue.riddleAnswer?.toUpperCase()) {
      // ÉXITO: LLAMAR CALLBACK LEGAL
      widget.onFinish();
      _showSuccessDialog(context, widget.clue);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('❌ Incorrecto'), backgroundColor: AppTheme.dangerRed));
      _onReset();
    }
  }

  @override
  Widget build(BuildContext context) {
    return _buildMinigameScaffold(
      context, widget.clue, widget.onFinish,
      SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Column(
          children: [
            const Icon(Icons.shuffle, size: 40, color: AppTheme.secondaryPink),
            const SizedBox(height: 8),
            const Text('PALABRA MISTERIOSA', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
            const SizedBox(height: 15),
            Container(
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 15),
              decoration: BoxDecoration(color: Colors.black.withOpacity(0.3), borderRadius: BorderRadius.circular(10), border: Border.all(color: AppTheme.accentGold, width: 2)),
              child: Text(_currentWord.padRight(widget.clue.riddleAnswer?.length ?? 8, '_').split('').join(' '), style: const TextStyle(color: AppTheme.accentGold, fontSize: 20, letterSpacing: 4, fontWeight: FontWeight.bold)),
            ),
            const SizedBox(height: 20),
            Wrap(
              spacing: 8, runSpacing: 8, alignment: WrapAlignment.center,
              children: _shuffledLetters.map((letter) => GestureDetector(
                onTap: () => _onLetterTap(letter),
                child: Container(width: 45, height: 45, decoration: BoxDecoration(gradient: const LinearGradient(colors: [AppTheme.primaryPurple, AppTheme.secondaryPink]), borderRadius: BorderRadius.circular(8)), child: Center(child: Text(letter, style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)))),
              )).toList(),
            ),
            const SizedBox(height: 20),
            Row(children: [
              Expanded(child: OutlinedButton(onPressed: _onReset, child: const Text("Reiniciar"))),
              const SizedBox(width: 10),
              Expanded(flex: 2, child: ElevatedButton(onPressed: _currentWord.length == (widget.clue.riddleAnswer?.length ?? 0) ? _checkAnswer : null, style: ElevatedButton.styleFrom(backgroundColor: AppTheme.successGreen), child: const Text("COMPROBAR"))),
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
      success = await gameProvider.completeCurrentClue(clue.riddleAnswer ?? "WIN");
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
        
        await playerProvider.refreshProfile();
      }
  } else {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Error al guardar el progreso. Verifica tu conexión.'),
          backgroundColor: AppTheme.dangerRed
        ),
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
    ),
  );
}

class SuccessCelebrationDialog extends StatefulWidget {
  final Clue clue;
  final bool showNextStep;
  const SuccessCelebrationDialog({super.key, required this.clue, required this.showNextStep});

  @override
  State<SuccessCelebrationDialog> createState() => _SuccessCelebrationDialogState();
}

class _SuccessCelebrationDialogState extends State<SuccessCelebrationDialog> {
  late ConfettiController _confettiController;

  @override
  void initState() {
    super.initState();
    _confettiController = ConfettiController(duration: const Duration(seconds: 5));
    _confettiController.play();
  }

  @override
  void dispose() {
    _confettiController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      backgroundColor: Colors.transparent,
      child: Stack(
        alignment: Alignment.topCenter,
        clipBehavior: Clip.none,
        children: [
          // Fondo del Confetti
          Align(
            alignment: Alignment.topCenter,
            child: ConfettiWidget(
              confettiController: _confettiController,
              blastDirectionality: BlastDirectionality.explosive,
              shouldLoop: false,
              colors: const [
                AppTheme.primaryPurple,
                AppTheme.secondaryPink,
                AppTheme.accentGold,
                AppTheme.successGreen,
                Colors.yellow,
                Colors.orange,
              ],
              numberOfParticles: 20,
              gravity: 0.1,
            ),
          ),
          
          Container(
            padding: const EdgeInsets.only(top: 60, left: 20, right: 20, bottom: 20),
            decoration: BoxDecoration(
              color: AppTheme.cardBg,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: AppTheme.primaryPurple, width: 2),
              boxShadow: [
                BoxShadow(color: Colors.black.withOpacity(0.5), blurRadius: 20, offset: const Offset(0, 10)),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('¡DESAFÍO COMPLETADO!', 
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppTheme.successGreen),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.all(12),
                  margin: const EdgeInsets.symmetric(vertical: 10),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.05),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppTheme.accentGold.withOpacity(0.3)),
                  ),
                  child: Column(
                    children: [
                      const Text("INFORMACIÓN DESBLOQUEADA", 
                        style: TextStyle(color: AppTheme.accentGold, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1.5),
                      ),
                      const SizedBox(height: 8),
                      Text(widget.clue.description, 
                        style: const TextStyle(color: Colors.white, fontSize: 14, height: 1.4),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _buildRewardBadge(Icons.star, "+${widget.clue.xpReward} XP", AppTheme.accentGold),
                    const SizedBox(width: 15),
                    _buildRewardBadge(Icons.monetization_on, "+${widget.clue.coinReward}", Colors.amber),
                  ],
                ),
                if (widget.showNextStep) ...[
                  const SizedBox(height: 20),
                  Text("¡Siguiente misión desbloqueada en el mapa!", 
                    style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 12, fontStyle: FontStyle.italic),
                  ),
                ],
                const SizedBox(height: 25),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () {
                      Navigator.of(context).pop(); // Cierra el diálogo
                      Future.delayed(const Duration(milliseconds: 100), () {
                        if (context.mounted) {
                          Navigator.of(context).pop(); // Vuelve al mapa
                        }
                      });
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primaryPurple,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      elevation: 5,
                    ),
                    icon: const Icon(Icons.map),
                    label: const Text('VOLVER AL MAPA', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ),
          ),
          
          Positioned(
            top: -40,
            child: Container(
              padding: const EdgeInsets.all(15),
              decoration: BoxDecoration(
                gradient: const LinearGradient(colors: [AppTheme.primaryPurple, AppTheme.secondaryPink]),
                shape: BoxShape.circle,
                border: Border.all(color: AppTheme.cardBg, width: 4),
                boxShadow: [BoxShadow(color: AppTheme.primaryPurple.withOpacity(0.5), blurRadius: 15, offset: const Offset(0, 5))],
              ),
              child: const Icon(Icons.emoji_events, size: 40, color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }
}

Widget _buildRewardBadge(IconData icon, String label, Color color) {
  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
    decoration: BoxDecoration(
      color: color.withOpacity(0.2), 
      borderRadius: BorderRadius.circular(20), 
      border: Border.all(color: color.withOpacity(0.5))
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min, 
      children: [
        Icon(icon, color: color, size: 14), 
        const SizedBox(width: 4), 
        Text(label, style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 12))
      ]
    ),
  );
}

// --- WRAPPERS ACTUALIZADOS CON ONFINISH ---

class SlidingPuzzleWrapper extends StatelessWidget {
  final Clue clue;
  final VoidCallback onFinish;
  const SlidingPuzzleWrapper({super.key, required this.clue, required this.onFinish});
  @override
  Widget build(BuildContext context) => _buildMinigameScaffold(
    context, 
    clue,
    onFinish,
    SlidingPuzzleMinigame(clue: clue, onSuccess: () {
      onFinish();
      _showSuccessDialog(context, clue);
    })
  );
}

class TicTacToeWrapper extends StatelessWidget {
  final Clue clue;
  final VoidCallback onFinish;
  const TicTacToeWrapper({super.key, required this.clue, required this.onFinish});
  @override
  Widget build(BuildContext context) => _buildMinigameScaffold(
    context, 
    clue, 
    onFinish,
    TicTacToeMinigame(clue: clue, onSuccess: () {
      onFinish();
      _showSuccessDialog(context, clue);
    })
  );
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
    HangmanMinigame(clue: clue, onSuccess: () {
      onFinish();
      _showSuccessDialog(context, clue);
    })
  );
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
    TetrisMinigame(clue: clue, onSuccess: () {
      onFinish();
      _showSuccessDialog(context, clue);
    })
  );
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
    FlagsMinigame(clue: clue, onSuccess: () {
      onFinish();
      _showSuccessDialog(context, clue);
    })
  );
}

class MinesweeperWrapper extends StatelessWidget {
  final Clue clue;
  final VoidCallback onFinish;
  const MinesweeperWrapper({super.key, required this.clue, required this.onFinish});
  @override
  Widget build(BuildContext context) => _buildMinigameScaffold(
    context, 
    clue, 
    onFinish,
    MinesweeperMinigame(clue: clue, onSuccess: () {
      onFinish();
      _showSuccessDialog(context, clue);
    })
  );
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
    SnakeMinigame(clue: clue, onSuccess: () {
      onFinish();
      _showSuccessDialog(context, clue);
    })
  );
}

class BlockFillWrapper extends StatelessWidget {
  final Clue clue;
  final VoidCallback onFinish;
  const BlockFillWrapper({super.key, required this.clue, required this.onFinish});
  @override
  Widget build(BuildContext context) => _buildMinigameScaffold(
    context, 
    clue, 
    onFinish,
    BlockFillMinigame(clue: clue, onSuccess: () {
      onFinish();
      _showSuccessDialog(context, clue);
    })
  );
}

// Para FindDifference, asumo que existe un wrapper similar o debes crearlo si no existe en el archivo original
class FindDifferenceWrapper extends StatelessWidget {
  final Clue clue;
  final VoidCallback onFinish;
  const FindDifferenceWrapper({super.key, required this.clue, required this.onFinish});
  @override
  Widget build(BuildContext context) => _buildMinigameScaffold(
    context, 
    clue, 
    onFinish,
    FindDifferenceMinigame(clue: clue, onSuccess: () {
      onFinish();
      _showSuccessDialog(context, clue);
    })
  );
}


// --- SCAFFOLD COMPARTIDO ACTUALIZADO (Soporta onFinish para Rendición Legal) ---

Widget _buildMinigameScaffold(BuildContext context, Clue clue, VoidCallback onFinish, Widget child) {
  return Scaffold(
    body: Container(
      decoration: const BoxDecoration(gradient: AppTheme.darkGradient),
      child: SafeArea(
        child: Column(
          children: [
            // AppBar Personalizado
            Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back, color: Colors.white, size: 20),
                    // OJO: Si presionan Back sin ganar ni rendirse, es un abandono (penalización)
                    // El Navigator.pop activará el ciclo de vida o simplemente no llamará a _finishLegally
                    onPressed: () => Navigator.pop(context),
                  ),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppTheme.accentGold.withOpacity(0.2), 
                      borderRadius: BorderRadius.circular(15),
                      border: Border.all(color: AppTheme.accentGold),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.star, color: AppTheme.accentGold, size: 12),
                        const SizedBox(width: 4),
                        Text(
                          '+${clue.xpReward} XP',
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 10),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  // Botón de Rendirse Integrado en el Scaffold Compartido
                  IconButton(
                    icon: const Icon(Icons.flag, color: AppTheme.dangerRed, size: 20),
                    tooltip: 'Rendirse',
                    onPressed: () => showSkipDialog(context, onFinish),
                  ),
                ],
              ),
            ),
            
            // Mapa de Progreso
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Consumer<GameProvider>(
                builder: (context, game, _) {
                  return RaceTrackWidget(
                    leaderboard: game.leaderboard,
                    currentPlayerId: Provider.of<PlayerProvider>(context, listen: false).currentPlayer?.id ?? '',
                    totalClues: game.clues.length,
                    // Pasamos el onFinish al callback de rendición del widget RaceTrack si lo soporta
                    // O usamos el botón del AppBar definido arriba
                    onSurrender: () => showSkipDialog(context, onFinish),
                  );
                },
              ),
            ),
            
            const SizedBox(height: 10),
            
            Expanded(child: child),
          ],
        ),
      ),
    ),
  );
}