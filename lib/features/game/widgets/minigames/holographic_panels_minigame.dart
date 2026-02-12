import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/clue.dart';
import '../../providers/game_provider.dart';
import '../../../../core/theme/app_theme.dart';
import 'game_over_overlay.dart';
import '../../utils/minigame_logic_helper.dart';
import '../../../auth/providers/player_provider.dart';
import '../../../mall/screens/mall_screen.dart';

class HolographicPanelsMinigame extends StatefulWidget {
  final Clue clue;
  final VoidCallback onSuccess;

  const HolographicPanelsMinigame({
    super.key,
    required this.clue,
    required this.onSuccess,
  });

  @override
  State<HolographicPanelsMinigame> createState() =>
      _HolographicPanelsMinigameState();
}

class _HolographicPanelsMinigameState extends State<HolographicPanelsMinigame>
    with TickerProviderStateMixin {
  // Config
  static const int _targetScore = 10; // Number of correct comparisons needed
  static const int _gameDurationSeconds = 60;

  // State
  int _score = 0;
  int _secondsRemaining = _gameDurationSeconds;
  bool _isGameOver = false;

  // Current Round Data
  late String _leftEquation;
  late int _leftResult;
  late String _rightEquation;
  late int _rightResult;

  // Animations
  late AnimationController _shakeController;
  late Animation<double> _shakeAnimation;

  // Overlay
  bool _showOverlay = false;
  String _overlayTitle = "";
  String _overlayMessage = "";
  bool _canRetry = false;
  bool _showShopButton = false;

  Timer? _gameTimer;
  final Random _random = Random();

  @override
  void initState() {
    super.initState();
    _shakeController = AnimationController(
        duration: const Duration(milliseconds: 500), vsync: this);
    _shakeAnimation = Tween<double>(begin: 0.0, end: 10.0)
        .chain(CurveTween(curve: Curves.elasticIn))
        .animate(_shakeController);

    _startGame();
  }

  void _startGame() {
    _score = 0;
    _secondsRemaining = _gameDurationSeconds;
    _isGameOver = false;
    _showOverlay = false;
    _generateRound();
    _startTimer();
  }

  void _startTimer() {
    _gameTimer?.cancel();
    _gameTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted || _isGameOver) {
        timer.cancel();
        return;
      }
      setState(() {
        if (_secondsRemaining > 0) {
          _secondsRemaining--;
        } else {
          _endGame(win: false, reason: "¡Se acabó el tiempo!");
        }
      });
    });
  }

  void _generateRound() {
    // Generate two different results
    _leftResult = _random.nextInt(20) + 1; // 1 to 20
    do {
      _rightResult = _random.nextInt(20) + 1;
    } while (_rightResult == _leftResult);

    _leftEquation = _generateEquation(_leftResult);
    _rightEquation = _generateEquation(_rightResult);
  }

  String _generateEquation(int result) {
    // Simple logic: a +/- b = result
    // 50% chance of + or -
    bool usePlus = _random.nextBool();

    if (usePlus) {
      int a = _random.nextInt(result); // 0 to result-1
      int b = result - a;
      return "$a + $b";
    } else {
      int b = _random.nextInt(10) + 1; // 1 to 10
      int a = result + b;
      return "$a - $b";
    }
  }

  void _handleSelection(bool isLeft) {
    if (_isGameOver) return;

    bool correct;
    if (isLeft) {
      correct = _leftResult > _rightResult;
    } else {
      correct = _rightResult > _leftResult;
    }

    if (correct) {
      setState(() {
        _score++;
        if (_score >= _targetScore) {
          _endGame(win: true);
        } else {
          _generateRound();
        }
      });
    } else {
      _handleMistake();
    }
  }

  Future<void> _handleMistake() async {
    _shakeController.forward(from: 0.0);

    // Logic for penalty (lose life)
    _gameTimer?.cancel();

    final playerProvider = Provider.of<PlayerProvider>(context, listen: false);
    if (playerProvider.currentPlayer != null) {
      final newLives = await MinigameLogicHelper.executeLoseLife(context);

      if (!mounted) return;

      if (newLives <= 0) {
        _endGame(
            win: false,
            reason: "Elección incorrecta. Sin vidas.",
            lives: newLives);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text("¡ERROR! -1 Vida"),
              backgroundColor: AppTheme.dangerRed,
              duration: Duration(milliseconds: 1000)),
        );
        _startTimer(); // Resume timer
        _generateRound(); // New round on mistake? Or keep same? Let's give new one.
      }
    }
  }

  void _endGame({required bool win, String? reason, int? lives}) {
    _gameTimer?.cancel();
    setState(() {
      _isGameOver = true;
    });

    if (win) {
      widget.onSuccess();
    } else {
      final currentLives = lives ??
          Provider.of<PlayerProvider>(context, listen: false)
              .currentPlayer
              ?.lives ??
          0;

      setState(() {
        _showOverlay = true;
        _overlayTitle = "GAME OVER";
        _overlayMessage = reason ?? "Perdiste";
        _canRetry = currentLives > 0;
        _showShopButton = true;
      });
    }
  }

  void _resetGame() {
    setState(() {
      _isGameOver = false;
      _showOverlay = false;
    });
    _startGame();
  }

  @override
  void dispose() {
    _gameTimer?.cancel();
    _shakeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Column(
          children: [
            // Status Bar
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildStatusBadge(
                      Icons.timer, "$_secondsRemaining s", Colors.orange),
                  _buildStatusBadge(
                      Icons.star, "$_score / $_targetScore", Colors.yellow),
                ],
              ),
            ),

            const SizedBox(height: 20),
            const Text(
              "¿Cuál resultado es MAYOR?",
              style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 20),
            // Panels
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20.0),
              child: Row(
                children: [
                  Expanded(
                      child: _buildPanel(_leftEquation,
                          () => _handleSelection(true), Colors.cyanAccent)),
                  const SizedBox(width: 20),
                  Expanded(
                      child: _buildPanel(_rightEquation,
                          () => _handleSelection(false), Colors.pinkAccent)),
                ],
              ),
            ),
            const SizedBox(height: 50),
          ],
        ),
        if (_showOverlay)
          GameOverOverlay(
            title: _overlayTitle,
            message: _overlayMessage,
            onRetry: _canRetry ? _resetGame : null,
            onGoToShop: _showShopButton
                ? () async {
                    await Navigator.push(context,
                        MaterialPageRoute(builder: (_) => const MallScreen()));
                    if (mounted) {
                      final player =
                          Provider.of<PlayerProvider>(context, listen: false)
                              .currentPlayer;
                      if ((player?.lives ?? 0) > 0) _resetGame();
                    }
                  }
                : null,
            onExit: () => Navigator.pop(context),
          ),
      ],
    );
  }

  Widget _buildPanel(String text, VoidCallback onTap, Color color) {
    return AnimatedBuilder(
      animation: _shakeAnimation,
      builder: (context, child) {
        return Transform.translate(
          offset: Offset(_shakeAnimation.value, 0),
          child: GestureDetector(
            onTap: onTap,
            child: Container(
              decoration: BoxDecoration(
                  color: Colors.black54,
                  border: Border.all(color: color, width: 2),
                  borderRadius: BorderRadius.circular(15),
                  boxShadow: [
                    BoxShadow(
                        color: color.withOpacity(0.3),
                        blurRadius: 15,
                        spreadRadius: 2)
                  ]),
              child: Center(
                child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      text,
                      style: TextStyle(
                          color: color,
                          fontSize: 32,
                          fontWeight: FontWeight.bold,
                          fontFamily: 'Courier' // Monospace for digital look
                          ),
                    )),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildStatusBadge(IconData icon, String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.black45,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.5)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 8),
          Text(text,
              style: TextStyle(
                  color: color, fontWeight: FontWeight.bold, fontSize: 16)),
        ],
      ),
    );
  }
}
