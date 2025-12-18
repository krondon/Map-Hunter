import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/clue.dart';
import '../../../auth/providers/player_provider.dart';
import '../../providers/game_provider.dart';
import '../../../../core/theme/app_theme.dart';

class TicTacToeMinigame extends StatefulWidget {
  final Clue clue;
  final VoidCallback onSuccess;

  const TicTacToeMinigame({
    super.key,
    required this.clue,
    required this.onSuccess,
  });

  @override
  State<TicTacToeMinigame> createState() => _TicTacToeMinigameState();
}

class _TicTacToeMinigameState extends State<TicTacToeMinigame> {
  // Configuración
  static const int gridSize = 3;
  late List<String> board; // '' empty, 'X' player, 'O' computer
  
  // Estado del juego
  late Timer _timer;
  int _secondsRemaining = 45; // 45 segundos para ganar
  bool _isGameOver = false;
  bool _isPlayerTurn = true; // El jugador siempre empieza (X)

  @override
  void initState() {
    super.initState();
    _initializeGame();
    _startTimer();
  }

  void _initializeGame() {
    board = List.generate(gridSize * gridSize, (_) => '');
    _isPlayerTurn = true;
    _isGameOver = false;
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
    _stopTimer();
    _loseLife("Te has rendido.");
  }

  void _loseLife(String reason) {
    _stopTimer(); // Asegurar detención
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
    final gameProvider = Provider.of<GameProvider>(context, listen: false);
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
            Text("Has perdido 1 vida ❤️\nTe quedan ${gameProvider.lives}", 
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
          ],
        ),
        actions: [
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              setState(() {
                _isGameOver = false;
                _secondsRemaining = 45;
                _initializeGame();
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
            },
            child: const Text("Salir"),
          )
        ],
      ),
    );
  }

  void _onTileTap(int index) {
    final player = Provider.of<PlayerProvider>(context, listen: false).currentPlayer;
    if (_isGameOver || board[index].isNotEmpty || !_isPlayerTurn || (player != null && player.isFrozen)) return;

    setState(() {
      board[index] = 'X';
      _isPlayerTurn = false;
    });

    if (_checkWin('X')) {
      _stopTimer();
      widget.onSuccess();
      return;
    }

    if (!board.contains('')) {
      // Empate
      _handleDraw();
      return;
    }

    // Turno de la IA con un pequeño delay
    Future.delayed(const Duration(milliseconds: 500), _computerMove);
  }

  void _computerMove() {
     if (_isGameOver) return;

     // IA Simple: Bloquear o ganar si puede, o random.
     // 1. Check if AI can win
     int? winMove = _findWinningMove('O');
     // 2. Check if AI needs to block
     int? blockMove = _findWinningMove('X');
     
     int moveIndex;
     if (winMove != null) {
       moveIndex = winMove;
     } else if (blockMove != null) {
       moveIndex = blockMove;
     } else {
       // Random valid move
        List<int> available = [];
        for (int i = 0; i < board.length; i++) {
          if (board[i].isEmpty) available.add(i);
        }
        if (available.isEmpty) return;
        moveIndex = available[Random().nextInt(available.length)];
     }

     setState(() {
       board[moveIndex] = 'O';
       _isPlayerTurn = true;
     });

     if (_checkWin('O')) {
       _stopTimer();
       _loseLife("¡La IA te ha ganado!");
     } else if (!board.contains('')) {
       _stopTimer();
       _handleDraw();
     }
  }

  void _handleDraw() {
    _stopTimer();
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.cardBg,
        title: const Text("¡EMPATE!", style: TextStyle(color: AppTheme.accentGold)),
        content: const Text(
          "Nadie gana esta ronda.\n¡Inténtalo de nuevo!",
          style: TextStyle(color: Colors.white),
          textAlign: TextAlign.center,
        ),
        actions: [
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context); // Close dialog
              setState(() {
                _isGameOver = false;
                _secondsRemaining = 45;
                _initializeGame();
                _startTimer();
              });
            },
            child: const Text("Jugar de Nuevo"),
          ),
        ],
      ),
    );
  }

  int? _findWinningMove(String player) {
    for (int i = 0; i < board.length; i++) {
      if (board[i].isEmpty) {
        // Try move
        board[i] = player;
        if (_checkWin(player)) {
          board[i] = ''; // Backtrack
          return i;
        }
        board[i] = ''; // Backtrack
      }
    }
    return null;
  }

  bool _checkWin(String player) {
    // Rows
    for (int i = 0; i < 9; i += 3) {
      if (board[i] == player && board[i+1] == player && board[i+2] == player) return true;
    }
    // Cols
    for (int i = 0; i < 3; i++) {
        if (board[i] == player && board[i+3] == player && board[i+6] == player) return true;
    }
    // Diagonals
    if (board[0] == player && board[4] == player && board[8] == player) return true;
    if (board[2] == player && board[4] == player && board[6] == player) return true;

    return false;
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
              Consumer<GameProvider>(
                builder: (context, game, _) {
                  return Row(
                    children: [
                      const Icon(Icons.favorite, color: AppTheme.dangerRed),
                      const SizedBox(width: 5),
                      Text("x${game.lives}", style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                    ],
                  );
                }
              ),
              // Timer
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: _secondsRemaining < 10 ? AppTheme.dangerRed.withOpacity(0.2) : Colors.white10,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: _secondsRemaining < 10 ? AppTheme.dangerRed : Colors.white24)
                ),
                child: Row(
                  children: [
                    Icon(Icons.timer, size: 16, color: _secondsRemaining < 10 ? AppTheme.dangerRed : Colors.white),
                    const SizedBox(width: 5),
                    Text(
                      "${_secondsRemaining ~/ 60}:${(_secondsRemaining % 60).toString().padLeft(2, '0')}",
                      style: TextStyle(
                        color: _secondsRemaining < 10 ? AppTheme.dangerRed : Colors.white, 
                        fontWeight: FontWeight.bold
                      )
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),

        const Text(
          "GANA A LA VIEJA (Tic Tac Toe)",
          style: TextStyle(color: AppTheme.accentGold, fontSize: 16, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 10),

        Expanded(
          child: Center(
            child: AspectRatio(
              aspectRatio: 1,
              child: Container(
                margin: const EdgeInsets.all(20),
                padding: const EdgeInsets.all(15),
                decoration: BoxDecoration(
                  color: AppTheme.cardBg,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(color: Colors.black.withOpacity(0.5), blurRadius: 15)
                  ]
                ),
                child: GridView.builder(
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3,
                    crossAxisSpacing: 8,
                    mainAxisSpacing: 8,
                  ),
                  itemCount: 9,
                  itemBuilder: (context, index) {
                    final cell = board[index];
                    Color cellColor = Colors.white10;
                    if (cell == 'X') cellColor = AppTheme.primaryPurple;
                    if (cell == 'O') cellColor = AppTheme.warningOrange;

                    return GestureDetector(
                      onTap: () => _onTileTap(index),
                      child: Container(
                        decoration: BoxDecoration(
                          color: cellColor,
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                             BoxShadow(color: Colors.black.withOpacity(0.2), offset: const Offset(2,2))
                          ]
                        ),
                        child: Center(
                          child: Text(
                            cell,
                            style: const TextStyle(
                              fontSize: 48,
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
