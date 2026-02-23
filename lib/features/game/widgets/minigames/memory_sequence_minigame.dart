import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../models/clue.dart';
import '../../../auth/providers/player_provider.dart';
import '../../utils/minigame_logic_helper.dart';
import '../../providers/game_provider.dart';
import '../../providers/connectivity_provider.dart';
import '../../../../core/theme/app_theme.dart';
import 'game_over_overlay.dart';
import 'cyber_surrender_button.dart';
import '../../../mall/screens/mall_screen.dart';
import '../../../../shared/widgets/animated_cyber_background.dart';
import '../race_track_widget.dart';

class MemorySequenceMinigame extends StatefulWidget {
  final Clue clue;
  final VoidCallback onSuccess;

  const MemorySequenceMinigame({
    super.key,
    required this.clue,
    required this.onSuccess,
  });

  @override
  State<MemorySequenceMinigame> createState() => _MemorySequenceMinigameState();
}

class _MemorySequenceMinigameState extends State<MemorySequenceMinigame> {
  // Configuración
  int _currentDifficulty = 6;
  int _lastRandom = -1; // To avoid immediate repeats if possible
  List<int> _sequence = [];
  List<int> _playerInput = [];
  bool _isPlayerTurn = false;
  bool _isGameActive = false;
  int _activeButtonIndex = -1;

  // Timer State
  late Timer _timer;
  int _secondsRemaining = 90; // Tiempo generoso
  bool _isGameOver = false;

  // Colores mejorados (Vibrantes pero legibles)
  final List<Color> _gameColors = [
    const Color(0xFFD500F9), // Purple (1)
    const Color(0xFF00E5FF), // Cyan (2)
    const Color(0xFF76FF03), // Green (3)
    const Color(0xFFFF3D00), // Orange (4)
  ];

  String _statusMessage = 'ESPERANDO...';

  // Overlay State
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

  @override
  void initState() {
    super.initState();
    _startTimer();
    Future.delayed(const Duration(milliseconds: 1000), _startGame);
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  void _startTimer() {
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;

      final gameProvider = Provider.of<GameProvider>(context, listen: false);
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
        _handleTimeOut();
      }
    });
  }

  void _stopTimer() {
    _timer.cancel();
  }

  void _handleTimeOut() {
    _stopTimer();
    _loseLife("¡Tiempo agotado!");
  }

  void _startGame() {
    if (!mounted || _isGameOver) return;
    setState(() {
      _isGameActive = true;
      _sequence = [];
      _playerInput = [];
      _statusMessage = 'MEMORIZA...';
    });
    _nextRound();
  }

  void _nextRound() {
    if (!mounted || _isGameOver) return;

    // Generar siguiente número evitando repeticiones inmediatas para mayor variedad
    int nextVal;
    do {
      nextVal = Random().nextInt(4);
    } while (nextVal == _lastRandom && _sequence.isNotEmpty);
    _lastRandom = nextVal;

    setState(() {
      _playerInput = [];
      _isPlayerTurn = false;
      _statusMessage = 'OBSERVA';
      _sequence.add(nextVal);
    });
    _playSequence();
  }

  void _playSequence() async {
    await Future.delayed(const Duration(milliseconds: 1000));
    if (_isGameOver) return;

    // Velocidad progresiva: más rápido a medida que avanza la secuencia
    int flashDuration = max(250, 600 - (_sequence.length * 30));
    int pauseDuration = max(100, 200 - (_sequence.length * 15));

    for (int i = 0; i < _sequence.length; i++) {
      if (!mounted || _isGameOver) return;
      setState(() => _activeButtonIndex = _sequence[i]);
      HapticFeedback.lightImpact();
      await Future.delayed(Duration(milliseconds: flashDuration));

      if (!mounted) return;
      setState(() => _activeButtonIndex = -1);
      await Future.delayed(Duration(milliseconds: pauseDuration));
    }

    if (!mounted || _isGameOver) return;
    setState(() {
      _isPlayerTurn = true;
      _statusMessage = 'TU TURNO';
    });
  }

  void _onButtonTap(int index) {
    if (!_isGameActive || !_isPlayerTurn || _isGameOver) return;

    final gameProvider = Provider.of<GameProvider>(context, listen: false);
    if (gameProvider.isFrozen) return;

    // [FIX] Prevent interaction if offline
    final connectivity =
        Provider.of<ConnectivityProvider>(context, listen: false);
    if (!connectivity.isOnline) return;

    HapticFeedback.selectionClick();
    _flashButton(index);

    if (_sequence[_playerInput.length] == index) {
      _playerInput.add(index);
      if (_playerInput.length == _sequence.length) {
        _handleRoundSuccess();
      }
    } else {
      _loseLife("Secuencia Incorrecta.");
    }
  }

  void _flashButton(int index) async {
    setState(() => _activeButtonIndex = index);
    await Future.delayed(const Duration(milliseconds: 200));
    if (mounted) setState(() => _activeButtonIndex = -1);
  }

  void _handleRoundSuccess() {
    setState(() {
      _isPlayerTurn = false;
      _statusMessage = '¡BIEN!';
    });

    if (_sequence.length >= _currentDifficulty) {
      _stopTimer();
      widget.onSuccess();
    } else {
      Future.delayed(const Duration(milliseconds: 800), _nextRound);
    }
  }

  void _handleGiveUp() {
    _stopTimer();
    _loseLife("Te has rendido.");
  }

  void _loseLife(String reason) async {
    _stopTimer();
    setState(() {
      _isGameActive = false;
      _isGameOver = true;
    });
    HapticFeedback.heavyImpact();

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
            title: "¡FALLASTE!",
            message: "$reason",
            retry: true,
            showShop: false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        SingleChildScrollView(
          child: Column(
            children: [
              const SizedBox(height: 5),

              // 1. STATUS BAR
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // LEVEL
                    Text(
                      "NIVEL ${_sequence.length}/$_currentDifficulty",
                      style: TextStyle(
                          color: Colors.white.withOpacity(0.5),
                          fontSize: 10,
                          letterSpacing: 2,
                          decoration: TextDecoration.none),
                    ),

                    // STATUS TEXT
                    Text(
                      _isPlayerTurn ? "TU TURNO" : "MEMORIZA",
                      style: TextStyle(
                        color: _isPlayerTurn
                            ? Colors.greenAccent
                            : AppTheme.accentGold,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.5,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 10),

              // STATUS MESSAGE
              Text(
                _statusMessage,
                style: TextStyle(
                  color:
                      _isPlayerTurn ? Colors.greenAccent : AppTheme.accentGold,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.5,
                  decoration: TextDecoration.none,
                  shadows: [
                    if (_isPlayerTurn)
                      const Shadow(color: Colors.greenAccent, blurRadius: 10)
                  ],
                ),
              ),

              const SizedBox(height: 20),

              // 4. GAME GRID
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 80.0, vertical: 5.0),
                child: AspectRatio(
                  aspectRatio: 1,
                  child: GridView.count(
                    crossAxisCount: 2,
                    mainAxisSpacing: 15,
                    crossAxisSpacing: 15,
                    physics: const NeverScrollableScrollPhysics(),
                    children: List.generate(4, (index) {
                      final isActive = _activeButtonIndex == index;
                      return _buildGameButton(index, isActive);
                    }),
                  ),
                ),
              ),

              const SizedBox(height: 50),

              // 5. SURRENDER BUTTON
              CyberSurrenderButton(
                onPressed: _showOverlay ? null : _handleGiveUp,
              ),
            ],
          ),
        ),
        if (_showOverlay)
          GameOverOverlay(
            title: _overlayTitle,
            message: _overlayMessage,
            isVictory: _isVictory,
            onRetry: _canRetry
                ? () {
                    setState(() {
                      _showOverlay = false;
                      _isGameOver = false;
                      _isPlayerTurn = false;
                      _startGame();
                    });
                  }
                : null,
            onGoToShop: _showShopButton
                ? () async {
                    await Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const MallScreen()),
                    );
                    if (context.mounted) {
                      setState(() {
                        _canRetry = true;
                        _showShopButton = false;
                        _overlayMessage = "¡Vidas recargadas!";
                      });
                    }
                  }
                : null,
            onExit: () => Navigator.pop(context),
          ),
      ],
    );
  }

  Widget _buildGameButton(int index, bool isActive) {
    final color = _gameColors[index];

    return GestureDetector(
      onTapDown: (_) => _onButtonTap(index),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        decoration: BoxDecoration(
          color: isActive ? color : color.withOpacity(0.8),
          borderRadius: BorderRadius.circular(25),
          border: Border.all(
            color: isActive ? Colors.white : Colors.white10,
            width: isActive ? 4 : 2,
          ),
          boxShadow: isActive
              ? [
                  BoxShadow(
                    color: color.withOpacity(0.8),
                    blurRadius: 30,
                    spreadRadius: 5,
                  )
                ]
              : [
                  BoxShadow(
                      color: color.withOpacity(0.2),
                      offset: const Offset(0, 4),
                      blurRadius: 8)
                ],
        ),
        child: Center(
          child: Text(
            "${index + 1}",
            style: const TextStyle(
              color: Colors.white,
              fontSize: 32,
              fontWeight: FontWeight.bold,
              decoration: TextDecoration.none,
            ),
          ),
        ),
      ),
    );
  }
}
