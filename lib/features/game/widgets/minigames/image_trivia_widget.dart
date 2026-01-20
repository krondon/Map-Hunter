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

    final userAnswer = _controller.text.trim().toLowerCase();
    final correctAnswer = widget.clue.riddleAnswer?.trim().toLowerCase() ?? "";
    
    if (userAnswer == correctAnswer ||
        (correctAnswer.isNotEmpty &&
            userAnswer.contains(correctAnswer.split(' ').first))) {
      // ÉXITO
      widget.onSuccess();
    } else {
      setState(() {
        _attempts--;
      });

      if (_attempts <= 0) {
        _loseLife("Se acabaron los intentos.");
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Incorrecto. Intentos restantes: $_attempts'),
            backgroundColor: AppTheme.dangerRed,
          ),
        );
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
           _controller.clear();
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
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          const Icon(
            Icons.image_outlined,
            size: 35,
            color: AppTheme.secondaryPink,
          ),
          const SizedBox(height: 8),
          const Text(
            'DESAFÍO VISUAL',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 15),
          
          // Imagen del desafío
          Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: AppTheme.primaryPurple.withValues(alpha: 0.5),
                  blurRadius: 15,
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.network(
                widget.clue.minigameUrl ?? 'https://via.placeholder.com/400',
                height: 180,
                width: double.infinity,
                fit: BoxFit.cover,
                errorBuilder: (ctx, err, stack) => Container(
                  height: 180,
                  color: AppTheme.cardBg,
                  child: const Center(
                    child: Icon(Icons.broken_image, color: Colors.white38),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 15),
          
          // Pregunta
          Text(
            widget.clue.riddleQuestion ?? "¿Qué es esto?",
            style: const TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
          
          // Campo de respuesta
          TextField(
            controller: _controller,
            style: const TextStyle(color: Colors.white, fontSize: 14),
            textAlign: TextAlign.center,
            decoration: InputDecoration(
              hintText: 'Tu respuesta...',
              hintStyle: const TextStyle(color: Colors.white38),
              filled: true,
              fillColor: AppTheme.cardBg,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide.none,
              ),
            ),
          ),
          const SizedBox(height: 12),
          
          // Pista (si está visible)
          if (_showHint)
            Container(
              padding: const EdgeInsets.all(10),
              margin: const EdgeInsets.only(bottom: 10),
              decoration: BoxDecoration(
                color: AppTheme.accentGold.withValues(alpha: 0.1),
                border: Border.all(color: AppTheme.accentGold),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                widget.clue.hint,
                style: const TextStyle(color: Colors.white70),
              ),
            ),
          
          // Botones de acción
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => setState(() => _showHint = !_showHint),
                  child: Text(_showHint ? "Ocultar" : "Pista"),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                flex: 2,
                child: ElevatedButton(
                  onPressed: _checkAnswer,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.successGreen,
                  ),
                  child: const Text("VERIFICAR"),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
