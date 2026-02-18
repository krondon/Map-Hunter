import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../utils/minigame_logic_helper.dart';
import '../../models/clue.dart';
import '../../../auth/providers/player_provider.dart';
import '../../providers/game_provider.dart';
import '../../providers/connectivity_provider.dart';
import '../../../../core/theme/app_theme.dart';
import 'game_over_overlay.dart';
import '../../../mall/screens/mall_screen.dart';

class FindDifferenceMinigame extends StatefulWidget {
  final Clue clue;
  final VoidCallback onSuccess;

  const FindDifferenceMinigame({
    super.key,
    required this.clue,
    required this.onSuccess,
  });

  @override
  State<FindDifferenceMinigame> createState() => _FindDifferenceMinigameState();
}

class _FindDifferenceMinigameState extends State<FindDifferenceMinigame> {
  final Random _random = Random();

  // Game Logic
  late List<_DistractorItem> _distractors;
  late IconData _targetIcon;
  late Offset _targetPosition;
  late bool _targetInTopImage;

  // State
  Timer? _timer;
  int _secondsRemaining = 40;
  bool _isGameOver = false;
  int _localAttempts = 3;

  // Overlay State
  bool _showOverlay = false;
  String _overlayTitle = "";
  String _overlayMessage = "";
  bool _canRetry = false;
  bool _showShopButton = false;

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
  void initState() {
    super.initState();
    _generateGame();
    _startTimer();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _generateGame() {
    final icons = [
      Icons.star_outline,
      Icons.ac_unit,
      Icons.wb_sunny_outlined,
      Icons.pets_outlined,
      Icons.favorite_outline,
      Icons.flash_on_outlined,
      Icons.filter_vintage_outlined,
      Icons.camera_outlined,
      Icons.brush_outlined,
      Icons.anchor_outlined,
      Icons.eco_outlined,
      Icons.lightbulb_outline,
      Icons.extension_outlined,
    ];

    // Pick 30 random distractors to populate the field
    icons.shuffle();
    _distractors = List.generate(30, (index) {
      return _DistractorItem(
        icon: icons[index % icons.length],
        position: Offset(0.05 + _random.nextDouble() * 0.9,
            0.05 + _random.nextDouble() * 0.9),
        rotation: _random.nextDouble() * pi * 2,
        size: 15.0 + _random.nextDouble() * 10,
      );
    });

    // Pick a random target icon that looks like the distractors
    _targetIcon = icons[_random.nextInt(icons.length)];
    _targetPosition = Offset(
        0.1 + _random.nextDouble() * 0.8, 0.1 + _random.nextDouble() * 0.8);
    _targetInTopImage = _random.nextBool();

    setState(() {});
  }

  void _startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;

      // Check for freeze state
      final gameProvider = Provider.of<GameProvider>(context, listen: false);
      if (gameProvider.isFrozen) return; // Pause timer

      if (gameProvider.isFrozen) return; // Pause timer

      // [FIX] Pause timer if connectivity is bad
      final connectivityByProvider =
          Provider.of<ConnectivityProvider>(context, listen: false);
      if (!connectivityByProvider.isOnline) {
        return; // Skip tick
      }

      if (_secondsRemaining > 0) {
        setState(() => _secondsRemaining--);
      } else {
        _handleFailure("Tiempo agotado");
      }
    });
  }

  // Feedback State
  Offset? _foundPosition; // Stores the relative position of the found target
  bool _foundInTop = false;

  void _handleTap(bool isTop, TapDownDetails? details, double panelWidth,
      double panelHeight) {
    if (_isGameOver) return;

    final gameProvider = Provider.of<GameProvider>(context, listen: false);
    if (gameProvider.isFrozen) return; // Ignore input if frozen

    // [FIX] Prevent interaction if offline
    final connectivity =
        Provider.of<ConnectivityProvider>(context, listen: false);
    if (!connectivity.isOnline) return;

    // 1. Check if we are in the correct panel
    if (isTop == _targetInTopImage) {
      // 2. Exact Hit Detection
      if (details != null) {
        // Re-calculate target position in pixels exactly as rendered
        final double renderWidth = MediaQuery.of(context).size.width - 80;
        final double renderHeight = panelHeight;

        final double targetX = _targetPosition.dx * renderWidth;
        final double targetY = _targetPosition.dy * renderHeight;

        // Icon is size 22 roughly. Center is +11.
        final double centerX = targetX + 11;
        final double centerY = targetY + 11;

        final double tapX = details.localPosition.dx;
        final double tapY = details.localPosition.dy;

        // Euclidean distance
        final double dist =
            sqrt(pow(tapX - centerX, 2) + pow(tapY - centerY, 2));

        // Threshold: 28px radius
        if (dist < 28.0) {
          _winGame(Offset(targetX, targetY), isTop);
          return;
        }
      }
    }

    // If we reached here, it's a miss
    _handleMiss();
  }

  void _winGame(Offset pixelPosition, bool isTop) {
    _timer?.cancel();
    _isGameOver = true;

    // Show visual feedback
    setState(() {
      _foundPosition = pixelPosition;
      _foundInTop = isTop;
    });

    // Wait so user sees the box
    Future.delayed(const Duration(milliseconds: 1500), () {
      if (mounted) widget.onSuccess();
    });
  }

  // ... (existing _handleMiss, _handleFailure methods) ...
  void _handleMiss() {
    if (_isGameOver) return;
    setState(() {
      _localAttempts--;
    });
    // Shake or visual feedback could go here
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text("¡Fallaste! Sigue buscando."),
        duration: Duration(milliseconds: 500),
        backgroundColor: Colors.redAccent));

    if (_localAttempts <= 0) {
      _handleFailure("Demasiados errores");
    }
  }

  void _handleFailure(String reason) async {
    _timer?.cancel();
    _isGameOver = true;

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
    return PopScope(
      canPop: false,
      onPopInvoked: (didPop) {},
      child: Stack(
        children: [
          // GAME CONTENT
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
            child: Column(
              children: [
                // Header Minimalista
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text("ANOMALÍA DETECTADA",
                              style: TextStyle(
                                  color: Colors.white38,
                                  fontSize: 10,
                                  letterSpacing: 2,
                                  fontWeight: FontWeight.bold)),
                          Text(
                            "Encuentra el icono que sobra y toca ese cuadro",
                            style: TextStyle(
                                color: Colors.white.withOpacity(0.7),
                                fontSize: 11),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 10),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: Colors.white10),
                      ),
                      child: Text(
                        "00:$_secondsRemaining",
                        style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontFamily: 'monospace'),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 30),

                // Paneles compactos
                Expanded(
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      return Column(
                        children: [
                          _buildCompactPanel(
                              isTop: true,
                              maxHeight: constraints.maxHeight * 0.45),
                          const SizedBox(height: 16),
                          _buildCompactPanel(
                              isTop: false,
                              maxHeight: constraints.maxHeight * 0.45),
                        ],
                      );
                    },
                  ),
                ),

                const SizedBox(height: 20),

                // Intentos sutiles
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(
                      3,
                      (index) => Container(
                            margin: const EdgeInsets.symmetric(horizontal: 4),
                            width: 8,
                            height: 8,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: index < _localAttempts
                                  ? AppTheme.accentGold
                                  : Colors.white10,
                            ),
                          )),
                ),
              ],
            ),
          ),

          // OVERLAY
          if (_showOverlay)
            GameOverOverlay(
              title: _overlayTitle,
              message: _overlayMessage,
              onRetry: _canRetry
                  ? () {
                      setState(() {
                        _showOverlay = false;
                        _secondsRemaining = 40;
                        _localAttempts = 3;
                        _isGameOver = false;
                        _foundPosition = null; // Reset found state
                        _generateGame();
                        _startTimer();
                      });
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

  Widget _buildCompactPanel({required bool isTop, required double maxHeight}) {
    bool hasTarget = isTop == _targetInTopImage;
    bool showHighlight = _foundPosition != null && _foundInTop == isTop;

    return Expanded(
      child: GestureDetector(
        onTapDown: (details) => _handleTap(
            isTop, details, MediaQuery.of(context).size.width, maxHeight),
        // Pass generic width, logic handles the -80 inside
        child: Container(
          width: double.infinity,
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.03),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
                color: hasTarget
                    ? AppTheme.neonGreen.withOpacity(0.8)
                    : Colors.white
                        .withOpacity(0.05), // Highlight target block always
                width: hasTarget ? 2 : 1),
          ),
          child: Stack(
            children: [
              // Distractors
              ..._distractors.map((d) => Positioned(
                    left: d.position.dx *
                        (MediaQuery.of(context).size.width - 80),
                    top: d.position.dy * maxHeight,
                    child: Opacity(
                      opacity: 0.3,
                      child: Transform.rotate(
                        angle: d.rotation,
                        child: Icon(d.icon, color: Colors.white, size: d.size),
                      ),
                    ),
                  )),

              // Target (Now visually identical to distractors)
              if (hasTarget)
                Positioned(
                  left: _targetPosition.dx *
                      (MediaQuery.of(context).size.width - 80),
                  top: _targetPosition.dy * maxHeight,
                  child: Opacity(
                    opacity: 0.3,
                    child: Icon(_targetIcon, color: Colors.white, size: 22),
                  ),
                ),

              // HIGHLIGHT BOX (Success Feedback)
              if (showHighlight && _foundPosition != null)
                Positioned(
                  left: _foundPosition!.dx -
                      9, // Centered over 22px icon (40-22)/2 = 9
                  top: _foundPosition!.dy - 9,
                  child: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                        color:
                            AppTheme.neonGreen.withOpacity(0.5), // More visible
                        border: Border.all(
                            color: AppTheme.neonGreen, width: 3), // Thicker
                        borderRadius: BorderRadius.circular(8),
                        boxShadow: [
                          BoxShadow(
                              color: AppTheme.neonGreen.withOpacity(0.6),
                              blurRadius: 15,
                              spreadRadius: 2)
                        ]),
                    child: const Icon(Icons.check,
                        color: Colors.white, size: 24), // Added check icon
                  ),
                ),

              // Label sutil
              Positioned(
                top: 12,
                left: 12,
                child: Text(
                  isTop ? "A" : "B",
                  style: const TextStyle(
                      color: Colors.white10,
                      fontWeight: FontWeight.bold,
                      fontSize: 10),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DistractorItem {
  final IconData icon;
  final Offset position;
  final double rotation;
  final double size;

  _DistractorItem({
    required this.icon,
    required this.position,
    required this.rotation,
    required this.size,
  });
}
