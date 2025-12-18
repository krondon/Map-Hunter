import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/clue.dart';
import '../../../auth/providers/player_provider.dart';
import '../../providers/game_provider.dart';
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
  static const int winScore = 10;
  
  // Game State
  List<Point<int>> _snake = [const Point(10, 10)];
  Point<int>? _food;
  Direction _direction = Direction.right;
  Direction _nextDirection = Direction.right;
  bool _isPlaying = false;
  bool _isGameOver = false;
  int _score = 0;
  
  // Intentos Locales
  int _crashAllowance = 3; 
  
  // Timer
  Timer? _gameLoop;
  Timer? _countdownTimer;
  int _secondsRemaining = 90;

  // Pre-game Countdown
  int _preStartCount = 3;
  bool _showingPreStart = false;
  Timer? _preStartTimer;

  @override
  void initState() {
    super.initState();
    _startNewGame();
  }

  @override
  void dispose() {
    _gameLoop?.cancel();
    _countdownTimer?.cancel();
    _preStartTimer?.cancel();
    super.dispose();
  }

  void _startNewGame() {
    _gameLoop?.cancel();
    _countdownTimer?.cancel();
    _preStartTimer?.cancel();
    
    setState(() {
      _snake = [const Point(10, 10), const Point(9, 10), const Point(8, 10)];
      _direction = Direction.right;
      _nextDirection = Direction.right;
      _score = 0;
      _secondsRemaining = 90;
      _isPlaying = false;
      _isGameOver = false;
      _crashAllowance = 3; // Reset intentos
      _generateFood();
      _showingPreStart = true;
      _preStartCount = 3;
    });

    _runPreStartCountdown();
  }

  void _runPreStartCountdown() {
    _preStartTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      
      setState(() {
        if (_preStartCount > 1) {
          _preStartCount--;
        } else if (_preStartCount == 1) {
          _preStartCount = 0; // 0 will represent "YA!"
        } else {
          timer.cancel();
          _showingPreStart = false;
          _isPlaying = true;
          _startCountdown();
          _startGameLoop();
        }
      });
    });
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
              _loseGlobalLife("¡Se acabó el tiempo!", isTimeOut: true);
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
            _handleCrash("¡Chocaste con la pared!");
            return;
        }

        // Colisión a sí mismo
        if (_snake.contains(newHead)) {
             _handleCrash("¡Te mordiste la cola!");
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

  void _handleCrash(String reason) {
    setState(() {
      _crashAllowance--;
    });

    if (_crashAllowance <= 0) {
       _loseGlobalLife("¡Agotaste tus intentos!"); 
    } else {
       // Pausar y Feedback
       _gameLoop?.cancel();
       ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("¡Choque! Intentos: $_crashAllowance. Reiniciando posición..."), 
            duration: const Duration(milliseconds: 1200),
            backgroundColor: AppTheme.warningOrange,
          )
       );
       
       setState(() {
          // Resetear solo la serpiente, mantener score y tiempo
          _snake = [const Point(10, 10), const Point(9, 10), const Point(8, 10)];
          _direction = Direction.right;
          _nextDirection = Direction.right;
       });
       
       // Reanudar
       Future.delayed(const Duration(seconds: 1), () {
         if (!_isGameOver && mounted) _startGameLoop();
       });
    }
  }

  void _winGame() {
      _isPlaying = false;
      _isGameOver = true;
      _gameLoop?.cancel();
      _countdownTimer?.cancel();
      widget.onSuccess();
  }

  void _loseGlobalLife(String reason, {bool isTimeOut = false}) {
      _isPlaying = false;
      _gameLoop?.cancel();
      _countdownTimer?.cancel();
      
      final gameProvider = Provider.of<GameProvider>(context, listen: false);
      final playerProvider = Provider.of<PlayerProvider>(context, listen: false);
      
      if (playerProvider.currentPlayer != null) {
          gameProvider.loseLife(playerProvider.currentPlayer!.id).then((_) {
             if (!mounted) return;
             
             if (gameProvider.lives <= 0) {
                _showGameOverDialog("Te has quedado sin vidas.");
             } else {
                _showRestartDialog(reason);
             }
          });
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
          ),
          TextButton(
            onPressed: () {
               Navigator.pop(context);
              Navigator.pop(context
              ); 
            },
            child: const Text("Salir"),
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
            // Header Info reducido
            Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                child: Row(
                    children: [
                        // Score
                        Expanded(
                          child: Container(
                               padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                               decoration: BoxDecoration(
                                 color: Colors.black45,
                                 borderRadius: BorderRadius.circular(15),
                                 border: Border.all(color: AppTheme.successGreen.withOpacity(0.3)),
                               ),
                               child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Text("🍎", style: TextStyle(fontSize: 16)),
                                    const SizedBox(width: 6),
                                    Text(
                                      "$_score / $winScore", 
                                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)
                                    ),
                                  ],
                               ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        // Intentos
                        Container(
                             padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                             child: Row(
                                 mainAxisSize: MainAxisSize.min,
                                 children: List.generate(3, (index) {
                                   return Icon(
                                       index < _crashAllowance ? Icons.flash_on : Icons.flash_off,
                                       color: index < _crashAllowance ? AppTheme.accentGold : Colors.white24,
                                       size: 18,
                                   );
                                 }),
                             ),
                        ),
                        const SizedBox(width: 8),
                        // Timer
                        Expanded(
                          child: Container(
                               padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                               decoration: BoxDecoration(
                                 color: isLowTime ? AppTheme.dangerRed.withOpacity(0.2) : Colors.black45,
                                 borderRadius: BorderRadius.circular(15),
                                 border: Border.all(color: isLowTime ? AppTheme.dangerRed : Colors.white12),
                               ),
                               child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(Icons.timer_outlined, color: isLowTime ? AppTheme.dangerRed : Colors.white70, size: 16),
                                    const SizedBox(width: 4),
                                    Text(
                                      "$minutes:$seconds", 
                                      style: TextStyle(
                                        color: isLowTime ? AppTheme.dangerRed : Colors.white, 
                                        fontWeight: FontWeight.bold, 
                                        fontSize: 14
                                      )
                                    ),
                                  ],
                               ),
                          ),
                        ),
                    ],
                ),
            ),
             
            const SizedBox(height: 10),

            Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  child: Center(
                      child: GestureDetector(
                          onPanEnd: (details) {
                              final velocity = details.velocity.pixelsPerSecond;
                              if (velocity.distance < 100) return; 

                              if (velocity.dx.abs() > velocity.dy.abs()) {
                                  if (velocity.dx > 0) _onChangeDirection(Direction.right);
                                  else _onChangeDirection(Direction.left);
                              } else {
                                  if (velocity.dy > 0) _onChangeDirection(Direction.down);
                                  else _onChangeDirection(Direction.up);
                              }
                          },
                          child: AspectRatio(
                              aspectRatio: cols / rows,
                              child: Container(
                                  decoration: BoxDecoration(
                                      color: const Color(0xFF121212),
                                      border: Border.all(color: AppTheme.primaryPurple.withOpacity(0.4), width: 3),
                                      borderRadius: BorderRadius.circular(12),
                                      boxShadow: [
                                        BoxShadow(color: AppTheme.primaryPurple.withOpacity(0.15), blurRadius: 30, spreadRadius: 5)
                                      ]
                                  ),
                                  child: LayoutBuilder(
                                      builder: (context, constraints) {
                                          final cellSize = constraints.maxWidth / cols;
                                          return Stack(
                                              clipBehavior: Clip.none,
                                              children: [
                                                  CustomPaint(
                                                    size: Size(constraints.maxWidth, constraints.maxHeight),
                                                    painter: GridPainter(rows, cols, Colors.white.withOpacity(0.04)),
                                                  ),
                                                  
                                                  if (_food != null)
                                                      Positioned(
                                                          left: _food!.x * cellSize,
                                                          top: _food!.y * cellSize,
                                                          child: SizedBox(
                                                              width: cellSize,
                                                              height: cellSize,
                                                              child: Center(
                                                                child: Text("🍎", style: TextStyle(fontSize: cellSize * 1.0)),
                                                              ),
                                                          ),
                                                      ),
                                                  
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
                                                              margin: const EdgeInsets.all(0.5),
                                                              decoration: BoxDecoration(
                                                                  color: isHead ? AppTheme.successGreen : Colors.greenAccent[700],
                                                                  borderRadius: BorderRadius.circular(isHead ? 4 : 2),
                                                              ),
                                                              child: isHead ? _buildHeadEyes(cellSize) : null,
                                                          ),
                                                      );
                                                  }),

                                                  if (_showingPreStart)
                                                    _buildPreStartOverlay(cellSize),
                                              ],
                                          );
                                      },
                                  ),
                              ),
                          ),
                      ),
                  ),
                ),
            ),
            
            // CONTROLES D-PAD COMPACTOS
            _buildDPad(),
            const SizedBox(height: 10),
        ],
    );
  }

  Widget _buildDPad() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 0),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildDPadButton(Icons.keyboard_arrow_up, () => _onChangeDirection(Direction.up)),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildDPadButton(Icons.keyboard_arrow_left, () => _onChangeDirection(Direction.left)),
              const SizedBox(width: 80), 
              _buildDPadButton(Icons.keyboard_arrow_right, () => _onChangeDirection(Direction.right)),
            ],
          ),
          _buildDPadButton(Icons.keyboard_arrow_down, () => _onChangeDirection(Direction.down)),
        ],
      ),
    );
  }

  Widget _buildDPadButton(IconData icon, VoidCallback onTap) {
    return GestureDetector(
      onTapDown: (_) => onTap(),
      child: Container(
        width: 45,
        height: 45,
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.06),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.white10),
        ),
        child: Icon(icon, color: Colors.white54, size: 28),
      ),
    );
  }

  Widget _buildPreStartOverlay(double cellSize) {
    String text = _preStartCount > 0 ? "$_preStartCount" : "¡YA!";
    Color textColor = _preStartCount > 0 ? AppTheme.accentGold : AppTheme.successGreen;
    
    return Container(
      width: double.infinity,
      height: double.infinity,
      color: Colors.black.withOpacity(0.4),
      child: Center(
        child: TweenAnimationBuilder<double>(
          key: ValueKey(text),
          tween: Tween(begin: 0.0, end: 1.0),
          duration: const Duration(milliseconds: 500),
          curve: Curves.elasticOut,
          builder: (context, value, child) {
            return Transform.scale(
              scale: 0.5 + (value * 1.5),
              child: Opacity(
                opacity: value.clamp(0, 1),
                child: child,
              ),
            );
          },
          child: Text(
            text,
            style: TextStyle(
              color: textColor,
              fontSize: 80,
              fontWeight: FontWeight.bold,
              shadows: [
                Shadow(
                  color: textColor.withOpacity(0.5),
                  blurRadius: 20,
                  offset: const Offset(0, 0),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeadEyes(double cellSize) {
     int quarterTurns = 0;
     switch(_direction) {
       case Direction.up: quarterTurns = 0; break;
       case Direction.right: quarterTurns = 1; break;
       case Direction.down: quarterTurns = 2; break;
       case Direction.left: quarterTurns = 3; break;
     }

     final eyeSize = cellSize * 0.2;

     return RotatedBox(
       quarterTurns: quarterTurns,
       child: Row(
         mainAxisAlignment: MainAxisAlignment.spaceEvenly,
         children: [
           Container(width: eyeSize, height: eyeSize, decoration: const BoxDecoration(color: Colors.black, shape: BoxShape.circle)),
           Container(width: eyeSize, height: eyeSize, decoration: const BoxDecoration(color: Colors.black, shape: BoxShape.circle)),
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