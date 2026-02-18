import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:sensors_plus/sensors_plus.dart';
import 'package:provider/provider.dart';
import '../../utils/minigame_logic_helper.dart';
import '../../models/clue.dart';
import '../../../auth/providers/player_provider.dart';
import '../../providers/game_provider.dart';
import '../../providers/connectivity_provider.dart';
import '../../../../core/theme/app_theme.dart';
import 'game_over_overlay.dart';
import '../../../mall/screens/mall_screen.dart';

class ChargeShakerMinigame extends StatefulWidget {
  final Clue clue;
  final VoidCallback onSuccess;

  const ChargeShakerMinigame({
    super.key,
    required this.clue,
    required this.onSuccess,
  });

  @override
  State<ChargeShakerMinigame> createState() => _ChargeShakerMinigameState();
}

class _ChargeShakerMinigameState extends State<ChargeShakerMinigame>
    with SingleTickerProviderStateMixin {
  // Game Configuration
  static const int _gameDurationSeconds = 10;
  static const double _chargeGoal = 100.0;
  static const double _shakeThreshold = 10.0; // Sensitivity for shake detection
  static const double _chargePerShake = 2.5; // Amount charged per valid shake
  static const double _decayRate = 0.2; // Charge lost per tick

  // State
  double _currentCharge = 0.0;
  int _secondsRemaining = _gameDurationSeconds;
  bool _isGameOver = false;

  // Shake Detection
  StreamSubscription<UserAccelerometerEvent>? _accelerometerSubscription;
  double _lastX = 0, _lastY = 0, _lastZ = 0;
  DateTime _lastShakeTime = DateTime.now();

  // Animation
  late AnimationController _pulseController;
  Timer? _gameTimer;
  Timer? _decayTimer;

  // Overlay State
  bool _showOverlay = false;
  String _overlayTitle = "";
  String _overlayMessage = "";
  bool _canRetry = false;
  bool _showShopButton = false;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..repeat(reverse: true);

    _startNewGame();
  }

  @override
  void dispose() {
    _accelerometerSubscription?.cancel();
    _gameTimer?.cancel();
    _decayTimer?.cancel();
    _pulseController.dispose();
    super.dispose();
  }

  void _startNewGame() {
    setState(() {
      _currentCharge = 0.0;
      _secondsRemaining = _gameDurationSeconds;
      _isGameOver = false;
      _showOverlay = false;
    });

    _startGameTimer();
    _startDecayTimer();
    _startListeningToSensors();
  }

  void _startGameTimer() {
    _gameTimer?.cancel();
    _gameTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
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
        _gameTimer?.cancel();
        _loseLife("¡Tiempo agotado! La batería no se cargó.");
      }
    });
  }

  void _startDecayTimer() {
    _decayTimer?.cancel();
    // Decay slightly faster than 1 second to feel smooth but pressure user
    _decayTimer = Timer.periodic(const Duration(milliseconds: 100), (timer) {
      if (!mounted || _isGameOver) return;

      // [FIX] Pause decay if connectivity is bad
      final connectivityByProvider =
          Provider.of<ConnectivityProvider>(context, listen: false);
      if (!connectivityByProvider.isOnline) {
        return; // Skip tick
      }

      setState(() {
        if (_currentCharge > 0) {
          _currentCharge = max(0.0, _currentCharge - _decayRate);
        }
      });
    });
  }

  void _startListeningToSensors() {
    _accelerometerSubscription?.cancel();
    // Use userAccelerometerEvents (excludes gravity) for better shake detection
    _accelerometerSubscription =
        userAccelerometerEvents.listen((UserAccelerometerEvent event) {
      if (_isGameOver) return;

      // [FIX] Ignore shakes if offline
      final connectivity =
          Provider.of<ConnectivityProvider>(context, listen: false);
      if (!connectivity.isOnline) return;

      // Simple shake detection
      // Calculate magnitude of acceleration vector
      // We use abs values sum as a rough approximation of "movement energy"
      double acceleration = event.x.abs() + event.y.abs() + event.z.abs();

      if (acceleration > _shakeThreshold) {
        final now = DateTime.now();
        // Debounce slightly to avoid counting one shake as multiple
        if (now.difference(_lastShakeTime).inMilliseconds > 100) {
          _lastShakeTime = now;
          _addCharge();
        }
      }
    });
  }

  void _addCharge() {
    if (_isGameOver) return;

    setState(() {
      _currentCharge = min(_chargeGoal, _currentCharge + _chargePerShake);
    });

    if (_currentCharge >= _chargeGoal) {
      _winGame();
    }
  }

  void _winGame() {
    _isGameOver = true;
    _gameTimer?.cancel();
    _decayTimer?.cancel();
    _accelerometerSubscription?.cancel();
    widget.onSuccess();
  }

  void _loseLife(String reason) async {
    _isGameOver = true;
    _gameTimer?.cancel();
    _decayTimer?.cancel();
    _accelerometerSubscription?.cancel();

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

  @override
  Widget build(BuildContext context) {
    final minutes = (_secondsRemaining / 60).floor().toString().padLeft(2, '0');
    final seconds = (_secondsRemaining % 60).toString().padLeft(2, '0');
    final isLowTime = _secondsRemaining <= 5;
    final chargePercent = _currentCharge / _chargeGoal;

    return PopScope(
      canPop: false,
      child: Stack(
        children: [
          // Main Game UI
          LayoutBuilder(builder: (context, constraints) {
            // Calculate available height to scale UI elements
            // We need to fit: Timer (~50px), Spacing, Battery (~250px), Spacing, Text (~80px)
            // If height is small, we scale down the battery.

            final availableHeight = constraints.maxHeight;
            final bool isSmallScreen = availableHeight < 500;

            // Scale battery based on available height, keeping aspect ratio roughly
            final double batteryHeight =
                isSmallScreen ? availableHeight * 0.4 : 250.0;
            final double batteryWidth =
                batteryHeight * 0.48; // Ratio 120/250 = 0.48

            return Center(
              child: SingleChildScrollView(
                // Safety net for very small screens
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  mainAxisSize: MainAxisSize.min, // Wrap content
                  children: [
                    // Timer
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 8),
                          decoration: BoxDecoration(
                            color: isLowTime
                                ? AppTheme.dangerRed.withOpacity(0.2)
                                : Colors.black45,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                                color: isLowTime
                                    ? AppTheme.dangerRed
                                    : AppTheme.accentGold),
                          ),
                          child: Row(
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
                      ],
                    ),

                    SizedBox(height: isSmallScreen ? 20 : 40),

                    // Battery Container
                    Stack(
                      alignment: Alignment.bottomCenter,
                      children: [
                        // Battery Outline
                        Container(
                          width: batteryWidth,
                          height: batteryHeight,
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.white, width: 4),
                            borderRadius: BorderRadius.circular(20),
                            color: Colors.black26,
                          ),
                          child: Column(
                            children: [
                              // Battery Nipple (Top)
                              Container(
                                width: batteryWidth * 0.33,
                                height: batteryHeight * 0.04,
                                decoration: const BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.vertical(
                                      top: Radius.circular(4)),
                                ),
                              ),
                            ],
                          ),
                        ),

                        // Filling Liquid
                        ClipRRect(
                          borderRadius: BorderRadius.circular(16),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            width: batteryWidth - 8, // padding
                            height: (batteryHeight - 20) *
                                chargePercent, // scale height based on charge
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: chargePercent < 0.3
                                    ? [Colors.red.shade900, Colors.red]
                                    : chargePercent < 0.7
                                        ? [
                                            Colors.orange.shade900,
                                            Colors.orange
                                          ]
                                        : [Colors.green.shade900, Colors.green],
                                begin: Alignment.bottomCenter,
                                end: Alignment.topCenter,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: chargePercent > 0.8
                                      ? Colors.green.withOpacity(0.5)
                                      : Colors.transparent,
                                  blurRadius: 20,
                                  spreadRadius: 5,
                                )
                              ],
                            ),
                          ),
                        ),

                        // Percentage Text
                        Positioned(
                          top: batteryHeight * 0.4,
                          child: Text(
                            "${(_currentCharge).toInt()}%",
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize:
                                  batteryHeight * 0.12, // Responsive font size
                              shadows: const [
                                Shadow(blurRadius: 5, color: Colors.black)
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),

                    SizedBox(height: isSmallScreen ? 20 : 40),

                    // Instructions
                    AnimatedBuilder(
                      animation: _pulseController,
                      builder: (context, child) {
                        return Transform.scale(
                          scale: 1.0 + (_pulseController.value * 0.05),
                          child: Column(
                            children: [
                              Icon(Icons.vibration,
                                  color: AppTheme.accentGold,
                                  size: isSmallScreen ? 30 : 40),
                              const SizedBox(height: 8),
                              Text(
                                "¡AGITA RÁPIDO!",
                                style: TextStyle(
                                  color: AppTheme.accentGold,
                                  fontSize: isSmallScreen ? 20 : 24,
                                  fontWeight: FontWeight.bold,
                                  shadows: [
                                    Shadow(
                                      color:
                                          AppTheme.accentGold.withOpacity(0.5),
                                      blurRadius: 10 * _pulseController.value,
                                    )
                                  ],
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),

                    const SizedBox(height: 20),

                    // Debug/Accessibility Button (Hidden in Prod usually, but good for testing on emulator)
                    // Only visible if running in debug mode or specific flag
                    if (false) // Set to true to test on emulator
                      ElevatedButton(
                        onPressed: _addCharge,
                        child: const Text("Simular Shake (Debug)"),
                      ),
                  ],
                ),
              ),
            );
          }),

          // Overlay
          if (_showOverlay)
            GameOverOverlay(
              title: _overlayTitle,
              message: _overlayMessage,
              onRetry: _canRetry
                  ? () {
                      _startNewGame();
                    }
                  : null,
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
