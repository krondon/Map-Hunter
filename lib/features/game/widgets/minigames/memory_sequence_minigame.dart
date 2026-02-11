import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../models/clue.dart';
import '../../../auth/providers/player_provider.dart';
import '../../utils/minigame_logic_helper.dart';
import '../../providers/game_provider.dart';
import '../../../../core/theme/app_theme.dart';
import 'game_over_overlay.dart';
import '../../../mall/screens/mall_screen.dart';
import '../../../../shared/widgets/animated_cyber_background.dart';
import '../race_track_widget.dart'; 

class MemorySequenceMinigame extends StatefulWidget {
  final Clue clue;
  final VoidCallback onSuccess;

  const MemorySequenceMinigame({
    super.key,
    required this.clue,
    required this.onSuccess,
  });

  @override
  State<MemorySequenceMinigame> createState() => _MemorySequenceMinigameState();
}

class _MemorySequenceMinigameState extends State<MemorySequenceMinigame> {
  // Configuración
  int _currentDifficulty = 4; 
  List<int> _sequence = [];
  List<int> _playerInput = [];
  bool _isPlayerTurn = false;
  bool _isGameActive = false;
  int _activeButtonIndex = -1;
  
  // Timer State
  late Timer _timer;
  int _secondsRemaining = 90; // Tiempo generoso
  bool _isGameOver = false;
  
  // Colores mejorados (Vibrantes pero legibles)
  final List<Color> _gameColors = [
    const Color(0xFFD500F9), // Purple (1)
    const Color(0xFF00E5FF), // Cyan (2)
    const Color(0xFF76FF03), // Green (3)
    const Color(0xFFFF3D00), // Orange (4)
  ];
  
  String _statusMessage = 'ESPERANDO...';

  // Overlay State
  bool _showOverlay = false;
  String _overlayTitle = "";
  String _overlayMessage = "";
  bool _canRetry = false;
  bool _isVictory = false;
  bool _showShopButton = false;

  void _showOverlayState({required String title, required String message, bool retry = false, bool victory = false, bool showShop = false}) {
    setState(() {
      _showOverlay = true;
      _overlayTitle = title;
      _overlayMessage = message;
      _canRetry = retry;
      _isVictory = victory;
      _showShopButton = showShop;
    });
  }

  @override
  void initState() {
    super.initState();
    _startTimer();
    Future.delayed(const Duration(milliseconds: 1000), _startGame);
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  void _startTimer() {
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
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

  void _stopTimer() {
    _timer.cancel();
  }

  void _handleTimeOut() {
    _stopTimer();
    _loseLife("¡Tiempo agotado!");
  }

  void _startGame() {
    if (!mounted || _isGameOver) return;
    setState(() {
      _isGameActive = true;
      _sequence = [];
      _playerInput = [];
      _statusMessage = 'MEMORIZA...';
    });
    _nextRound();
  }

  void _nextRound() {
    if (!mounted || _isGameOver) return;
    setState(() {
      _playerInput = [];
      _isPlayerTurn = false;
      _statusMessage = 'OBSERVA';
      _sequence.add(Random().nextInt(4));
    });
    _playSequence();
  }

  void _playSequence() async {
    await Future.delayed(const Duration(milliseconds: 1000));
    if (_isGameOver) return;

    for (int i = 0; i < _sequence.length; i++) {
      if (!mounted || _isGameOver) return;
      setState(() => _activeButtonIndex = _sequence[i]);
      HapticFeedback.lightImpact(); 
      await Future.delayed(const Duration(milliseconds: 600));

      if (!mounted) return;
      setState(() => _activeButtonIndex = -1);
      await Future.delayed(const Duration(milliseconds: 200));
    }

    if (!mounted || _isGameOver) return;
    setState(() {
      _isPlayerTurn = true;
      _statusMessage = 'TU TURNO';
    });
  }

  void _onButtonTap(int index) {
    if (!_isGameActive || !_isPlayerTurn || _isGameOver) return;

    final gameProvider = Provider.of<GameProvider>(context, listen: false);
    if (gameProvider.isFrozen) return;

    HapticFeedback.selectionClick();
    _flashButton(index);

    if (_sequence[_playerInput.length] == index) {
      _playerInput.add(index);
      if (_playerInput.length == _sequence.length) {
        _handleRoundSuccess();
      }
    } else {
      _loseLife("Secuencia Incorrecta.");
    }
  }

  void _flashButton(int index) async {
    setState(() => _activeButtonIndex = index);
    await Future.delayed(const Duration(milliseconds: 200));
    if (mounted) setState(() => _activeButtonIndex = -1);
  }

  void _handleRoundSuccess() {
    setState(() {
      _isPlayerTurn = false;
      _statusMessage = '¡BIEN!';
    });

    if (_sequence.length >= _currentDifficulty) { 
      _stopTimer();
      widget.onSuccess();
    } else {
      Future.delayed(const Duration(milliseconds: 800), _nextRound);
    }
  }

  void _handleGiveUp() {
    _stopTimer();
    _loseLife("Te has rendido.");
  }

  void _loseLife(String reason) async {
    _stopTimer();
    setState(() {
        _isGameActive = false;
        _isGameOver = true;
    });
    HapticFeedback.heavyImpact();

    final playerProvider = Provider.of<PlayerProvider>(context, listen: false);
    
    if (playerProvider.currentPlayer != null) {
      final newLives = await MinigameLogicHelper.executeLoseLife(context);

      if (!mounted) return;
      
      if (newLives <= 0) {
        _showOverlayState(
          title: "GAME OVER", 
          message: "Te has quedado sin vidas.",
          retry: false,
          showShop: true
        );
      } else {
        _showOverlayState(
          title: "¡FALLASTE!", 
          message: "$reason",
          retry: true,
          showShop: false
        );
      }
    }
  }

  IconData _getIconForIndex(int index) {
    switch (index) {
      case 0: return Icons.code;
      case 1: return Icons.wifi;
      case 2: return Icons.memory;
      case 3: return Icons.security;
      default: return Icons.error;
    }
  }

  @override
  Widget build(BuildContext context) {
    final gameProvider = Provider.of<GameProvider>(context);
    final playerProvider = Provider.of<PlayerProvider>(context);
    final player = playerProvider.currentPlayer;

    return PopScope(
      canPop: false,
      child: Material( 
        color: Colors.transparent,
        child: Stack(
          children: [
            Opacity( opacity: 0.3, child: const AnimatedCyberBackground()),

            Column(
              children: [
                // 1. TOP HEADER: Lives (Pill) | XP (Pill) | Flag (Pill) - Grouped on the right
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 10),
                  child: Row(
                    children: [
                      const Spacer(), // Push everything to the right
                      
                      // LIVES PILL
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: Colors.redAccent.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: Colors.redAccent.withOpacity(0.6)),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.favorite, color: Colors.redAccent, size: 16),
                            const SizedBox(width: 4),
                            Text(
                              'x${gameProvider.lives}',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                decoration: TextDecoration.none,
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(width: 6), // Very small gap

                      // XP PILL
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: Colors.amber.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: Colors.amber.withOpacity(0.5)),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.star, color: Colors.amber, size: 14),
                            const SizedBox(width: 4),
                            const Text(
                              '+50 XP', 
                              style: TextStyle(
                                color: Colors.amber,
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                                decoration: TextDecoration.none,
                              ),
                            ),
                          ],
                        ),
                      ),
                      
                      const SizedBox(width: 10), // Small gap before flag
                      
                      // FLAG ICON
                      const Icon(Icons.flag, color: Colors.redAccent, size: 24),
                    ],
                  ),
                ),

                // 2. LIVE RACE WIDGET (FULL SIZE)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                  child: RaceTrackWidget(
                    leaderboard: gameProvider.leaderboard,
                    currentPlayerId: player?.userId ?? '',
                    totalClues: gameProvider.clues.length,
                  ),
                ),
                
                const SizedBox(height: 10),

                // 2.5 LIVES BELOW RACE (normal style)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Row(
                    children: [
                      const Icon(Icons.favorite, color: AppTheme.dangerRed, size: 20),
                      const SizedBox(width: 5),
                      Text(
                        "x${gameProvider.lives}", 
                        style: const TextStyle(
                          color: Colors.white, 
                          fontSize: 16, 
                          fontWeight: FontWeight.bold,
                          decoration: TextDecoration.none,
                        )
                      ),
                    ],
                  ),
                ),
                
                const SizedBox(height: 5),

                // 3. STATUS & TIMER
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                        // LEVEL
                        Text(
                          "NIVEL ${_sequence.length}/$_currentDifficulty",
                          style: TextStyle(
                              color: Colors.white.withOpacity(0.5), 
                              fontSize: 12, 
                              letterSpacing: 2,
                              decoration: TextDecoration.none
                          ),
                        ),
                        
                        // TIMER PILL
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: const Color(0xFF2A2A2E),
                            borderRadius: BorderRadius.circular(15),
                            border: Border.all(color: _secondsRemaining < 10 ? AppTheme.dangerRed : Colors.white10),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.timer_outlined, size: 14, color: _secondsRemaining < 10 ? AppTheme.dangerRed : Colors.white70),
                              const SizedBox(width: 4),
                              Text(
                                "${_secondsRemaining ~/ 60}:${(_secondsRemaining % 60).toString().padLeft(2, '0')}",
                                style: TextStyle(
                                  color: _secondsRemaining < 10 ? AppTheme.dangerRed : Colors.white, 
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                  decoration: TextDecoration.none
                                )
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),

                const SizedBox(height: 5),

                // STATUS MESSAGE
                Text(
                  _statusMessage,
                  style: TextStyle(
                    color: _isPlayerTurn ? Colors.greenAccent : AppTheme.accentGold, 
                    fontSize: 18, 
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.5,
                    decoration: TextDecoration.none,
                    shadows: [
                         if (_isPlayerTurn) const Shadow(color: Colors.greenAccent, blurRadius: 10)
                    ],
                  ),
                ),

                const SizedBox(height: 15),

                // 4. GAME GRID (compact)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 90.0, vertical: 10.0),
                  child: AspectRatio(
                    aspectRatio: 1,
                    child: GridView.count(
                      crossAxisCount: 2,
                      mainAxisSpacing: 10,
                      crossAxisSpacing: 10,
                      physics: const NeverScrollableScrollPhysics(),
                      children: List.generate(4, (index) {
                        final isActive = _activeButtonIndex == index;
                        return _buildGameButton(index, isActive);
                      }),
                    ),
                  ),
                ),

                const Spacer(),

                // 5. BOTÓN RENDIRSE (RECTANGULAR)
                Padding(
                  padding: const EdgeInsets.all(20),
                  child: SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton.icon(
                      onPressed: _showOverlay ? null : _handleGiveUp,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.transparent,
                        surfaceTintColor: Colors.transparent,
                        shadowColor: Colors.transparent,
                        foregroundColor: AppTheme.dangerRed,
                        side: const BorderSide(color: AppTheme.dangerRed),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), // More rectangular
                        elevation: 0,
                      ),
                      icon: const Icon(Icons.flag_outlined),
                      label: const Text("RENDIRSE"),
                    ),
                  ),
                )
              ],
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
                    _isPlayerTurn = false;
                    _timer.cancel();
                    _secondsRemaining = 90;
                    _startTimer();
                    _startGame();
                  });
                } : null,
                onGoToShop: _showShopButton ? () async {
                   await Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const MallScreen()),
                  );
                  if (context.mounted) {
                     setState(() {
                       _canRetry = true;
                       _showShopButton = false;
                       _overlayMessage = "¡Vidas recargadas!";
                     });
                  }
                } : null,
                onExit: () => Navigator.pop(context),
              ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildGameButton(int index, bool isActive) {
    final color = _gameColors[index];
    
    return GestureDetector(
      onTapDown: (_) => _onButtonTap(index),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        decoration: BoxDecoration(
          color: isActive ? color : color.withOpacity(0.8), 
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isActive ? Colors.white : Colors.transparent,
            width: 4,
          ),
          boxShadow: isActive ? [
            BoxShadow(
              color: color.withOpacity(0.8),
              blurRadius: 30,
              spreadRadius: 5,
            )
          ] : [
            BoxShadow(
              color: color.withOpacity(0.3),
              offset: const Offset(0, 4),
              blurRadius: 8
            )
          ],
        ),
        child: Center(
          child: Text(
            (index + 1).toString(), 
            style: const TextStyle(
              color: Colors.white,
              fontSize: 48,
              fontWeight: FontWeight.bold,
              decoration: TextDecoration.none,
            ),
          ),
        ),
      ),
    );
  }
}
