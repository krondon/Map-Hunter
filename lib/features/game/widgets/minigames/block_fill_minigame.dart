import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/clue.dart';
import '../../../auth/providers/player_provider.dart';
import '../../../../core/theme/app_theme.dart';

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
  int _secondsRemaining = 120; // 2 minutos
  bool _isGameOver = false;

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
      if (_secondsRemaining > 0) {
        setState(() => _secondsRemaining--);
      } else {
        _timer?.cancel();
        _loseLife("¡Tiempo agotado!");
      }
    });
  }

  void _startNewGame({bool resetTimer = true}) {
    // Generar laberinto MÁS SIMPLE (menos paredes)
    // 0 = Vacío, 2 = Inicio
    _grid = List.generate(rows, (_) => List.filled(cols, 0));
    
    // Solo 1 pared para facilitar
    _grid[2][2] = -1;
    
    // Inicio
    _playerRow = 0;
    _playerCol = 0;
    _grid[_playerRow][_playerCol] = 2; // Visitado inicial

    if (resetTimer) {
      _secondsRemaining = 120;
    }
    _isGameOver = false;
    _startTimer();
    setState(() {});
  }

  void _move(int dRow, int dCol) {
    if (_isGameOver) return;

    final newRow = _playerRow + dRow;
    final newCol = _playerCol + dCol;

    // Validar límites
    if (newRow < 0 || newRow >= rows || newCol < 0 || newCol >= cols) return;
    
    // Validar pared o ya visitado
    if (_grid[newRow][newCol] == -1 || _grid[newRow][newCol] == 2 || _grid[newRow][newCol] == 1) {
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

  void _undoMove() {
      // Reinicia nivel pero mantiene el tiempo
      _startNewGame(resetTimer: false);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Nivel reiniciado (Tiempo corre)")));
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

  void _loseLife(String reason) {
    // Sin sistema de vidas - solo reinicia
    _timer?.cancel();
    _showGameOverDialog(reason);
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
    final minutes = (_secondsRemaining / 60).floor().toString().padLeft(2, '0');
    final seconds = (_secondsRemaining % 60).toString().padLeft(2, '0');
    final isLowTime = _secondsRemaining <= 10;

    return Column(
      children: [
        // Timer
        Row(
           mainAxisAlignment: MainAxisAlignment.center,
           children: [
             Container(
               padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
               decoration: BoxDecoration(
                 color: isLowTime ? AppTheme.dangerRed.withOpacity(0.2) : Colors.black45,
                 borderRadius: BorderRadius.circular(20),
                 border: Border.all(color: isLowTime ? AppTheme.dangerRed : AppTheme.accentGold),
               ),
               child: Row(
                  children: [
                    Icon(Icons.timer, color: isLowTime ? AppTheme.dangerRed : AppTheme.accentGold),
                    const SizedBox(width: 5),
                    Text("$minutes:$seconds", style: const TextStyle(color: Colors.white, fontSize: 18, fontFamily: 'monospace')),
                  ],
               ),
             ),
           ],
        ),
        
        const SizedBox(height: 10),
        const Text("Desliza el dedo para rellenar todo el camino", style: TextStyle(color: Colors.white70), textAlign: TextAlign.center),
        const SizedBox(height: 10),

        // GRID TACTIL
        Expanded(
          child: LayoutBuilder(
            builder: (context, constraints) {
              // Calcular tamaño máximo del cuadrado disponible
              final size = constraints.maxWidth < constraints.maxHeight 
                  ? constraints.maxWidth 
                  : constraints.maxHeight;
                  
              final cellSize = (size - 32) / cols; // 32 es el margen total (16+16)

              return Center(
                child: Listener(
                  onPointerMove: (details) {
                     // Calcular celda objetivo basada en la posición local del toque
                     // Ajustamos por el margen de 16
                     final dx = details.localPosition.dx;
                     final dy = details.localPosition.dy;
                     
                     if (dx < 0 || dy < 0 || dx > size - 32 || dy > size - 32) return;

                     final int targetCol = (dx / cellSize).floor();
                     final int targetRow = (dy / cellSize).floor();
                     
                     // Verificar si es adyacente al jugador
                     if ((targetRow == _playerRow && (targetCol - _playerCol).abs() == 1) ||
                         (targetCol == _playerCol && (targetRow - _playerRow).abs() == 1)) {
                         _move(targetRow - _playerRow, targetCol - _playerCol);
                     }
                  },
                  child: Container(
                    width: size - 32,
                    height: size - 32,
                    decoration: BoxDecoration(
                      border: Border.all(color: AppTheme.accentGold, width: 2),
                      borderRadius: BorderRadius.circular(8),
                      color: Colors.black54,
                    ),
                    child: GridView.builder(
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: rows * cols,
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: cols,
                        crossAxisSpacing: 2,
                        mainAxisSpacing: 2,
                      ),
                      itemBuilder: (context, index) {
                        final r = index ~/ cols;
                        final c = index % cols;
                        final cellValue = _grid[r][c];
                        
                        Color color = Colors.transparent;
                        if (cellValue == -1) color = Colors.grey[800]!; // Wall
                        else if (cellValue == 1) color = AppTheme.primaryPurple.withOpacity(0.5); // Path
                        else if (cellValue == 2) color = AppTheme.primaryPurple; // Player (Head)
                        
                        return Container(
                           decoration: BoxDecoration(
                             color: color,
                             borderRadius: BorderRadius.circular(4),
                             border: cellValue == 0 ? Border.all(color: Colors.white10) : null,
                           ),
                           child: cellValue == 2 
                              ? const Icon(Icons.face, color: Colors.white, size: 24) 
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
          onPressed: _undoMove, 
          child: const Text("Reiniciar Nivel", style: TextStyle(color: Colors.orange, fontSize: 16))
        ),
        
        const SizedBox(height: 20),
      ],
    );
  }
}
