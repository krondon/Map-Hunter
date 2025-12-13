import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/clue.dart';
import '../../../auth/providers/player_provider.dart';
import '../../../../core/theme/app_theme.dart';

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
    tiles = List.generate(gridSize * gridSize, (index) => (index + 1) % (gridSize * gridSize));
    tiles[gridSize * gridSize - 1] = 0; // El último es el vacío

    // Hacer 50 movimientos aleatorios válidos
    int emptyIndex = tiles.indexOf(0);
    for (int i = 0; i < 50; i++) {
        final neighbors = _getNeighbors(emptyIndex);
        final randomNeighbor = neighbors[DateTime.now().microsecond % neighbors.length];
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

  void _loseLife(String reason) {
    final playerProvider = Provider.of<PlayerProvider>(context, listen: false);
    if (playerProvider.currentPlayer != null) {
      // Logic for reducing lives would go here if Player had logic for it.
      // Since we just added the field, we can do:
      playerProvider.currentPlayer!.lives--;
      playerProvider.notifyListeners(); // Force update

      if (playerProvider.currentPlayer!.lives <= 0) {
        // Game Over Total?
        _showGameOverDialog();
      } else {
        _showTryAgainDialog(reason);
      }
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
              Navigator.pop(context); // Close Dialog
              setState(() {
                _isGameOver = false;
                _secondsRemaining = 120;
                _initializePuzzle();
                _startTimer();
              });
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
               // Aquí se podría navegar a la tienda automáticamente
            },
            child: const Text("Salir"),
          )
        ],
      ),
    );
  }

  @override
  void dispose() {
    _timer.cancel();
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
                  const Icon(Icons.favorite, color: AppTheme.dangerRed),
                  const SizedBox(width: 5),
                  Text("x${player?.lives ?? 0}", style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                ],
              ),
              // Timer
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: _secondsRemaining < 30 ? AppTheme.dangerRed.withOpacity(0.2) : Colors.white10,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: _secondsRemaining < 30 ? AppTheme.dangerRed : Colors.white24)
                ),
                child: Row(
                  children: [
                    Icon(Icons.timer, size: 16, color: _secondsRemaining < 30 ? AppTheme.dangerRed : Colors.white),
                    const SizedBox(width: 5),
                    Text(
                      "${_secondsRemaining ~/ 60}:${(_secondsRemaining % 60).toString().padLeft(2, '0')}",
                      style: TextStyle(
                        color: _secondsRemaining < 30 ? AppTheme.dangerRed : Colors.white, 
                        fontWeight: FontWeight.bold
                      )
                    ),
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
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppTheme.cardBg,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(color: Colors.black.withOpacity(0.3), blurRadius: 10)
                  ]
                ),
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
                    if (number == 0) return const SizedBox.shrink(); // Espacio vacío

                    return GestureDetector(
                      onTap: () => _onTileTap(index),
                      child: Container(
                        decoration: BoxDecoration(
                          color: AppTheme.primaryPurple,
                          borderRadius: BorderRadius.circular(8),
                          gradient: const LinearGradient(
                            colors: [AppTheme.primaryPurple, AppTheme.secondaryPink],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          boxShadow: [
                             BoxShadow(color: Colors.black.withOpacity(0.2), offset: const Offset(2,2))
                          ]
                        ),
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
        
        // Controles Inferiores
        Padding(
          padding: const EdgeInsets.all(20),
          child: SizedBox(
            width: double.infinity,
            height: 50,
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
        )
      ],
    );
  }
}
