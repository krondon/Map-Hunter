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

class MatchThreeMinigame extends StatefulWidget {
  final Clue clue;
  final VoidCallback onSuccess;

  const MatchThreeMinigame({
    super.key,
    required this.clue,
    required this.onSuccess,
  });

  @override
  State<MatchThreeMinigame> createState() => _MatchThreeMinigameState();
}

class Candy {
  final int type; // 0-4
  final UniqueKey key; // For animations if we had them

  Candy(this.type) : key = UniqueKey();
}

class _MatchThreeMinigameState extends State<MatchThreeMinigame> {
  // Config
  static const int _gridRows = 8;
  static const int _gridCols = 8;
  static const int _typesCount = 5;
  static const int _targetScore = 1000;
  static const int _gameDurationSeconds = 120;

  // State
  int _score = 0;
  int _secondsRemaining = _gameDurationSeconds;
  bool _isGameOver = false;
  List<Candy?> _grid = []; // row-major

  int? _selectedindex;
  bool _isProcessing = false; // Guard for animations/gravity

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
    _score = 0;
    _secondsRemaining = _gameDurationSeconds;
    _isGameOver = false;
    _showOverlay = false;
    _generateGrid();
    _startTimer();
  }

  void _generateGrid() {
    final List<Candy?> localGrid = List.filled(_gridRows * _gridCols, null);

    for (int index = 0; index < _gridRows * _gridCols; index++) {
      int r = index ~/ _gridCols;
      int c = index % _gridCols;
      List<int> possibleTypes = List.generate(_typesCount, (i) => i);

      // Avoid initial matches
      if (c >= 2) {
        int left1 = localGrid[index - 1]!.type;
        int left2 = localGrid[index - 2]!.type;
        if (left1 == left2) possibleTypes.remove(left1);
      }
      if (r >= 2) {
        int above1 = localGrid[index - _gridCols]!.type;
        int above2 = localGrid[index - 2 * _gridCols]!.type;
        if (above1 == above2) possibleTypes.remove(above1);
      }

      localGrid[index] =
          Candy(possibleTypes[_random.nextInt(possibleTypes.length)]);
    }

    setState(() {
      _grid = localGrid;
    });
  }

  Candy _randomCandy() {
    return Candy(_random.nextInt(_typesCount));
  }

  void _startTimer() {
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
        } else {
          _endGame(win: false, reason: "Se acabó el tiempo.");
        }
      });
    });
  }

  void _handleTap(int index) {
    if (_isGameOver || _isProcessing) return;

    // [FIX] Prevent interaction if offline
    final connectivity =
        Provider.of<ConnectivityProvider>(context, listen: false);
    if (!connectivity.isOnline) return;

    if (_selectedindex == null) {
      setState(() {
        _selectedindex = index;
      });
    } else {
      // Swap
      if (_areNeighbors(_selectedindex!, index)) {
        _swapAndCheck(_selectedindex!, index);
      } else {
        setState(() {
          _selectedindex = index; // Changing selection
        });
      }
    }
  }

  bool _areNeighbors(int a, int b) {
    int r1 = a ~/ _gridCols;
    int c1 = a % _gridCols;
    int r2 = b ~/ _gridCols;
    int c2 = b % _gridCols;

    return (r1 == r2 && (c1 - c2).abs() == 1) ||
        (c1 == c2 && (r1 - r2).abs() == 1);
  }

  Future<void> _swapAndCheck(int a, int b) async {
    setState(() {
      _isProcessing = true;
      final temp = _grid[a];
      _grid[a] = _grid[b];
      _grid[b] = temp;
      _selectedindex = null;
    });

    bool matched = await _removeMatches();
    if (!matched) {
      // Swap back if no match (standard rule)
      await Future.delayed(const Duration(milliseconds: 300));
      if (!mounted) return;
      setState(() {
        final temp = _grid[a];
        _grid[a] = _grid[b];
        _grid[b] = temp;
        _isProcessing = false;
      });
    } else {
      // If we matched something, we might have triggered a chain reaction
      // _removeMatches is recursive, so it handles the chain.
      if (mounted) {
        setState(() {
          _isProcessing = false;
        });
      }
      if (_score >= _targetScore) {
        _endGame(win: true);
      }
    }
  }

  Future<bool> _removeMatches({bool initial = false}) async {
    // Detect horizontal
    Set<int> matchedIndices = {};

    for (int r = 0; r < _gridRows; r++) {
      for (int c = 0; c < _gridCols - 2; c++) {
        int idx = r * _gridCols + c;
        if (_grid[idx] == null) continue;
        int type = _grid[idx]!.type;
        if (_grid[idx + 1]?.type == type && _grid[idx + 2]?.type == type) {
          matchedIndices.add(idx);
          matchedIndices.add(idx + 1);
          matchedIndices.add(idx + 2);
        }
      }
    }

    // Detect vertical
    for (int c = 0; c < _gridCols; c++) {
      for (int r = 0; r < _gridRows - 2; r++) {
        int idx = r * _gridCols + c;
        if (_grid[idx] == null) continue;
        int type = _grid[idx]!.type;
        if (_grid[(r + 1) * _gridCols + c]?.type == type &&
            _grid[(r + 2) * _gridCols + c]?.type == type) {
          matchedIndices.add(idx);
          matchedIndices.add((r + 1) * _gridCols + c);
          matchedIndices.add((r + 2) * _gridCols + c);
        }
      }
    }

    if (matchedIndices.isNotEmpty) {
      setState(() {
        if (!initial) {
          // New scoring logic: 50 for 3, 100 for 4, etc.
          _score += (matchedIndices.length - 2) * 50;
        }
        for (var idx in matchedIndices) {
          _grid[idx] = null; // Remove
        }
      });

      // Gravity
      await Future.delayed(const Duration(milliseconds: 200));
      _applyGravity();

      // Recursive check
      await Future.delayed(const Duration(milliseconds: 200));
      await _removeMatches(initial: initial);
      return true;
    }
    return false;
  }

  void _applyGravity() {
    setState(() {
      for (int c = 0; c < _gridCols; c++) {
        // Shift down
        for (int r = _gridRows - 1; r >= 0; r--) {
          int idx = r * _gridCols + c;
          if (_grid[idx] == null) {
            // Find nearest above
            int? aboveRow;
            for (int k = r - 1; k >= 0; k--) {
              if (_grid[k * _gridCols + c] != null) {
                aboveRow = k;
                break;
              }
            }
            if (aboveRow != null) {
              _grid[idx] = _grid[aboveRow * _gridCols + c];
              _grid[aboveRow * _gridCols + c] = null;
            } else {
              // Spawn new
              _grid[idx] = _randomCandy();
            }
          }
        }
      }
      // Fill remaining nulls (top)
      for (int i = 0; i < _grid.length; i++) {
        if (_grid[i] == null) _grid[i] = _randomCandy();
      }
    });
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
    return Stack(children: [
      Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            Text("Puntos: $_score/$_targetScore",
                style: const TextStyle(color: Colors.white, fontSize: 18)),
            Text("Tiempo: $_secondsRemaining",
                style: const TextStyle(color: Colors.white, fontSize: 18))
          ],
        ),
        const SizedBox(height: 10),
        Expanded(
          child: Center(
            child: LayoutBuilder(builder: (context, constraints) {
              final double size = min(constraints.maxWidth * 0.95, 400);
              return SizedBox(
                width: size,
                height: size,
                child: GridView.builder(
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: _gridRows * _gridCols,
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: _gridCols),
                    itemBuilder: (context, index) {
                      final candy = _grid.isEmpty ? null : _grid[index];
                      bool isSelected = _selectedindex == index;
                      return GestureDetector(
                          onTap: () => _handleTap(index),
                          child: Container(
                              margin: const EdgeInsets.all(2),
                              decoration: BoxDecoration(
                                  color: isSelected
                                      ? Colors.white24
                                      : Colors.transparent,
                                  borderRadius: BorderRadius.circular(5)),
                              child: candy == null
                                  ? const SizedBox()
                                  : Icon(_getIcon(candy.type),
                                      color: _getColor(candy.type),
                                      size: (size / _gridCols) * 0.8)));
                    }),
              );
            }),
          ),
        )
      ]),
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
    ]);
  }

  IconData _getIcon(int type) {
    switch (type) {
      case 0:
        return Icons.favorite;
      case 1:
        return Icons.star;
      case 2:
        return Icons.bolt;
      case 3:
        return Icons.diamond;
      case 4:
        return Icons.circle;
      default:
        return Icons.help;
    }
  }

  Color _getColor(int type) {
    switch (type) {
      case 0:
        return Colors.red;
      case 1:
        return Colors.yellow;
      case 2:
        return Colors.amber;
      case 3:
        return Colors.cyan;
      case 4:
        return Colors.purple;
      default:
        return Colors.white;
    }
  }
}
