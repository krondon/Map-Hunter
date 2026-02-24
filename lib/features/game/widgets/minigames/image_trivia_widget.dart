import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/clue.dart';
import '../../providers/game_provider.dart';
import '../../providers/connectivity_provider.dart';
import '../../../auth/providers/player_provider.dart';
import '../../../../core/theme/app_theme.dart';
import '../../utils/minigame_logic_helper.dart';
import 'game_over_overlay.dart';
import '../../../mall/screens/mall_screen.dart';

class ImageTriviaWidget extends StatefulWidget {
  final Clue clue;
  final VoidCallback onSuccess;

  const ImageTriviaWidget(
      {super.key, required this.clue, required this.onSuccess});

  @override
  State<ImageTriviaWidget> createState() => _ImageTriviaWidgetState();
}

class _ImageTriviaWidgetState extends State<ImageTriviaWidget> {
  final TextEditingController _controller = TextEditingController();
  bool _showHint = false;
  int _attempts = 3;

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

  void _checkAnswer() {
    final gameProvider = Provider.of<GameProvider>(context, listen: false);
    if (gameProvider.isFrozen) return;

    // [FIX] Prevent interaction if offline
    final connectivity =
        Provider.of<ConnectivityProvider>(context, listen: false);
    if (!connectivity.isOnline) return;

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
    final playerProvider = Provider.of<PlayerProvider>(context, listen: false);
    final gameProvider = Provider.of<GameProvider>(context, listen: false);

    if (playerProvider.currentPlayer != null) {
      final newLives = await MinigameLogicHelper.executeLoseLife(context);

      if (!mounted) return;

      final playerLives = playerProvider.currentPlayer?.lives ?? 0;
      final gameLives = gameProvider.lives;

      if (gameLives <= 0 || playerLives <= 0) {
        _showOverlayState(
            title: "GAME OVER",
            message: "Te has quedado sin vidas.",
            retry: false,
            showShop: true);
      } else {
        setState(() {
          _attempts = 3;
          _controller.clear();
        });
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
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvoked: (didPop) {},
      child: Stack(
        children: [
          // GAME CONTENT
          SingleChildScrollView(
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
                      widget.clue.minigameUrl ??
                          'https://via.placeholder.com/400',
                      height: 180,
                      width: double.infinity,
                      fit: BoxFit.cover,
                      errorBuilder: (ctx, err, stack) => Container(
                        height: 180,
                        color: AppTheme.cardBg,
                        child: const Center(
                          child:
                              Icon(Icons.broken_image, color: Colors.white38),
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
                        onPressed: _showOverlay
                            ? null
                            : _checkAnswer, // Disable if overlay is up
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
                      // Reset has already been done in logic
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
