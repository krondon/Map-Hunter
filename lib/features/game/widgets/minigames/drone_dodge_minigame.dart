import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
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

class DroneObstacle {
  final String id;
  double x; // 0.0 to 1.0
  double y; // 0.0 to 1.0
  final double speed;
  final double widthRatio; // Width as % of screen width

  DroneObstacle({
    required this.id,
    required this.x,
    this.y = -0.2,
    required this.speed,
    this.widthRatio = 0.15,
  });
}

class DroneDodgeMinigame extends StatefulWidget {
  final Clue clue;
  final VoidCallback onSuccess;

  const DroneDodgeMinigame({
    super.key,
    required this.clue,
    required this.onSuccess,
  });

  @override
  State<DroneDodgeMinigame> createState() => _DroneDodgeMinigameState();
}

class _DroneDodgeMinigameState extends State<DroneDodgeMinigame> {
  // Config
  static const int _gameDurationSeconds = 30; // Requested 30s
  double _playerX = 0.5; // Center
  static const double _playerWidthRatio = 0.15;
  static const double _playerHeightRatio = 0.08;

  // Dynamic Difficulty
  double _spawnRateMs = 1200;
  double _obstacleSpeed = 0.006;

  // State
  int _secondsRemaining = _gameDurationSeconds;
  bool _isGameOver = false;

  // Overlay
  bool _showOverlay = false;
  String _overlayTitle = "";
  String _overlayMessage = "";
  bool _canRetry = false;
  bool _showShopButton = false;

  Timer? _gameTimer;
  Timer? _loopTimer;
  Timer? _spawnTimer;

  final List<DroneObstacle> _obstacles = [];
  final Random _random = Random();

  @override
  void initState() {
    super.initState();
    _startGame();
  }

  void _startGame() {
    _secondsRemaining = _gameDurationSeconds;
    _obstacles.clear();
    _playerX = 0.5;
    _spawnRateMs = 1000;
    _obstacleSpeed = 0.007; // Start moderate
    _isGameOver = false;
    _showOverlay = false;

    _startTimers();
  }

  void _startTimers() {
    _gameTimer?.cancel();
    _gameTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted || _isGameOver) {
        timer.cancel();
        return;
      }
      setState(() {
        // [FIX] Pause timer if connectivity is bad OR if game is frozen (sabotage)
        final gameProvider = Provider.of<GameProvider>(context, listen: false);
        final connectivityByProvider =
            Provider.of<ConnectivityProvider>(context, listen: false);
        if (!connectivityByProvider.isOnline || gameProvider.isFrozen) {
          return; // Skip tick
        }

        if (_secondsRemaining > 0) {
          _secondsRemaining--;

          // Difficulty Logic
          if (_secondsRemaining == 15) {
            // Major difficulty spike at 15 seconds
            _spawnRateMs = 600; // Much faster spawns
            _obstacleSpeed = 0.012; // Much faster falling
            _rescheduleSpawn();

            // Visual hint of speed up
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                  content: Text("¡VELOCIDAD AUMENTADA!"),
                  backgroundColor: Colors.orange,
                  duration: Duration(milliseconds: 1000)),
            );
          } else if (_secondsRemaining > 15 && _secondsRemaining % 5 == 0) {
            // Mild ramp up before 15s
            _spawnRateMs = max(800, _spawnRateMs - 50);
            _obstacleSpeed += 0.0005;
          }
        } else {
          _endGame(win: true);
        }
      });
    });

    _loopTimer?.cancel();
    _loopTimer = Timer.periodic(const Duration(milliseconds: 16), (timer) {
      if (!mounted || _isGameOver) {
        timer.cancel();
        return;
      }

      // [FIX] Pause game loop if offline OR if game is frozen (sabotage)
      final gameProvider = Provider.of<GameProvider>(context, listen: false);
      final connectivity =
          Provider.of<ConnectivityProvider>(context, listen: false);
      if (!connectivity.isOnline || gameProvider.isFrozen) return;

      _updateGameLoop();
    });

    _rescheduleSpawn();
  }

  void _rescheduleSpawn() {
    _spawnTimer?.cancel();
    _spawnTimer = Timer(Duration(milliseconds: _spawnRateMs.toInt()), () {
      if (mounted && !_isGameOver) {
        // [FIX] Pause spawning if offline OR if game is frozen (sabotage)
        final gameProvider = Provider.of<GameProvider>(context, listen: false);
        final connectivity =
            Provider.of<ConnectivityProvider>(context, listen: false);
        if (connectivity.isOnline && !gameProvider.isFrozen) {
          _spawnObstacle();
        }
        _rescheduleSpawn();
      }
    });
  }

  void _spawnObstacle() {
    final obstacle = DroneObstacle(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      x: _random.nextDouble() * 0.8 + 0.1, // 10% to 90%
      speed: _obstacleSpeed * (_random.nextDouble() * 0.4 + 0.8),
      widthRatio: _random.nextDouble() * 0.1 + 0.1, // 10% to 20% width
    );
    setState(() {
      _obstacles.add(obstacle);
    });
  }

  void _updateGameLoop() {
    setState(() {
      // Move Obstacles
      for (var obs in _obstacles) {
        obs.y += obs.speed;
      }
      // Remove off-screen
      _obstacles.removeWhere((obs) => obs.y > 1.1);

      // Collision Detection
      _checkCollisions();
    });
  }

  void _checkCollisions() {
    // Player Y range: 0.82 to 0.92 (approx based on icon size and positioning)
    const double playerTop = 0.82;
    const double playerBottom = 0.92;
    final double playerLeft = _playerX - (_playerWidthRatio / 2);
    final double playerRight = _playerX + (_playerWidthRatio / 2);

    for (var obs in _obstacles) {
      // Obstacle Rect
      const double obsHeight = 0.05;
      final double obsTop = obs.y;
      final double obsBottom = obs.y + obsHeight;
      final double obsLeft = obs.x - (obs.widthRatio / 2);
      final double obsRight = obs.x + (obs.widthRatio / 2);

      bool overlapY = playerTop < obsBottom && playerBottom > obsTop;
      bool overlapX = playerLeft < obsRight && playerRight > obsLeft;

      if (overlapX && overlapY) {
        _handleCollision();
        break; // Handle one collision per frame max
      }
    }
  }

  Future<void> _handleCollision() async {
    // Pause temporarily
    _gameTimer?.cancel();
    _loopTimer?.cancel();
    _spawnTimer?.cancel();

    final playerProvider = Provider.of<PlayerProvider>(context, listen: false);
    if (playerProvider.currentPlayer != null) {
      // 1. Lose Life
      final newLives = await MinigameLogicHelper.executeLoseLife(context);

      if (!mounted) return;

      // 2. Check Game Over
      if (newLives <= 0) {
        _endGame(
            win: false, reason: "¡Te estrellaste! Sin vidas.", lives: newLives);
      } else {
        // 3. Reset & Continue
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text("¡CRASH! -1 Vida. Tiempo reiniciado."),
              backgroundColor: AppTheme.dangerRed,
              duration: Duration(milliseconds: 1000)),
        );

        setState(() {
          // Reset Time
          _secondsRemaining = _gameDurationSeconds;

          // Clear field
          _obstacles.clear();

          // Reset Difficulty
          _spawnRateMs = 1000;
          _obstacleSpeed = 0.007;
        });

        // Delay restart slightly
        Future.delayed(const Duration(milliseconds: 1000), () {
          if (mounted && !_isGameOver) {
            _startTimers();
          }
        });
      }
    }
  }

  void _endGame({required bool win, String? reason, int? lives}) {
    _gameTimer?.cancel();
    _loopTimer?.cancel();
    _spawnTimer?.cancel();

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
    _loopTimer?.cancel();
    _spawnTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final height = constraints.maxHeight;

        return GestureDetector(
          onPanUpdate: (details) {
            if (_isGameOver) return;
            // [FIX] Block movement if offline
            if (!Provider.of<ConnectivityProvider>(context, listen: false)
                .isOnline) return;

            setState(() {
              _playerX += details.delta.dx / width;
              _playerX = _playerX.clamp(0.1, 0.9);
            });
          },
          child: Container(
            color: Colors.transparent, // Capture taps
            child: Stack(
              children: [
                // Obstacles
                ..._obstacles.map((obs) {
                  return Positioned(
                    left: (obs.x - obs.widthRatio / 2) * width,
                    top: obs.y * height,
                    width: obs.widthRatio * width,
                    height: height * 0.07, // slightly taller
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            Colors.red.shade900,
                            Colors.redAccent,
                            Colors.orangeAccent,
                          ],
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                        ),
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.red.withOpacity(0.6),
                            blurRadius: 10,
                            spreadRadius: 2,
                          ),
                        ],
                        border: Border.all(
                          color: Colors.white.withOpacity(0.3),
                          width: 1,
                        ),
                      ),
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          Icon(
                            Icons
                                .vaping_rooms_rounded, // Looks like a drone/engine
                            color: Colors.white.withOpacity(0.3),
                            size: height * 0.05,
                          ),
                          Icon(
                            Icons.adb_rounded, // Cyber bug/drone
                            color: Colors.yellowAccent,
                            size: height * 0.035,
                          ),
                        ],
                      ),
                    ),
                  );
                }),

                // Player Spaceship (formerly Drone)
                Positioned(
                  left: (_playerX - _playerWidthRatio / 2) * width,
                  bottom: height * 0.08,
                  width: _playerWidthRatio * width,
                  height: height * _playerHeightRatio,
                  child: Container(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.cyanAccent.withOpacity(0.5),
                          blurRadius: 20,
                          spreadRadius: 5,
                        ),
                      ],
                    ),
                    child: Center(
                      child: Transform.rotate(
                        angle:
                            0, // Icons.rocket points Up by default in newer Flutter versions or use a specific one
                        child: Icon(
                          Icons.rocket_launch_rounded,
                          color: Colors.white,
                          size: height * 0.06,
                          shadows: const [
                            Shadow(
                              color: Colors.cyanAccent,
                              blurRadius: 10,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),

                // Header
                Positioned(
                  top: 10,
                  left: 10,
                  right: 10,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _buildInfoBadge(
                          Icons.timer,
                          "$_secondsRemaining s",
                          _secondsRemaining <= 10
                              ? AppTheme.dangerRed
                              : Colors.white),
                      const Text("SOBREVIVE",
                          style: TextStyle(
                              fontWeight: FontWeight.bold,
                              letterSpacing: 2,
                              color: Colors.white54)),
                    ],
                  ),
                ),

                // Game Over Overlay
                if (_showOverlay)
                  GameOverOverlay(
                    title: _overlayTitle,
                    message: _overlayMessage,
                    onRetry: _canRetry ? _resetGame : null,
                    onGoToShop: _showShopButton
                        ? () async {
                            await Navigator.push(
                                context,
                                MaterialPageRoute(
                                    builder: (_) => const MallScreen()));
                            if (mounted) {
                              final player = Provider.of<PlayerProvider>(
                                      context,
                                      listen: false)
                                  .currentPlayer;
                              if ((player?.lives ?? 0) > 0) _resetGame();
                            }
                          }
                        : null,
                    onExit: () => Navigator.pop(context),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildInfoBadge(IconData icon, String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.black45,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 8),
          Text(text,
              style: TextStyle(
                  color: color, fontWeight: FontWeight.bold, fontSize: 18)),
        ],
      ),
    );
  }
}
