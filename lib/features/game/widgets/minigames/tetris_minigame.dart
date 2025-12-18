import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/clue.dart';
import '../../../auth/providers/player_provider.dart';
import '../../providers/game_provider.dart';
import '../../../../core/theme/app_theme.dart';
import 'package:audioplayers/audioplayers.dart';

class TetrisMinigame extends StatefulWidget {
  final Clue clue;
  final VoidCallback onSuccess;

  const TetrisMinigame({
    super.key,
    required this.clue,
    required this.onSuccess,
  });

  @override
  State<TetrisMinigame> createState() => _TetrisMinigameState();
}

class _TetrisMinigameState extends State<TetrisMinigame> {
  // Configuración del tablero
  static const int rows = 20;
  static const int columns = 10;
  List<List<Color?>> board = List.generate(rows, (_) => List.filled(columns, null));

  // Pieza actual
  List<Point<int>> currentPiece = [];
  Color currentPieceColor = Colors.transparent;
  Point<int> currentPiecePosition = const Point(0, 0);
  
  // Estado del juego
  Timer? _timer;
  int _score = 0;
  int _targetScore = 1500; // Puntos para ganar
  bool _isGameOver = false;
  bool _isPaused = false;
  int _level = 1;
  int _linesCleared = 0;
  
  // Audio
  late AudioPlayer _audioPlayer;
  bool _isMusicPlaying = false;
  // Usando un link de Archive.org que es muy persistente
  static const String _tetrisMusicUrl = "https://archive.org/download/TetrisThemeA/Tetris%20Theme%20A.mp3";
  
  // Próxima pieza
  int? _nextPieceIndex;
  
  // Tetrominoes
  final List<List<Point<int>>> _tetrominoes = [
    [const Point(0, 0), const Point(1, 0), const Point(2, 0), const Point(3, 0)], // I
    [const Point(0, 0), const Point(1, 0), const Point(0, 1), const Point(1, 1)], // O
    [const Point(1, 0), const Point(0, 1), const Point(1, 1), const Point(2, 1)], // T
    [const Point(1, 0), const Point(2, 0), const Point(0, 1), const Point(1, 1)], // S
    [const Point(0, 0), const Point(1, 0), const Point(1, 1), const Point(2, 1)], // Z
    [const Point(0, 0), const Point(0, 1), const Point(1, 1), const Point(2, 1)], // J
    [const Point(2, 0), const Point(0, 1), const Point(1, 1), const Point(2, 1)], // L
  ];

  final List<Color> _tetrominoColors = [
    Colors.cyan,
    Colors.yellow,
    Colors.purple,
    Colors.green,
    Colors.red,
    Colors.blue,
    Colors.orange,
  ];

  @override
  void initState() {
    super.initState();
    _audioPlayer = AudioPlayer();
    _audioPlayer.setReleaseMode(ReleaseMode.loop);
    _audioPlayer.setVolume(1.0);
    
    // Iniciar lo más rápido posible
    _playMusic();
    _startGame();
  }

  Future<void> _playMusic() async {
    try {
      debugPrint("DEBUG: Intentando reproducir música de Tetris...");
      await _audioPlayer.play(UrlSource(_tetrisMusicUrl));
      if (mounted) {
        setState(() => _isMusicPlaying = true);
      }
      debugPrint("DEBUG: Música iniciada correctamente.");
    } catch (e) {
      debugPrint("ERROR en _playMusic: $e");
    }
  }

  Future<void> _stopMusic() async {
    try {
      await _audioPlayer.pause();
      if (mounted) {
        setState(() => _isMusicPlaying = false);
      }
    } catch (e) {
      debugPrint("ERROR en _stopMusic: $e");
    }
  }

  void _startGame() {
    _score = 0;
    _linesCleared = 0;
    _level = 1;
    _isGameOver = false;
    _isPaused = false;
    _clearBoard();
    _spawnPiece();
    _startTimer();
  }

  void _clearBoard() {
    setState(() {
      board = List.generate(rows, (_) => List.filled(columns, null));
    });
  }

  void _startTimer() {
    _timer?.cancel();
    int speed = max(100, 800 - (_level * 50));
    _timer = Timer.periodic(Duration(milliseconds: speed), (timer) {
      if (!_isPaused && !_isGameOver) {
        _moveDown();
      }
    });
  }

  void _spawnPiece() {
    final random = Random();
    
    // Si no hay próxima pieza (inicio), generamos una
    if (_nextPieceIndex == null) {
      _nextPieceIndex = random.nextInt(_tetrominoes.length);
    }
    
    final index = _nextPieceIndex!;
    currentPiece = List.from(_tetrominoes[index]);
    currentPieceColor = _tetrominoColors[index];
    currentPiecePosition = Point((columns - 4) ~/ 2, 0);

    // Generamos la siguiente
    _nextPieceIndex = random.nextInt(_tetrominoes.length);

    if (!_isValidPosition(currentPiece, currentPiecePosition)) {
      _gameOver();
    }
    setState(() {});
  }

  bool _isValidPosition(List<Point<int>> piece, Point<int> position) {
    for (var point in piece) {
      final x = position.x + point.x;
      final y = position.y + point.y;

      if (x < 0 || x >= columns || y >= rows) {
        return false;
      }
      
      if (y >= 0 && board[y][x] != null) {
        return false;
      }
    }
    return true;
  }

  void _moveDown() {
    if (_isValidPosition(currentPiece, Point(currentPiecePosition.x, currentPiecePosition.y + 1))) {
      setState(() {
        currentPiecePosition = Point(currentPiecePosition.x, currentPiecePosition.y + 1);
      });
    } else {
      _lockPiece();
    }
  }

  void _lockPiece() {
    setState(() {
      for (var point in currentPiece) {
        final x = currentPiecePosition.x + point.x;
        final y = currentPiecePosition.y + point.y;
        if (y >= 0) {
          board[y][x] = currentPieceColor;
        }
      }
      _checkLines();
      _spawnPiece();
    });
  }

  void _checkLines() {
    int lines = 0;
    for (int i = rows - 1; i >= 0; i--) {
      if (board[i].every((color) => color != null)) {
        board.removeAt(i);
        board.insert(0, List.filled(columns, null));
        lines++;
        i++; // Re-check the same row index as rows shifted down
      }
    }

    if (lines > 0) {
      int points = lines == 1 ? 100 : lines == 2 ? 300 : lines == 3 ? 500 : 800;
      _score += points;
      _linesCleared += lines;
      
      if (_linesCleared >= _level * 5) {
        _level++;
        _startTimer(); // Aumentar velocidad
      }
      
      if (_score >= _targetScore) {
        _winGame();
      }
    }
  }

  void _moveLeft() {
    if (!_isPaused && !_isGameOver && _isValidPosition(currentPiece, Point(currentPiecePosition.x - 1, currentPiecePosition.y))) {
      setState(() {
        currentPiecePosition = Point(currentPiecePosition.x - 1, currentPiecePosition.y);
      });
    }
  }

  void _moveRight() {
    if (!_isPaused && !_isGameOver && _isValidPosition(currentPiece, Point(currentPiecePosition.x + 1, currentPiecePosition.y))) {
      setState(() {
        currentPiecePosition = Point(currentPiecePosition.x + 1, currentPiecePosition.y);
      });
    }
  }

  void _rotate() {
    if (_isPaused || _isGameOver) return;
    
    // Simplest rotation: 90 degrees clockwise
    // x' = -y
    // y' = x
    List<Point<int>> newPiece = [];
    for (var point in currentPiece) {
      // Rotate around the second block (usually center-ish)
      // Or just standard rotation logic
      // Simplificado: rotar alrededor de (1,1) de la pieza relativa
      // Para hacerlo más robusto usamos pivote en 1,1 si es posible, o centro.
      // Implementación simple de rotación
      int x = point.y;
      int y = -point.x;
      // Ajuste para mantenerla positiva/cerca
      // Mejor estrategia: transponer y reverse filas
      // Pero dado que son puntos:
      // x' = y
      // y' = 3 - x (para matriz 4x4)
      // Vamos a usar una rotación simple relativa al primer bloque
    }
    
    // Mejor enfoque: rotar alrededor del centro relativo de la pieza
    // Para 3x3 o 4x4.
    // Usaremos una tabla predefinida o simplemente lógica de matriz
    
    List<Point<int>> rotated = [];
    // Centro de rotación aproximado (1.5, 1.5) no funciona bien con Points enteros.
    // Usamos rotación básica: (x, y) -> (-y, x)
    
    // Vamos a hardcodear algo simple: cambiar ancho por alto
    // Realmente necesitamos rotar cada punto relativo al origen de la pieza
    
    // Estrategia correcta:
    // 1. Encontrar centro
    // 2. Rotar
    
    // Implementación simple:
    List<Point<int>> next = [];
    for (var p in currentPiece) {
      // Asumiendo matriz de 4x4 o 3x3.
      // x' = y
      // y' = -x
      // Esto rota alrededor de 0,0.
      // La mayoría de piezas giran alrededor de punto 1 (o p[1])
      Point<int> pivot = currentPiece[1]; 
      int dx = p.x - pivot.x;
      int dy = p.y - pivot.y;
      
      int rx = -dy;
      int ry = dx;
      
      next.add(Point(pivot.x + rx, pivot.y + ry));
    }
    
    // Corrección para la pieza cuadrada (O) que no debe rotar o la I que es larga
    // Si es O (amarilla), no rotar.
    if (currentPieceColor == Colors.yellow) return;
    
    // Normalizar para que no se salga mucho
    // Verificar validez
    if (_isValidPosition(next, currentPiecePosition)) {
      setState(() {
        currentPiece = next;
      });
    }
  }

  void _gameOver() {
    _timer?.cancel();
    setState(() => _isGameOver = true);
    _loseLife("El juego ha terminado.");
  }

  void _winGame() {
    _timer?.cancel();
    widget.onSuccess();
  }
  
  void _loseLife(String reason) {
    _timer?.cancel();
    final gameProvider = Provider.of<GameProvider>(context, listen: false);
    final playerProvider = Provider.of<PlayerProvider>(context, listen: false);
    
    if (playerProvider.currentPlayer != null) {
      gameProvider.loseLife(playerProvider.currentPlayer!.id).then((_) {
         if (!mounted) return;
         
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
            Text(reason, style: const TextStyle(color: Colors.white)),
            const SizedBox(height: 10),
            const Text("Has perdido 1 vida ❤️", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ],
        ),
        actions: [
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _startGame();
            },
            child: const Text("Reintentar"),
          ),
          TextButton(
            onPressed: () {
                Navigator.pop(context); // Dialog
                Navigator.pop(context); // Screen
            },
             child: const Text("Salir")
          )
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
  void dispose() {
    _timer?.cancel();
    _audioPlayer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final player = Provider.of<PlayerProvider>(context).currentPlayer;

    return Column(
      children: [
        // Status Bar
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Vidas
              Row(
                children: [
                   IconButton(
                    icon: Icon(_isMusicPlaying ? Icons.music_note : Icons.music_off, color: Colors.white54),
                    onPressed: () => _isMusicPlaying ? _stopMusic() : _playMusic(),
                  ),
                  const SizedBox(width: 5),
                  const Icon(Icons.favorite, color: AppTheme.dangerRed),
                  const SizedBox(width: 5),
                  Text("x${player?.lives ?? 0}", style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                ],
              ),
              // Score & Target
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text("Puntos: $_score / $_targetScore", style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  Text("Nivel: $_level", style: const TextStyle(color: Colors.white70, fontSize: 12)),
                ],
              ),
            ],
          ),
        ),

        const Text(
          "TETRIS CHALLENGE",
          style: TextStyle(color: AppTheme.accentGold, fontSize: 16, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 5),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Text(
            widget.clue.riddleQuestion ?? "Consigue los puntos para ganar",
            style: const TextStyle(color: Colors.white70, fontSize: 12),
            textAlign: TextAlign.center,
          ),
        ),
        const SizedBox(height: 10),

        // Game Board & Next Piece Sidebar
        Expanded(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Main Board
              Expanded(
                flex: 3,
                child: Center(
                  child: AspectRatio(
                    aspectRatio: columns / rows,
                    child: Container(
                      margin: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.black,
                        border: Border.all(color: Colors.white24, width: 2),
                        borderRadius: BorderRadius.circular(8),
                        boxShadow: [
                          BoxShadow(color: AppTheme.primaryPurple.withOpacity(0.1), blurRadius: 20)
                        ]
                      ),
                      child: Column(
                        children: List.generate(rows, (y) {
                          return Expanded(
                            child: Row(
                              children: List.generate(columns, (x) {
                                Color? color = board[y][x];
                                
                                bool isCurrentPiece = false;
                                for (var p in currentPiece) {
                                  if (currentPiecePosition.y + p.y == y && currentPiecePosition.x + p.x == x) {
                                    color = currentPieceColor;
                                    isCurrentPiece = true;
                                    break;
                                  }
                                }

                                return Expanded(
                                  child: Container(
                                    margin: const EdgeInsets.all(0.5),
                                    decoration: BoxDecoration(
                                      color: color ?? Colors.white.withOpacity(0.02),
                                      borderRadius: BorderRadius.circular(1),
                                      border: isCurrentPiece || color != null 
                                        ? Border.all(color: Colors.white.withOpacity(0.3), width: 0.5) 
                                        : null,
                                    ),
                                  ),
                                );
                              }),
                            ),
                          );
                        }),
                      ),
                    ),
                  ),
                ),
              ),
              
              // Right Sidebar (Next Piece)
              Expanded(
                flex: 1,
                child: Padding(
                  padding: const EdgeInsets.only(top: 20, right: 10),
                  child: Column(
                    children: [
                      const Text("SIGUIENTE", style: TextStyle(color: Colors.white54, fontSize: 10, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 10),
                      _buildNextPiecePreview(),
                      const Spacer(),
                      // Score info
                      _buildMiniStat("LVL", "$_level"),
                      const SizedBox(height: 10),
                      _buildMiniStat("LINES", "$_linesCleared"),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),

        // Controls
        Padding(
          padding: const EdgeInsets.only(bottom: 20, left: 20, right: 20, top: 10),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildControlBtn(Icons.arrow_back, _moveLeft),
              _buildControlBtn(Icons.rotate_right, _rotate, color: AppTheme.accentGold),
              _buildControlBtn(Icons.arrow_downward, _moveDown), // Soft drop
              _buildControlBtn(Icons.arrow_forward, _moveRight),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildControlBtn(IconData icon, VoidCallback onTap, {Color color = Colors.white}) {
    return GestureDetector(
      onTapDown: (_) => onTap(),
      child: Container(
        padding: const EdgeInsets.all(15),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.1),
          shape: BoxShape.circle,
          border: Border.all(color: color.withOpacity(0.5)),
        ),
        child: Icon(icon, color: color, size: 28),
      ),
    );
  }

  Widget _buildNextPiecePreview() {
    if (_nextPieceIndex == null) return const SizedBox();
    
    final piece = _tetrominoes[_nextPieceIndex!];
    final color = _tetrominoColors[_nextPieceIndex!];
    
    return Container(
      width: 60,
      height: 60,
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.black38,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white10),
      ),
      child: Center(
        child: LayoutBuilder(builder: (context, constraints) {
          final size = constraints.maxWidth / 4;
          return Stack(
            children: piece.map((p) {
              return Positioned(
                left: p.x * size,
                top: p.y * size,
                child: Container(
                  width: size - 1,
                  height: size - 1,
                  decoration: BoxDecoration(
                    color: color,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              );
            }).toList(),
          );
        }),
      ),
    );
  }

  Widget _buildMiniStat(String label, String value) {
    return Column(
      children: [
        Text(label, style: const TextStyle(color: Colors.white38, fontSize: 8)),
        Text(value, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
      ],
    );
  }
}
