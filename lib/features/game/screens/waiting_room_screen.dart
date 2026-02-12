import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../game/providers/game_provider.dart';
import '../../auth/providers/player_provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/animated_cyber_background.dart';
import '../widgets/race_track_widget.dart';

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
        // Force check against server just in case
        gameProvider.checkRaceStatus(); 
      }
    });
  }

  @override
  void dispose() {
    _gameProviderRef?.removeListener(_onGameProviderChange);
    // Do NOT stop leaderboard updates here, as we might naturally transition to Winner Screen
    // which also needs them, or we leave them running. 
    // Actually, WinnerScreen handles its own data fetching usually, but safe to leave or stop?
    // Let's stop to be clean, WinnerScreen will Init its own.
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
    return Scaffold(
      body: AnimatedCyberBackground(
        child: SafeArea(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Header Message
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                decoration: BoxDecoration(
                  color: AppTheme.cardBg.withOpacity(0.8),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: AppTheme.accentGold.withOpacity(0.5)),
                  boxShadow: [
                    BoxShadow(
                      color: AppTheme.accentGold.withOpacity(0.2),
                      blurRadius: 10,
                      spreadRadius: 2,
                    )
                  ]
                ),
                child: Column(
                  children: [
                    const Icon(Icons.check_circle_outline, color: AppTheme.successGreen, size: 50),
                    const SizedBox(height: 10),
                    const Text(
                      "¡CARRERA COMPLETADA!",
                      style: TextStyle(
                        color: AppTheme.successGreen,
                        fontWeight: FontWeight.bold,
                        fontSize: 24,
                        letterSpacing: 1.2
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      "Esperando que lleguen los demás ganadores...",
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),

              // Position Display (NEW)
              const SizedBox(height: 20),
              Consumer<GameProvider>(builder: (context, game, child) {
                 final playerProvider = Provider.of<PlayerProvider>(context, listen: false);
                 final myId = playerProvider.currentPlayer?.userId;
                 int myRank = 0;
                 if (game.leaderboard.isNotEmpty && myId != null) {
                    final idx = game.leaderboard.indexWhere((p) => p.userId == myId || p.id == myId);
                    if (idx >= 0) myRank = idx + 1;
                 }
                 
                 if (myRank == 0) return const SizedBox.shrink();

                 return Container(
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppTheme.accentGold)
                    ),
                    child: Column(
                      children: [
                        const Text("TU POSICIÓN PARCIAL", style: TextStyle(color: AppTheme.accentGold, fontSize: 12, fontWeight: FontWeight.bold)),
                        Text("#$myRank", style: const TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.bold)),
                      ],
                    ),
                 );
              }),

              const SizedBox(height: 30),

              // Race Tracker View
              Expanded(
                child: Consumer<GameProvider>(
                  builder: (context, gameProvider, child) {
                     final playerProvider = Provider.of<PlayerProvider>(context, listen: false);
                     final currentPlayerId = playerProvider.currentPlayer?.userId ?? '';

                     if (gameProvider.leaderboard.isEmpty) {
                        return const Center(child: CircularProgressIndicator());
                     }

                    return Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16.0),
                      child: Container(
                        decoration: BoxDecoration(
                           color: Colors.black26,
                           borderRadius: BorderRadius.circular(16)
                        ),
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          children: [
                            const Text(
                              "TABLA DE POSICIONES EN VIVO",
                              style: TextStyle(
                                color: AppTheme.secondaryPink,
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                                letterSpacing: 1.5
                              ),
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
      ),
    );
  }
}
