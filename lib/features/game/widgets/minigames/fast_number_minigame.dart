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
import '../../../mall/screens/mall_screen.dart';

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
  bool _isError = false; // Added missing member

  // Overlay State
  bool _showOverlay = false;
  String _overlayTitle = "";
  String _overlayMessage = "";
  bool _canRetry = false;
  bool _isVictory = false;
  bool _showShopButton = false;

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
    _preparationCountdown = 1; // Faster internal start
    _targetNumber = _generateRandomNumber(5);
    _currentInput = "";
    _statusMessage = "";
    
    _stateTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;
      if (_preparationCountdown > 1) {
        setState(() => _preparationCountdown--);
      } else {
        timer.cancel();
        // Clear countdown and wait 1 second silently
        setState(() => _preparationCountdown = 0);
        Future.delayed(const Duration(seconds: 1), () {
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

    return Stack(
      children: [
        Column(
          children: [
            const SizedBox(height: 10),
            
            // STATUS & PROGRESS
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text("ESTADO:", style: TextStyle(color: Colors.white54, fontSize: 10, letterSpacing: 1, decoration: TextDecoration.none)),
                      Text(
                        _state == GameState.showing 
                          ? "¡ATENTO AL NÚMERO!" 
                          : _state == GameState.inputting 
                            ? "INGRESA EL NÚMERO" 
                            : "PREPARANDO...", 
                        style: TextStyle(color: _statusColor, fontSize: 13, fontWeight: FontWeight.bold, decoration: TextDecoration.none)
                      ),
                    ],
                  ),
                  _buildStatusPill(Icons.speed, "CAPTURA VELOZ"),
                ],
              ),
            ),

            const SizedBox(height: 15),

            // FLYING AREA
            Expanded(
              flex: 3,
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 20),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.02),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.white10),
                ),
                child: ClipRect(
                  child: Stack(
                    children: [
                      Center(child: Text(_state == GameState.inputting ? "???" : "", style: TextStyle(color: Colors.white.withOpacity(0.05), fontSize: 80, fontWeight: FontWeight.bold, decoration: TextDecoration.none))),
                      if (_state == GameState.showing)
                        SlideTransition(
                          position: _flyAnimation,
                          child: Center(
                            child: Text(
                              _targetNumber,
                              style: const TextStyle(
                                color: AppTheme.accentGold,
                                fontSize: 80,
                                fontWeight: FontWeight.w900,
                                decoration: TextDecoration.none,
                                shadows: [Shadow(color: AppTheme.accentGold, blurRadius: 20)],
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),

            // INPUT AREA
            Expanded(
              flex: 4,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 20),
                child: Column(
                  children: [
                    // Display current input
                    Container(
                      height: 60,
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: Colors.black26,
                        borderRadius: BorderRadius.circular(15),
                        border: Border.all(color: _isError ? AppTheme.dangerRed : Colors.white24),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        _currentInput.isEmpty ? "----" : _currentInput,
                        style: TextStyle(
                          color: _isError ? AppTheme.dangerRed : Colors.white,
                          fontSize: 32,
                          letterSpacing: 10,
                          fontWeight: FontWeight.bold,
                          decoration: TextDecoration.none
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    // Keypad
                    Expanded(
                      child: GridView.builder(
                        physics: const NeverScrollableScrollPhysics(),
                        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 3,
                          childAspectRatio: 1.8,
                          crossAxisSpacing: 10,
                          mainAxisSpacing: 10,
                        ),
                        itemCount: 12,
                        itemBuilder: (context, index) {
                          if (index == 9) return _buildKey("C", Colors.white38, _clearInput);
                          if (index == 10) return _buildKey("0", Colors.white, () => _handleKeyPress("0"));
                          if (index == 11) return _buildKey("OK", AppTheme.successGreen, _submitInput);
                          
                          String key = (index + 1).toString();
                          return _buildKey(key, Colors.white, () => _handleKeyPress(key));
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),

        if (_showOverlay)
          GameOverOverlay(
            title: _overlayTitle,
            message: _overlayMessage,
            isVictory: _isVictory,
            onRetry: _canRetry ? _resetGame : null,
            onGoToShop: _showShopButton ? () async {
              await Navigator.push(context, MaterialPageRoute(builder: (_) => const MallScreen()));
              if (mounted) {
                setState(() {
                  _canRetry = true;
                  _showShopButton = false;
                });
              }
            } : null,
            onExit: () => Navigator.pop(context),
          ),
      ],
    );
  }

  Widget _buildStatusPill(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: AppTheme.accentGold.withOpacity(0.1),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: AppTheme.accentGold.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: AppTheme.accentGold, size: 12),
          const SizedBox(width: 5),
          Text(label, style: const TextStyle(color: AppTheme.accentGold, fontSize: 9, fontWeight: FontWeight.bold, decoration: TextDecoration.none)),
        ],
      ),
    );
  }

  Widget _buildKey(String label, Color color, VoidCallback onTap) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        onTap();
      },
      child: Container(
        decoration: BoxDecoration(
          color: color.withOpacity(0.05),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withOpacity(0.2)),
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: TextStyle(color: color, fontSize: 18, fontWeight: FontWeight.bold, decoration: TextDecoration.none),
        ),
      ),
    );
  }

  void _handleKeyPress(String key) => _onKeyPress(key);
  void _clearInput() => _onDelete();
  void _submitInput() => _checkInput();

  void _resetGame() {
    setState(() {
      _showOverlay = false;
      _isGameOver = false;
      _secondsRemaining = 45;
      _currentInput = "";
      _startPreparation();
    });
  }
}
