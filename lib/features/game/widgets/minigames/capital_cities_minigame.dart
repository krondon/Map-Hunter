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

class CapitalCitiesMinigame extends StatefulWidget {
  final Clue clue;
  final VoidCallback onSuccess;

  const CapitalCitiesMinigame({
    super.key,
    required this.clue,
    required this.onSuccess,
  });

  @override
  State<CapitalCitiesMinigame> createState() => _CapitalCitiesMinigameState();
}

class _CapitalCitiesMinigameState extends State<CapitalCitiesMinigame> {
  // Config
  static const int _targetScore = 5;
  static const int _gameDurationSeconds = 30; // Reduced to 30s as requested

  // Data
  Map<String, String> _capitals = {}; // Empty initially, loaded from Supabase

  // State
  int _score = 0;
  int _secondsRemaining = _gameDurationSeconds;
  bool _isGameOver = false;

  late String _currentCountry;
  late String _correctAnswer;
  List<String> _options = [];

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
    if (gameProvider.minigameCapitals.isEmpty) {
      await gameProvider.loadMinigameData();
    }

    if (mounted) {
      setState(() {
        // Convertir lista a mapa
        _capitals = {
          for (var item in gameProvider.minigameCapitals)
            item['flag']!: item['capital']!
        };

        if (_capitals.isNotEmpty) {
          _startGame();
        } else {
          // Fallback logic if Supabase is empty or fails
          _capitals = {"❓": "Error de carga"};
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
    // Pick a random country
    List<String> countries = _capitals.keys.toList();
    _currentCountry = countries[_random.nextInt(countries.length)];
    _correctAnswer = _capitals[_currentCountry]!;

    // Generate 3 distractors
    Set<String> optionsSet = {_correctAnswer};
    List<String> allCapitals = _capitals.values.toList();

    while (optionsSet.length < 4) {
      String distractor = allCapitals[_random.nextInt(allCapitals.length)];
      optionsSet.add(distractor);
    }

    _options = optionsSet.toList();
    _options.shuffle();
  }

  void _handleSelection(String selected) {
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
            win: false,
            reason: "Capital incorrecta. Sin vidas.",
            lives: newLives);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text("¡ERROR! -1 Vida"),
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
          padding: const EdgeInsets.all(16.0),
          child: _capitals.isEmpty ||
                  (_capitals.length == 1 && _capitals.containsKey("❓"))
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
                        Text("Progreso: $_score/$_targetScore",
                            style: const TextStyle(
                                color: Colors.white, fontSize: 16)),
                      ],
                    ),
                    const SizedBox(height: 20),
                    // const Text("BANDERA DE:",
                    //     style: TextStyle(color: Colors.white54, fontSize: 18)),
                    // const SizedBox(height: 10),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        _currentCountry,
                        style: const TextStyle(
                            color: Colors.amberAccent,
                            fontSize: 80, // slightly smaller to save space
                            fontWeight: FontWeight.bold),
                      ),
                    ),
                    const SizedBox(height: 10),
                    // Options Grid
                    Center(
                      child: GridView.count(
                        shrinkWrap: true,
                        crossAxisCount: 2,
                        crossAxisSpacing: 12,
                        mainAxisSpacing: 12,
                        childAspectRatio: 2.2, // Taller buttons
                        physics: const NeverScrollableScrollPhysics(),
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        children: _options.map((opt) {
                          return ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.white10,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  side:
                                      const BorderSide(color: Colors.white24)),
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 4),
                            ),
                            onPressed: () => _handleSelection(opt),
                            child: Center(
                              child: AutoSizeText(
                                opt,
                                style: const TextStyle(fontSize: 18),
                                maxLines: 2,
                                textAlign: TextAlign.center,
                                minFontSize: 10,
                                wrapWords: false,
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                    const SizedBox(height: 4),
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
