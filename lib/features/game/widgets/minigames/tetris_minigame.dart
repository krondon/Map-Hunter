import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../utils/minigame_logic_helper.dart';
import '../../models/clue.dart';
import '../../../auth/providers/player_provider.dart';
import '../../providers/game_provider.dart';
import '../../providers/connectivity_provider.dart';
import '../../../../core/theme/app_theme.dart';
import 'package:audioplayers/audioplayers.dart';
import 'game_over_overlay.dart';
import '../../../mall/screens/mall_screen.dart';

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
  List<List<Color?>> board =
      List.generate(rows, (_) => List.filled(columns, null));

  // Pieza actual
  List<Point<int>> currentPiece = [];
  Color currentPieceColor = Colors.transparent;
  Point<int> currentPiecePosition = const Point(0, 0);

  // Estado del juego
  Timer? _timer;
  int _score = 0;
  int _targetScore = 1000; // Puntos para ganar
  bool _isGameOver = false;
  bool _isPaused = false;
  int _level = 1;
  int _linesCleared = 0;

  // Overlay State
  bool _showOverlay = false;
  String _overlayTitle = "";
  String _overlayMessage = "";
  bool _canRetry = false;
  bool _showShopButton = false;

  void _showOverlayState(
      {required String title,
      required String message,
      bool retry = false,
      bool showShop = false}) {
    setState(() {
      _showOverlay = true;
      _overlayTitle = title;
      _overlayMessage = message;
      _canRetry = retry;
      _showShopButton = showShop;
    });
  }

  // Audio
  late AudioPlayer _audioPlayer;
  bool _isMusicPlaying = false;

  // Próxima pieza
  int? _nextPieceIndex;

  // Tetrominoes
  final List<List<Point<int>>> _tetrominoes = [
    [
      const Point(0, 0),
      const Point(1, 0),
      const Point(2, 0),
      const Point(3, 0)
    ], // I
    [
      const Point(0, 0),
      const Point(1, 0),
      const Point(0, 1),
      const Point(1, 1)
    ], // O
    [
      const Point(1, 0),
      const Point(0, 1),
      const Point(1, 1),
      const Point(2, 1)
    ], // T
    [
      const Point(1, 0),
      const Point(2, 0),
      const Point(0, 1),
      const Point(1, 1)
    ], // S
    [
      const Point(0, 0),
      const Point(1, 0),
      const Point(1, 1),
      const Point(2, 1)
    ], // Z
    [
      const Point(0, 0),
      const Point(0, 1),
      const Point(1, 1),
      const Point(2, 1)
    ], // J
    [
      const Point(2, 0),
      const Point(0, 1),
      const Point(1, 1),
      const Point(2, 1)
    ], // L
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
    _audioPlayer.setVolume(0.5);

    // Iniciar lo más rápido posible
    _playMusic();
    _startGame();
  }

  Future<void> _playMusic() async {
    if (_isMusicPlaying) return;
    try {
      debugPrint("DEBUG: Intentando reproducir música de Tetris (local)...");
      await _audioPlayer.play(AssetSource('audio/tetris_theme.mp3'));
      if (mounted) {
        setState(() => _isMusicPlaying = true);
      }
      debugPrint("DEBUG: Música de Tetris iniciada correctamente.");
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
      if (!mounted) return;

      // Check for freeze state
      final gameProvider = Provider.of<GameProvider>(context, listen: false);
      if (gameProvider.isFrozen) return; // Pause game loop

      // [FIX] Pause game loop if connectivity is bad
      final connectivityByProvider =
          Provider.of<ConnectivityProvider>(context, listen: false);
      if (!connectivityByProvider.isOnline) {
        return; // Skip tick
      }

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
    // Si la música no ha empezado, intentamos iniciarla en la primera interacción
    if (!_isMusicPlaying) {
      _playMusic();
    }

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
    if (_isValidPosition(currentPiece,
        Point(currentPiecePosition.x, currentPiecePosition.y + 1))) {
      setState(() {
        currentPiecePosition =
            Point(currentPiecePosition.x, currentPiecePosition.y + 1);
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
      int points = lines == 1
          ? 100
          : lines == 2
              ? 300
              : lines == 3
                  ? 500
                  : 800;
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
    if (!_isPaused &&
        !_isGameOver &&
        _isValidPosition(currentPiece,
            Point(currentPiecePosition.x - 1, currentPiecePosition.y))) {
      setState(() {
        currentPiecePosition =
            Point(currentPiecePosition.x - 1, currentPiecePosition.y);
      });
    }
  }

  void _moveRight() {
    if (!_isPaused &&
        !_isGameOver &&
        _isValidPosition(currentPiece,
            Point(currentPiecePosition.x + 1, currentPiecePosition.y))) {
      setState(() {
        currentPiecePosition =
            Point(currentPiecePosition.x + 1, currentPiecePosition.y);
      });
    }
  }

  void _rotate() {
    if (_isPaused || _isGameOver) return;

    // [FIX] Prevent interaction if offline
    if (!Provider.of<ConnectivityProvider>(context, listen: false).isOnline)
      return;

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

  void _loseLife(String reason) async {
    _timer?.cancel();
    _stopMusic();
    final playerProvider = Provider.of<PlayerProvider>(context, listen: false);

    if (playerProvider.currentPlayer != null) {
      final newLives = await MinigameLogicHelper.executeLoseLife(context);

      if (!mounted) return;

      if (newLives <= 0) {
        _showOverlayState(
            title: "GAME OVER",
            message: "Te has quedado sin vidas.",
            retry: false,
            showShop: true);
      } else {
        _showOverlayState(
            title: "¡FALLASTE!",
            message: "$reason",
            retry: true,
            showShop: false);
      }
    }
  }

  // DIALOGS REMOVED

  @override
  void dispose() {
    _timer?.cancel();
    _audioPlayer.dispose();
    super.dispose();
  }

  @override
  // --- GESTURE CONTROLS ---
  double _horizontalDragAccumulator = 0.0;
  double _verticalDragAccumulator = 0.0;
  static const double _sensitivity = 20.0; // Píxeles para detectar movimiento

  void _handleHorizontalDrag(DragUpdateDetails details) {
    if (_isPaused || _isGameOver) return;

    // [FIX] Prevent interaction if offline
    if (!Provider.of<ConnectivityProvider>(context, listen: false).isOnline)
      return;

    _horizontalDragAccumulator += details.delta.dx;

    if (_horizontalDragAccumulator.abs() > _sensitivity) {
      if (_horizontalDragAccumulator > 0) {
        _moveRight();
      } else {
        _moveLeft();
      }
      _horizontalDragAccumulator = 0.0; // Reset after move
    }
  }

  void _handleVerticalDrag(DragUpdateDetails details) {
    if (_isPaused || _isGameOver) return;

    // [FIX] Prevent interaction if offline
    if (!Provider.of<ConnectivityProvider>(context, listen: false).isOnline)
      return;

    _verticalDragAccumulator += details.delta.dy;

    if (_verticalDragAccumulator > _sensitivity) {
      _moveDown(); // Soft drop
      _verticalDragAccumulator = 0.0;
    }
  }

  void _handleTap() {
    _rotate();
  }

  @override
  Widget build(BuildContext context) {
    final player = Provider.of<PlayerProvider>(context).currentPlayer;

    return PopScope(
      canPop: false,
      onPopInvoked: (didPop) {},
      child: Stack(
        children: [
          // Background/Game Layer
          GestureDetector(
            onTap: _handleTap,
            onHorizontalDragUpdate: _handleHorizontalDrag,
            onVerticalDragUpdate: _handleVerticalDrag,
            behavior: HitTestBehavior.opaque, // Catch all touches
            child: Column(
              children: [
                // Game Board Area
                Expanded(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Main Board (Maximized)
                      Expanded(
                        flex: 5, // Reduced flex to give more space to sidebar
                        child: Center(
                          child: LayoutBuilder(builder: (context, constraints) {
                            // Calcular tamaño máximo posible manteniendo aspect ratio 1:2
                            double height = constraints.maxHeight;
                            double width =
                                height / 2; // Ratio 10 cols / 20 rows = 0.5

                            // Allow wider if possible, limited by container
                            if (width > constraints.maxWidth) {
                              width = constraints.maxWidth;
                              height = width * 2;
                            }

                            return Container(
                              width: width,
                              height: height,
                              margin: const EdgeInsets.symmetric(
                                  horizontal: 0, vertical: 0),
                              decoration: BoxDecoration(
                                  color: Colors.black.withOpacity(0.8),
                                  border: Border.all(
                                      color: AppTheme.primaryPurple
                                          .withOpacity(0.5),
                                      width: 1),
                                  boxShadow: [
                                    BoxShadow(
                                        color: AppTheme.primaryPurple
                                            .withOpacity(0.1),
                                        blurRadius: 10,
                                        spreadRadius: 2)
                                  ]),
                              child: Column(
                                children: List.generate(rows, (y) {
                                  return Expanded(
                                    child: Row(
                                      children: List.generate(columns, (x) {
                                        Color? color = board[y][x];
                                        bool isCurrentPiece = false;

                                        // Check current piece
                                        for (var p in currentPiece) {
                                          if (currentPiecePosition.y + p.y ==
                                                  y &&
                                              currentPiecePosition.x + p.x ==
                                                  x) {
                                            color = currentPieceColor;
                                            isCurrentPiece = true;
                                            break;
                                          }
                                        }

                                        if (color == null) {
                                          return Expanded(
                                            child: Container(
                                              margin: const EdgeInsets.all(0),
                                              decoration: BoxDecoration(
                                                border: Border.all(
                                                    color: Colors.white
                                                        .withOpacity(0.03),
                                                    width: 0.5), // Subtle grid
                                              ),
                                            ),
                                          );
                                        }

                                        return Expanded(
                                          child: Container(
                                            margin: const EdgeInsets.all(0.5),
                                            decoration: BoxDecoration(
                                              color: color,
                                              gradient: LinearGradient(
                                                  begin: Alignment.topLeft,
                                                  end: Alignment.bottomRight,
                                                  colors: [
                                                    color!.withOpacity(0.9),
                                                    color!.withOpacity(0.7),
                                                  ]),
                                              boxShadow: isCurrentPiece
                                                  ? [
                                                      BoxShadow(
                                                          color: color!
                                                              .withOpacity(0.6),
                                                          blurRadius: 4,
                                                          spreadRadius: 0)
                                                    ]
                                                  : null,
                                              borderRadius:
                                                  BorderRadius.circular(2),
                                            ),
                                          ),
                                        );
                                      }),
                                    ),
                                  );
                                }),
                              ),
                            );
                          }),
                        ),
                      ),

                      // Right Sidebar (Integrated)
                      Expanded(
                        flex: 2, // Increased flex for wider score area
                        child: Padding(
                          padding: const EdgeInsets.only(
                              top: 10, right: 10, left: 10),
                          child: Column(
                            children: [
                              // Score Block
                              Container(
                                width: double.infinity,
                                padding:
                                    const EdgeInsets.symmetric(vertical: 8),
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.05),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: Colors.white10),
                                ),
                                child: Column(
                                  children: [
                                    const FittedBox(
                                      fit: BoxFit.scaleDown,
                                      child: Text("META",
                                          style: TextStyle(
                                              color: AppTheme.accentGold,
                                              fontSize: 12,
                                              fontWeight: FontWeight.bold)),
                                    ),
                                    const SizedBox(height: 4),
                                    FittedBox(
                                      fit: BoxFit.scaleDown,
                                      child: Text(
                                        "$_score / $_targetScore",
                                        style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 20,
                                            fontWeight: FontWeight.bold),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 20),

                              // Next Piece
                              Container(
                                decoration: BoxDecoration(
                                    border: Border.all(color: Colors.white10),
                                    borderRadius: BorderRadius.circular(8)),
                                padding: const EdgeInsets.all(4),
                                child: Column(
                                  children: [
                                    const Text("NEXT",
                                        style: TextStyle(
                                            color: Colors.white38,
                                            fontSize: 8,
                                            fontWeight: FontWeight.bold)),
                                    const SizedBox(height: 2),
                                    SizedBox(
                                        height: 35, // Slightly bigger height
                                        width: 45, // and width
                                        child: _buildNextPiecePreview()),
                                  ],
                                ),
                              ),
// ... (rest of sidebar) ...

// ... (rest of build) ...
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // Bottom Controls (Discrete but functional)
                // Mantenerlos como opción secundaria o para accesibilidad
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: const Text(
                    "Desliza para mover • Toca para rotar",
                    style: TextStyle(
                      color: Colors.white54,
                      fontSize: 12,
                      letterSpacing: 1.0,
                    ),
                  ),
                ),

                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 10),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _buildControlBtn(Icons.arrow_back, _moveLeft,
                          size: 50, iconSize: 28),
                      _buildControlBtn(Icons.arrow_downward, _moveDown,
                          size: 50, iconSize: 28),
                      _buildControlBtn(Icons.arrow_forward, _moveRight,
                          size: 50, iconSize: 28),
                      _buildControlBtn(Icons.rotate_right, _rotate,
                          color: AppTheme.accentGold, size: 50, iconSize: 28),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // OVERLAY
          if (_showOverlay)
            GameOverOverlay(
              title: _overlayTitle,
              message: _overlayMessage,
              onRetry: _canRetry
                  ? () {
                      setState(() {
                        _showOverlay = false;
                      });
                      _startGame();
                    }
                  : null,
              onGoToShop: _showShopButton
                  ? () async {
                      await Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const MallScreen()),
                      );
                      if (!context.mounted) return;
                      final player =
                          Provider.of<PlayerProvider>(context, listen: false)
                              .currentPlayer;
                      if ((player?.lives ?? 0) > 0) {
                        setState(() {
                          _canRetry = true;
                          _showShopButton = false;
                          _overlayTitle = "¡VIDAS OBTENIDAS!";
                          _overlayMessage = "Puedes continuar jugando.";
                        });
                      }
                    }
                  : null,
              onExit: () {
                Navigator.pop(context);
              },
            ),
        ],
      ),
    );
  }

  Widget _buildControlBtn(IconData icon, VoidCallback onTap,
      {Color color = Colors.white, double size = 50, double iconSize = 28}) {
    return GestureDetector(
      onTapDown: (_) => onTap(),
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.05),
          shape: BoxShape.circle,
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Icon(icon, color: color, size: iconSize),
      ),
    );
  }

  Widget _buildNextPiecePreview() {
    if (_nextPieceIndex == null) return const SizedBox();

    final piece = _tetrominoes[_nextPieceIndex!];
    final color = _tetrominoColors[_nextPieceIndex!];

    return Container(
      decoration: BoxDecoration(
        color: Colors.black38,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: Colors.white10),
      ),
      child: LayoutBuilder(builder: (context, constraints) {
        // Calculate bounds
        int minX = 4, maxX = 0, minY = 4, maxY = 0;
        for (var p in piece) {
          if (p.x < minX) minX = p.x;
          if (p.x > maxX) maxX = p.x;
          if (p.y < minY) minY = p.y;
          if (p.y > maxY) maxY = p.y;
        }

        final width = maxX - minX + 1;
        final height = maxY - minY + 1;

        final size =
            min(constraints.maxWidth / width, constraints.maxHeight / height) *
                0.8;

        final totalWidth = width * size;
        final totalHeight = height * size;

        return Center(
          child: SizedBox(
            width: totalWidth,
            height: totalHeight,
            child: Stack(
              children: piece.map((p) {
                return Positioned(
                  left: (p.x - minX) * size,
                  top: (p.y - minY) * size,
                  child: Container(
                    width: size - 1,
                    height: size - 1,
                    decoration: BoxDecoration(
                      color: color,
                      borderRadius: BorderRadius.circular(1),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        );
      }),
    );
  }
}
