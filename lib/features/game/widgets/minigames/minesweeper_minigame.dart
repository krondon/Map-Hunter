import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/clue.dart';
import '../../../auth/providers/player_provider.dart';
import '../../providers/game_provider.dart';
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
  static const int rows = 6;
  static const int cols = 6;
  static const int totalMines = 7;

  late List<List<Cell>> _grid;
  bool _isFirstMove = true;
  bool _isGameOver = false;
  
  // Timer State
  Timer? _timer;
  int _secondsRemaining = 120; // 2 minutos
  
  // Stats
  int _flagsAvailable = totalMines;
  int _shields = 3; // Intentos Locales (Escudos)

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
      if (!mounted) return;
      if (_secondsRemaining > 0) {
        setState(() => _secondsRemaining--);
      } else {
        _timer?.cancel();
        _loseGlobalLife("¡Tiempo agotado!", timeOut: true);
      }
    });
  }

  void _startNewGame() {
    _timer?.cancel();
    _secondsRemaining = 120;
    _isGameOver = false;
    _isFirstMove = true;
    _flagsAvailable = totalMines;
    _shields = 3; // Reiniciar escudos
    
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

      // Reducir el radio de seguridad para que abra menos bloques al iniciar (~5 bloques en lugar de 9)
      if ((r - safeRow).abs() + (c - safeCol).abs() <= 1) continue;
      
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
          _grid[r][c].isRevealed = true; // Solo revelar esa mina
          _shields--; // Restar escudo
      });

      if (_shields <= 0) {
          // Game Over Real: Revelar todo
          setState(() {
            for(var row in _grid) {
                for(var cell in row) {
                    if (cell.isMine) cell.isRevealed = true;
                }
            }
          });
          _loseGlobalLife("¡BOOM! Te quedaste sin escudos.");
      } else {
          // Feedback de escudo roto
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text("¡Mina detonada! Escudos restantes: $_shields"),
              backgroundColor: AppTheme.dangerRed,
              duration: const Duration(seconds: 1),
            ),
          );
      }
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

  void _loseGlobalLife(String reason, {bool timeOut = false}) {
    _timer?.cancel(); // Detener timer inmediatamente
    final gameProvider = Provider.of<GameProvider>(context, listen: false);
    final playerProvider = Provider.of<PlayerProvider>(context, listen: false);
    
    if (playerProvider.currentPlayer != null) {
      // Llamamos a loseLife para restar la vida en el backend
      gameProvider.loseLife(playerProvider.currentPlayer!.id).then((_) {
         if (!mounted) return;
         
         // Si se quedó sin vidas globales -> Game Over Definitivo
         if (gameProvider.lives <= 0) {
            _showGameOverDialog("Te has quedado sin vidas globales.");
         } else {
            // Si le quedan vidas, reiniciamos el nivel tras una pausa
            Future.delayed(const Duration(seconds: 2), () {
                _showRestartDialog(reason);
            });
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
        content: const Text("Has perdido 1 vida. Inténtalo de nuevo. Se generará un nuevo campo.", style: TextStyle(color: Colors.white)),
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
               
               // ESCUDOS (Nuevo)
               Container(
                 padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                 decoration: BoxDecoration(
                   color: Colors.black54,
                   borderRadius: BorderRadius.circular(8),
                   border: Border.all(color: Colors.blueAccent),
                 ),
                 child: Row(
                    children: [
                      const Icon(Icons.shield, color: Colors.blueAccent, size: 20),
                      const SizedBox(width: 8),
                      Text("$_shields", style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18)),
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
        
        // Vidas Globales (Solo visualización)
        Consumer<GameProvider>(
            builder: (context, game, _) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(3, (index) {
                  return Icon(
                      index < game.lives ? Icons.favorite : Icons.favorite_border,
                      color: AppTheme.dangerRed,
                      size: 24,
                  );
                  }),
              ),
            );
            },
        ),

        const Text("Toca para abrir. Mantén para marcar 🚩", style: TextStyle(color: Colors.white54, fontSize: 12)),
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
                constraints: const BoxConstraints(maxWidth: 320, maxHeight: 320),
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
        
        const SizedBox(height: 20),
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
             child = const Icon(Icons.dangerous, color: Colors.black, size: 24);
          } else {
             bgColor = Colors.grey[200]!;
             if (cell.adjacentMines > 0) {
                 child = Text(
                     '${cell.adjacentMines}',
                     style: TextStyle(
                         fontWeight: FontWeight.w900,
                         fontSize: 20,
                         color: _getNumberColor(cell.adjacentMines),
                         shadows: [
                            Shadow(color: Colors.black.withOpacity(0.2), offset: const Offset(1, 1), blurRadius: 1)
                         ]
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