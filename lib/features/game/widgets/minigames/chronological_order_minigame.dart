import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/clue.dart';
import '../../providers/game_provider.dart';
import '../../../../core/theme/app_theme.dart';
import 'game_over_overlay.dart';
import '../../utils/minigame_logic_helper.dart';
import '../../../auth/providers/player_provider.dart';
import '../../../mall/screens/mall_screen.dart';

class ChronologicalOrderMinigame extends StatefulWidget {
  final Clue clue;
  final VoidCallback onSuccess;

  const ChronologicalOrderMinigame({
    super.key,
    required this.clue,
    required this.onSuccess,
  });

  @override
  State<ChronologicalOrderMinigame> createState() =>
      _ChronologicalOrderMinigameState();
}

class HistoricalEvent {
  final String description;
  final int year;

  HistoricalEvent(this.description, this.year);
}

class _ChronologicalOrderMinigameState
    extends State<ChronologicalOrderMinigame> {
  // Config
  static const int _gameDurationSeconds = 60;

  // State
  int _secondsRemaining = _gameDurationSeconds;
  bool _isGameOver = false;
  List<HistoricalEvent> _events = [];
  int? _selectedIndex; // Track selected item for swap

  // Overlay
  bool _showOverlay = false;
  String _overlayTitle = "";
  String _overlayMessage = "";
  bool _canRetry = false;
  bool _showShopButton = false;

  Timer? _gameTimer;

  // Repository of events
  final List<HistoricalEvent> _allEvents = [
    HistoricalEvent("Invención de la Rueda", -3500),
    HistoricalEvent("Construcción Pirámides Giza", -2580),
    HistoricalEvent("Caída del Imperio Romano", 476),
    HistoricalEvent("Descubrimiento de América", 1492),
    HistoricalEvent("Invención de la Imprenta", 1440),
    HistoricalEvent("Revolución Francesa", 1789),
    HistoricalEvent("Primer Vuelo Hermanos Wright", 1903),
    HistoricalEvent("Llegada a la Luna", 1969),
    HistoricalEvent("Lanzamiento del Primer iPhone", 2007),
    HistoricalEvent("Invención World Wide Web", 1989),
    HistoricalEvent("Caída Muro de Berlín", 1989),
    HistoricalEvent("Hundimiento del Titanic", 1912),
    HistoricalEvent("Fin de la Segunda Guerra Mundial", 1945),
    HistoricalEvent("Primer transplante de corazón", 1967),
    HistoricalEvent("Lanzamiento de Windows 95", 1995),
  ];

  @override
  void initState() {
    super.initState();
    _startGame();
  }

  void _startGame() {
    _secondsRemaining = _gameDurationSeconds;
    _isGameOver = false;
    _showOverlay = false;
    _selectedIndex = null;
    _generateRound();
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
        if (_secondsRemaining > 0) {
          _secondsRemaining--;
        } else {
          _endGame(win: false, reason: "Se acabó el tiempo.");
        }
      });
    });
  }

  void _generateRound() {
    // Pick 4 random events
    var shuffled = List<HistoricalEvent>.from(_allEvents)..shuffle();
    _events = shuffled.take(4).toList();
    // Shuffle them for the user to sort
    _events.shuffle();
  }

  void _handleItemTap(int index) {
    if (_isGameOver) return;

    setState(() {
      if (_selectedIndex == null) {
        // Select first item
        _selectedIndex = index;
      } else if (_selectedIndex == index) {
        // Deselect if same item tapped
        _selectedIndex = null;
      } else {
        // Swap
        final temp = _events[_selectedIndex!];
        _events[_selectedIndex!] = _events[index];
        _events[index] = temp;
        _selectedIndex = null; // Clear selection after swap
      }
    });
  }

  void _checkOrder() {
    if (_isGameOver) return;

    bool correct = true;
    for (int i = 0; i < _events.length - 1; i++) {
      if (_events[i].year > _events[i + 1].year) {
        correct = false;
        break;
      }
    }

    if (correct) {
      _endGame(win: true);
    } else {
      _handleMistake();
    }
  }

  Future<void> _handleMistake() async {
    _gameTimer?.cancel();
    final playerProvider = Provider.of<PlayerProvider>(context, listen: false);
    if (playerProvider.currentPlayer != null) {
      final newLives = await MinigameLogicHelper.executeLoseLife(context);
      if (!mounted) return;

      if (newLives <= 0) {
        _endGame(
            win: false,
            reason: "Orden incorrecto. Sin vidas.",
            lives: newLives);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text("¡ORDEN INCORRECTO! -1 Vida"),
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
      _selectedIndex = null;
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
        Column(
          children: [
            Padding(
              padding:
                  const EdgeInsets.symmetric(vertical: 8.0, horizontal: 16.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.timer, color: Colors.white, size: 20),
                  const SizedBox(width: 8),
                  Text("Tiempo: $_secondsRemaining",
                      style:
                          const TextStyle(color: Colors.white, fontSize: 16)),
                ],
              ),
            ),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 20.0),
              child: Text(
                "Toca dos tarjetas para intercambiarlas\n(Más antiguo arriba)",
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white70, fontSize: 14),
              ),
            ),
            const SizedBox(height: 8),
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: 20),
              itemCount: _events.length,
              itemBuilder: (context, index) {
                final isSelected = _selectedIndex == index;
                return GestureDetector(
                  onTap: () => _handleItemTap(index),
                  child: Card(
                    key: ValueKey(_events[index].description),
                    color: isSelected
                        ? AppTheme.primaryPurple
                        : Colors.blueGrey[800],
                    margin: const EdgeInsets.symmetric(vertical: 4),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                        side: isSelected
                            ? const BorderSide(
                                color: AppTheme.accentGold, width: 2)
                            : BorderSide.none),
                    child: ListTile(
                      visualDensity: VisualDensity.compact,
                      contentPadding:
                          const EdgeInsets.symmetric(horizontal: 12),
                      leading: CircleAvatar(
                        radius: 16,
                        backgroundColor:
                            isSelected ? Colors.white : Colors.cyan,
                        child: Text("${index + 1}",
                            style: TextStyle(
                                color: isSelected
                                    ? AppTheme.primaryPurple
                                    : Colors.white,
                                fontSize: 14)),
                      ),
                      title: Text(
                        _events[index].description,
                        style:
                            const TextStyle(color: Colors.white, fontSize: 14),
                      ),
                      trailing: Icon(Icons.swap_vert,
                          color:
                              isSelected ? AppTheme.accentGold : Colors.white54,
                          size: 20),
                    ),
                  ),
                );
              },
            ),
            Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 20.0, vertical: 10.0),
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.accentGold,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 40, vertical: 12),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(30)),
                ),
                onPressed: _checkOrder,
                child: const Text("VERIFICAR ORDEN",
                    style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.black)),
              ),
            ),
            const SizedBox(height: 10),
          ],
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
