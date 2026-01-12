import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/clue.dart';
import '../../../auth/providers/player_provider.dart';
import '../../../../core/theme/app_theme.dart';
import '../../providers/game_provider.dart';

class HangmanMinigame extends StatefulWidget {
  final Clue clue;
  final VoidCallback onSuccess;

  const HangmanMinigame({
    super.key,
    required this.clue,
    required this.onSuccess,
  });

  @override
  State<HangmanMinigame> createState() => _HangmanMinigameState();
}

class _HangmanMinigameState extends State<HangmanMinigame> {
  // Configuración
  late String _word;
  final Set<String> _guessedLetters = {};
  static const int _maxAttempts = 8; // Cambiado a 8 intentos
  
  // Estado
  int _wrongAttempts = 0;
  bool _isGameOver = false;
  
  // Timer
  Timer? _timer;
  int _secondsRemaining = 120;

  @override
  void initState() {
    super.initState();
    _initializeGame();
  }
  
  @override
  void dispose() {
    _stopTimer();
    super.dispose();
  }

  void _initializeGame() {
    _word = (widget.clue.riddleAnswer?.toUpperCase() ?? "FLUTTER").trim();
    _guessedLetters.clear();
    _wrongAttempts = 0;
    _isGameOver = false;
    _secondsRemaining = 120;
    _startTimer();
  }
  
  void _startTimer() {
    _stopTimer();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;
      setState(() {
        if (_secondsRemaining > 0) {
          _secondsRemaining--;
        } else {
          _stopTimer();
          _loseLife("¡Se acabó el tiempo!");
        }
      });
    });
  }

  void _stopTimer() {
    _timer?.cancel();
    _timer = null;
  }

  void _onLetterGuess(String letter) {
    if (_isGameOver || _guessedLetters.contains(letter)) return;

    setState(() {
      _guessedLetters.add(letter);
      
      if (!_word.contains(letter)) {
        _wrongAttempts++;
      }
    });

    _checkGameContent();
  }

  void _checkGameContent() {
    // Check Win
    bool won = true;
    for (int i = 0; i < _word.length; i++) {
      if (!_guessedLetters.contains(_word[i]) && _word[i] != ' ') {
        won = false;
        break;
      }
    }

    if (won) {
      _stopTimer();
      _isGameOver = true;
      Future.delayed(const Duration(milliseconds: 500), widget.onSuccess);
      return;
    }

    // Check Lose
    if (_wrongAttempts >= _maxAttempts) {
      _stopTimer();
      _isGameOver = true;
      _loseLife("¡Te han ahorcado! La palabra era: $_word");
    }
  }

  void _handleGiveUp() {
    _stopTimer();
    _loseLife("Te has rendido.");
  }

  // hangman_minigame.dart

void _loseLife(String reason) {
  if (!mounted) return;
  _stopTimer();
  
  final gameProvider = Provider.of<GameProvider>(context, listen: false);
  final playerProvider = Provider.of<PlayerProvider>(context, listen: false);
  
  final userId = playerProvider.currentPlayer?.id;
  
  if (userId != null) {
    // Verificación de debug para ti:
    if (gameProvider.currentEventId == null) {
       debugPrint("¡Cuidado! El minijuego se inició sin un Event ID en el GameProvider");
    }

    gameProvider.loseLife(userId).then((_) {
      if (!mounted) return;
      
      // Ahora usamos el estado actualizado del provider
      if (gameProvider.lives <= 0) {
        _showGameOverDialog();
      } else {
        _showTryAgainDialog(reason);
      }
    });
  }
}

  void _showTryAgainDialog(String reason) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.cardBg,
        title: const Text("¡Fallaste!", style: TextStyle(color: AppTheme.dangerRed)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(reason, style: const TextStyle(color: Colors.white), textAlign: TextAlign.center),
            const SizedBox(height: 10),
            const Text("Has perdido 1 vida ❤️", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ],
        ),
        actions: [
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context); // Close Dialog
              setState(() {
                _initializeGame();
              });
            },
            child: const Text("Reintentar"),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context); // Dialog
              Navigator.pop(context); // Screen
            },
            child: const Text("Salir"),
          ),
        ],
      ),
    );
  }

  void _showGameOverDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.cardBg,
        title: const Text("GAME OVER", style: TextStyle(color: AppTheme.dangerRed, fontSize: 24, fontWeight: FontWeight.bold)),
        content: const Text("Te has quedado sin vidas. Ve a la Tienda a comprar más.", style: TextStyle(color: Colors.white)),
        actions: [
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context); // Dialog
              Navigator.pop(context); // Screen
            },
            child: const Text("Salir"),
          )
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final player = Provider.of<PlayerProvider>(context).currentPlayer;

    // Usamos SingleChildScrollView para permitir scroll si el contenido es muy alto
    return SingleChildScrollView(
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(
        children: [
          // Status Bar
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Vidas
                Consumer<GameProvider>(
                  builder: (context, game, _) {
                    return Row(
                      children: [
                        const Icon(Icons.favorite, color: AppTheme.dangerRed, size: 24),
                        const SizedBox(width: 5),
                        Text("x${game.lives}", style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                      ],
                    );
                  }
                ),
                
                // Timer
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: _secondsRemaining <= 10 ? AppTheme.dangerRed.withOpacity(0.2) : Colors.white10,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: _secondsRemaining <= 10 ? AppTheme.dangerRed : Colors.white24)
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.timer, size: 18, color: _secondsRemaining <= 10 ? AppTheme.dangerRed : Colors.white),
                      const SizedBox(width: 5),
                      Text(
                        "$_secondsRemaining s",
                        style: TextStyle(
                          color: _secondsRemaining <= 10 ? AppTheme.dangerRed : Colors.white, 
                          fontWeight: FontWeight.bold, 
                          fontSize: 14
                        ),
                      ),
                    ],
                  ),
                ),

                // Intentos
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.white10,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: _wrongAttempts >= _maxAttempts - 1 ? AppTheme.dangerRed : Colors.white24)
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.warning_amber_rounded, size: 18, color: AppTheme.warningOrange),
                      const SizedBox(width: 5),
                      Text(
                        "$_wrongAttempts/$_maxAttempts",
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
      
          const Text(
            "AHORCADO",
            style: TextStyle(color: AppTheme.accentGold, fontSize: 20, fontWeight: FontWeight.bold),
          ),

          // Pista
          if (widget.clue.riddleQuestion != null && widget.clue.riddleQuestion!.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: AppTheme.accentGold.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppTheme.accentGold.withOpacity(0.3)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.lightbulb_outline, color: AppTheme.accentGold, size: 18),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        "Pista: ${widget.clue.riddleQuestion}",
                        style: const TextStyle(color: Colors.white, fontStyle: FontStyle.italic, fontSize: 14),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          
          // Área de Dibujo y Palabra
          Container(
            margin: const EdgeInsets.all(16),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppTheme.cardBg.withOpacity(0.5),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Dibujo del Ahorcado
                SizedBox(
                  height: 150,
                  width: 150,
                  child: CustomPaint(
                    painter: HangmanPainter(_wrongAttempts),
                  ),
                ),
                
                const SizedBox(height: 20),
                
                // Palabra Oculta (Ultra-Compact Word-Aware)
                Wrap(
                  alignment: WrapAlignment.center,
                  spacing: 10,
                  runSpacing: 8,
                  children: _word.split(' ').map((word) {
                    return Wrap(
                      spacing: 2, // Tiny spacing
                      runSpacing: 4,
                      children: word.split('').map((char) {
                        final isGuessed = _guessedLetters.contains(char);
                        return Container(
                          width: 24, // Ultra narrow (was 28)
                          height: 34, // Slightly shorter
                          decoration: BoxDecoration(
                            border: Border(bottom: BorderSide(
                              color: isGuessed ? AppTheme.accentGold : Colors.white54,
                              width: 2,
                            )),
                          ),
                          child: Center(
                            child: Text(
                              isGuessed ? char : '',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 18, // Reduced font
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    );
                  }).toList(),
                ),
              ],
            ),
          ),
      
          // Teclado
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            child: GridView.builder(
              shrinkWrap: true, // Allow it to take necessary size
              physics: const NeverScrollableScrollPhysics(), // Scroll handled by parent
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 7,
                childAspectRatio: 0.85,
                crossAxisSpacing: 5,
                mainAxisSpacing: 5,
              ),
              itemCount: 26,
              itemBuilder: (context, index) {
                final letter = String.fromCharCode(65 + index);
                final isGuessed = _guessedLetters.contains(letter);
                final isCorrect = _word.contains(letter);
                
                Color bgColor = Colors.white10;
                Color textColor = Colors.white;
                
                if (isGuessed) {
                  if (isCorrect) {
                    bgColor = AppTheme.successGreen;
                    textColor = Colors.black;
                  } else {
                    bgColor = Colors.black38;
                    textColor = Colors.grey;
                  }
                }
      
                return GestureDetector(
                  onTap: isGuessed ? null : () => _onLetterGuess(letter),
                  child: Container(
                    decoration: BoxDecoration(
                      color: bgColor,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                        color: isGuessed ? Colors.transparent : Colors.white24,
                      ),
                    ),
                    child: Center(
                      child: Text(
                        letter,
                        style: TextStyle(
                          color: textColor,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          
          const SizedBox(height: 20),
      
          // Botón Rendirse
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: SizedBox(
              width: double.infinity,
              height: 45,
              child: ElevatedButton.icon(
                onPressed: _handleGiveUp,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.cardBg,
                  foregroundColor: AppTheme.dangerRed,
                  side: const BorderSide(color: AppTheme.dangerRed),
                ),
                icon: const Icon(Icons.flag_outlined),
                label: const Text("RENDIRSE"),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class HangmanPainter extends CustomPainter {
  final int wrongAttempts;
  
  HangmanPainter(this.wrongAttempts);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.0
      ..strokeCap = StrokeCap.round;

    final double w = size.width;
    final double h = size.height;

    // 8 Intentos - Dibujo Progresivo
    
    // 1. Base Suelo (Base)
    if (wrongAttempts >= 1) canvas.drawLine(Offset(w * 0.2, h * 0.9), Offset(w * 0.8, h * 0.9), paint);
    
    // 2. Poste Vertical (Poste 1)
    if (wrongAttempts >= 2) canvas.drawLine(Offset(w * 0.3, h * 0.9), Offset(w * 0.3, h * 0.1), paint);
    
    // 3. Poste Horizontal + Soporte (Poste 2)
    if (wrongAttempts >= 3) {
      canvas.drawLine(Offset(w * 0.3, h * 0.1), Offset(w * 0.6, h * 0.1), paint);
      canvas.drawLine(Offset(w * 0.3, h * 0.2), Offset(w * 0.4, h * 0.1), paint); // Soporte
    }

    // 4. Cuerda
    if (wrongAttempts >= 4) canvas.drawLine(Offset(w * 0.6, h * 0.1), Offset(w * 0.6, h * 0.2), paint);

    // 5. Cabeza
    if (wrongAttempts >= 5) canvas.drawCircle(Offset(w * 0.6, h * 0.3), h * 0.1, paint);

    // 6. Cuerpo
    if (wrongAttempts >= 6) canvas.drawLine(Offset(w * 0.6, h * 0.4), Offset(w * 0.6, h * 0.7), paint);

    // 7. Brazos (Ambos)
    if (wrongAttempts >= 7) {
      canvas.drawLine(Offset(w * 0.6, h * 0.45), Offset(w * 0.5, h * 0.55), paint); // Izq
      canvas.drawLine(Offset(w * 0.6, h * 0.45), Offset(w * 0.7, h * 0.55), paint); // Der
    }

    // 8. Piernas (Ambas) + Ojos (Game Over)
    if (wrongAttempts >= 8) {
      canvas.drawLine(Offset(w * 0.6, h * 0.7), Offset(w * 0.5, h * 0.85), paint); // Izq
      canvas.drawLine(Offset(w * 0.6, h * 0.7), Offset(w * 0.7, h * 0.85), paint); // Der
      
      final eyePaint = Paint()
        ..color = AppTheme.dangerRed
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.0;
        
      canvas.drawLine(Offset(w * 0.57, h * 0.28), Offset(w * 0.59, h * 0.30), eyePaint);
      canvas.drawLine(Offset(w * 0.59, h * 0.28), Offset(w * 0.57, h * 0.30), eyePaint);
      
      canvas.drawLine(Offset(w * 0.61, h * 0.28), Offset(w * 0.63, h * 0.30), eyePaint);
      canvas.drawLine(Offset(w * 0.63, h * 0.28), Offset(w * 0.61, h * 0.30), eyePaint);
    }
  }

  @override
  bool shouldRepaint(HangmanPainter oldDelegate) => oldDelegate.wrongAttempts != wrongAttempts;
}
