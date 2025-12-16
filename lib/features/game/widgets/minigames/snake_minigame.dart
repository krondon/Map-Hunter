import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/clue.dart';
import '../../../auth/providers/player_provider.dart';
import '../../../../core/theme/app_theme.dart';

class SnakeMinigame extends StatefulWidget {
  final Clue clue;
  final VoidCallback onSuccess;

  const SnakeMinigame({
    super.key,
    required this.clue,
    required this.onSuccess,
  });

  @override
  State<SnakeMinigame> createState() => _SnakeMinigameState();
}

enum Direction { up, down, left, right }

class _SnakeMinigameState extends State<SnakeMinigame> {
  // Config
  static const int rows = 20;
  static const int cols = 20;
  static const int winScore = 15; // Manzanas para ganar
  
  // Game State
  List<Point<int>> _snake = [const Point(10, 10)];
  Point<int>? _food;
  Direction _direction = Direction.right;
  Direction _nextDirection = Direction.right;
  bool _isPlaying = false;
  bool _isGameOver = false;
  int _score = 0;
  
  // Timer
  Timer? _gameLoop;
  Timer? _countdownTimer;
  int _secondsRemaining = 90;

  @override
  void initState() {
    super.initState();
    _startNewGame();
  }

  @override
  void dispose() {
    _gameLoop?.cancel();
    _countdownTimer?.cancel();
    super.dispose();
  }

  void _startNewGame() {
    _gameLoop?.cancel();
    _countdownTimer?.cancel();
    
    setState(() {
      _snake = [const Point(10, 10), const Point(9, 10), const Point(8, 10)]; // Cuerpo inicial
      _direction = Direction.right;
      _nextDirection = Direction.right;
      _score = 0;
      _secondsRemaining = 90;
      _isPlaying = true;
      _isGameOver = false;
      _generateFood();
    });

    _startCountdown();
    _startGameLoop();
  }
  
  void _startGameLoop() {
    _gameLoop = Timer.periodic(const Duration(milliseconds: 200), (timer) {
      _updateGame();
    });
  }

  void _startCountdown() {
      _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
          if (_secondsRemaining > 0) {
              setState(() => _secondsRemaining--);
          } else {
              _loseLife("¡Se acabó el tiempo!", isTimeOut: true);
          }
      });
  }

  void _generateFood() {
    final random = Random();
    Point<int> newFood;
    do {
      newFood = Point(random.nextInt(cols), random.nextInt(rows));
    } while (_snake.contains(newFood));
    
    setState(() {
      _food = newFood;
    });
  }

  void _updateGame() {
    if (!_isPlaying || _isGameOver) return;
    
    setState(() {
        _direction = _nextDirection;
        
        Point<int> newHead;
        switch (_direction) {
            case Direction.up:    newHead = Point(_snake.first.x, _snake.first.y - 1); break;
            case Direction.down:  newHead = Point(_snake.first.x, _snake.first.y + 1); break;
            case Direction.left:  newHead = Point(_snake.first.x - 1, _snake.first.y); break;
            case Direction.right: newHead = Point(_snake.first.x + 1, _snake.first.y); break;
        }

        // Colisión Paredes
        if (newHead.x < 0 || newHead.x >= cols || newHead.y < 0 || newHead.y >= rows) {
            _loseLife("¡Chocaste con la pared!");
            return;
        }

        // Colisión a sí mismo
        if (_snake.contains(newHead)) {
             _loseLife("¡Te mordiste la cola!");
             return;
        }

        _snake.insert(0, newHead);

        // Comer
        if (newHead == _food) {
            _score++;
            if (_score >= winScore) {
                _winGame();
            } else {
                _generateFood();
            }
        } else {
            _snake.removeLast();
        }
    });
  }

  void _winGame() {
      _isPlaying = false;
      _isGameOver = true;
      _gameLoop?.cancel();
      _countdownTimer?.cancel();
      widget.onSuccess();
  }

  void _loseLife(String reason, {bool isTimeOut = false}) {
      _isPlaying = false;
      _gameLoop?.cancel();
      
      final playerProvider = Provider.of<PlayerProvider>(context, listen: false);
      if (playerProvider.currentPlayer != null) {
          playerProvider.currentPlayer!.lives--;
          playerProvider.notifyListeners(); // Actualizar UI
          
          if (playerProvider.currentPlayer!.lives <= 0) {
               _countdownTimer?.cancel();
              _showGameOverDialog("Te has quedado sin vidas.");
          } else {
               if (isTimeOut) { 
                 _countdownTimer?.cancel(); // Si fue timeout y aun tiene vidas, igual reiniciamos todo
                  _showRestartDialog("Tiempo agotado.");
               } else {
                 ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text("$reason -1 Vida 💔"), backgroundColor: AppTheme.dangerRed, duration: const Duration(milliseconds: 1000)),
                 );
                 // Reiniciar tablero tras breve pausa
                 Future.delayed(const Duration(seconds: 1), _startNewGame);
               }
          }
      }
  }

  void _showRestartDialog(String title) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.cardBg,
        title: Text(title, style: const TextStyle(color: AppTheme.dangerRed)),
        content: const Text("Inténtalo de nuevo.", style: TextStyle(color: Colors.white)),
        actions: [
           TextButton(
            onPressed: () {
               Navigator.pop(context);
               _startNewGame(); 
            },
            child: const Text("Reintentar"),
          )
        ],
      ),
    );
  }

  void _showGameOverDialog(String message) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.cardBg,
        title: const Text("GAME OVER", style: TextStyle(color: AppTheme.dangerRed)),
        content: Text(message, style: const TextStyle(color: Colors.white)),
        actions: [
          ElevatedButton(
            onPressed: () {
               Navigator.pop(context); 
               Navigator.pop(context); 
            },
            child: const Text("Salir"),
          ),
        ],
      ),
    );
  }

  void _onChangeDirection(Direction newDir) {
      if (_direction == Direction.up && newDir == Direction.down) return;
      if (_direction == Direction.down && newDir == Direction.up) return;
      if (_direction == Direction.left && newDir == Direction.right) return;
      if (_direction == Direction.right && newDir == Direction.left) return;
      _nextDirection = newDir;
  }

  @override
  Widget build(BuildContext context) {
    final minutes = (_secondsRemaining / 60).floor().toString().padLeft(2, '0');
    final seconds = (_secondsRemaining % 60).toString().padLeft(2, '0');
    final isLowTime = _secondsRemaining <= 10;
    
    return Column(
        children: [
            // Header Info
            Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                        // Score
                        Container(
                             padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                             decoration: BoxDecoration(
                               color: Colors.black26,
                               borderRadius: BorderRadius.circular(20),
                               border: Border.all(color: AppTheme.successGreen.withOpacity(0.5)),
                             ),
                             child: Row(
                                children: [
                                  const Text("🍎", style: TextStyle(fontSize: 20)),
                                  const SizedBox(width: 8),
                                  Text(
                                    "$_score / $winScore", 
                                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18)
                                  ),
                                ],
                             ),
                        ),
                        
                        // Timer
                        Container(
                             padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                             decoration: BoxDecoration(
                               color: isLowTime ? AppTheme.dangerRed.withOpacity(0.2) : Colors.black26,
                               borderRadius: BorderRadius.circular(20),
                               border: Border.all(color: isLowTime ? AppTheme.dangerRed : Colors.white24),
                             ),
                             child: Row(
                                children: [
                                  Icon(Icons.timer, color: isLowTime ? AppTheme.dangerRed : Colors.white70, size: 22),
                                  const SizedBox(width: 8),
                                  Text(
                                    "$minutes:$seconds", 
                                    style: TextStyle(
                                      color: isLowTime ? AppTheme.dangerRed : Colors.white, 
                                      fontWeight: FontWeight.bold, 
                                      fontSize: 18
                                    )
                                  ),
                                ],
                             ),
                        ),
                    ],
                ),
            ),
             
             // Lives
             Consumer<PlayerProvider>(
                builder: (context, playerProvider, _) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 15),
                  child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: List.generate(3, (index) {
                      return Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        child: Icon(
                            index < (playerProvider.currentPlayer?.lives ?? 0) ? Icons.favorite : Icons.favorite_border,
                            color: AppTheme.dangerRed,
                            shadows: [if (index < (playerProvider.currentPlayer?.lives ?? 0)) const Shadow(color: AppTheme.dangerRed, blurRadius: 10)],
                            size: 28,
                        ),
                      );
                      }),
                  ),
                );
                },
            ),
            
            const Text("Desliza para moverte 👆👇👈👉", style: TextStyle(color: Colors.white54, fontSize: 12, letterSpacing: 1.2)),
            const SizedBox(height: 10),

            // GAME AREA
            Expanded(
                child: Center(
                    child: GestureDetector(
                        onVerticalDragUpdate: (details) {
                            if (details.delta.dy > 10) _onChangeDirection(Direction.down);
                            else if (details.delta.dy < -10) _onChangeDirection(Direction.up);
                        },
                        onHorizontalDragUpdate: (details) {
                            if (details.delta.dx > 10) _onChangeDirection(Direction.right);
                            else if (details.delta.dx < -10) _onChangeDirection(Direction.left);
                        },
                        child: Container(
                            margin: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                                color: const Color(0xFF1E1E1E), // Fondo gris muy oscuro
                                border: Border.all(color: AppTheme.primaryPurple.withOpacity(0.5), width: 2),
                                borderRadius: BorderRadius.circular(16),
                                boxShadow: [
                                  BoxShadow(color: AppTheme.primaryPurple.withOpacity(0.2), blurRadius: 20, spreadRadius: 2)
                                ]
                            ),
                            child: AspectRatio(
                                aspectRatio: cols / rows,
                                child: LayoutBuilder(
                                    builder: (context, constraints) {
                                        final cellSize = constraints.maxWidth / cols;
                                        return Stack(
                                            children: [
                                                // Grid Background Pattern
                                                CustomPaint(
                                                  size: Size(constraints.maxWidth, constraints.maxHeight),
                                                  painter: GridPainter(rows, cols, Colors.white.withOpacity(0.03)),
                                                ),
                                                
                                                // Food
                                                if (_food != null)
                                                    Positioned(
                                                        left: _food!.x * cellSize,
                                                        top: _food!.y * cellSize,
                                                        child: Container(
                                                            width: cellSize,
                                                            height: cellSize,
                                                            alignment: Alignment.center,
                                                            child: Container(
                                                              decoration: BoxDecoration(
                                                                shape: BoxShape.circle,
                                                                boxShadow: [
                                                                  BoxShadow(color: Colors.red.withOpacity(0.6), blurRadius: 10, spreadRadius: 2)
                                                                ]
                                                              ),
                                                              child: Text(
                                                                "🍎", 
                                                                style: TextStyle(fontSize: cellSize * 0.8),
                                                              ),
                                                            ),
                                                        ),
                                                    ),
                                                
                                                // Snake
                                                ..._snake.asMap().entries.map((entry) {
                                                    final index = entry.key;
                                                    final part = entry.value;
                                                    final isHead = index == 0;
                                                    
                                                    return Positioned(
                                                        left: part.x * cellSize,
                                                        top: part.y * cellSize,
                                                        child: Container(
                                                            width: cellSize,
                                                            height: cellSize,
                                                            margin: const EdgeInsets.all(1),
                                                            decoration: BoxDecoration(
                                                                color: isHead ? AppTheme.successGreen : Colors.greenAccent[400],
                                                                borderRadius: BorderRadius.circular(isHead ? 6 : 4),
                                                                gradient: isHead ? const LinearGradient(colors: [Colors.greenAccent, Colors.green]) : null,
                                                                boxShadow: isHead ? [
                                                                  BoxShadow(color: Colors.greenAccent.withOpacity(0.4), blurRadius: 8)
                                                                ] : null
                                                            ),
                                                            child: isHead ? _buildHeadEyes() : null,
                                                        ),
                                                    );
                                                }),
                                            ],
                                        );
                                    },
                                ),
                            ),
                        ),
                    ),
                ),
            ),
        ],
    );
  }

  Widget _buildHeadEyes() {
     // Rotar ojos según dirección
     int quarterTurns = 0;
     switch(_direction) {
       case Direction.up: quarterTurns = 0; break;
       case Direction.right: quarterTurns = 1; break;
       case Direction.down: quarterTurns = 2; break;
       case Direction.left: quarterTurns = 3; break;
     }

     return RotatedBox(
       quarterTurns: quarterTurns,
       child: Row(
         mainAxisAlignment: MainAxisAlignment.spaceEvenly,
         children: [
           Container(width: 4, height: 4, decoration: const BoxDecoration(color: Colors.black, shape: BoxShape.circle)),
           Container(width: 4, height: 4, decoration: const BoxDecoration(color: Colors.black, shape: BoxShape.circle)),
         ],
       ),
     );
  }
}

class GridPainter extends CustomPainter {
  final int rows;
  final int cols;
  final Color color;

  GridPainter(this.rows, this.cols, this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1;

    final cellWidth = size.width / cols;
    final cellHeight = size.height / rows;

    for (int i = 0; i <= cols; i++) {
      canvas.drawLine(Offset(i * cellWidth, 0), Offset(i * cellWidth, size.height), paint);
    }

    for (int i = 0; i <= rows; i++) {
      canvas.drawLine(Offset(0, i * cellHeight), Offset(size.width, i * cellHeight), paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
