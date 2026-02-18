import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/clue.dart';
import '../../providers/game_provider.dart';
import '../../providers/connectivity_provider.dart';
import '../../../../core/theme/app_theme.dart';
import 'game_over_overlay.dart';
import '../../utils/minigame_logic_helper.dart';
import '../../../auth/providers/player_provider.dart';
import '../../../mall/screens/mall_screen.dart';

class PercentageCalculationMinigame extends StatefulWidget {
  final Clue clue;
  final VoidCallback onSuccess;

  const PercentageCalculationMinigame({
    super.key,
    required this.clue,
    required this.onSuccess,
  });

  @override
  State<PercentageCalculationMinigame> createState() =>
      _PercentageCalculationMinigameState();
}

class _PercentageCalculationMinigameState
    extends State<PercentageCalculationMinigame> {
  // Config
  static const int _targetScore = 5;
  static const int _gameDurationSeconds = 60;

  // State
  int _score = 0;
  int _secondsRemaining = _gameDurationSeconds;
  bool _isGameOver = false;

  // Round Data
  late int _baseNumber;
  late int _percentage; // 10, 20, 25, 50
  late int _correctAnswer;
  List<int> _options = [];

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
        // [FIX] Pause timer if connectivity is bad
        final connectivityByProvider =
            Provider.of<ConnectivityProvider>(context, listen: false);
        if (!connectivityByProvider.isOnline) {
          return; // Skip tick
        }

        if (_secondsRemaining > 0) {
          _secondsRemaining--;
        } else {
          _endGame(win: false, reason: "Tiempo agotado.");
        }
      });
    });
  }

  void _generateRound() {
    // Generate clear percentages: 10, 20, 25, 50
    List<int> percents = [10, 20, 25, 50];
    _percentage = percents[_random.nextInt(percents.length)];

    // Generate accurate base numbers (multiples of 10 or 100)
    if (_percentage == 25) {
      _baseNumber = (_random.nextInt(20) + 1) * 4; // Ensure divisible by 4
    } else {
      _baseNumber = (_random.nextInt(40) + 1) * 10;
    }

    _correctAnswer = (_baseNumber * _percentage) ~/ 100;

    // Generate distractors
    Set<int> distractorSet = {_correctAnswer};
    while (distractorSet.length < 4) {
      // Logic for distractors: slightly off, or calculating wrong %
      int type = _random.nextInt(3);
      int val;
      if (type == 0) {
        // Close value
        val = _correctAnswer + (_random.nextInt(10) - 5) * 2;
      } else if (type == 1) {
        // Wrong percentage logic (e.g. 10% instead of 20%)
        int wrongP = percents[_random.nextInt(percents.length)];
        val = (_baseNumber * wrongP) ~/ 100;
      } else {
        // Random
        val = _random.nextInt(_baseNumber);
      }

      if (val > 0) distractorSet.add(val);
    }

    _options = distractorSet.toList();
    _options.shuffle();
  }

  void _handleSelection(int selected) {
    if (_isGameOver) return;

    // [FIX] Prevent interaction if offline
    final connectivity =
        Provider.of<ConnectivityProvider>(context, listen: false);
    if (!connectivity.isOnline) return;

    if (selected == _correctAnswer) {
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
            win: false, reason: "Cálculo erróneo. Sin vidas.", lives: newLives);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text("¡ERROR DE CÁLCULO! -1 Vida"),
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
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const SizedBox(height: 10), // Reduced top padding

              // 1. Top Bar (Compact)
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  Text("Tiempo: $_secondsRemaining",
                      style:
                          const TextStyle(color: Colors.white, fontSize: 16)),
                  Text("Progreso: $_score/$_targetScore",
                      style:
                          const TextStyle(color: Colors.white, fontSize: 16)),
                ],
              ),

              const SizedBox(height: 10),

              const SizedBox(height: 20),
              Center(
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  margin: const EdgeInsets.symmetric(horizontal: 10),
                  decoration: BoxDecoration(
                      color: Colors.indigo.shade900,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                            color: Colors.indigo.withOpacity(0.5),
                            blurRadius: 20)
                      ]),
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          "$_percentage%",
                          style: const TextStyle(
                              fontSize: 50,
                              color: Colors.amberAccent,
                              fontWeight: FontWeight.bold),
                        ),
                        const Text("DE",
                            style:
                                TextStyle(color: Colors.white54, fontSize: 16)),
                        Text(
                          "$_baseNumber",
                          style: const TextStyle(
                              fontSize: 40,
                              color: Colors.white,
                              fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 10),

              const SizedBox(height: 20),
              Padding(
                padding: const EdgeInsets.only(bottom: 20.0),
                child: Center(
                  child: SizedBox(
                    height: 250, // Fixed height for options grid
                    child: LayoutBuilder(builder: (context, constraints) {
                      // Exact calculation to fit GridView in available space
                      // Height = 2 * itemHeight + 1 * mainAxisSpacing (15)
                      double availableHeight = constraints.maxHeight;
                      double rows = 2;
                      double mainAxisSpacing = 15;
                      // Calculate item height to fit exactly:
                      double itemHeight =
                          (availableHeight - (rows - 1) * mainAxisSpacing) /
                              rows;

                      // Width = 2 * itemWidth + 1 * crossAxisSpacing (15)
                      double availableWidth = constraints.maxWidth;
                      double crossAxisSpacing = 15;
                      double itemWidth =
                          (availableWidth - (2 - 1) * crossAxisSpacing) / 2;

                      // Protect against negative or zero values
                      if (itemHeight <= 0 || itemWidth <= 0)
                        return const SizedBox.shrink();

                      double childAspectRatio = itemWidth / itemHeight;

                      return GridView.count(
                        crossAxisCount: 2,
                        crossAxisSpacing: 15,
                        mainAxisSpacing: 15,
                        childAspectRatio: childAspectRatio,
                        physics: const NeverScrollableScrollPhysics(),
                        children: _options.map((opt) {
                          return GestureDetector(
                            onTap: () => _handleSelection(opt),
                            child: Container(
                              decoration: BoxDecoration(
                                  color: Colors.white10,
                                  borderRadius: BorderRadius.circular(15),
                                  border: Border.all(color: Colors.white24)),
                              child: Center(
                                child: FittedBox(
                                  fit: BoxFit.scaleDown,
                                  child: Text(
                                    "$opt",
                                    style: const TextStyle(
                                        fontSize: 28,
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold),
                                  ),
                                ),
                              ),
                            ),
                          );
                        }).toList(),
                      );
                    }),
                  ),
                ),
              ),
            ],
          ),
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
