import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../models/clue.dart';
import '../../../auth/providers/player_provider.dart';
import '../../providers/game_provider.dart';
import '../../providers/connectivity_provider.dart';
import '../../../../core/theme/app_theme.dart';
import 'game_over_overlay.dart';
import '../race_track_widget.dart';
import '../../utils/minigame_logic_helper.dart';
import '../../../../shared/widgets/animated_cyber_background.dart';
import '../../../mall/screens/mall_screen.dart';

class BagShuffleMinigame extends StatefulWidget {
  final Clue clue;
  final VoidCallback onSuccess;

  const BagShuffleMinigame({
    super.key,
    required this.clue,
    required this.onSuccess,
  });

  @override
  State<BagShuffleMinigame> createState() => _BagShuffleMinigameState();
}

enum GameState { idle, showing, shuffling, guessing, reveal, finished }

class BagModel {
  int id;
  Color ballColor;
  int currentPosition; // 0, 1, 2

  BagModel(
      {required this.id,
      required this.ballColor,
      required this.currentPosition});
}

class _BagShuffleMinigameState extends State<BagShuffleMinigame>
    with TickerProviderStateMixin {
  GameState _state = GameState.idle;
  late List<BagModel> _bags;
  late Color _targetColor;
  int _shufflesDone = 0;
  final int _totalShuffles = 15;

  // Animation controllers
  late AnimationController _shuffleController;

  // Stats
  late Timer _gameTimer;
  int _secondsRemaining = 60;
  bool _isGameOver = false;

  // Overlay State
  bool _showOverlay = false;
  String _overlayTitle = "";
  String _overlayMessage = "";
  bool _canRetry = false;
  bool _isVictory = false;
  bool _showShopButton = false; // Added missing member

  @override
  void initState() {
    super.initState();
    _bags = [
      BagModel(id: 0, ballColor: Colors.red, currentPosition: 0),
      BagModel(id: 1, ballColor: Colors.green, currentPosition: 1),
      BagModel(id: 2, ballColor: Colors.blue, currentPosition: 2),
    ];

    _shuffleController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );

    _startGameTimer();
    _startRound();
  }

  @override
  void dispose() {
    _shuffleController.dispose();
    _gameTimer.cancel();
    super.dispose();
  }

  void _startGameTimer() {
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
        _handleTimeOut();
      }
    });
  }

  void _handleTimeOut() {
    _gameTimer.cancel();
    _loseLife("¡Tiempo agotado!");
  }

  void _startRound() async {
    setState(() {
      _state = GameState.showing;
      _shufflesDone = 0;
      // Reset positions
      for (int i = 0; i < _bags.length; i++) {
        _bags[i].currentPosition = i;
      }
      // Randomize target
      _targetColor =
          [Colors.red, Colors.green, Colors.blue][Random().nextInt(3)];
    });

    // Slow down the memorization phase to 3 seconds
    await Future.delayed(const Duration(milliseconds: 3000));
    if (!mounted) return;

    _startShuffling();
  }

  void _startShuffling() async {
    setState(() => _state = GameState.shuffling);

    // Wait for the bags to slowly cover the balls (entry animation)
    await Future.delayed(const Duration(milliseconds: 1500));
    if (!mounted) return;

    for (int i = 0; i < _totalShuffles; i++) {
      if (!mounted || _isGameOver) return;

      int idx1 = Random().nextInt(3);
      int idx2;
      do {
        idx2 = Random().nextInt(3);
      } while (idx1 == idx2);

      await _performSwap(idx1, idx2);
      _shufflesDone++;
    }

    if (mounted) {
      setState(() => _state = GameState.guessing);
    }
  }

  Future<void> _performSwap(int pos1, int pos2) async {
    BagModel? bag1 = _bags.firstWhere((b) => b.currentPosition == pos1);
    BagModel? bag2 = _bags.firstWhere((b) => b.currentPosition == pos2);

    setState(() {
      bag1.currentPosition = pos2;
      bag2.currentPosition = pos1;
    });

    HapticFeedback.lightImpact();
    // Swapping takes longer now (700ms)
    await Future.delayed(const Duration(milliseconds: 700));
  }

  void _onBagTap(BagModel bag) {
    if (_state != GameState.guessing || _isGameOver) return;

    // [FIX] Prevent interaction if offline
    final connectivity =
        Provider.of<ConnectivityProvider>(context, listen: false);
    if (!connectivity.isOnline) return;

    setState(() => _state = GameState.reveal);
    HapticFeedback.mediumImpact();

    if (bag.ballColor == _targetColor) {
      _handleWin();
    } else {
      _loseLife("Selección incorrecta");
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
    widget.onSuccess();
  }

  void _loseLife(String reason) async {
    _gameTimer.cancel();

    int livesLeftCount = await MinigameLogicHelper.executeLoseLife(context);

    if (mounted) {
      if (livesLeftCount <= 0) {
        setState(() => _isGameOver = true);
        _showOverlayState(
          title: "SISTEMA BLOQUEADO",
          message: "$reason - Sin vidas.",
        );
      } else {
        _showOverlayState(
          title: "OBJETIVO PERDIDO",
          message: "$reason -1 Vida.",
          retry: true,
        );
      }
    }
  }

  void _handleGiveUp() {
    _gameTimer.cancel();
    _loseLife("Abandono.");
  }

  void _showOverlayState(
      {required String title,
      required String message,
      bool retry = false,
      bool victory = false}) {
    setState(() {
      _showOverlay = true;
      _overlayTitle = title;
      _overlayMessage = message;
      _canRetry = retry;
      _isVictory = victory;
    });
  }

  String _getColorName(Color color) {
    if (color == Colors.red) return "ROJO";
    if (color == Colors.green) return "VERDE";
    return "AZUL";
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Column(
          children: [
            const SizedBox(height: 5),

            // BARRA DE ESTADO (Vidas y Tiempo)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              child: Row(
                children: [
                  _buildStatPill(
                      Icons.favorite,
                      "x${Provider.of<GameProvider>(context).lives}",
                      AppTheme.dangerRed),
                  const Spacer(),
                  _buildStatPill(
                      Icons.timer_outlined,
                      "${(_secondsRemaining ~/ 60)}:${(_secondsRemaining % 60).toString().padLeft(2, '0')}",
                      _secondsRemaining < 10
                          ? AppTheme.dangerRed
                          : Colors.white70),
                ],
              ),
            ),

            const SizedBox(height: 10),

            // STATUS & TARGET INFO
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      _state == GameState.showing
                          ? "MEMORIZA LA POSICIÓN"
                          : _state == GameState.shuffling
                              ? "¡AQUÍ VAN!"
                              : "TOCA LA BOLSA CORRECTA",
                      style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1,
                          decoration: TextDecoration.none),
                    ),
                  ),
                  if (_state != GameState.shuffling) ...[
                    const Text("BUSCA: ",
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            decoration: TextDecoration.none)),
                    const SizedBox(width: 8),
                    Container(
                      width: 20,
                      height: 20,
                      decoration: BoxDecoration(
                        color: _targetColor,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white),
                      ),
                    ),
                  ]
                ],
              ),
            ),

            const SizedBox(height: 20),

            // GAME AREA
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10),
                child: Stack(
                  children: [
                    // Position slots indicators
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: List.generate(3, (index) => _buildSlotMarker()),
                    ),

                    // The Bags
                    ..._bags.map((bag) => _buildAnimatedBag(bag)),
                  ],
                ),
              ),
            ),

            // SHUFFLE PROGRESS
            if (_state == GameState.shuffling)
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 40, vertical: 10),
                child: Column(
                  children: [
                    LinearProgressIndicator(
                      value: _shufflesDone / _totalShuffles,
                      backgroundColor: Colors.white10,
                      color: AppTheme.accentGold,
                    ),
                    const SizedBox(height: 5),
                    const Text("MEZCLANDO...",
                        style: TextStyle(
                            color: AppTheme.accentGold,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            decoration: TextDecoration.none)),
                  ],
                ),
              ),

            // BOTÓN DE RENDICIÓN
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
              child: OutlinedButton(
                onPressed: _handleGiveUp,
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 45),
                  side: BorderSide(
                      color: AppTheme.dangerRed.withOpacity(0.4), width: 1),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8)),
                ),
                child: Text(
                  "RENDIRSE",
                  style: TextStyle(
                      color: AppTheme.dangerRed.withOpacity(0.7),
                      fontSize: 11,
                      fontWeight: FontWeight.bold),
                ),
              ),
            ),
            const SizedBox(height: 10),
          ],
        ),
        if (_showOverlay)
          GameOverOverlay(
            title: _overlayTitle,
            message: _overlayMessage,
            isVictory: _isVictory,
            onRetry: _canRetry ? _resetGame : null,
            onGoToShop: _showShopButton
                ? () async {
                    await Navigator.push(context,
                        MaterialPageRoute(builder: (_) => const MallScreen()));
                    if (mounted) {
                      setState(() {
                        _canRetry = true;
                        _showShopButton = false;
                      });
                    }
                  }
                : null,
            onExit: () {
              Navigator.pop(context);
            },
          ),
      ],
    );
  }

  void _resetGame() {
    setState(() {
      _showOverlay = false;
      _isGameOver = false;
      _isVictory = false;
      _secondsRemaining = 60;
      _startRound();
    });
  }

  Widget _buildAnimatedBag(BagModel bag) {
    double width = MediaQuery.of(context).size.width - 40;
    double slotWidth = width / 3;
    double targetLeft = bag.currentPosition * slotWidth;

    return AnimatedPositioned(
      duration: const Duration(milliseconds: 600), // Speed of the swap movement
      curve: Curves.easeInOutBack,
      left: targetLeft,
      top: 50,
      width: slotWidth,
      child: GestureDetector(
        onTap: () => _onBagTap(bag),
        child: Column(
          children: [
            Stack(
              alignment: Alignment.bottomCenter,
              children: [
                // Ball
                if (_state == GameState.showing || _state == GameState.reveal)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 20.0),
                    child: Container(
                      width: 35,
                      height: 35,
                      decoration: BoxDecoration(
                        color: bag.ballColor,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                              color: bag.ballColor.withOpacity(0.4),
                              blurRadius: 10)
                        ],
                      ),
                    ),
                  ),

                // BAG DESIGN (Pouch shape)
                AnimatedContainer(
                  duration: const Duration(
                      milliseconds: 1200), // Slower entry/covering animation
                  height: (_state == GameState.showing ||
                          _state == GameState.reveal)
                      ? 100
                      : 160,
                  width: 95,
                  margin: EdgeInsets.only(
                      bottom: (_state == GameState.showing ||
                              _state == GameState.reveal)
                          ? 80
                          : 0),
                  child: CustomPaint(
                    painter: BagPainter(
                      color: const Color(0xFF8B4513)
                          .withOpacity(0.9), // Brown leather color
                      borderColor: const Color(0xFF5D2E0A),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSlotMarker() {
    return Container(
      width: 60,
      height: 6,
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(10),
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
          Text(text,
              style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 13)),
        ],
      ),
    );
  }
}

class BagPainter extends CustomPainter {
  final Color color;
  final Color borderColor;

  BagPainter({required this.color, required this.borderColor});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    final borderPaint = Paint()
      ..color = borderColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3;

    final ropePaint = Paint()
      ..color = Colors.amber.shade700
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4;

    final path = Path();

    // Smooth Pouch Shape
    path.moveTo(size.width * 0.35, 0); // Top left neck
    path.lineTo(size.width * 0.65, 0); // Top right neck

    // Neck curve
    path.quadraticBezierTo(size.width * 0.8, size.height * 0.1,
        size.width * 0.9, size.height * 0.3);

    // Belly curve right
    path.quadraticBezierTo(
        size.width * 1.0, size.height * 0.7, size.width * 0.8, size.height);

    // Bottom
    path.lineTo(size.width * 0.2, size.height);

    // Belly curve left
    path.quadraticBezierTo(
        0, size.height * 0.7, size.width * 0.1, size.height * 0.3);

    // Back to neck
    path.quadraticBezierTo(
        size.width * 0.2, size.height * 0.1, size.width * 0.35, 0);
    path.close();

    // Fill
    canvas.drawPath(path, paint);

    // Gradient overlay for volume
    final rect = Offset.zero & size;
    final gradient = RadialGradient(
      center: const Alignment(-0.2, -0.3),
      colors: [Colors.white.withOpacity(0.2), Colors.black.withOpacity(0.2)],
    ).createShader(rect);

    final gradientPaint = Paint()..shader = gradient;
    canvas.drawPath(path, gradientPaint);

    // Border
    canvas.drawPath(path, borderPaint);

    // Draw the "Tie" (Rope around the neck)
    final ropePath = Path();
    ropePath.moveTo(size.width * 0.25, size.height * 0.15);
    ropePath.quadraticBezierTo(size.width * 0.5, size.height * 0.2,
        size.width * 0.75, size.height * 0.15);
    canvas.drawPath(ropePath, ropePaint);

    // Small knot/detail
    canvas.drawCircle(Offset(size.width * 0.5, size.height * 0.18), 4,
        ropePaint..style = PaintingStyle.fill);
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) => false;
}
