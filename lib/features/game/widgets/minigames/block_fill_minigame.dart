import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../utils/minigame_logic_helper.dart';
import '../../models/clue.dart';
import '../../../auth/providers/player_provider.dart';
import '../../providers/game_provider.dart';
import '../../providers/connectivity_provider.dart';
import '../../../../core/theme/app_theme.dart';
import 'game_over_overlay.dart';
import '../../../mall/screens/mall_screen.dart';

class BlockFillMinigame extends StatefulWidget {
  final Clue clue;
  final VoidCallback onSuccess;

  const BlockFillMinigame({
    super.key,
    required this.clue,
    required this.onSuccess,
  });

  @override
  State<BlockFillMinigame> createState() => _BlockFillMinigameState();
}

class _BlockFillMinigameState extends State<BlockFillMinigame> {
  static const int rows = 5;
  static const int cols = 5;

  // -1: Pared, 0: Vacío, 1: Visitado, 2: Inicio, 3: Meta
  late List<List<int>> _grid;
  late int _playerRow;
  late int _playerCol;

  Timer? _timer;
  int _secondsRemaining = 20; // 20 segundos
  bool _isGameOver = false;

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

  @override
  void initState() {
    super.initState();
    _startNewGame(resetTimer: true);
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;

      // Check for freeze state
      final gameProvider = Provider.of<GameProvider>(context, listen: false);
      if (gameProvider.isFrozen) return; // Pause timer

      if (gameProvider.isFrozen) return; // Pause timer

      // [FIX] Pause timer if connectivity is bad
      final connectivityByProvider =
          Provider.of<ConnectivityProvider>(context, listen: false);
      if (!connectivityByProvider.isOnline) {
        return; // Skip tick
      }

      if (_secondsRemaining > 0) {
        setState(() => _secondsRemaining--);
      } else {
        _timer?.cancel();
        _loseLife("¡Tiempo agotado!");
      }
    });
  }

  void _startNewGame({bool resetTimer = true}) {
    // Generar laberinto con un solo bloque central como obstáculo
    _grid = List.generate(rows, (_) => List.filled(cols, 0));

    // Un solo bloque central como pared
    _grid[2][2] = -1;

    // Inicio
    _playerRow = 0;
    _playerCol = 0;
    _grid[_playerRow][_playerCol] = 2; // Visitado inicial

    if (resetTimer) {
      _secondsRemaining = 20;
    }
    _isGameOver = false;
    _startTimer();
    setState(() {});
  }

  void _move(int dRow, int dCol) {
    if (_isGameOver) return;

    // [FIX] Prevent interaction if offline
    final connectivity =
        Provider.of<ConnectivityProvider>(context, listen: false);
    if (!connectivity.isOnline) return;

    final newRow = _playerRow + dRow;
    final newCol = _playerCol + dCol;

    // Validar límites
    if (newRow < 0 || newRow >= rows || newCol < 0 || newCol >= cols) return;

    // Validar pared o ya visitado
    if (_grid[newRow][newCol] == -1 ||
        _grid[newRow][newCol] == 2 ||
        _grid[newRow][newCol] == 1) {
      // Opcional: Feedback visual de "no puedes pasar"
      return;
    }

    setState(() {
      // Marcar anterior como visitado camino (1)
      if (_grid[_playerRow][_playerCol] == 2) {
        _grid[_playerRow][_playerCol] = 1;
      } else {
        _grid[_playerRow][_playerCol] = 1;
      }

      // Mover jugador
      _playerRow = newRow;
      _playerCol = newCol;
      _grid[_playerRow][_playerCol] = 2; // Cabeza del jugador

      _checkWin();
    });
  }

  void _undoMove() async {
    if (_isGameOver) return;

    // Preguntar confirmación o avisar que cuesta una vida
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.cardBg,
        title: const Text("¿Reiniciar Nivel?",
            style: TextStyle(color: Colors.white)),
        content: const Text(
            "Reiniciar el nivel te costará 1 VIDA. ¿Deseas continuar?",
            style: TextStyle(color: Colors.white70)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child:
                const Text("CANCELAR", style: TextStyle(color: Colors.white54)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style:
                ElevatedButton.styleFrom(backgroundColor: AppTheme.dangerRed),
            child: const Text("REINICIAR (-1 ❤️)",
                style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      _timer?.cancel();
      _isGameOver = true;

      final playerProvider =
          Provider.of<PlayerProvider>(context, listen: false);
      if (playerProvider.currentPlayer != null) {
        final newLives = await MinigameLogicHelper.executeLoseLife(context);

        if (!mounted) return;

        if (newLives <= 0) {
          _showOverlayState(
              title: "GAME OVER",
              message: "Te has quedado sin vidas al reiniciar.",
              retry: false,
              showShop: true);
        } else {
          // Reiniciar nivel con el tiempo completo
          _startNewGame(resetTimer: true);
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text("Nivel reiniciado. -1 Vida"),
            backgroundColor: Colors.orange,
          ));
        }
      }
    }
  }

  void _checkWin() {
    // Ganar si no quedan 0s (vacíos)
    bool hasEmpty = false;
    for (var row in _grid) {
      if (row.contains(0)) {
        hasEmpty = true;
        break;
      }
    }

    if (!hasEmpty) {
      _timer?.cancel();
      _isGameOver = true;
      widget.onSuccess();
    }
  }

  void _loseLife(String reason) async {
    _timer?.cancel();
    _isGameOver = true;
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

  @override
  Widget build(BuildContext context) {
    final minutes = (_secondsRemaining / 60).floor().toString().padLeft(2, '0');
    final seconds = (_secondsRemaining % 60).toString().padLeft(2, '0');
    final isLowTime = _secondsRemaining <= 10;

    return PopScope(
      canPop: false,
      onPopInvoked: (didPop) {},
      child: Stack(
        children: [
          // GAME CONTENT
          Column(
            children: [
              // Timer
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: isLowTime
                          ? AppTheme.dangerRed.withOpacity(0.2)
                          : Colors.black45,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                          color: isLowTime
                              ? AppTheme.dangerRed
                              : AppTheme.accentGold),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.timer,
                            color: isLowTime
                                ? AppTheme.dangerRed
                                : AppTheme.accentGold),
                        const SizedBox(width: 5),
                        Text("$minutes:$seconds",
                            style: const TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                                fontFamily: 'monospace')),
                      ],
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 10),
              const Text("Desliza el dedo para rellenar todo el camino",
                  style: TextStyle(color: Colors.white70),
                  textAlign: TextAlign.center),
              const SizedBox(height: 10),

              // GRID TACTIL
              Expanded(
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    // Calcular tamaño máximo del cuadrado disponible
                    final size = constraints.maxWidth < constraints.maxHeight
                        ? constraints.maxWidth
                        : constraints.maxHeight;

                    final cellSize =
                        (size - 32) / cols; // 32 es el margen total (16+16)

                    return Center(
                      child: Listener(
                        onPointerMove: (details) {
                          // Calcular celda objetivo basada en la posición local del toque
                          // Ajustamos por el margen de 16
                          final dx = details.localPosition.dx;
                          final dy = details.localPosition.dy;

                          if (dx < 0 ||
                              dy < 0 ||
                              dx > size - 32 ||
                              dy > size - 32) return;

                          final int targetCol = (dx / cellSize).floor();
                          final int targetRow = (dy / cellSize).floor();

                          // Verificar si es adyacente al jugador
                          if ((targetRow == _playerRow &&
                                  (targetCol - _playerCol).abs() == 1) ||
                              (targetCol == _playerCol &&
                                  (targetRow - _playerRow).abs() == 1)) {
                            _move(
                                targetRow - _playerRow, targetCol - _playerCol);
                          }
                        },
                        child: Container(
                          width: size - 32,
                          height: size - 32,
                          decoration: BoxDecoration(
                            border: Border.all(
                                color: AppTheme.accentGold, width: 2),
                            borderRadius: BorderRadius.circular(8),
                            color: Colors.black54,
                          ),
                          child: GridView.builder(
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: rows * cols,
                            gridDelegate:
                                const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: cols,
                              crossAxisSpacing: 2,
                              mainAxisSpacing: 2,
                            ),
                            itemBuilder: (context, index) {
                              final r = index ~/ cols;
                              final c = index % cols;
                              final cellValue = _grid[r][c];

                              Color color = Colors.transparent;
                              if (cellValue == -1)
                                color = Colors.grey[800]!; // Wall
                              else if (cellValue == 1)
                                color = AppTheme.primaryPurple
                                    .withOpacity(0.5); // Path
                              else if (cellValue == 2)
                                color = AppTheme.primaryPurple; // Player (Head)

                              return Container(
                                decoration: BoxDecoration(
                                  color: color,
                                  borderRadius: BorderRadius.circular(4),
                                  border: cellValue == 0
                                      ? Border.all(color: Colors.white10)
                                      : null,
                                ),
                                child: cellValue == 2
                                    ? const Icon(Icons.face,
                                        color: Colors.white, size: 24)
                                    : null,
                              );
                            },
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),

              const SizedBox(height: 20),

              TextButton(
                  onPressed: _showOverlay
                      ? null
                      : _undoMove, // Disable if overlay is up
                  child: const Text("Reiniciar Nivel",
                      style: TextStyle(color: Colors.orange, fontSize: 16))),

              const SizedBox(height: 20),
            ],
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
                      _startNewGame();
                    }
                  : null,
              onGoToShop: _showShopButton
                  ? () async {
                      await Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const MallScreen()),
                      );
                      // Check lives upon return
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
}
