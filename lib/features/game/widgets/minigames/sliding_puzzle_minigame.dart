import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../utils/minigame_logic_helper.dart';
import '../../models/clue.dart';
import '../../../auth/providers/player_provider.dart';
import '../../providers/game_provider.dart';
import '../../providers/connectivity_provider.dart';
import '../../../../core/theme/app_theme.dart';

import 'game_over_overlay.dart';
import 'cyber_surrender_button.dart';
import '../../../mall/screens/mall_screen.dart';

class SlidingPuzzleMinigame extends StatefulWidget {
  final Clue clue;
  final VoidCallback onSuccess;

  const SlidingPuzzleMinigame({
    super.key,
    required this.clue,
    required this.onSuccess,
  });

  @override
  State<SlidingPuzzleMinigame> createState() => _SlidingPuzzleMinigameState();
}

class _SlidingPuzzleMinigameState extends State<SlidingPuzzleMinigame> {
  // Configuración
  final int gridSize = 3;
  late List<int> tiles;

  // Estado del juego
  late Timer _timer;
  int _secondsRemaining = 120; // 2 minutos
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
    _initializePuzzle();
    _startTimer();
  }

  void _initializePuzzle() {
    // Generar 8 números y 1 vacío (0)
    tiles = List.generate(gridSize * gridSize, (index) => index);
    // Mezclar hasta que sea resoluble (o simplemente random para demo)
    // Nota: Un shuffle simple puede crear puzzles irresolubles.
    // Para simplificar demo: Haremos movimientos válidos aleatorios desde el estado resuelto.
    _shuffleSolvable();
  }

  void _shuffleSolvable() {
    // Empezar resuelto
    tiles = List.generate(
        gridSize * gridSize, (index) => (index + 1) % (gridSize * gridSize));
    tiles[gridSize * gridSize - 1] = 0; // El último es el vacío

    // Hacer 50 movimientos aleatorios válidos
    int emptyIndex = tiles.indexOf(0);
    for (int i = 0; i < 50; i++) {
      final neighbors = _getNeighbors(emptyIndex);
      final randomNeighbor =
          neighbors[DateTime.now().microsecond % neighbors.length];
      _swap(emptyIndex, randomNeighbor);
      emptyIndex = randomNeighbor;
    }
  }

  List<int> _getNeighbors(int index) {
    List<int> neighbors = [];
    int row = index ~/ gridSize;
    int col = index % gridSize;

    if (row > 0) neighbors.add(index - gridSize); // Arriba
    if (row < gridSize - 1) neighbors.add(index + gridSize); // Abajo
    if (col > 0) neighbors.add(index - 1); // Izquierda
    if (col < gridSize - 1) neighbors.add(index + 1); // Derecha

    return neighbors;
  }

  void _swap(int idx1, int idx2) {
    final temp = tiles[idx1];
    tiles[idx1] = tiles[idx2];
    tiles[idx2] = temp;
  }

  void _onTileTap(int index) {
    if (_isGameOver) return;

    // [FIX] Prevent interaction if offline
    final connectivity =
        Provider.of<ConnectivityProvider>(context, listen: false);
    if (!connectivity.isOnline) return;

    final emptyIndex = tiles.indexOf(0);
    if (_getNeighbors(emptyIndex).contains(index)) {
      setState(() {
        _swap(index, emptyIndex);
      });
      _checkWin();
    }
  }

  void _checkWin() {
    bool won = true;
    for (int i = 0; i < tiles.length - 1; i++) {
      if (tiles[i] != i + 1) {
        won = false;
        break;
      }
    }
    if (won) {
      _stopTimer();
      widget.onSuccess();
    }
  }

  void _startTimer() {
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;

      // Check for freeze state
      final gameProvider = Provider.of<GameProvider>(context, listen: false);
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
        _handleTimeOut();
      }
    });
  }

  void _stopTimer() {
    _timer.cancel();
  }

  void _handleTimeOut() {
    _stopTimer();
    setState(() => _isGameOver = true);
    _loseLife("¡Se acabó el tiempo!");
  }

  void _handleGiveUp() {
    _loseLife("Te has rendido.");
  }

  void _loseLife(String reason) async {
    _stopTimer(); // Asegurar que el timer se detiene
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
    _timer.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvoked: (didPop) {},
      child: Stack(
        children: [
          // GAME CONTENT
          Column(
            children: [
              // Status Bar
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Vidas
                    Consumer<GameProvider>(builder: (context, game, _) {
                      return Row(
                        children: [
                          const Icon(Icons.favorite, color: AppTheme.dangerRed),
                          const SizedBox(width: 5),
                          Text("x${game.lives}",
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold)),
                        ],
                      );
                    }),
                    // Timer
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                          color: _secondsRemaining < 30
                              ? AppTheme.dangerRed.withOpacity(0.2)
                              : Colors.white10,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                              color: _secondsRemaining < 30
                                  ? AppTheme.dangerRed
                                  : Colors.white24)),
                      child: Row(
                        children: [
                          Icon(Icons.timer,
                              size: 16,
                              color: _secondsRemaining < 30
                                  ? AppTheme.dangerRed
                                  : Colors.white),
                          const SizedBox(width: 5),
                          Text(
                              "${_secondsRemaining ~/ 60}:${(_secondsRemaining % 60).toString().padLeft(2, '0')}",
                              style: TextStyle(
                                  color: _secondsRemaining < 30
                                      ? AppTheme.dangerRed
                                      : Colors.white,
                                  fontWeight: FontWeight.bold)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              Expanded(
                child: Center(
                  child: AspectRatio(
                    aspectRatio: 1,
                    child: Container(
                      margin: const EdgeInsets.all(20),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(16),
                        child: BackdropFilter(
                          filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
                          child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.08),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: Colors.white.withOpacity(0.15),
                            width: 1.5,
                          ),
                          boxShadow: [
                            BoxShadow(
                                color: Colors.black.withOpacity(0.2),
                                blurRadius: 10)
                          ]),
                      child: GridView.builder(
                        physics: const NeverScrollableScrollPhysics(),
                        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: gridSize,
                          crossAxisSpacing: 4,
                          mainAxisSpacing: 4,
                        ),
                        itemCount: tiles.length,
                        itemBuilder: (context, index) {
                          final number = tiles[index];
                          if (number == 0)
                            return const SizedBox.shrink(); // Espacio vacío

                          return GestureDetector(
                            onTap: () => _onTileTap(index),
                            child: Container(
                              decoration: BoxDecoration(
                                  color: AppTheme.primaryPurple,
                                  borderRadius: BorderRadius.circular(8),
                                  gradient: const LinearGradient(
                                    colors: [
                                      AppTheme.primaryPurple,
                                      AppTheme.secondaryPink
                                    ],
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                        color: Colors.black.withOpacity(0.2),
                                        offset: const Offset(2, 2))
                                  ]),
                              child: Center(
                                child: Text(
                                  "$number",
                                  style: const TextStyle(
                                    fontSize: 32,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                ),
                ),
                ),
                ),
              ),

              // Controles Inferiores
              CyberSurrenderButton(
                onPressed: _showOverlay ? null : _handleGiveUp,
              )
            ],
          ),

          // OVERLAY
          if (_showOverlay)
            GameOverOverlay(
              title: _overlayTitle,
              message: _overlayMessage,
              isVictory: false, // Sliding puzzle failure is always loss here
              onRetry: _canRetry
                  ? () {
                      setState(() {
                        _showOverlay = false;
                        _isGameOver = false;
                        _secondsRemaining = 120;
                        _initializePuzzle();
                        _startTimer();
                      });
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

                      // Force Sync
                      await Provider.of<PlayerProvider>(context, listen: false)
                          .refreshProfile();

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
