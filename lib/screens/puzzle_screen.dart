import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/player_provider.dart';
import '../providers/game_provider.dart';
import '../theme/app_theme.dart';
import '../models/clue.dart';
import '../widgets/race_track_widget.dart';
import 'riddle_screen.dart';

class PuzzleScreen extends StatelessWidget {
  final Clue clue;

  const PuzzleScreen({super.key, required this.clue});

  @override
  Widget build(BuildContext context) {
    switch (clue.puzzleType) {
      case PuzzleType.codeBreaker:
        return CodeBreakerWidget(clue: clue);
      case PuzzleType.imageTrivia:
        return ImageTriviaWidget(clue: clue);
      case PuzzleType.wordScramble:
        return WordScrambleWidget(clue: clue);
      case PuzzleType.riddle:
      default:
        return RiddleScreen(clue: clue);
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

void showSkipDialog(BuildContext context) {
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
          onPressed: () {
            Navigator.pop(context); // Dialog
            Navigator.pop(context); // PuzzleScreen
            Navigator.pop(context); // QRScreen
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


// --- WIDGET: CODE BREAKER ---
class CodeBreakerWidget extends StatefulWidget {
  final Clue clue;
  const CodeBreakerWidget({super.key, required this.clue});

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
    if (_enteredCode == widget.clue.riddleAnswer) {
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

  void _skipChallenge() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.cardBg,
        title: const Text('¿Rendirse?', style: TextStyle(color: Colors.white)),
        content: const Text(
          'Perderás las recompensas de este desafío.',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () {
              final gameProvider = Provider.of<GameProvider>(context, listen: false);
              gameProvider.completeCurrentClue();
              Navigator.pop(context); // Dialog
              Navigator.pop(context); // PuzzleScreen
              Navigator.pop(context); // QRScreen
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.dangerRed),
            child: const Text('Rendirse'),
          ),
        ],
      ),
    );
  }

  void _showClueSelector(BuildContext context) {
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
              final isCurrentClue = clue.id == widget.clue.id;
              
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
                  final gameProvider = Provider.of<GameProvider>(context, listen: false);
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(gradient: AppTheme.darkGradient),
        child: SafeArea(
          child: Column(
            children: [
              // AppBar compacto
              Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_back, color: Colors.white, size: 20),
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
                            '+${widget.clue.xpReward} XP',
                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 10),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 4),
                    // Botón Cambiar Pista
                    IconButton(
                      icon: const Icon(Icons.swap_horiz, color: AppTheme.secondaryPink, size: 20),
                      onPressed: () => showClueSelector(context, widget.clue),
                      tooltip: 'Cambiar Pista',
                    ),
                    const SizedBox(width: 4),
                    // Botón Rendirse
                    IconButton(
                      icon: const Icon(Icons.flag, color: AppTheme.dangerRed, size: 20),
                      onPressed: () => showSkipDialog(context),
                      tooltip: 'Rendirse',
                    ),
                  ],
                ),
              ),

              // Mini Mapa de Carrera
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Consumer<GameProvider>(
                  builder: (context, game, _) {
                    return RaceTrackWidget(
                      currentClueIndex: game.currentClueIndex,
                      totalClues: game.clues.length,
                    );
                  },
                ),
              ),

              const SizedBox(height: 10),

              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Column(
                    children: [
                      // Icon más pequeño
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: LinearGradient(
                            colors: [
                              AppTheme.primaryPurple.withOpacity(0.3),
                              AppTheme.secondaryPink.withOpacity(0.3),
                            ],
                          ),
                        ),
                        child: const Icon(Icons.lock_outline, size: 35, color: AppTheme.accentGold),
                      ),

                      const SizedBox(height: 10),

                      const Text(
                        'CAJA FUERTE',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                          letterSpacing: 2,
                        ),
                      ),

                      const SizedBox(height: 8),

                      Text(
                        widget.clue.riddleQuestion ?? "Ingresa el código de 4 dígitos",
                        style: const TextStyle(color: Colors.white70, fontSize: 12),
                        textAlign: TextAlign.center,
                      ),

                      const SizedBox(height: 15),

                      // Display más pequeño
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
                                width: 2,
                              ),
                            ),
                            child: Center(
                              child: Text(
                                hasDigit ? _enteredCode[index] : '',
                                style: TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold,
                                  color: _isError ? AppTheme.dangerRed : Colors.white,
                                ),
                              ),
                            ),
                          );
                        }),
                      ),

                      const SizedBox(height: 15),

                      // Teclado más compacto
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
                          if (index == 9) {
                            return _buildKey(
                              icon: Icons.backspace_outlined,
                              onTap: _onDelete,
                              color: AppTheme.warningOrange,
                            );
                          }
                          if (index == 10) {
                            return _buildKey(text: '0', onTap: () => _onDigitPress('0'));
                          }
                          if (index == 11) {
                            return _buildKey(
                              icon: Icons.check_circle,
                              onTap: _enteredCode.length == 4 ? _checkCode : null,
                              color: AppTheme.successGreen,
                            );
                          }

                          final digit = '${index + 1}';
                          return _buildKey(text: digit, onTap: () => _onDigitPress(digit));
                        },
                      ),

                      const SizedBox(height: 10),
                    ],
                  ),
                ),
              ),
            ],
          ),
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
            gradient: onTap != null
                ? LinearGradient(
                    colors: [
                      AppTheme.primaryPurple.withOpacity(0.2),
                      AppTheme.secondaryPink.withOpacity(0.2),
                    ],
                  )
                : null,
          ),
          child: Center(
            child: text != null
                ? Text(
                    text,
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: color ?? Colors.white,
                    ),
                  )
                : Icon(icon, color: color ?? Colors.white, size: 20),
          ),
        ),
      ),
    );
  }
}

// --- WIDGET: IMAGE TRIVIA ---
class ImageTriviaWidget extends StatefulWidget {
  final Clue clue;
  const ImageTriviaWidget({super.key, required this.clue});

  @override
  State<ImageTriviaWidget> createState() => _ImageTriviaWidgetState();
}

class _ImageTriviaWidgetState extends State<ImageTriviaWidget> {
  final TextEditingController _controller = TextEditingController();
  bool _showHint = false;

  void _checkAnswer() {
    final userAnswer = _controller.text.trim().toLowerCase();
    final correctAnswer = widget.clue.riddleAnswer?.toLowerCase() ?? "";

    if (userAnswer == correctAnswer || userAnswer.contains(correctAnswer.split(' ').first)) {
      _showSuccessDialog(context, widget.clue);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('❌ Respuesta incorrecta. Intenta de nuevo.'),
          backgroundColor: AppTheme.dangerRed,
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  void _skipChallenge() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.cardBg,
        title: const Text('¿Rendirse?', style: TextStyle(color: Colors.white)),
        content: const Text(
          'Perderás las recompensas de este desafío.',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () {
              final gameProvider = Provider.of<GameProvider>(context, listen: false);
              gameProvider.completeCurrentClue();
              Navigator.pop(context);
              Navigator.pop(context);
              Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.dangerRed),
            child: const Text('Rendirse'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(gradient: AppTheme.darkGradient),
        child: SafeArea(
          child: Column(
            children: [
              // AppBar compacto
              Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_back, color: Colors.white, size: 20),
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
                            '+${widget.clue.xpReward} XP',
                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 10),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    TextButton.icon(
                      onPressed: _skipChallenge,
                      icon: const Icon(Icons.flag, color: AppTheme.dangerRed, size: 16),
                      label: const Text('Rendirse', style: TextStyle(color: AppTheme.dangerRed, fontSize: 11)),
                      style: TextButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 8)),
                    ),
                  ],
                ),
              ),

              // Mini Mapa
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Consumer<GameProvider>(
                  builder: (context, game, _) {
                    return RaceTrackWidget(
                      currentClueIndex: game.currentClueIndex,
                      totalClues: game.clues.length,
                    );
                  },
                ),
              ),

              const SizedBox(height: 10),

              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      const Icon(Icons.image_outlined, size: 35, color: AppTheme.secondaryPink),
                      const SizedBox(height: 8),

                      const Text(
                        'DESAFÍO VISUAL',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),

                      const SizedBox(height: 15),

                      // Imagen más pequeña
                      Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(
                              color: AppTheme.primaryPurple.withOpacity(0.5),
                              blurRadius: 15,
                            ),
                          ],
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: Image.network(
                            widget.clue.minigameUrl ?? 'https://via.placeholder.com/400',
                            height: 180,
                            width: double.infinity,
                            fit: BoxFit.cover,
                            loadingBuilder: (context, child, loadingProgress) {
                              if (loadingProgress == null) return child;
                              return Container(
                                height: 180,
                                color: AppTheme.cardBg,
                                child: const Center(child: CircularProgressIndicator(color: AppTheme.accentGold)),
                              );
                            },
                            errorBuilder: (context, error, stackTrace) {
                              return Container(
                                height: 180,
                                color: AppTheme.cardBg,
                                child: const Center(
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(Icons.broken_image, size: 40, color: Colors.white38),
                                      SizedBox(height: 5),
                                      Text('Error', style: TextStyle(color: Colors.white38, fontSize: 11)),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                      ),

                      const SizedBox(height: 15),

                      Text(
                        widget.clue.riddleQuestion ?? "¿Qué es esto?",
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                        textAlign: TextAlign.center,
                      ),

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
                          contentPadding: const EdgeInsets.symmetric(vertical: 12, horizontal: 15),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: BorderSide.none,
                          ),
                          prefixIcon: const Icon(Icons.edit, color: AppTheme.secondaryPink, size: 18),
                        ),
                      ),

                      const SizedBox(height: 10),

                      if (_showHint)
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: AppTheme.accentGold.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: AppTheme.accentGold),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.lightbulb, color: AppTheme.accentGold, size: 16),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  widget.clue.hint,
                                  style: const TextStyle(color: Colors.white70, fontSize: 12),
                                ),
                              ),
                            ],
                          ),
                        ),

                      const SizedBox(height: 12),

                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: () => setState(() => _showHint = !_showHint),
                              icon: Icon(
                                _showHint ? Icons.visibility_off : Icons.visibility,
                                size: 16,
                                color: AppTheme.accentGold,
                              ),
                              label: Text(
                                _showHint ? 'Ocultar' : 'Pista',
                                style: const TextStyle(color: Colors.white, fontSize: 12),
                              ),
                              style: OutlinedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(vertical: 12),
                                side: const BorderSide(color: AppTheme.accentGold),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            flex: 2,
                            child: ElevatedButton(
                              onPressed: _checkAnswer,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppTheme.successGreen,
                                padding: const EdgeInsets.symmetric(vertical: 12),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                              ),
                              child: const Text(
                                'VERIFICAR',
                                style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// --- WIDGET: WORD SCRAMBLE ---
class WordScrambleWidget extends StatefulWidget {
  final Clue clue;
  const WordScrambleWidget({super.key, required this.clue});

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
      _showSuccessDialog(context, widget.clue);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('❌ Incorrecto. Intenta de nuevo.'),
          backgroundColor: AppTheme.dangerRed,
          duration: Duration(seconds: 2),
        ),
      );
      _onReset();
    }
  }

  void _skipChallenge() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.cardBg,
        title: const Text('¿Rendirse?', style: TextStyle(color: Colors.white)),
        content: const Text(
          'Perderás las recompensas de este desafío.',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () {
              final gameProvider = Provider.of<GameProvider>(context, listen: false);
              gameProvider.completeCurrentClue();
              Navigator.pop(context);
              Navigator.pop(context);
              Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.dangerRed),
            child: const Text('Rendirse'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(gradient: AppTheme.darkGradient),
        child: SafeArea(
          child: Column(
            children: [
              // AppBar
              Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_back, color: Colors.white, size: 20),
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
                            '+${widget.clue.xpReward} XP',
                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 10),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    TextButton.icon(
                      onPressed: _skipChallenge,
                      icon: const Icon(Icons.flag, color: AppTheme.dangerRed, size: 16),
                      label: const Text('Rendirse', style: TextStyle(color: AppTheme.dangerRed, fontSize: 11)),
                      style: TextButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 8)),
                    ),
                  ],
                ),
              ),

              // Mini Mapa
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Consumer<GameProvider>(
                  builder: (context, game, _) {
                    return RaceTrackWidget(
                      currentClueIndex: game.currentClueIndex,
                      totalClues: game.clues.length,
                    );
                  },
                ),
              ),

              const SizedBox(height: 10),

              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Column(
                    children: [
                      const Icon(Icons.shuffle, size: 40, color: AppTheme.secondaryPink),
                      const SizedBox(height: 8),

                      const Text(
                        'PALABRA MISTERIOSA',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),

                      const SizedBox(height: 8),

                      Text(
                        widget.clue.riddleQuestion ?? "Ordena las letras",
                        style: const TextStyle(color: Colors.white70, fontSize: 12),
                      ),

                      const SizedBox(height: 15),

                      // Palabra
                      Container(
                        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 15),
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.3),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: AppTheme.accentGold, width: 2),
                        ),
                        child: Text(
                          _currentWord.padRight(widget.clue.riddleAnswer?.length ?? 8, '_').split('').join(' '),
                          style: const TextStyle(
                            color: AppTheme.accentGold,
                            fontSize: 20,
                            letterSpacing: 4,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),

                      const SizedBox(height: 20),

                      // Letras
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        alignment: WrapAlignment.center,
                        children: _shuffledLetters.map((letter) {
                          return GestureDetector(
                            onTap: () => _onLetterTap(letter),
                            child: Container(
                              width: 45,
                              height: 45,
                              decoration: BoxDecoration(
                                gradient: const LinearGradient(
                                  colors: [AppTheme.primaryPurple, AppTheme.secondaryPink],
                                ),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Center(
                                child: Text(
                                  letter,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ),
                          );
                        }).toList(),
                      ),

                      const SizedBox(height: 20),

                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: _onReset,
                              icon: const Icon(Icons.refresh, size: 16, color: AppTheme.warningOrange),
                              label: const Text(
                                'Reiniciar',
                                style: TextStyle(color: Colors.white, fontSize: 12),
                              ),
                              style: OutlinedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(vertical: 12),
                                side: const BorderSide(color: AppTheme.warningOrange),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            flex: 2,
                            child: ElevatedButton(
                              onPressed: _currentWord.length == (widget.clue.riddleAnswer?.length ?? 0)
                                  ? _checkAnswer
                                  : null,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppTheme.successGreen,
                                padding: const EdgeInsets.symmetric(vertical: 12),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                              ),
                              child: const Text(
                                'COMPROBAR',
                                style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                              ),
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 10),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// --- HELPER: SUCCESS DIALOG ---
void _showSuccessDialog(BuildContext context, Clue clue) {
  final playerProvider = Provider.of<PlayerProvider>(context, listen: false);
  final gameProvider = Provider.of<GameProvider>(context, listen: false);

  playerProvider.addExperience(clue.xpReward);
  playerProvider.addCoins(clue.coinReward);
  gameProvider.completeCurrentClue();

  showDialog(
    context: context,
    barrierDismissible: false,
    builder: (context) => Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      backgroundColor: Colors.transparent,
      child: Container(
        padding: const EdgeInsets.all(25),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [AppTheme.primaryPurple, AppTheme.secondaryPink],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: AppTheme.accentGold.withOpacity(0.5),
              blurRadius: 30,
              spreadRadius: 5,
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(15),
              decoration: const BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.celebration, size: 50, color: AppTheme.accentGold),
            ),
            const SizedBox(height: 20),
            const Text(
              '¡DESAFÍO SUPERADO!',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 15),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.star, color: AppTheme.accentGold, size: 20),
                  const SizedBox(width: 8),
                  Text(
                    '+${clue.xpReward} XP',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(width: 20),
                  const Icon(Icons.monetization_on, color: AppTheme.accentGold, size: 20),
                  const SizedBox(width: 8),
                  Text(
                    '+${clue.coinReward}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 25),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.pop(context); // Dialog
                  Navigator.pop(context); // PuzzleScreen
                  Navigator.pop(context); // QRScreen
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: AppTheme.primaryPurple,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text(
                  'CONTINUAR',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
