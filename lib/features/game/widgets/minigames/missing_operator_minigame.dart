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

class MissingOperatorMinigame extends StatefulWidget {
  final Clue clue;
  final VoidCallback onSuccess;

  const MissingOperatorMinigame({
    super.key,
    required this.clue,
    required this.onSuccess,
  });

  @override
  State<MissingOperatorMinigame> createState() =>
      _MissingOperatorMinigameState();
}

class _MissingOperatorMinigameState extends State<MissingOperatorMinigame> {
  // Config
  static const int _targetScore = 5;
  static const int _gameDurationSeconds = 60;

  // State
  int _score = 0;
  int _secondsRemaining = _gameDurationSeconds;
  bool _isGameOver = false;

  // Round Data
  late int _operand1;
  late int _operand2;
  late int _result;
  late String _correctOperator; // +, -, *, /
  List<String> _options = ['+', '-', 'x', '/'];

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
          _endGame(win: false, reason: "Tiempo agotado.");
        }
      });
    });
  }

  void _generateRound() {
    // Determine operator first
    int opIndex = _random.nextInt(4); // 0:+, 1:-, 2:*, 3:/

    switch (opIndex) {
      case 0: // +
        _correctOperator = '+';
        _operand1 = _random.nextInt(50);
        _operand2 = _random.nextInt(50);
        _result = _operand1 + _operand2;
        break;
      case 1: // -
        _correctOperator = '-';
        _operand1 = _random.nextInt(50) + 10;
        _operand2 = _random.nextInt(_operand1); // Result positive
        _result = _operand1 - _operand2;
        break;
      case 2: // x
        _correctOperator = 'x';
        _operand1 = _random.nextInt(12) + 1;
        _operand2 = _random.nextInt(12) + 1;
        _result = _operand1 * _operand2;
        break;
      case 3: // /
        _correctOperator = '/';
        _operand2 = _random.nextInt(10) + 1; // Divisor
        _result = _random.nextInt(10) + 1; // Quotient
        _operand1 = _operand2 * _result; // Dividend
        break;
    }
  }

  void _handleSelection(String selectedOp) {
    if (_isGameOver) return;

    if (selectedOp == _correctOperator) {
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
    _gameTimer?.cancel();
    final playerProvider = Provider.of<PlayerProvider>(context, listen: false);
    if (playerProvider.currentPlayer != null) {
      final newLives = await MinigameLogicHelper.executeLoseLife(context);
      if (!mounted) return;

      if (newLives <= 0) {
        _endGame(
            win: false,
            reason: "Operador incorrecto. Sin vidas.",
            lives: newLives);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text("¡INCORRECTO! -1 Vida"),
              backgroundColor: AppTheme.dangerRed,
              duration: Duration(milliseconds: 1000)),
        );
        _startTimer();
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
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 20),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  Text("Tiempo: $_secondsRemaining",
                      style: const TextStyle(color: Colors.white)),
                  Text("Progreso: $_score/$_targetScore",
                      style: const TextStyle(color: Colors.white)),
                ],
              ),
            ),

            // Equation Display (The "Door")
            Container(
              padding: const EdgeInsets.all(30),
              margin: const EdgeInsets.symmetric(horizontal: 20),
              decoration: BoxDecoration(
                  color: Colors.grey[900],
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.blueAccent, width: 3),
                  boxShadow: [
                    BoxShadow(
                        color: Colors.blue.withOpacity(0.3), blurRadius: 20)
                  ]),
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  mainAxisSize: MainAxisSize.min, // Ensure it shrinks if needed
                  children: [
                    Text("$_operand1",
                        style:
                            const TextStyle(fontSize: 40, color: Colors.white)),
                    const SizedBox(width: 10), // Reduced spacing
                    Container(
                      width: 50,
                      height: 50,
                      decoration: BoxDecoration(
                          color: Colors.black,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: Colors.amber)),
                      child: const Center(
                        child: Text("?",
                            style:
                                TextStyle(fontSize: 30, color: Colors.amber)),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Text("$_operand2",
                        style:
                            const TextStyle(fontSize: 40, color: Colors.white)),
                    const SizedBox(width: 10),
                    const Text("=",
                        style: TextStyle(fontSize: 40, color: Colors.white)),
                    const SizedBox(width: 10),
                    Text("$_result",
                        style: const TextStyle(
                            fontSize: 40, color: Colors.greenAccent)),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 50),

            // Options
            Wrap(
              spacing: 20,
              runSpacing: 20,
              alignment: WrapAlignment.center,
              children: _options.map((op) {
                return GestureDetector(
                  onTap: () => _handleSelection(op),
                  child: Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                        color: AppTheme.cardBg,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white54),
                        boxShadow: [
                          BoxShadow(
                              color: Colors.white.withOpacity(0.1),
                              blurRadius: 10)
                        ]),
                    child: Center(
                      child: Text(op,
                          style: const TextStyle(
                              fontSize: 40,
                              color: Colors.white,
                              fontWeight: FontWeight.bold)),
                    ),
                  ),
                );
              }).toList(),
            )
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
}
