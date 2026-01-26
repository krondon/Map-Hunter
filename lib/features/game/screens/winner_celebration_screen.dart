import 'package:flutter/material.dart';
import 'package:confetti/confetti.dart';
import 'package:provider/provider.dart';
import 'dart:math';
import '../providers/game_provider.dart';
import '../../auth/providers/player_provider.dart';
import '../../../core/theme/app_theme.dart';
import 'scenarios_screen.dart';

class WinnerCelebrationScreen extends StatefulWidget {
  final String eventId;
  final int playerPosition;
  final int totalCluesCompleted;

  const WinnerCelebrationScreen({
    super.key,
    required this.eventId,
    required this.playerPosition,
    required this.totalCluesCompleted,
  });

  @override
  State<WinnerCelebrationScreen> createState() =>
      _WinnerCelebrationScreenState();
}

class _WinnerCelebrationScreenState extends State<WinnerCelebrationScreen> {
  late ConfettiController _confettiController;
  late int _currentPosition; // Mutable state for position

  @override
  void initState() {
    super.initState();
    _currentPosition = widget.playerPosition; // Initialize
    _confettiController =
        ConfettiController(duration: const Duration(seconds: 3));

    // Start confetti for top 3 finishers (positive ranks only)
    if (_currentPosition >= 1 && _currentPosition <= 3) {
      _confettiController.play();
    }

    // Load final leaderboard and update position if needed
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final gameProvider = Provider.of<GameProvider>(context, listen: false);

      // Add listener to self-correct position
      gameProvider.addListener(_updatePositionFromLeaderboard);

      gameProvider.fetchLeaderboard();
      // Try immediate update if data exists
      _updatePositionFromLeaderboard();
    });
  }

  void _updatePositionFromLeaderboard() {
    if (!mounted) return;
    final gameProvider = Provider.of<GameProvider>(context, listen: false);
    final playerProvider = Provider.of<PlayerProvider>(context, listen: false);
    final currentPlayerId = playerProvider.currentPlayer?.id ?? '';

    if (gameProvider.leaderboard.isNotEmpty) {
      final index =
          gameProvider.leaderboard.indexWhere((p) => p.userId == playerProvider.currentPlayer?.userId);
      final newPos =
          index >= 0 ? index + 1 : gameProvider.leaderboard.length + 1;

      // Update if position changed or was 0 (unknown)
      if (newPos != _currentPosition && newPos > 0) {
        setState(() {
          _currentPosition = newPos;
        });
        // Check for confetti again
        if (newPos >= 1 && newPos <= 3) {
          _confettiController.play();
        } else {
          _confettiController.stop();
        }
      }
    }
  }

  @override
  void dispose() {
    // Remove listener safely
    try {
      Provider.of<GameProvider>(context, listen: false)
          .removeListener(_updatePositionFromLeaderboard);
    } catch (_) {}

    _confettiController.dispose();
    super.dispose();
  }

  String _getMedalEmoji() {
    switch (_currentPosition) {
      case 1:
        return '🏆';
      case 2:
        return '🥈';
      case 3:
        return '🥉';
      default:
        return '🏁';
    }
  }

  String _getCelebrationMessage() {
    if (_currentPosition == 1) {
      return '¡Eres el Campeón!';
    } else if (_currentPosition >= 1 && _currentPosition <= 3) {
      return '¡Podio Merecido!';
    } else {
      return '¡Carrera Completada!';
    }
  }

  Color _getPositionColor() {
    switch (_currentPosition) {
      case 1:
        return const Color(0xFFFFD700); // Gold
      case 2:
        return const Color(0xFFC0C0C0); // Silver
      case 3:
        return const Color(0xFFCD7F32); // Bronze
      default:
        return AppTheme.accentGold;
    }
  }

  @override
  Widget build(BuildContext context) {
    final gameProvider = Provider.of<GameProvider>(context);
    final playerProvider = Provider.of<PlayerProvider>(context);
    final currentPlayerId = playerProvider.currentPlayer?.id ?? '';

    return WillPopScope(
      onWillPop: () async => false, // Prevent back button
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: Container(
          decoration: const BoxDecoration(
            gradient: AppTheme.darkGradient,
          ),
          child: Stack(
            children: [
              // Confetti overlay
              Align(
                alignment: Alignment.topCenter,
                child: ConfettiWidget(
                  confettiController: _confettiController,
                  blastDirection: pi / 2, // Down
                  maxBlastForce: 5,
                  minBlastForce: 2,
                  emissionFrequency: 0.05,
                  numberOfParticles: 20,
                  gravity: 0.3,
                  colors: const [
                    Colors.green,
                    Colors.blue,
                    Colors.pink,
                    Colors.orange,
                    Colors.purple,
                    Color(0xFFFFD700),
                  ],
                ),
              ),

              SafeArea(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
                  child: Column(
                    children: [
                      // User's Position Header (Very Prominent)
                      Column(
                        children: [
                          Text(
                            _getCelebrationMessage(),
                            style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              color: _getPositionColor(),
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 10),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 15),
                            decoration: BoxDecoration(
                              color: _getPositionColor().withOpacity(0.15),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: _getPositionColor(), width: 2),
                              boxShadow: [
                                BoxShadow(
                                  color: _getPositionColor().withOpacity(0.2),
                                  blurRadius: 15,
                                  spreadRadius: 2,
                                ),
                              ],
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  _getMedalEmoji(),
                                  style: const TextStyle(fontSize: 40),
                                ),
                                const SizedBox(width: 15),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      'TU POSICIÓN',
                                      style: TextStyle(
                                        color: Colors.white70,
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                        letterSpacing: 1.5,
                                      ),
                                    ),
                                    Text(
                                      '#$_currentPosition',
                                      style: TextStyle(
                                        fontSize: 36,
                                        fontWeight: FontWeight.w900,
                                        color: _getPositionColor(),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),

                      const Spacer(),

                      // Top 3 Podium (Fixed at center)
                      if (gameProvider.leaderboard.length >= 3)
                        Column(
                          children: [
                            const Text(
                              'PODIO DE LA CARRERA',
                              style: TextStyle(
                                color: Colors.white54,
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 2,
                              ),
                            ),
                            const SizedBox(height: 20),
                            Container(
                              padding: const EdgeInsets.all(20),
                              decoration: BoxDecoration(
                                color: AppTheme.cardBg.withOpacity(0.5),
                                borderRadius: BorderRadius.circular(24),
                                border: Border.all(color: AppTheme.accentGold.withOpacity(0.2)),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  // 2nd place
                                  _buildPodiumPosition(
                                    gameProvider.leaderboard[1],
                                    2,
                                    60,
                                    Colors.grey,
                                  ),
                                  // 1st place
                                  _buildPodiumPosition(
                                    gameProvider.leaderboard[0],
                                    1,
                                    90,
                                    const Color(0xFFFFD700),
                                  ),
                                  // 3rd place
                                  _buildPodiumPosition(
                                    gameProvider.leaderboard[2],
                                    3,
                                    50,
                                    const Color(0xFFCD7F32),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        )
                      else if (gameProvider.isLoading)
                        const CircularProgressIndicator()
                      else
                        const Text(
                          'Cargando resultados finales...',
                          style: TextStyle(color: Colors.white54),
                        ),

                      const Spacer(),

                      // Final Info and Button
                      Column(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.05),
                              borderRadius: BorderRadius.circular(15),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.stars, color: Colors.greenAccent, size: 20),
                                const SizedBox(width: 10),
                                Text(
                                  '${widget.totalCluesCompleted} Pistas Completadas',
                                  style: const TextStyle(
                                    color: Colors.white70,
                                    fontSize: 16,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 30),
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton.icon(
                              onPressed: () {
                                Navigator.of(context).pushAndRemoveUntil(
                                  MaterialPageRoute(builder: (_) => const ScenariosScreen()),
                                  (route) => false,
                                );
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppTheme.accentGold,
                                foregroundColor: Colors.black,
                                padding: const EdgeInsets.symmetric(vertical: 18),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                elevation: 8,
                                shadowColor: AppTheme.accentGold.withOpacity(0.5),
                              ),
                              icon: const Icon(Icons.home_rounded, size: 28),
                              label: const Text(
                                'VOLVER AL INICIO',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 1,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Color _getPositionColorForRank(int rank) {
    switch (rank) {
      case 1:
        return const Color(0xFFFFD700); // Gold
      case 2:
        return const Color(0xFFC0C0C0); // Silver
      case 3:
        return const Color(0xFFCD7F32); // Bronze
      default:
        return Colors.grey.shade700;
    }
  }

  String _getMedalEmojiForRank(int rank) {
    switch (rank) {
      case 1:
        return '🏆';
      case 2:
        return '🥈';
      case 3:
        return '🥉';
      default:
        return '';
    }
  }

  Widget _buildPodiumPosition(player, int position, double height, Color color) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Stack(
          alignment: Alignment.center,
          children: [
            Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: color, width: 2),
                boxShadow: [
                  BoxShadow(
                    color: color.withOpacity(0.3),
                    blurRadius: 8,
                    spreadRadius: 1,
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(25),
                child: Builder(
                  builder: (context) {
                    final avatarId = player.avatarId;
                    if (avatarId != null && avatarId.isNotEmpty) {
                      return Image.asset(
                        'assets/images/avatars/$avatarId.png',
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => const Icon(Icons.person, color: Colors.white70, size: 25),
                      );
                    }
                    if (player.avatarUrl.isNotEmpty && player.avatarUrl.startsWith('http')) {
                      return Image.network(
                        player.avatarUrl,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => const Icon(Icons.person, color: Colors.white70, size: 25),
                      );
                    }
                    return const Icon(Icons.person, color: Colors.white70, size: 25);
                  },
                ),
              ),
            ),
            Positioned(
              bottom: -2,
              child: Container(
                padding: const EdgeInsets.all(3),
                decoration: BoxDecoration(
                  color: color,
                  shape: BoxShape.circle,
                ),
                child: Text(
                  '$position',
                  style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: Colors.black,
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        SizedBox(
          width: 60,
          child: Text(
            player.name,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        const SizedBox(height: 6),
        Container(
          width: 60,
          height: height,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [color.withOpacity(0.4), color.withOpacity(0.1)],
            ),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(8)),
            border: Border(
              top: BorderSide(color: color, width: 2),
              left: BorderSide(color: color.withOpacity(0.5), width: 1),
              right: BorderSide(color: color.withOpacity(0.5), width: 1),
            ),
          ),
          child: Center(
            child: Text(
              '${player.totalXP}',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
