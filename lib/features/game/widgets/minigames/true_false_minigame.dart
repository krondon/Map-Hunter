import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:auto_size_text/auto_size_text.dart';
import '../../models/clue.dart';
import '../../providers/game_provider.dart';
import '../../providers/connectivity_provider.dart';
import '../../../../core/theme/app_theme.dart';
import 'game_over_overlay.dart';
import '../../utils/minigame_logic_helper.dart';
import '../../../auth/providers/player_provider.dart';
import '../../../mall/screens/mall_screen.dart';

class TrueFalseMinigame extends StatefulWidget {
  final Clue clue;
  final VoidCallback onSuccess;

  const TrueFalseMinigame({
    super.key,
    required this.clue,
    required this.onSuccess,
  });

  @override
  State<TrueFalseMinigame> createState() => _TrueFalseMinigameState();
}

class TFStatement {
  final String text;
  final bool isTrue;
  final String
      correction; // Shown if false and user gets it wrong (educational)

  TFStatement(this.text, this.isTrue, {this.correction = ""});
}

class _TrueFalseMinigameState extends State<TrueFalseMinigame> {
  // Config
  static const int _targetScore =
      5; // Streak or total? Let's say total for now.
  static const int _gameDurationSeconds = 45; // Faster pace

  // Data
  List<TFStatement> _allStatements =
      []; // Empty initially, loaded from Supabase

  // State
  int _score = 0;
  int _secondsRemaining = _gameDurationSeconds;
  bool _isGameOver = false;

  late TFStatement _currentStatement;

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
    _loadDataAndStart();
  }

  Future<void> _loadDataAndStart() async {
    final gameProvider = Provider.of<GameProvider>(context, listen: false);

    // Si no hay datos, cargarlos
    if (gameProvider.minigameTFStatements.isEmpty) {
      await gameProvider.loadMinigameData();
    }

    if (mounted) {
      setState(() {
        _allStatements = gameProvider.minigameTFStatements
            .map((e) => TFStatement(
                e['statement'].toString(), e['isTrue'] as bool,
                correction: e['correction']?.toString() ?? ""))
            .toList();

        if (_allStatements.isNotEmpty) {
          _startGame();
        } else {
          // Fallback logic
          _allStatements = [TFStatement("Error al cargar datos.", true)];
          _startGame();
        }
      });
    }
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
          _endGame(win: false, reason: "Se acabó el tiempo.");
        }
      });
    });
  }

  void _generateRound() {
    _currentStatement = _allStatements[_random.nextInt(_allStatements.length)];
  }

  void _handleSelection(bool selectedTrue) {
    if (_isGameOver) return;

    // [FIX] Prevent interaction if offline
    final connectivity =
        Provider.of<ConnectivityProvider>(context, listen: false);
    if (!connectivity.isOnline) return;

    if (selectedTrue == _currentStatement.isTrue) {
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
            reason: "Incorrecto. ${_currentStatement.correction}",
            lives: newLives);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text("¡INCORRECTO! -1 Vida"),
              backgroundColor: AppTheme.dangerRed,
              duration: Duration(milliseconds: 1000)),
        );
        _startTimer();
        // Maybe new round?
        _generateRound();
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
          padding: const EdgeInsets.all(20.0),
          child: _allStatements.isEmpty ||
                  (_allStatements.length == 1 &&
                      _allStatements.first.text.contains("Error"))
              ? const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      CircularProgressIndicator(color: AppTheme.accentGold),
                      SizedBox(height: 10),
                      Text("Cargando datos...",
                          style: TextStyle(color: Colors.white70)),
                    ],
                  ),
                )
              : Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Top Bar
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        Text("Tiempo: $_secondsRemaining",
                            style: const TextStyle(
                                color: Colors.white, fontSize: 16)),
                        Text("Racha: $_score/$_targetScore",
                            style: const TextStyle(
                                color: Colors.white, fontSize: 16)),
                      ],
                    ),
                    const SizedBox(height: 20),
                    Container(
                      padding: const EdgeInsets.all(20), // Reduced from 30
                      decoration: BoxDecoration(
                        color: Colors.white12,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: Colors.white30),
                      ),
                      child: Center(
                        child: Text(
                          _currentStatement.text,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 22, // slightly smaller
                              fontWeight: FontWeight.bold,
                              height: 1.2),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    Row(
                      children: [
                        Expanded(
                          child: SizedBox(
                            height: 60, // reduced from 80
                            child: ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.redAccent,
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(15)),
                              ),
                              onPressed: () => _handleSelection(false),
                              child: const AutoSizeText(
                                "FALSO",
                                style: TextStyle(
                                    fontSize: 20, color: Colors.white),
                                maxLines: 1,
                                minFontSize: 12,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 20),
                        Expanded(
                          child: SizedBox(
                            height: 60, // reduced from 80
                            child: ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.greenAccent,
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(15)),
                              ),
                              onPressed: () => _handleSelection(true),
                              child: const AutoSizeText(
                                "VERDADERO",
                                style: TextStyle(
                                    fontSize: 20, color: Colors.black87),
                                maxLines: 1,
                                minFontSize: 12,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20), // reduced from 40
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
