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

enum VirusItemType { virus, trap }

class GameItem {
  final String id;
  final VirusItemType type;
  double x; // 0.0 to 1.0 (relative width)
  double y; // 0.0 to 1.0 (relative height)
  final double speed; // relative height per tick

  GameItem({
    required this.id,
    required this.type,
    required this.x,
    this.y = -0.1, // Start slightly above
    required this.speed,
  });
}

class VirusTapMinigame extends StatefulWidget {
  final Clue clue;
  final VoidCallback onSuccess;

  const VirusTapMinigame({
    super.key,
    required this.clue,
    required this.onSuccess,
  });

  @override
  State<VirusTapMinigame> createState() => _VirusTapMinigameState();
}

class _VirusTapMinigameState extends State<VirusTapMinigame> {
  // Game Config
  static const int _gameDurationSeconds = 20;
  static const int _winScore = 15;

  // Dynamic Config (Increases with time)
  double _spawnRateMs = 800;
  double _baseSpeed = 0.005;

  // State
  int _score = 0;
  int _secondsRemaining = _gameDurationSeconds;
  bool _isGameOver = false;

  // Overlay State (Local)
  bool _showOverlay = false;
  String _overlayTitle = "";
  String _overlayMessage = "";
  bool _canRetry = false;
  bool _showShopButton = false;

  Timer? _gameTimer; // Main countdown
  Timer? _loopTimer; // Animation loop
  Timer? _spawnTimer; // Spawn loop

  final List<GameItem> _items = [];
  final Random _random = Random();

  @override
  void initState() {
    super.initState();
    _startGame();
  }

  void _startGame() {
    _score = 0;
    _secondsRemaining = _gameDurationSeconds;
    _items.clear();
    _spawnRateMs = 700;
    _baseSpeed = 0.008; // ~0.8% height per 16ms
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
        // [FIX] Pause timer if connectivity is bad
        final connectivityByProvider =
            Provider.of<ConnectivityProvider>(context, listen: false);
        if (!connectivityByProvider.isOnline) {
          return; // Skip tick
        }

        if (_secondsRemaining > 0) {
          _secondsRemaining--;
          // Difficulty Ramp Up
          if (_secondsRemaining % 5 == 0) {
            _spawnRateMs = max(300, _spawnRateMs - 100);
            _baseSpeed += 0.001;
            _rescheduleSpawn();
          }
        } else {
          _endGame(win: false, reason: "¡Tiempo agotado!");
        }
      });
    });

    _loopTimer?.cancel();
    _loopTimer = Timer.periodic(const Duration(milliseconds: 16), (timer) {
      if (!mounted || _isGameOver) {
        timer.cancel();
        return;
      }
      // [FIX] Pause game loop if connectivity is bad
      final connectivityByProvider =
          Provider.of<ConnectivityProvider>(context, listen: false);
      if (!connectivityByProvider.isOnline) {
        return; // Skip tick
      }

      _updateGameLoop();
    });

    _rescheduleSpawn();
  }

  void _rescheduleSpawn() {
    _spawnTimer?.cancel();
    _spawnTimer = Timer(Duration(milliseconds: _spawnRateMs.toInt()), () {
      if (mounted && !_isGameOver) {
        _spawnItem();
        _rescheduleSpawn();
      }
    });
  }

  void _spawnItem() {
    // 70% Virus, 30% Bomb
    final isTrap = _random.nextDouble() < 0.30;
    final item = GameItem(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      type: isTrap ? VirusItemType.trap : VirusItemType.virus,
      x: _random.nextDouble() * 0.8 + 0.1, // Keep within 10%-90% width
      speed: _baseSpeed * (_random.nextDouble() * 0.4 + 0.8), // Variance
    );
    setState(() {
      _items.add(item);
    });
  }

  void _updateGameLoop() {
    setState(() {
      // Move items
      for (var item in _items) {
        item.y += item.speed;
      }
      // Remove off-screen
      _items.removeWhere((item) => item.y > 1.1);
    });
  }

  Future<void> _handleTap(GameItem item) async {
    if (_isGameOver) return;

    // [FIX] Prevent interaction if offline
    final connectivity =
        Provider.of<ConnectivityProvider>(context, listen: false);
    if (!connectivity.isOnline) return;

    if (item.type == VirusItemType.virus) {
      // Good tap
      setState(() {
        _score++;
        _items.remove(item);
      });
      if (_score >= _winScore) {
        _endGame(win: true);
      }
    } else {
      // Trap tap!
      setState(() {
        // Visual feedback?
        _items.remove(item);
      });
      await _loseLife("¡Explotó una bomba! 💥");
    }
  }

  Future<void> _loseLife(String reason) async {
    // Pause everything
    _gameTimer?.cancel();
    _loopTimer?.cancel();
    _spawnTimer?.cancel();

    final playerProvider = Provider.of<PlayerProvider>(context, listen: false);
    if (playerProvider.currentPlayer != null) {
      final newLives = await MinigameLogicHelper.executeLoseLife(context);

      if (!mounted) return;

      if (newLives <= 0) {
        _endGame(win: false, reason: "Sin vidas. $reason");
      } else {
        // Resume
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(reason),
              backgroundColor: AppTheme.dangerRed,
              duration: const Duration(milliseconds: 800)),
        );
        // Wait a bit before resuming
        Future.delayed(const Duration(milliseconds: 1000), () {
          if (mounted && !_isGameOver) _startTimers();
        });
      }
    }
  }

  void _endGame({required bool win, String? reason}) {
    _gameTimer?.cancel();
    _loopTimer?.cancel();
    _spawnTimer?.cancel();

    setState(() {
      _isGameOver = true;
    });

    if (win) {
      widget.onSuccess();
    } else {
      final player =
          Provider.of<PlayerProvider>(context, listen: false).currentPlayer;
      final lives = player?.lives ?? 0;

      setState(() {
        _showOverlay = true;
        _overlayTitle = "GAME OVER";
        _overlayMessage = reason ?? "Perdiste";
        _canRetry = lives > 0; // Only allow retry if lives remain
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
    // LayoutBuilder to get dimensions for positioning
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final height = constraints.maxHeight;

        return Stack(
          children: [
            // Floating Items
            ..._items.map((item) {
              return Positioned(
                left: item.x * (width - 60), // Adjust for item size
                top: item.y * height,
                child: GestureDetector(
                  onTap: () => _handleTap(item),
                  child: Container(
                    width: 60,
                    height: 60,
                    alignment: Alignment.center,
                    child: item.type == VirusItemType.virus
                        ? const Icon(Icons.bug_report,
                            color: Color(0xFF00FF00), size: 45) // Neon Green
                        : const BombWidget(),
                  ),
                ),
              );
            }),

            // Header (Overlay)
            Positioned(
              top: 10,
              left: 10,
              right: 10,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _buildInfoBadge(
                      Icons.timer,
                      "$_secondsRemaining",
                      _secondsRemaining <= 5
                          ? AppTheme.dangerRed
                          : AppTheme.accentGold),
                  Column(
                    children: [
                      Text("META: $_winScore",
                          style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.white54)),
                      const SizedBox(height: 4),
                      const Text("¡Evita las bombas!",
                          style:
                              TextStyle(color: Colors.white30, fontSize: 10)),
                    ],
                  ),
                  _buildInfoBadge(
                      Icons.bug_report, "$_score", Colors.cyanAccent),
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
                          final player = Provider.of<PlayerProvider>(context,
                                  listen: false)
                              .currentPlayer;
                          if ((player?.lives ?? 0) > 0) _resetGame();
                        }
                      }
                    : null,
                onExit: () => Navigator.pop(context),
              ),
          ],
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
              style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 18)),
        ],
      ),
    );
  }
}

class BombWidget extends StatelessWidget {
  const BombWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: Alignment.center,
      children: [
        // Bomb Body
        const Icon(Icons.circle, color: Colors.black, size: 40),
        // Shine
        Positioned(
          top: 15,
          left: 15,
          child: Container(
            width: 8,
            height: 8,
            decoration: const BoxDecoration(
              color: Colors.white24,
              shape: BoxShape.circle,
            ),
          ),
        ),
        // Fuse
        Positioned(
          top: 5,
          right: 12,
          child: Transform.rotate(
            angle: 0.5,
            child: Container(
              width: 4,
              height: 12,
              color: Colors.brown[700],
            ),
          ),
        ),
        // Spark
        Positioned(
          top: 0,
          right: 8,
          child: const Icon(Icons.star, color: Colors.orangeAccent, size: 14),
        ),
      ],
    );
  }
}
