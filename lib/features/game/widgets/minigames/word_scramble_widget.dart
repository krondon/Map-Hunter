import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:math'; // For shuffling
import '../../models/clue.dart';
import '../../providers/game_provider.dart';
import '../../providers/connectivity_provider.dart';
import '../../../auth/providers/player_provider.dart';
import '../../../../core/theme/app_theme.dart';
import '../../utils/minigame_logic_helper.dart';
import 'game_over_overlay.dart';
import '../../../mall/screens/mall_screen.dart';

class WordScrambleWidget extends StatefulWidget {
  final Clue clue;
  final VoidCallback onSuccess;

  const WordScrambleWidget(
      {super.key, required this.clue, required this.onSuccess});

  @override
  State<WordScrambleWidget> createState() => _WordScrambleWidgetState();
}

class _WordScrambleWidgetState extends State<WordScrambleWidget> {
  // State logic
  String _currentWord = "";
  List<String> _shuffledLetters = [];
  int _attempts = 3;

  // Overlay State
  bool _showOverlay = false;
  String _overlayTitle = "";
  String _overlayMessage = "";
  bool _canRetry = false;
  bool _showShopButton = false;

  @override
  void initState() {
    super.initState();
    _onReset();
  }

  void _onReset() {
    final answer = widget.clue.riddleAnswer?.toUpperCase() ?? "FLUTTER";
    _currentWord = "";

    // Create pool of letters (answer + some random noise if needed, but simple scramble is safer)
    List<String> letters = answer.split('');
    letters.shuffle(Random());
    _shuffledLetters = letters;

    setState(() {});
  }

  void _onLetterTap(String letter) {
    if (_showOverlay) return;

    // [FIX] Prevent interaction if offline
    final connectivity =
        Provider.of<ConnectivityProvider>(context, listen: false);
    if (!connectivity.isOnline) return;

    setState(() {
      _currentWord += letter;
      _shuffledLetters.remove(letter); // Remove ONE instance of the letter
    });
  }

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
          _onReset();
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
    final answerLength = widget.clue.riddleAnswer?.length ?? 8;

    return PopScope(
      canPop: false,
      onPopInvoked: (didPop) {},
      child: Stack(
        children: [
          // GAME CONTENT
          SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              children: [
                const Icon(Icons.shuffle,
                    size: 40, color: AppTheme.secondaryPink),
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
                  padding:
                      const EdgeInsets.symmetric(vertical: 12, horizontal: 15),
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
                        onPressed: _showOverlay
                            ? null
                            : (_currentWord.length == answerLength
                                ? _checkAnswer
                                : null), // Disable if overlay is up
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
                      // Reset already called in loseLife
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
