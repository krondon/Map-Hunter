import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../models/clue.dart';
import '../../../auth/providers/player_provider.dart';
import '../../providers/game_provider.dart';
import '../../../../core/theme/app_theme.dart';
import 'game_over_overlay.dart';
import '../race_track_widget.dart';
import '../../utils/minigame_logic_helper.dart';
import '../../../../shared/widgets/animated_cyber_background.dart';

class FastNumberMinigame extends StatefulWidget {
  final Clue clue;
  final VoidCallback onSuccess;

  const FastNumberMinigame({
    super.key,
    required this.clue,
    required this.onSuccess,
  });

  @override
  State<FastNumberMinigame> createState() => _FastNumberMinigameState();
}

enum GameState { preparing, showing, inputting, finished }

class _FastNumberMinigameState extends State<FastNumberMinigame> with SingleTickerProviderStateMixin {
  GameState _state = GameState.preparing;
  String _targetNumber = "";
  String _currentInput = "";
  late AnimationController _animationController;
  late Animation<Offset> _flyAnimation;
  
  Timer? _stateTimer;
  int _preparationCountdown = 3;
  int _attemptsRemaining = 3; // internal attempts per life
  
  // Stats
  late Timer _gameTimer;
  int _secondsRemaining = 45;
  bool _isGameOver = false;
  String _statusMessage = "";
  Color _statusColor = Colors.white;

  // Overlay State
  bool _showOverlay = false;
  String _overlayTitle = "";
  String _overlayMessage = "";
  bool _canRetry = false;
  bool _isVictory = false;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1050), // Speed of the flying number
    );
    
    _flyAnimation = Tween<Offset>(
      begin: const Offset(-1.5, 0.0), // Start from left outside
      end: const Offset(1.5, 0.0),   // End at right outside
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.linear,
    ));

    _startPreparation();
    _startGameTimer();
  }

  @override
  void dispose() {
    _animationController.dispose();
    _stateTimer?.cancel();
    _gameTimer.cancel();
    super.dispose();
  }

  void _startGameTimer() {
    _gameTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;
      final gameProvider = Provider.of<GameProvider>(context, listen: false);
      if (gameProvider.isFrozen) return;

      if (_secondsRemaining > 0) {
        setState(() => _secondsRemaining--);
      } else {
        _handleTimeOut();
      }
    });
  }

  void _handleTimeOut() {
    _gameTimer.cancel();
    _loseLife("¡Tiempo agotado!");
  }

  void _startPreparation() {
    _state = GameState.preparing;
    _preparationCountdown = 3;
    _targetNumber = _generateRandomNumber(5);
    _currentInput = "";
    _statusMessage = "";
    
    _stateTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;
      if (_preparationCountdown > 1) {
        setState(() => _preparationCountdown--);
      } else {
        timer.cancel();
        // Clear countdown and wait 5 seconds silently
        setState(() => _preparationCountdown = 0);
        Future.delayed(const Duration(seconds: 5), () {
          if (mounted) _showNumberTransition();
        });
      }
    });
  }

  String _generateRandomNumber(int length) {
    String number = "";
    for (int i = 0; i < length; i++) {
      number += Random().nextInt(10).toString();
    }
    return number;
  }

  void _showNumberTransition() async {
    setState(() => _state = GameState.showing);
    
    await Future.delayed(const Duration(milliseconds: 500));
    if (!mounted) return;
    
    _animationController.forward().then((_) {
      if (mounted) {
        setState(() => _state = GameState.inputting);
        _animationController.reset();
      }
    });
  }

  void _onKeyPress(String value) {
    if (_state != GameState.inputting || _isGameOver) return;
    
    HapticFeedback.lightImpact();
    setState(() {
      if (_currentInput.length < 5) {
        _currentInput += value;
        _statusMessage = ""; // Clear error message when typing
        if (_currentInput.length == 5) {
          _checkInput();
        }
      }
    });
  }

  void _onDelete() {
    if (_state != GameState.inputting || _isGameOver) return;
    if (_currentInput.isNotEmpty) {
      setState(() => _currentInput = _currentInput.substring(0, _currentInput.length - 1));
      HapticFeedback.selectionClick();
    }
  }

  void _checkInput() {
    if (_currentInput == _targetNumber) {
      _handleWin();
    } else {
      setState(() {
        _attemptsRemaining--;
        _statusMessage = "CÓDIGO INCORRECTO";
        _statusColor = AppTheme.dangerRed;
        _currentInput = ""; // Clear input for next attempt
      });
      
      if (_attemptsRemaining > 0) {
        HapticFeedback.vibrate();
        // Wait a small moment to show the error before restarting
        Future.delayed(const Duration(milliseconds: 1000), () {
          if (mounted) _startPreparation();
        });
      } else {
        _loseLife("Se agotaron los intentos.");
      }
    }
  }

  void _handleWin() {
    _gameTimer.cancel();
    setState(() {
      _state = GameState.finished;
      _isGameOver = true;
      _isVictory = true;
    });
    HapticFeedback.heavyImpact();
    _showOverlayState(
      title: "CÓDIGO CAPTURADO",
      message: "Has interceptado el paquete de datos.",
      victory: true,
    );
  }

  void _loseLife(String reason) async {
    _gameTimer.cancel();
    _stateTimer?.cancel();
    
    int livesLeftCount = await MinigameLogicHelper.executeLoseLife(context);
    
    if (mounted) {
      if (livesLeftCount <= 0) {
        setState(() => _isGameOver = true);
        _showOverlayState(
          title: "ERROR CRÍTICO",
          message: "$reason - Sin vidas.",
        );
      } else {
        _showOverlayState(
          title: "FALLO DE SINCRONÍA",
          message: "$reason -1 Vida.",
          retry: true,
        );
      }
    }
  }

  void _handleGiveUp() {
    _gameTimer.cancel();
    _stateTimer?.cancel();
    _loseLife("Abandono.");
  }

  void _showOverlayState({required String title, required String message, bool retry = false, bool victory = false}) {
    setState(() {
      _showOverlay = true;
      _overlayTitle = title;
      _overlayMessage = message;
      _canRetry = retry;
      _isVictory = victory;
    });
  }

  @override
  Widget build(BuildContext context) {
    final gameProvider = Provider.of<GameProvider>(context);
    final player = context.watch<PlayerProvider>().currentPlayer;

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          const AnimatedCyberBackground(),
          
          SafeArea(
            child: Column(
              children: [
                // 1. TOP HEADER (Requested: Lives, XP and Flag Icon at the top right)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 8),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      _buildStatPill(Icons.favorite, "x${gameProvider.lives}", AppTheme.dangerRed),
                      const SizedBox(width: 8),
                      _buildStatPill(Icons.star, "+50 XP", Colors.amber),
                      const SizedBox(width: 10),
                      IconButton(
                        onPressed: _handleGiveUp,
                        icon: const Icon(Icons.flag, color: AppTheme.dangerRed, size: 22),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
                    ],
                  ),
                ),

                // 2. RACE TRACK
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: RaceTrackWidget(
                    leaderboard: gameProvider.leaderboard,
                    currentPlayerId: player?.userId ?? '',
                    totalClues: gameProvider.clues.length,
                  ),
                ),

                // 3. SUB-HEADER (Lives, Timer)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 8),
                  child: Row(
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.favorite, color: AppTheme.dangerRed, size: 24),
                          const SizedBox(width: 8),
                          Text(
                            "x${gameProvider.lives}",
                            style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                      const Spacer(),
                      // Attempts indicator
                      _buildStatPill(Icons.refresh, "Intentos: $_attemptsRemaining", _attemptsRemaining == 1 ? AppTheme.dangerRed : AppTheme.accentGold),
                      const SizedBox(width: 8),
                      // Timer
                      _buildStatPill(Icons.timer_outlined, "${(_secondsRemaining ~/ 60)}:${(_secondsRemaining % 60).toString().padLeft(2, '0')}", _secondsRemaining < 10 ? AppTheme.dangerRed : Colors.white70),
                    ],
                  ),
                ),

                const SizedBox(height: 20),

                // 4. GAME AREA
                Expanded(
                  child: Container(
                    width: double.infinity,
                    margin: const EdgeInsets.symmetric(horizontal: 20),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.05),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: Colors.white10),
                    ),
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        if (_state == GameState.preparing)
                          _buildPreparingView(),
                        if (_state == GameState.showing)
                          SlideTransition(
                            position: _flyAnimation,
                            child: _buildFlyingNumber(),
                          ),
                        if (_state == GameState.inputting)
                          _buildInputView(),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 20),

                // 5. KEYPAD (Only in inputting state)
                _buildKeypad(),

                const SizedBox(height: 20),
              ],
            ),
          ),

          if (_showOverlay)
            GameOverOverlay(
              title: _overlayTitle,
              message: _overlayMessage,
              isVictory: _isVictory,
              onRetry: _canRetry ? () {
                setState(() {
                  _showOverlay = false;
                  _isGameOver = false;
                  _isVictory = false;
                  _secondsRemaining = 45;
                  _startPreparation();
                  _startGameTimer();
                });
              } : null,
              onExit: () {
                if (_isVictory) widget.onSuccess();
                Navigator.pop(context);
              },
            ),
        ],
      ),
    );
  }

  Widget _buildPreparingView() {
    // Hidden during the 5s pause after countdown
    if (_preparationCountdown == 0) return const SizedBox.shrink();

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                "PRESTA ATENCIÓN",
                style: TextStyle(
                  color: AppTheme.accentGold, 
                  fontSize: 20, 
                  fontWeight: FontWeight.w900, 
                  letterSpacing: 2
                ),
              ),
              const SizedBox(height: 30),
              Text(
                "$_preparationCountdown",
                style: const TextStyle(
                  color: Colors.white, 
                  fontSize: 80, 
                  fontWeight: FontWeight.bold
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFlyingNumber() {
    return Text(
      _targetNumber,
      style: const TextStyle(
        color: Colors.white,
        fontSize: 60,
        fontWeight: FontWeight.bold,
        letterSpacing: 8,
        shadows: [
          Shadow(color: Colors.cyanAccent, blurRadius: 20),
        ],
      ),
    );
  }

  Widget _buildInputView() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          _statusMessage.isNotEmpty ? _statusMessage : "INGRESA EL CÓDIGO",
          style: TextStyle(
            color: _statusMessage.isNotEmpty ? _statusColor : Colors.white, 
            fontSize: 18, 
            fontWeight: FontWeight.bold, 
            letterSpacing: 1.5
          ),
        ),
        const SizedBox(height: 30),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(5, (index) {
            bool hasChar = _currentInput.length > index;
            return Container(
              width: 45,
              height: 60,
              margin: const EdgeInsets.symmetric(horizontal: 5),
              decoration: BoxDecoration(
                color: Colors.black38,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: hasChar ? AppTheme.primaryPurple : Colors.white24,
                  width: 2,
                ),
                boxShadow: hasChar ? [
                  BoxShadow(color: AppTheme.primaryPurple.withOpacity(0.3), blurRadius: 8)
                ] : [],
              ),
              child: Center(
                child: Text(
                  hasChar ? _currentInput[index] : "",
                  style: const TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.bold),
                ),
              ),
            );
          }),
        ),
      ],
    );
  }

  Widget _buildKeypad() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 40),
      child: Column(
        children: [
          _buildKeyRow(["1", "2", "3"]),
          const SizedBox(height: 10),
          _buildKeyRow(["4", "5", "6"]),
          const SizedBox(height: 10),
          _buildKeyRow(["7", "8", "9"]),
          const SizedBox(height: 10),
          Row(
            children: [
              const Spacer(flex: 1),
              _buildKey("0"),
              Expanded(
                flex: 1,
                child: IconButton(
                  onPressed: _onDelete,
                  icon: const Icon(Icons.backspace_outlined, color: Colors.white70),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildKeyRow(List<String> keys) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: keys.map((k) => _buildKey(k)).toList(),
    );
  }

  Widget _buildKey(String label) {
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 5),
        child: InkWell(
          onTap: () => _onKeyPress(label),
          borderRadius: BorderRadius.circular(10),
          child: Container(
            height: 50,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.white10),
            ),
            child: Center(
              child: Text(
                label,
                style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStatPill(IconData icon, String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 14),
          const SizedBox(width: 6),
          Text(text, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
        ],
      ),
    );
  }
}
