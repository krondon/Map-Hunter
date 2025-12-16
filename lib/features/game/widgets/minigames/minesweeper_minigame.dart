import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/clue.dart';
import '../../../auth/providers/player_provider.dart';
import '../../../../core/theme/app_theme.dart';

class MinesweeperMinigame extends StatefulWidget {
  final Clue clue;
  final VoidCallback onSuccess;

  const MinesweeperMinigame({
    super.key,
    required this.clue,
    required this.onSuccess,
  });

  @override
  State<MinesweeperMinigame> createState() => _MinesweeperMinigameState();
}

class _MinesweeperMinigameState extends State<MinesweeperMinigame> {
  // Configuración Difficulty: Easy (4x4)
  static const int rows = 4;
  static const int cols = 4;
  static const int totalMines = 3;

  late List<List<Cell>> _grid;
  bool _isFirstMove = true;
  bool _isGameOver = false;
  
  // Timer State
  Timer? _timer;
  int _secondsRemaining = 120; // 2 minutos
  
  // Stats
  int _flagsAvailable = totalMines;

  @override
  void initState() {
    super.initState();
    _startNewGame();
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
        _loseLife("¡Tiempo agotado!", timeOut: true);
      }
    });
  }

  void _startNewGame() {
    _timer?.cancel();
    _secondsRemaining = 120; // reset
    _isGameOver = false;
    _isFirstMove = true;
    _flagsAvailable = totalMines;
    
    // Generar grid vacío
    _grid = List.generate(rows, (r) => List.generate(cols, (c) => Cell(row: r, col: c)));

    _startTimer();
    setState(() {});
  }

  void _plantMines(int safeRow, int safeCol) {
    int minesPlanted = 0;
    final random = Random();

    while (minesPlanted < totalMines) {
      int r = random.nextInt(rows);
      int c = random.nextInt(cols);

      // Evitar colocar mina en la primera celda pulsada o sus vecinas (para asegurar apertura)
      if ((r - safeRow).abs() <= 1 && (c - safeCol).abs() <= 1) continue;
      
      if (!_grid[r][c].isMine) {
        _grid[r][c].isMine = true;
        minesPlanted++;
      }
    }
    
    // Calcular números adyacentes
    for (int r = 0; r < rows; r++) {
      for (int c = 0; c < cols; c++) {
        if (!_grid[r][c].isMine) {
           _grid[r][c].adjacentMines = _countAdjacentMines(r, c);
        }
      }
    }
  }
  
  int _countAdjacentMines(int r, int c) {
    int count = 0;
    for (int i = -1; i <= 1; i++) {
        for (int j = -1; j <= 1; j++) {
            int nr = r + i;
            int nc = c + j;
            if (nr >= 0 && nr < rows && nc >= 0 && nc < cols && _grid[nr][nc].isMine) {
                count++;
            }
        }
    }
    return count;
  }

  void _handleCellTap(int r, int c) {
    if (_isGameOver) return;
    if (_grid[r][c].isFlagged) return; // No abrir si tiene bandera

    if (_isFirstMove) {
      _plantMines(r, c);
      _isFirstMove = false;
    }

    if (_grid[r][c].isMine) {
      _triggerMine(r, c);
    } else {
      _revealCell(r, c);
      _checkWin();
    }
  }

  void _handleCellLongPress(int r, int c) {
     if (_isGameOver || _grid[r][c].isRevealed) return;
     
     setState(() {
         if (_grid[r][c].isFlagged) {
             _grid[r][c].isFlagged = false;
             _flagsAvailable++;
         } else {
             if (_flagsAvailable > 0) {
                 _grid[r][c].isFlagged = true;
                 _flagsAvailable--;
             } else {
                 ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("No quedan banderas 🚩"), duration: Duration(milliseconds: 500)));
             }
         }
     });
  }

  void _revealCell(int r, int c) {
    if (r < 0 || r >= rows || c < 0 || c >= cols || _grid[r][c].isRevealed || _grid[r][c].isFlagged) return;

    setState(() {
       _grid[r][c].isRevealed = true;
    });

    if (_grid[r][c].adjacentMines == 0) {
       // Flood fill recursivo
        for (int i = -1; i <= 1; i++) {
            for (int j = -1; j <= 1; j++) {
               if (i != 0 || j != 0) _revealCell(r + i, c + j);
            }
        }
    }
  }

  void _triggerMine(int r, int c) {
      setState(() {
          _grid[r][c].isExploded = true;
          // Revelar todas las minas
          for(var row in _grid) {
              for(var cell in row) {
                  if (cell.isMine) cell.isRevealed = true;
              }
          }
      });
      _loseLife("¡BOOM! Has pisado una mina 💣");
  }

  void _checkWin() {
      bool won = true;
      for (var row in _grid) {
          for (var cell in row) {
              if (!cell.isMine && !cell.isRevealed) {
                  won = false;
                  break;
              }
          }
      }
      
      if (won) {
          _timer?.cancel();
          _isGameOver = true;
          widget.onSuccess();
      }
  }

  void _loseLife(String reason, {bool timeOut = false}) {
    final playerProvider = Provider.of<PlayerProvider>(context, listen: false);
    if (playerProvider.currentPlayer != null) {
      playerProvider.currentPlayer!.lives--;
      playerProvider.notifyListeners();

      if (playerProvider.currentPlayer!.lives <= 0) {
        _timer?.cancel();
        _showGameOverDialog("Te has quedado sin vidas.");
      } else {
        // Delay para ver la explosión antes de reiniciar
        Future.delayed(const Duration(seconds: 2), () {
            _showRestartDialog(reason);
        });
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
        content: const Text("Inténtalo de nuevo. Se generará un nuevo campo.", style: TextStyle(color: Colors.white)),
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

  @override
  Widget build(BuildContext context) {
    final minutes = (_secondsRemaining / 60).floor().toString().padLeft(2, '0');
    final seconds = (_secondsRemaining % 60).toString().padLeft(2, '0');
    final isLowTime = _secondsRemaining <= 10;

    return Column(
      children: [
        // Header
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
                // Flag Counter
                 Container(
                 padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                 decoration: BoxDecoration(
                   color: Colors.black54,
                   borderRadius: BorderRadius.circular(8),
                   border: Border.all(color: AppTheme.primaryPurple),
                 ),
                 child: Row(
                    children: [
                      const Icon(Icons.flag, color: AppTheme.dangerRed, size: 20),
                      const SizedBox(width: 8),
                      Text("$_flagsAvailable", style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18)),
                    ],
                 ),
               ),
                
               // Timer
               Container(
                 padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                 decoration: BoxDecoration(
                   color: isLowTime ? AppTheme.dangerRed : Colors.black54,
                   borderRadius: BorderRadius.circular(8),
                 ),
                 child: Row(
                    children: [
                      const Icon(Icons.timer, color: Colors.white, size: 20),
                      const SizedBox(width: 8),
                      Text("$minutes:$seconds", style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18)),
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
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(3, (index) {
                  return Icon(
                      index < (playerProvider.currentPlayer?.lives ?? 0) ? Icons.favorite : Icons.favorite_border,
                      color: AppTheme.dangerRed,
                      size: 24,
                  );
                  }),
              ),
            );
            },
        ),

        const Text("Toca para abrir. Mantén para marcar bandera 🚩", style: TextStyle(color: Colors.white54, fontSize: 12)),
        const SizedBox(height: 10),

        // GRID
        Expanded(
          child: Center(
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                  color: Colors.grey[900],
                  borderRadius: BorderRadius.circular(8), 
                  border: Border.all(color: Colors.grey[700]!, width: 4),
              ),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 280, maxHeight: 280),
                child: AspectRatio(
                  aspectRatio: 1, // Square grid
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
                      return _buildCell(r, c);
                    },
                  ),
                ),
              ),
            ),
          ),
        ),
        
        Padding(
          padding: const EdgeInsets.only(bottom: 20, top: 10),
          // Botón eliminado a petición del usuario
        ),
      ],
    );
  }
  
  Widget _buildCell(int r, int c) {
      final cell = _grid[r][c];
      
      Color bgColor;
      Widget? child;
      
      if (!cell.isRevealed) {
          bgColor = Colors.blueGrey[700]!;
          if (cell.isFlagged) {
             child = const Icon(Icons.flag, color: AppTheme.dangerRed, size: 24);
          }
      } else {
          // Revelado
          if (cell.isMine) {
             bgColor = cell.isExploded ? Colors.red : Colors.grey[400]!;
             child = const Icon(Icons.dangerous, color: Colors.black, size: 28);
          } else {
             bgColor = Colors.grey[300]!;
             if (cell.adjacentMines > 0) {
                 child = Text(
                     '${cell.adjacentMines}',
                     style: TextStyle(
                         fontWeight: FontWeight.bold,
                         fontSize: 14,
                         color: _getNumberColor(cell.adjacentMines),
                     ),
                 );
             }
          }
      }
      
      return GestureDetector(
          onTap: () => _handleCellTap(r, c),
          onLongPress: () => _handleCellLongPress(r, c),
          child: Container(
              decoration: BoxDecoration(
                  color: bgColor,
                  borderRadius: BorderRadius.circular(2),
                  border: !cell.isRevealed ? Border.all(color: Colors.white10) : null,
                  boxShadow: !cell.isRevealed ? [
                      BoxShadow(color: Colors.black.withOpacity(0.3), offset: const Offset(1,1), blurRadius: 1)
                  ] : null
              ),
              child: Center(child: child),
          ),
      );
  }
  
  Color _getNumberColor(int n) {
      switch(n) {
          case 1: return Colors.blue[800]!;
          case 2: return Colors.green[800]!;
          case 3: return Colors.red[800]!;
          case 4: return Colors.purple[800]!;
          case 5: return Colors.orange[800]!;
          default: return Colors.black;
      }
  }
}

class Cell {
    final int row;
    final int col;
    bool isMine = false;
    bool isRevealed = false;
    bool isFlagged = false;
    bool isExploded = false;
    int adjacentMines = 0;
    
    Cell({required this.row, required this.col});
}
