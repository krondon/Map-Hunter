import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../utils/minigame_logic_helper.dart';
import '../../models/clue.dart';
import '../../../auth/providers/player_provider.dart';
import '../../../../core/theme/app_theme.dart';
import '../../providers/game_provider.dart';
import '../../providers/connectivity_provider.dart';
import 'game_over_overlay.dart';
import '../../../mall/screens/mall_screen.dart';

class FlagsMinigame extends StatefulWidget {
  final Clue clue;
  final VoidCallback onSuccess;

  const FlagsMinigame({
    super.key,
    required this.clue,
    required this.onSuccess,
  });

  @override
  State<FlagsMinigame> createState() => _FlagsMinigameState();
}

class _FlagsMinigameState extends State<FlagsMinigame> {
  int _score = 0;
  final int _targetScore = 10; // Más banderas para que no sea tan corto
  int _currentQuestionIndex = 0;
  bool _isGameOver = false;

  late List<Map<String, String>> _shuffledQuestions;

  // Timer State
  Timer? _timer;
  int _secondsRemaining = 45; // Menos tiempo para presionar un poco más

  // Estado Local
  List<String>? _currentOptions;
  int _localAttempts = 3;

  // Lista de países balanceada (Nivel Intermedio)
  final List<Map<String, String>> _allCountries = [
    {'code': 've', 'name': 'Venezuela'},
    {'code': 'es', 'name': 'España'},
    {'code': 'us', 'name': 'Estados Unidos'},
    {'code': 'fr', 'name': 'Francia'},
    {'code': 'de', 'name': 'Alemania'},
    {'code': 'jp', 'name': 'Japón'},
    {'code': 'br', 'name': 'Brasil'},
    {'code': 'ar', 'name': 'Argentina'},
    {'code': 'mx', 'name': 'México'},
    {'code': 'it', 'name': 'Italia'},
    {'code': 'ca', 'name': 'Canadá'},
    {'code': 'pt', 'name': 'Portugal'},
    {'code': 'au', 'name': 'Australia'},
    {'code': 'kr', 'name': 'Corea del Sur'},
    {'code': 'ch', 'name': 'Suiza'},
    {'code': 'gr', 'name': 'Grecia'},
    {'code': 'be', 'name': 'Bélgica'},
    {'code': 'nl', 'name': 'Países Bajos'},
    {'code': 'se', 'name': 'Suecia'},
    {'code': 'no', 'name': 'Noruega'},
    {'code': 'dk', 'name': 'Dinamarca'},
    {'code': 'fi', 'name': 'Finlandia'},
    {'code': 'pl', 'name': 'Polonia'},
    {'code': 'tr', 'name': 'Turquía'},
    {'code': 'za', 'name': 'Sudáfrica'},
    {'code': 'eg', 'name': 'Egipto'},
    {'code': 'th', 'name': 'Tailandia'},
    {'code': 'vn', 'name': 'Vietnam'},
    {'code': 'ph', 'name': 'Filipinas'},
    {'code': 'my', 'name': 'Malasia'},
    {'code': 'id', 'name': 'Indonesia'},
    {'code': 'co', 'name': 'Colombia'},
    {'code': 'cl', 'name': 'Chile'},
    {'code': 'pe', 'name': 'Perú'},
    {'code': 'uy', 'name': 'Uruguay'},
  ];

  @override
  void initState() {
    super.initState();
    _startNewGame();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;

      // Check for freeze state
      final gameProvider = Provider.of<GameProvider>(context, listen: false);
      if (gameProvider.isFrozen) return; // Pause timer

      // [FIX] Pause timer if connectivity is bad
      final connectivityByProvider =
          Provider.of<ConnectivityProvider>(context, listen: false);
      if (!connectivityByProvider.isOnline) {
        return; // Skip tick
      }

      if (_secondsRemaining > 0) {
        setState(() {
          _secondsRemaining--;
        });
      } else {
        _timer?.cancel();
        _loseGlobalLife("¡Se acabó el tiempo!", timeOut: true);
      }
    });
  }

  void _startNewGame() {
    final random = Random();
    var questions = List<Map<String, String>>.from(_allCountries);
    questions.shuffle(random);
    // Tomar suficientes para el target
    _shuffledQuestions = questions.take(_targetScore).toList();

    _score = 0;
    _currentQuestionIndex = 0;
    _isGameOver = false;
    _secondsRemaining = 45;
    _currentOptions = null;
    _localAttempts = 3;
    _startTimer();
    setState(() {});
  }

  void _handleOptionSelected(String selectedName) {
    if (_isGameOver) return;

    final gameProvider = Provider.of<GameProvider>(context, listen: false);
    if (gameProvider.isFrozen) return; // Ignore input if frozen

    if (gameProvider.isFrozen) return; // Ignore input if frozen

    // [FIX] Prevent interaction if offline
    final connectivity =
        Provider.of<ConnectivityProvider>(context, listen: false);
    if (!connectivity.isOnline) return;

    final correctAnswer = _shuffledQuestions[_currentQuestionIndex]['name'];

    if (selectedName == correctAnswer) {
      _score++;
      _currentOptions = null;

      if (_score >= _targetScore) {
        _winGame();
      } else {
        setState(() {
          _currentQuestionIndex++;
        });
      }
    } else {
      setState(() {
        _localAttempts--;
      });

      if (_localAttempts <= 0) {
        _loseGlobalLife("¡Demasiados errores!");
      } else {
        // Al fallar, barajamos las opciones para que no sea solo adivinar por eliminación estática
        setState(() {
          _currentOptions = null;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Incorrecto. Te quedan $_localAttempts intentos."),
            backgroundColor: AppTheme.warningOrange,
            duration: const Duration(milliseconds: 600),
          ),
        );
      }
    }
  }

  // State for overlay
  bool _showOverlay = false;
  String _overlayTitle = "";
  String _overlayMessage = "";
  bool _canRetry = false;
  bool _isVictory = false;
  bool _showShopButton = false;

  void _showOverlayState(
      {required String title,
      required String message,
      bool retry = false,
      bool victory = false,
      bool showShop = false}) {
    setState(() {
      _showOverlay = true;
      _overlayTitle = title;
      _overlayMessage = message;
      _canRetry = retry;
      _isVictory = victory;
      _showShopButton = showShop;
    });
  }

  void _loseGlobalLife(String reason, {bool timeOut = false}) async {
    _timer?.cancel();
    final playerProvider = Provider.of<PlayerProvider>(context, listen: false);

    // Stop interaction immediately
    setState(() => _isGameOver = true);

    if (playerProvider.currentPlayer != null) {
      final newLives = await MinigameLogicHelper.executeLoseLife(context);

      if (!mounted) return;

      if (newLives <= 0) {
        _showOverlayState(
            title: "GAME OVER",
            message: "Te has quedado sin vidas globales.\n$reason",
            retry: false,
            showShop: true);
      } else {
        _showOverlayState(
            title: "¡FALLASTE!",
            message: "$reason\nHas perdido 1 vida.",
            retry: true,
            showShop: false);
      }
    }
  }

  // Old dialog methods removed in favor of _showOverlayState

  List<String> _generateOptions() {
    if (_currentOptions != null) return _currentOptions!;

    final correctAnswer = _shuffledQuestions[_currentQuestionIndex]['name']!;
    final random = Random();
    final options = <String>{correctAnswer};

    while (options.length < 4) {
      final randomCountry =
          _allCountries[random.nextInt(_allCountries.length)]['name']!;
      options.add(randomCountry);
    }

    _currentOptions = options.toList()..shuffle();
    return _currentOptions!;
  }

  void _winGame() {
    _timer?.cancel();
    setState(() {
      _isGameOver = true;
    });
    // For victory, we might still want to call onSuccess directly,
    // or show a victory overlay first. Use logic helper's standard if preferred,
    // but here we just follow previous logic:
    widget.onSuccess();
  }

  @override
  Widget build(BuildContext context) {
    // 2. Implementación del Bloqueo de INTERFAZ (UI Hardening)
    return PopScope(
      canPop: false, // Prevent back button
      onPopInvoked: (didPop) {
        if (didPop) return;
        // Optional: Show toast "Completa o sal del juego usando los botones"
      },
      child: Stack(
        children: [
          // GAME CONTENT
          Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(vertical: 20),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // HEADER: TIMER & INTENTOS LOCALES
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: (_secondsRemaining <= 10)
                          ? AppTheme.dangerRed.withOpacity(0.2)
                          : Colors.black45,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                          color: (_secondsRemaining <= 10)
                              ? AppTheme.dangerRed
                              : AppTheme.accentGold),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.timer,
                            color: (_secondsRemaining <= 10)
                                ? AppTheme.dangerRed
                                : AppTheme.accentGold,
                            size: 20),
                        const SizedBox(width: 8),
                        Text(
                          "${(_secondsRemaining / 60).floor().toString().padLeft(2, '0')}:${(_secondsRemaining % 60).toString().padLeft(2, '0')}",
                          style: TextStyle(
                            color: (_secondsRemaining <= 10)
                                ? AppTheme.dangerRed
                                : Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            fontFamily: 'monospace',
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 20),

                  const Text(
                    "¿DE QUÉ PAÍS ES ESTA BANDERA?",
                    style: TextStyle(
                        color: AppTheme.primaryPurple,
                        fontSize: 16,
                        fontWeight: FontWeight.bold),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 5),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        "Aciertos: $_score / $_targetScore",
                        style: const TextStyle(color: Colors.white70),
                      ),
                      const SizedBox(width: 20),
                      // Intentos Locales (Visual)
                      Row(
                        children: List.generate(3, (index) {
                          return Icon(
                            index < _localAttempts
                                ? Icons.favorite
                                : Icons.favorite_border,
                            color: AppTheme.secondaryPink,
                            size: 20,
                          );
                        }),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  // Bandera
                  if (_shuffledQuestions.isNotEmpty &&
                      _currentQuestionIndex < _shuffledQuestions.length)
                    Container(
                      height: 150,
                      width: 250,
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.white, width: 2),
                        boxShadow: [
                          BoxShadow(
                              color: Colors.black.withOpacity(0.5),
                              blurRadius: 10,
                              offset: const Offset(0, 5))
                        ],
                        image: DecorationImage(
                          fit: BoxFit.cover,
                          image: NetworkImage(
                              "https://flagcdn.com/w640/${_shuffledQuestions[_currentQuestionIndex]['code']}.png"),
                        ),
                      ),
                    ),

                  const SizedBox(height: 40),

                  // Opciones
                  if (!_showOverlay) // Hide options if overlay is ON to prevent interaction (AbsorbPointer handles it, but cleaner UI)
                    Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      alignment: WrapAlignment.center,
                      children: _generateOptions().map((option) {
                        return ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.primaryPurple,
                            padding: const EdgeInsets.symmetric(
                                horizontal: 30, vertical: 15),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10)),
                          ),
                          onPressed: () => _handleOptionSelected(option),
                          child: Text(
                            option,
                            style: const TextStyle(
                                fontSize: 16, color: Colors.white),
                          ),
                        );
                      }).toList(),
                    ),
                  // Espacio extra
                  const SizedBox(height: 100),
                ],
              ),
            ),
          ),

          // OVERLAY
          if (_showOverlay)
            GameOverOverlay(
              title: _overlayTitle,
              message: _overlayMessage,
              isVictory: _isVictory,
              onRetry: _canRetry
                  ? () {
                      setState(() {
                        _showOverlay = false;
                      });
                      _startNewGame();
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
                      // Force sync
                      await Provider.of<PlayerProvider>(context, listen: false)
                          .refreshProfile();

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
