import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/clue.dart';
import '../../providers/game_provider.dart';
import '../../providers/connectivity_provider.dart';
import '../../../../core/theme/app_theme.dart';
import 'game_over_overlay.dart';
import '../../utils/minigame_logic_helper.dart';
import '../../../auth/providers/player_provider.dart';
import '../../../mall/screens/mall_screen.dart';

class PrimeNetworkMinigame extends StatefulWidget {
  final Clue clue;
  final VoidCallback onSuccess;

  const PrimeNetworkMinigame({
    super.key,
    required this.clue,
    required this.onSuccess,
  });

  @override
  State<PrimeNetworkMinigame> createState() => _PrimeNetworkMinigameState();
}

class Node {
  final int value;
  final bool isPrime;
  bool isSecured;
  final Offset position; // 0.0-1.0 coords

  Node({
    required this.value,
    required this.isPrime,
    required this.position,
    this.isSecured = false,
  });
}

class _PrimeNetworkMinigameState extends State<PrimeNetworkMinigame> {
  // Config
  static const int _gameDurationSeconds = 45;

  // State
  int _secondsRemaining = _gameDurationSeconds;
  bool _isGameOver = false;
  List<Node> _nodes = [];
  int _primesToFind = 0;
  int _primesFound = 0;

  // Overlay
  bool _showOverlay = false;
  String _overlayTitle = "";
  String _overlayMessage = "";
  bool _canRetry = false;
  bool _showShopButton = false;

  Timer? _gameTimer;
  final Random _random = Random();

  @override
  void initState() {
    super.initState();
    _startGame();
  }

  void _startGame() {
    _secondsRemaining = _gameDurationSeconds;
    _isGameOver = false;
    _showOverlay = false;
    _generateNetwork();
    _startTimer();
  }

  void _startTimer() {
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
        } else {
          _endGame(win: false, reason: "Se acabó el tiempo.");
        }
      });
    });
  }

  bool _isPrime(int n) {
    if (n < 2) return false;
    for (int i = 2; i <= sqrt(n); i++) {
      if (n % i == 0) return false;
    }
    return true;
  }

  void _generateNetwork() {
    _nodes.clear();
    _primesFound = 0;

    // Generate ~6-8 nodes
    int nodeCount = 6 + _random.nextInt(3);

    // Ensure at least 3 primes
    int primesGenerated = 0;
    int targetPrimes = 3 + _random.nextInt(2);

    for (int i = 0; i < nodeCount; i++) {
      int val;
      bool isP;

      if (primesGenerated < targetPrimes) {
        // Force prime
        do {
          val = _random.nextInt(30) + 2;
        } while (!_isPrime(val) || _nodes.any((n) => n.value == val));
        isP = true;
        primesGenerated++;
      } else {
        // Force composite or random (but bias to composite to balance)
        do {
          val = _random.nextInt(30) + 2;
        } while ((_isPrime(val) && _random.nextDouble() > 0.2) ||
            _nodes.any((n) => n.value == val));
        isP = _isPrime(val);
        if (isP) primesGenerated++;
      }

      // Random position with some padding
      // Check collision with existing nodes roughly
      Offset pos;
      bool collision;
      int attempts = 0;
      do {
        collision = false;
        pos = Offset(
            0.1 + _random.nextDouble() * 0.8, 0.1 + _random.nextDouble() * 0.8);
        for (var n in _nodes) {
          if ((n.position - pos).distance < 0.2) {
            collision = true;
            break;
          }
        }
        attempts++;
      } while (collision && attempts < 20);

      _nodes.add(Node(value: val, isPrime: isP, position: pos));
    }

    _primesToFind = primesGenerated;
  }

  void _handleNodeTap(Node node) {
    if (_isGameOver || node.isSecured) return;

    // [FIX] Prevent interaction if offline
    final connectivity =
        Provider.of<ConnectivityProvider>(context, listen: false);
    if (!connectivity.isOnline) return;

    if (node.isPrime) {
      setState(() {
        node.isSecured = true;
        _primesFound++;
        if (_primesFound >= _primesToFind) {
          _endGame(win: true);
        }
      });
    } else {
      _handleMistake();
    }
  }

  Future<void> _handleMistake() async {
    // Auditivo/Visual alrma logic here ideally
    _gameTimer?.cancel();
    final playerProvider = Provider.of<PlayerProvider>(context, listen: false);
    if (playerProvider.currentPlayer != null) {
      final newLives = await MinigameLogicHelper.executeLoseLife(context);
      if (!mounted) return;

      if (newLives <= 0) {
        _endGame(
            win: false,
            reason: "Activaste una alarma (No primo).",
            lives: newLives);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text("¡ALARMA! No es Primo. -1 Vida"),
              backgroundColor: AppTheme.dangerRed,
              duration: Duration(milliseconds: 1000)),
        );
        _startTimer();
      }
    }
  }

  void _endGame({required bool win, String? reason, int? lives}) {
    _gameTimer?.cancel();
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
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // Network play area
        SizedBox(
          height: 500,
          child: Stack(
            children: [
              CustomPaint(
                size: Size.infinite,
                painter: NetworkPainter(nodes: _nodes),
              ),
              LayoutBuilder(
                builder: (context, constraints) {
                  return Stack(
                    children: _nodes.map((node) {
                      return Positioned(
                        left: node.position.dx * constraints.maxWidth - 30,
                        top: node.position.dy * constraints.maxHeight - 30,
                        child: GestureDetector(
                          onTap: () => _handleNodeTap(node),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 300),
                            width: 60,
                            height: 60,
                            decoration: BoxDecoration(
                                color: node.isSecured
                                    ? Colors.green
                                    : Colors.blueGrey[800],
                                shape: BoxShape.circle,
                                border: Border.all(
                                    color: node.isSecured
                                        ? Colors.lightGreenAccent
                                        : Colors.cyan,
                                    width: 2),
                                boxShadow: [
                                  BoxShadow(
                                      color: node.isSecured
                                          ? Colors.green.withOpacity(0.5)
                                          : Colors.cyan.withOpacity(0.3),
                                      blurRadius: 10)
                                ]),
                            child: Center(
                              child: Text(
                                "${node.value}",
                                style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold),
                              ),
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  );
                },
              ),
            ],
          ),
        ),

        // HUD
        Positioned(
          top: 16,
          left: 0,
          right: 0,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.black54,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text("Primos asegurados: $_primesFound / $_primesToFind",
                    style: const TextStyle(color: Colors.white)),
              ),
              const SizedBox(width: 20),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.black54,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text("Tiempo: $_secondsRemaining",
                    style: const TextStyle(color: Colors.white)),
              )
            ],
          ),
        ),

        if (_showOverlay)
          GameOverOverlay(
            title: _overlayTitle,
            message: _overlayMessage,
            onRetry: _canRetry ? _resetGame : null,
            onGoToShop: _showShopButton
                ? () async {
                    await Navigator.push(context,
                        MaterialPageRoute(builder: (_) => const MallScreen()));
                    if (mounted) {
                      final player =
                          Provider.of<PlayerProvider>(context, listen: false)
                              .currentPlayer;
                      if ((player?.lives ?? 0) > 0) _resetGame();
                    }
                  }
                : null,
            onExit: () => Navigator.pop(context),
          ),
      ],
    );
  }
}

class NetworkPainter extends CustomPainter {
  final List<Node> nodes;

  NetworkPainter({required this.nodes});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.cyan.withOpacity(0.2)
      ..strokeWidth = 1.0;

    // Draw connection lines between nearest neighbors or all
    // For simplicity, connect all to create "Network" visual
    for (int i = 0; i < nodes.length; i++) {
      for (int j = i + 1; j < nodes.length; j++) {
        Offset p1 = Offset(nodes[i].position.dx * size.width,
            nodes[i].position.dy * size.height);
        Offset p2 = Offset(nodes[j].position.dx * size.width,
            nodes[j].position.dy * size.height);

        // Draw line only if reasonably close to avoid clutter
        if ((nodes[i].position - nodes[j].position).distance < 0.4) {
          canvas.drawLine(p1, p2, paint);
        }
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
