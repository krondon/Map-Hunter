import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:async';
import 'dart:math';
import '../../models/clue.dart';
import '../../providers/game_provider.dart';
import '../../providers/connectivity_provider.dart';
import '../../../../core/theme/app_theme.dart';
import 'game_over_overlay.dart';
import '../../utils/minigame_logic_helper.dart';
import '../../../auth/providers/player_provider.dart';
import '../../../mall/screens/mall_screen.dart';
import 'package:treasure_hunt_rpg/features/game/services/emoji_movie_service.dart';
import 'package:treasure_hunt_rpg/features/game/models/emoji_movie_problem.dart';

class EmojiMovieMinigame extends StatefulWidget {
  final Clue clue;
  final VoidCallback onSuccess;

  const EmojiMovieMinigame({
    super.key,
    required this.clue,
    required this.onSuccess,
  });

  @override
  State<EmojiMovieMinigame> createState() => _EmojiMovieMinigameState();
}

class _EmojiMovieMinigameState extends State<EmojiMovieMinigame>
    with SingleTickerProviderStateMixin {
  // Game Config
  static const int _gameDurationSeconds = 20;

  // State
  bool _isGameOver = false;
  bool _showOverlay = false;
  String _overlayTitle = "";
  String _overlayMessage = "";
  bool _canRetry = false;
  bool _showShopButton = false;
  bool _isLoading = true;
  int _secondsRemaining = _gameDurationSeconds;
  Timer? _gameTimer;

  // Game Data
  late String _displayEmojis;
  late List<String> _validAnswers;
  List<String> _options = []; // The 4 options to display

  // Service
  late EmojiMovieService _movieService;
  List<EmojiMovieProblem> _allMovies = []; // Cache fetched movies

  // Animations
  late AnimationController _shakeController;
  late Animation<double> _shakeAnimation;

  @override
  void initState() {
    super.initState();
    _movieService = EmojiMovieService(Supabase.instance.client);

    _shakeController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );
    _shakeAnimation = Tween<double>(begin: 0.0, end: 10.0)
        .chain(CurveTween(curve: Curves.elasticIn))
        .animate(_shakeController);

    _initializeGameData();
  }

  void _startGameTimer() {
    _gameTimer?.cancel();
    _gameTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;

      final gameProvider = Provider.of<GameProvider>(context, listen: false);
      if (gameProvider.isFrozen) return;

      if (gameProvider.isFrozen) return;

      // [FIX] Pause timer if connectivity is bad
      final connectivityByProvider =
          Provider.of<ConnectivityProvider>(context, listen: false);
      if (!connectivityByProvider.isOnline) {
        return; // Skip tick
      }

      if (_secondsRemaining > 0) {
        setState(() => _secondsRemaining--);
      } else {
        _gameTimer?.cancel();
        _loseLife("¡Tiempo agotado!");
      }
    });
  }

  Future<void> _initializeGameData() async {
    setState(() => _isLoading = true);

    final question = widget.clue.riddleQuestion;
    final answer = widget.clue.riddleAnswer;

    // Custom Data Check
    bool hasCustomData = question != null &&
        question.isNotEmpty &&
        question != "Adivina la película con los emojis" &&
        answer != null &&
        answer.isNotEmpty;

    String correctAnswer;

    if (hasCustomData) {
      // Use Admin configured data
      _displayEmojis = question!;
      correctAnswer = answer!.trim();
      _validAnswers = [correctAnswer.toLowerCase()];

      // Even if using custom data, we need fetched data for WRONG options
      if (_allMovies.isEmpty) {
        _allMovies = await _movieService.fetchAllMovies();
      }

      _generateOptions(correctAnswer);
      setState(() => _isLoading = false);
      _startGameTimer();
    } else {
      // Use Random Data (Fetched from DB)
      if (_allMovies.isEmpty) {
        _allMovies = await _movieService.fetchAllMovies();
      }

      if (_allMovies.isNotEmpty) {
        final random = Random();
        final problem = _allMovies[random.nextInt(_allMovies.length)];

        _displayEmojis = problem.emojis;
        if (problem.validAnswers.isEmpty) {
          _displayEmojis = "❓❓";
          correctAnswer = "error";
          _validAnswers = ["error"];
        } else {
          correctAnswer = problem.validAnswers.first;
          _validAnswers = problem.validAnswers;
        }

        _generateOptions(correctAnswer);
      } else {
        // DB is empty or offline, and no local fallback
        _displayEmojis = "⚠️";
        correctAnswer = "Sin conexión";
        _validAnswers = ["error"];
        _options = ["Reintentar", "Sin Datos", "Error DB", "Offline"];
      }

      setState(() => _isLoading = false);
      _startGameTimer();
    }
  }

  void _generateOptions(String correctAnswer) {
    if (_allMovies.isEmpty) {
      _options = [correctAnswer, "Option 1", "Option 2", "Option 3"];
      _options.shuffle();
      return;
    }

    final random = Random();
    Set<String> wrongOptions = {};

    int attempts = 0;
    while (wrongOptions.length < 3 && attempts < 100) {
      attempts++;
      final problem = _allMovies[random.nextInt(_allMovies.length)];
      if (problem.validAnswers.isEmpty) continue;

      final candidate = problem.validAnswers.first;

      if (!_validAnswers.contains(candidate.toLowerCase()) &&
          !wrongOptions.contains(candidate)) {
        bool collision = false;
        for (var valid in _validAnswers) {
          if (valid.contains(candidate.toLowerCase()) ||
              candidate.toLowerCase().contains(valid)) {
            collision = true;
            break;
          }
        }

        if (!collision) {
          wrongOptions.add(candidate.toUpperCase());
        }
      }
    }

    while (wrongOptions.length < 3) {
      wrongOptions.add("Opción ${wrongOptions.length + 1}");
    }

    _options = [correctAnswer, ...wrongOptions];
    _options.shuffle();

    _options = _options.map((opt) {
      if (opt.isEmpty) return opt;
      return opt[0].toUpperCase() + opt.substring(1);
    }).toList();
  }

  @override
  void dispose() {
    _shakeController.dispose();
    _gameTimer?.cancel();
    super.dispose();
  }

  void _checkAnswer(String selectedOption) {
    if (_isGameOver) return;

    // [FIX] Prevent interaction if offline
    final connectivity =
        Provider.of<ConnectivityProvider>(context, listen: false);
    if (!connectivity.isOnline) return;

    // Safety check for options like "Sin Datos"
    if (_validAnswers.contains("error") && selectedOption == "Reintentar") {
      _resetGame();
      return;
    }

    final normalizedSelection = selectedOption.toLowerCase();

    // Normalize logic
    bool isCorrect =
        _validAnswers.any((ans) => normalizedSelection == ans.toLowerCase());

    if (isCorrect) {
      _winGame();
    } else {
      _shakeController.forward(from: 0.0);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Incorrecto"),
          backgroundColor: AppTheme.dangerRed,
          duration: Duration(milliseconds: 500),
        ),
      );
      _loseLife("Respuesta incorrecta");
    }
  }

  void _winGame() {
    _gameTimer?.cancel();
    setState(() {
      _isGameOver = true;
    });
    widget.onSuccess();
  }

  Future<void> _loseLife(String reason) async {
    _gameTimer?.cancel();
    final playerProvider = Provider.of<PlayerProvider>(context, listen: false);

    if (playerProvider.currentPlayer != null) {
      final newLives = await MinigameLogicHelper.executeLoseLife(context);

      if (!mounted) return;

      if (newLives <= 0) {
        _showOverlayState(
            title: "GAME OVER",
            message: "Te has quedado sin vidas.",
            retry: false,
            showShop: true);
      } else {
        _showOverlayState(
            title: "¡FALLASTE!", message: reason, retry: true, showShop: false);
      }
    }
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

  void _resetGame() {
    _initializeGameData();

    setState(() {
      _isGameOver = false;
      _showOverlay = false;
      _secondsRemaining = _gameDurationSeconds;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(
          child: CircularProgressIndicator(color: AppTheme.accentGold));
    }

    final minutes = (_secondsRemaining / 60).floor().toString().padLeft(2, '0');
    final seconds = (_secondsRemaining % 60).toString().padLeft(2, '0');
    final isLowTime = _secondsRemaining <= 5;

    return Stack(
      children: [
        Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Timer
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                margin: const EdgeInsets.only(bottom: 20),
                decoration: BoxDecoration(
                  color: isLowTime
                      ? AppTheme.dangerRed.withOpacity(0.2)
                      : Colors.black45,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                      color:
                          isLowTime ? AppTheme.dangerRed : AppTheme.accentGold),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.timer,
                        color: isLowTime
                            ? AppTheme.dangerRed
                            : AppTheme.accentGold),
                    const SizedBox(width: 5),
                    Text("$minutes:$seconds",
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontFamily: 'monospace')),
                  ],
                ),
              ),

              // Emojis Display
              Text(
                _displayEmojis,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 48,
                  letterSpacing: 4,
                ),
              ),

              const SizedBox(height: 40),

              // MULTIPLE CHOICE BUTTONS (2x2 GRID)
              if (_options.length >= 4)
                AnimatedBuilder(
                  animation: _shakeController,
                  builder: (context, child) {
                    return Transform.translate(
                      offset: Offset(
                          _shakeAnimation.value *
                              (_shakeController.status ==
                                      AnimationStatus.forward
                                  ? 1
                                  : -1),
                          0),
                      child: child,
                    );
                  },
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Expanded(child: _buildOptionButton(_options[0])),
                          const SizedBox(width: 12),
                          Expanded(child: _buildOptionButton(_options[1])),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(child: _buildOptionButton(_options[2])),
                          const SizedBox(width: 12),
                          Expanded(child: _buildOptionButton(_options[3])),
                        ],
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),

        // Overlay
        if (_showOverlay)
          GameOverOverlay(
            title: _overlayTitle,
            message: _overlayMessage,
            onRetry: _canRetry ? _resetGame : null,
            onGoToShop: _showShopButton
                ? () async {
                    await Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const MallScreen()),
                    );
                    if (!context.mounted) return;
                    final player =
                        Provider.of<PlayerProvider>(context, listen: false)
                            .currentPlayer;
                    if ((player?.lives ?? 0) > 0) {
                      _resetGame();
                      setState(() {
                        _showOverlay = false;
                      });
                    }
                  }
                : null,
            onExit: () => Navigator.pop(context),
          ),
      ],
    );
  }

  Widget _buildOptionButton(String text) {
    return SizedBox(
      height: 85, // Fixed height for consistency
      child: ElevatedButton(
        onPressed: () => _checkAnswer(text),
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.black54,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
          side: const BorderSide(color: AppTheme.accentGold),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(15),
          ),
          elevation: 4,
        ),
        child: Center(
          child: Text(
            text,
            style: const TextStyle(
              fontSize: 15, // Slightly smaller to fit
              fontWeight: FontWeight.bold,
              height: 1.1,
            ),
            textAlign: TextAlign.center,
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ),
    );
  }
}
