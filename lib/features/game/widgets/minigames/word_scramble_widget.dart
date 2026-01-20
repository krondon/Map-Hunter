import 'package:provider/provider.dart';
import '../../utils/minigame_logic_helper.dart';
import '../../../auth/providers/player_provider.dart';
import '../../providers/game_provider.dart';

    // ... (imports)

  // Inside State logic
  int _attempts = 3;

  void _checkAnswer() {
    final gameProvider = Provider.of<GameProvider>(context, listen: false);
    if (gameProvider.isFrozen) return;

    if (_currentWord == widget.clue.riddleAnswer?.toUpperCase()) {
      // ÉXITO
      widget.onSuccess();
    } else {
      setState(() {
        _attempts--;
      });

      if (_attempts <= 0) {
        _loseLife("Demasiados intentos.");
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Incorrecto. Intentos restantes: $_attempts'),
            backgroundColor: AppTheme.dangerRed,
          ),
        );
        _onReset();
      }
    }
  }

  void _loseLife(String reason) async {
    final gameProvider = Provider.of<GameProvider>(context, listen: false);
    final playerProvider = Provider.of<PlayerProvider>(context, listen: false);
    
    if (playerProvider.currentPlayer != null) {
      // USAR HELPER CENTRALIZADO
      final newLives = await MinigameLogicHelper.executeLoseLife(context);

      
      if (!mounted) return;
      
      final playerLives = playerProvider.currentPlayer?.lives ?? 0;
      final gameLives = gameProvider.lives;

      if (gameLives <= 0 || playerLives <= 0) {
         _showGameOverDialog();
      } else {
         setState(() {
           _attempts = 3;
           _onReset();
         });
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
            onPressed: () => Navigator.pop(context),
            child: const Text("Reintentar"),
          ),
          TextButton(
            onPressed: () {
               Navigator.pop(context);
               Navigator.pop(context);
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
        title: const Text("GAME OVER", style: TextStyle(color: AppTheme.dangerRed)),
        content: const Text("Te has quedado sin vidas.", style: TextStyle(color: Colors.white)),
        actions: [
          ElevatedButton(
            onPressed: () {
               Navigator.pop(context);
               Navigator.pop(context);
            },
            child: const Text("Salir"),
          )
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final answerLength = widget.clue.riddleAnswer?.length ?? 8;
    
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        children: [
          const Icon(Icons.shuffle, size: 40, color: AppTheme.secondaryPink),
          const SizedBox(height: 8),
          const Text(
            'PALABRA MISTERIOSA',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 15),
          
          // Display de la palabra actual
          Container(
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 15),
            decoration: BoxDecoration(
              color: const Color.fromRGBO(0, 0, 0, 0.3),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppTheme.accentGold, width: 2),
            ),
            child: Text(
              _currentWord
                  .padRight(answerLength, '_')
                  .split('')
                  .join(' '),
              style: const TextStyle(
                color: AppTheme.accentGold,
                fontSize: 20,
                letterSpacing: 4,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(height: 20),
          
          // Letras disponibles
          Wrap(
            spacing: 8,
            runSpacing: 8,
            alignment: WrapAlignment.center,
            children: _shuffledLetters
                .map((letter) => GestureDetector(
                      onTap: () => _onLetterTap(letter),
                      child: Container(
                        width: 45,
                        height: 45,
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [
                              AppTheme.primaryPurple,
                              AppTheme.secondaryPink,
                            ],
                          ),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Center(
                          child: Text(
                            letter,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    ))
                .toList(),
          ),
          const SizedBox(height: 20),
          
          // Botones de acción
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: _onReset,
                  child: const Text("Reiniciar"),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                flex: 2,
                child: ElevatedButton(
                  onPressed: _currentWord.length == answerLength
                      ? _checkAnswer
                      : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.successGreen,
                  ),
                  child: const Text("COMPROBAR"),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
