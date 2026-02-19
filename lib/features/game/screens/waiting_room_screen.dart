import 'package:flutter/material.dart';
import 'dart:async';
import 'package:provider/provider.dart';
import 'package:treasure_hunt_rpg/features/game/providers/game_provider.dart';
import 'package:treasure_hunt_rpg/features/auth/providers/player_provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/animated_cyber_background.dart';
import '../widgets/race_track_widget.dart';
import '../widgets/sponsor_banner.dart'; // NEW

import 'winner_celebration_screen.dart';

class WaitingRoomScreen extends StatefulWidget {
  final String eventId;

  const WaitingRoomScreen({super.key, required this.eventId});

  @override
  State<WaitingRoomScreen> createState() => _WaitingRoomScreenState();
}

class _WaitingRoomScreenState extends State<WaitingRoomScreen> {
  // Store reference to avoid unsafe lookup in dispose
  GameProvider? _gameProviderRef;

  Timer? _pollingTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        final gameProvider = Provider.of<GameProvider>(context, listen: false);
        _gameProviderRef = gameProvider;

        // Ensure we are fetching updates
        gameProvider.startLeaderboardUpdates();

        // Listen for global completion
        gameProvider.addListener(_onGameProviderChange);

        // Check immediately
        gameProvider.checkRaceStatus();

        // 🟢 START POLLING: Check race status every 5 seconds
        // This acts as a fallback if Realtime fails
        _pollingTimer = Timer.periodic(const Duration(seconds: 5), (timer) {
          if (mounted) {
            debugPrint("⏳ WaitingRoom: Polling race status...");
            gameProvider.checkRaceStatus();
          }
        });
      }
    });
  }

  @override
  void dispose() {
    _pollingTimer?.cancel();
    _gameProviderRef?.removeListener(_onGameProviderChange);
    _gameProviderRef?.stopLeaderboardUpdates();
    super.dispose();
  }

  void _onGameProviderChange() {
    if (!mounted) return;
    _checkIfRaceCompleted();
  }

  void _checkIfRaceCompleted() {
    final gameProvider = Provider.of<GameProvider>(context, listen: false);
    if (gameProvider.isRaceCompleted) {
      _navigateToWinnerScreen();
    }
  }

  void _navigateToWinnerScreen() {
    // Navigate to WinnerCelebrationScreen
    final gameProvider = Provider.of<GameProvider>(context, listen: false);
    final playerProvider = Provider.of<PlayerProvider>(context, listen: false);

    // Calculate final position
    int playerPosition = 0;
    final currentPlayerId = playerProvider.currentPlayer?.id ?? '';
    final leaderboard = gameProvider.leaderboard;

    if (leaderboard.isNotEmpty) {
      final index = leaderboard.indexWhere((p) => p.id == currentPlayerId);
      playerPosition = index >= 0 ? index + 1 : leaderboard.length + 1;
    } else {
      playerPosition = 999;
    }

    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => WinnerCelebrationScreen(
          eventId: widget.eventId,
          playerPosition: playerPosition,
          totalCluesCompleted: gameProvider.completedClues,
          // Prize might be null if we are waiting, or maybe we already got it.
          // We can check GameProvider.currentPrizeWon
          prizeWon: gameProvider.currentPrizeWon,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Provider.of<PlayerProvider>(context).isDarkMode;
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: AnimatedCyberBackground(
        child: Stack(
          children: [
            Positioned.fill(
              child: Image.asset(
                isDarkMode
                    ? 'assets/images/fotogrupalnoche.png'
                    : 'assets/images/personajesgrupal.png',
                fit: BoxFit.cover,
                alignment: Alignment.center,
              ),
            ),
            SafeArea(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Header Message
                  const SizedBox(height: 20),
                  Container(
                    margin: const EdgeInsets.symmetric(horizontal: 24),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 20, vertical: 20),
                    decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.05),
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(
                            color: AppTheme.secondaryPink.withOpacity(0.5),
                            width: 1.5),
                        boxShadow: [
                          BoxShadow(
                            color: AppTheme.secondaryPink.withOpacity(0.1),
                            blurRadius: 15,
                            spreadRadius: 2,
                          )
                        ]),
                    child: Column(
                      children: [
                        const Icon(Icons.check_circle_rounded,
                            color: AppTheme.successGreen, size: 40),
                        const SizedBox(height: 16),
                        const Text(
                          "DESAFÍO COMPLETADO",
                          textAlign: TextAlign.center,
                          style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w900,
                              fontFamily: 'Orbitron',
                              fontSize: 20,
                              letterSpacing: 1.5),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          "Esperando resultados finales...",
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Colors.white70,
                            fontSize: 12,
                          ),
                        ),
                        const SizedBox(height: 16),
                        const CircularProgressIndicator(
                            color: AppTheme.accentGold, strokeWidth: 3),
                      ],
                    ),
                  ),

                  // Position Display (NEW)
                  const SizedBox(height: 20),
                  Consumer<GameProvider>(builder: (context, game, child) {
                    final playerProvider =
                        Provider.of<PlayerProvider>(context, listen: false);
                    final myId = playerProvider.currentPlayer?.userId;
                    int myRank = 0;
                    if (game.leaderboard.isNotEmpty && myId != null) {
                      final idx = game.leaderboard
                          .indexWhere((p) => p.userId == myId || p.id == myId);
                      if (idx >= 0) myRank = idx + 1;
                    }

                    if (myRank == 0) return const SizedBox.shrink();

                    return Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 24, vertical: 16),
                      decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.05),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                              color: AppTheme.accentGold.withOpacity(0.3),
                              width: 1.5)),
                      child: Column(
                        children: [
                          const Text("TU POSICIÓN PARCIAL",
                              style: TextStyle(
                                color: AppTheme.accentGold,
                                fontSize: 10,
                                fontWeight: FontWeight.w900,
                                fontFamily: 'Orbitron',
                                letterSpacing: 1.0,
                              )),
                          const SizedBox(height: 8),
                          Text("#$myRank",
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 36,
                                fontWeight: FontWeight.w900,
                                fontFamily: 'Orbitron',
                              )),
                        ],
                      ),
                    );
                  }),

                  const SizedBox(height: 30),

                  // Race Tracker View
                  Expanded(
                    child: Consumer<GameProvider>(
                      builder: (context, gameProvider, child) {
                        final playerProvider =
                            Provider.of<PlayerProvider>(context, listen: false);
                        final currentPlayerId =
                            playerProvider.currentPlayer?.userId ?? '';

                        if (gameProvider.leaderboard.isEmpty) {
                          return const Center(
                              child: CircularProgressIndicator());
                        }

                        return Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16.0),
                          child: Container(
                            decoration: BoxDecoration(
                                color: Colors.black26,
                                borderRadius: BorderRadius.circular(16)),
                            padding: const EdgeInsets.all(12),
                            child: Column(
                              children: [
                                const Text(
                                  "TABLA DE POSICIONES EN VIVO",
                                  style: TextStyle(
                                      color: AppTheme.secondaryPink,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 12,
                                      letterSpacing: 1.5),
                                ),
                                const SizedBox(height: 10),
                                Expanded(
                                  child: RaceTrackWidget(
                                    leaderboard: gameProvider.leaderboard,
                                    currentPlayerId: currentPlayerId,
                                    totalClues: gameProvider.totalClues,
                                    compact: false,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),

                  // SPONSOR BANNER
                  Consumer<GameProvider>(
                    builder: (context, game, child) {
                      if (game.currentSponsor != null &&
                          game.currentSponsor!.hasSponsoredByBanner) {
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 16.0),
                          child: SponsorBanner(
                            sponsor: game.currentSponsor,
                            isCompact: true,
                          ),
                        );
                      }
                      return const SizedBox.shrink();
                    },
                  ),

                  const SizedBox(height: 20),

                  // Loading/Waiting Animation
                  const CircularProgressIndicator(color: AppTheme.accentGold),
                  const SizedBox(height: 10),
                  const Text(
                    "Actualizando en tiempo real...",
                    style: TextStyle(color: Colors.white38, fontSize: 10),
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
