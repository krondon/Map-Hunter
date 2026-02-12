import 'package:flutter/material.dart';
import 'package:confetti/confetti.dart';
import 'package:provider/provider.dart';
import 'dart:math';
import '../providers/game_provider.dart';
import '../../auth/providers/player_provider.dart';
import '../../../core/theme/app_theme.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'scenarios_screen.dart';

class WinnerCelebrationScreen extends StatefulWidget {
  final String eventId;
  final int playerPosition;
  final int totalCluesCompleted;
  final int? prizeWon; // NEW

  const WinnerCelebrationScreen({
    super.key,
    required this.eventId,
    required this.playerPosition,
    required this.totalCluesCompleted,
    this.prizeWon, // NEW
  });

  @override
  State<WinnerCelebrationScreen> createState() =>
      _WinnerCelebrationScreenState();
}

class _WinnerCelebrationScreenState extends State<WinnerCelebrationScreen> {
  late ConfettiController _confettiController;
  late int _currentPosition; // Mutable state for position
  bool _isLoading = true; // NEW: Start with loading state
  Map<String, int> _prizes = {};

  @override
  void initState() {
    super.initState();
    debugPrint("🏆 WinnerCelebrationScreen INIT: Prize = ${widget.prizeWon}");
    _currentPosition = widget.playerPosition;
    _confettiController =
        ConfettiController(duration: const Duration(seconds: 3));

    // Start loading always to ensure sync
    _isLoading = true;

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final gameProvider = Provider.of<GameProvider>(context, listen: false);
      final playerProvider =
          Provider.of<PlayerProvider>(context, listen: false);

      // REFRESH WALLET to ensure balance is current
      await playerProvider.reloadProfile();
      debugPrint(
          "💰 Wallet refreshed on podium. Balance: ${playerProvider.currentPlayer?.clovers}");

      // Fetch prizes for everyone
      _fetchPrizes();

      // Add listener to self-correct position
      gameProvider.addListener(_updatePositionFromLeaderboard);

      // FORCE SYNC: Ensure provider knows the event ID
      if (gameProvider.currentEventId != widget.eventId) {
        debugPrint("🏆 WinnerScreen: EventID Mismatch (Provider: ${gameProvider.currentEventId} vs Widget: ${widget.eventId}). Fixing...");
        // Re-initialize provider context for this event without heavy loading UI
        await gameProvider.fetchClues(eventId: widget.eventId, silent: true);
      }

      // Force a fresh fetch
      await gameProvider.fetchLeaderboard();

      // Try immediate check
      _updatePositionFromLeaderboard();

      // Safety timeout: If after 8 seconds we still loading, force show content
      Future.delayed(const Duration(seconds: 8), () {
        if (mounted && _isLoading) {
          debugPrint("⚠️ Podium timeout: Forcing display with available data.");
          setState(() {
            _isLoading = false;
          });
        }
      });
    });
  }

  Future<void> _fetchPrizes() async {
    try {
      final supabase = Supabase.instance.client;
      final response = await supabase
          .from('prize_distributions')
          .select('user_id, amount')
          .eq('event_id', widget.eventId);

      final Map<String, int> loadedPrizes = {};
      for (final row in response) {
        if (row['user_id'] != null && row['amount'] != null) {
          loadedPrizes[row['user_id'].toString()] = row['amount'] as int;
        }
      }

      if (mounted) {
        setState(() {
          _prizes = loadedPrizes;
        });
        debugPrint("🏆 Prizes loaded: $_prizes");
      }
    } catch (e) {
      debugPrint("⚠️ Error fetching podium prizes: $e");
    }
  }

  void _updatePositionFromLeaderboard() {
    if (!mounted) return;
    final gameProvider = Provider.of<GameProvider>(context, listen: false);
    final playerProvider = Provider.of<PlayerProvider>(context, listen: false);

    // 1. If loading, keep waiting
    if (gameProvider.leaderboard.isEmpty && gameProvider.isLoading) return;

    if (gameProvider.leaderboard.isNotEmpty) {
      final currentUser = gameProvider.leaderboard.firstWhere(
          (p) => p.userId == playerProvider.currentPlayer?.userId,
          orElse: () =>
              playerProvider.currentPlayer!); // Fallback to avoid crash

      // 2. STRICT CHECK: Does the leaderboard reflect my completed clues?
      // If the leaderboard says I have fewer clues than I actually completed, it's stale.
      if (currentUser.completedCluesCount < widget.totalCluesCompleted) {
        debugPrint(
            "⏳ Podium Sync: Leaderboard stale (Server: ${currentUser.completedCluesCount} vs Local: ${widget.totalCluesCompleted}). Waiting...");
        
        // RETRY LOGIC: If data is stale, we MUST force a refresh, even if isLoading is false.
        // We use a debounce to avoid spamming.
        if (!gameProvider.isLoading) {
           Future.delayed(const Duration(milliseconds: 1000), () {
              if (mounted) {
                 debugPrint("🔄 Podium Sync: Retrying fetchLeaderboard...");
                 gameProvider.fetchLeaderboard(silent: true);
              }
           });
        }
        return;
      }

      final index = gameProvider.leaderboard
          .indexWhere((p) => p.userId == playerProvider.currentPlayer?.userId);
      final newPos = index >= 0 ? index + 1 : _currentPosition;

      debugPrint("✅ Podium Sync: Data verified. Rank: $newPos");

      // Verify prizes if not loaded cleanly yet
      if (_prizes.isEmpty) {
        _fetchPrizes();
      }

      // Data is consistent, update and show
      if (newPos != _currentPosition || _isLoading) {
        setState(() {
          _currentPosition = newPos;
          _isLoading = false;
        });

        if (newPos >= 1 && newPos <= 3) {
          _confettiController.play();
        } else {
          _confettiController.stop();
        }
      }
    } else {
      // Leaderboard empty/failed?
      if (!gameProvider.isLoading && _isLoading) {
         debugPrint("⚠️ Podium Sync: Leaderboard empty. Retrying...");
         Future.delayed(const Duration(seconds: 2), () {
             if (mounted && !gameProvider.isLoading) {
                 gameProvider.fetchLeaderboard(silent: true);
             }
         });
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

    debugPrint("🏆 WinnerScreen Build: eventId=${widget.eventId}, leaderboardSize=${gameProvider.leaderboard.length}, isLoading=${gameProvider.isLoading}, internalIsLoading=$_isLoading");

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

              if (_isLoading)
                const Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      CircularProgressIndicator(color: AppTheme.accentGold),
                      SizedBox(height: 20),
                      Text("Calculando resultados finales...",
                          style: TextStyle(color: Colors.white70)),
                    ],
                  ),
                )
              else
                SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 24, vertical: 20),
                    child: Column(
                      children: [
                        // User's Position Header (Very Prominent)
                        Column(
                          children: [
                            Text(
                              _currentPosition > 0
                                  ? _getCelebrationMessage()
                                  : 'Resultados del Evento',
                              style: TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                                color: _getPositionColor(),
                              ),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 10),
                            if (_currentPosition > 0)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 30, vertical: 15),
                                decoration: BoxDecoration(
                                  color: _getPositionColor().withOpacity(0.15),
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(
                                      color: _getPositionColor(), width: 2),
                                  boxShadow: [
                                    BoxShadow(
                                      color:
                                          _getPositionColor().withOpacity(0.2),
                                      blurRadius: 15,
                                      spreadRadius: 2,
                                    ),
                                  ],
                                ),
                                child: Column(children: [
                                  Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        _getMedalEmoji(),
                                        style: const TextStyle(fontSize: 40),
                                      ),
                                      const SizedBox(width: 15),
                                      Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
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
                                  if (_prizes.containsKey(currentPlayerId)) ...[
                                    const SizedBox(height: 10),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 16, vertical: 8),
                                      decoration: BoxDecoration(
                                        color: Colors.black45,
                                        borderRadius: BorderRadius.circular(12),
                                        border: Border.all(
                                            color: const Color(0xFFFFD700)),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          const Text("💰",
                                              style: TextStyle(fontSize: 20)),
                                          const SizedBox(width: 8),
                                          Text(
                                            "+${_prizes[currentPlayerId]} 🍀",
                                            style: const TextStyle(
                                              color: Color(0xFFFFD700),
                                              fontSize: 20,
                                              fontWeight: FontWeight.bold,
                                              shadows: [
                                                Shadow(
                                                    color: Colors.black,
                                                    blurRadius: 2)
                                              ],
                                            ),
                                          ),
                                        ],
                                      ),
                                    )
                                  ] else if (widget.prizeWon != null &&
                                      widget.prizeWon! > 0) ...[
                                    const SizedBox(height: 10),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 16, vertical: 8),
                                      decoration: BoxDecoration(
                                        color: Colors.black45,
                                        borderRadius: BorderRadius.circular(12),
                                        border: Border.all(
                                            color: const Color(0xFFFFD700)),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          const Text("💰",
                                              style: TextStyle(fontSize: 20)),
                                          const SizedBox(width: 8),
                                          Text(
                                            "+${widget.prizeWon} 🍀",
                                            style: const TextStyle(
                                              color: Color(0xFFFFD700),
                                              fontSize: 20,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ],
                                      ),
                                    )
                                  ]
                                ]),
                              )
                            else
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 20, vertical: 12),
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.05),
                                  borderRadius: BorderRadius.circular(15),
                                  border: Border.all(color: Colors.white10),
                                ),
                                child: const Text(
                                  'No participaste en esta competencia.\nAquí tienes el podio final:',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                      color: Colors.white70, fontSize: 14),
                                ),
                              ),
                          ],
                        ),

                        const Spacer(),

                        // Top 3 Podium (Fixed at center)
                        if (gameProvider.leaderboard.isNotEmpty)
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
                                  border: Border.all(
                                      color:
                                          AppTheme.accentGold.withOpacity(0.2)),
                                ),
                                child: Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceEvenly,
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    // 2nd place
                                    if (gameProvider.leaderboard.length >= 2)
                                      _buildPodiumPosition(
                                        gameProvider.leaderboard[1],
                                        2,
                                        60,
                                        Colors.grey,
                                        _prizes[gameProvider.leaderboard[1].id
                                            .toString()],
                                      )
                                    else if (gameProvider.leaderboard.length >=
                                        3)
                                      const SizedBox(width: 60),

                                    // 1st place
                                    _buildPodiumPosition(
                                      gameProvider.leaderboard[0],
                                      1,
                                      90,
                                      const Color(0xFFFFD700),
                                      _prizes[gameProvider.leaderboard[0].id
                                          .toString()],
                                    ),

                                    // 3rd place
                                    if (gameProvider.leaderboard.length >= 3)
                                      _buildPodiumPosition(
                                        gameProvider.leaderboard[2],
                                        3,
                                        50,
                                        const Color(0xFFCD7F32),
                                        _prizes[gameProvider.leaderboard[2].id
                                            .toString()],
                                      )
                                    else if (gameProvider.leaderboard.length >=
                                        2)
                                      const SizedBox(width: 60),
                                  ],
                                ),
                              ),
                            ],
                          )
                        else if (gameProvider.isLoading)
                          const CircularProgressIndicator()
                        else
                          const Text(
                            'No hay resultados disponibles',
                            style: TextStyle(color: Colors.white54),
                          ),

                        const Spacer(),

                        // Final Info and Button
                        Column(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 20, vertical: 12),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.05),
                                borderRadius: BorderRadius.circular(15),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.stars,
                                      color: Colors.greenAccent, size: 20),
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
                                    MaterialPageRoute(
                                        builder: (_) =>
                                            const ScenariosScreen()),
                                    (route) => false,
                                  );
                                },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppTheme.accentGold,
                                  foregroundColor: Colors.black,
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 18),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                  elevation: 8,
                                  shadowColor:
                                      AppTheme.accentGold.withOpacity(0.5),
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

  Widget _buildPodiumPosition(
      player, int position, double height, Color color, int? prizeAmount) {
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
                    // Sanitize avatarId (remove path and extension if present)
                    String? avatarId = player.avatarId;
                    if (avatarId != null) {
                      avatarId = avatarId.split('/').last; // Remove path
                      avatarId = avatarId.replaceAll('.png', '').replaceAll('.jpg', ''); // Remove extension
                    }

                    debugPrint("🏆 Podium Avatar Build: Original='${player.avatarId}' -> Sanitized='$avatarId'");

                    if (avatarId != null && avatarId.isNotEmpty) {
                      return Image.asset(
                        'assets/images/avatars/$avatarId.png',
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) {
                          debugPrint("⚠️ Failed to load avatar asset: assets/images/avatars/$avatarId.png");
                          return const Icon(Icons.person, color: Colors.white70, size: 25);
                        },
                      );
                    }
                    if (player.avatarUrl.isNotEmpty &&
                        player.avatarUrl.startsWith('http')) {
                      return Image.network(
                        player.avatarUrl,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => const Icon(Icons.person,
                            color: Colors.white70, size: 25),
                      );
                    }
                    return const Icon(Icons.person,
                        color: Colors.white70, size: 25);
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

        // PRIZE DISPLAY ON PODIUM
        if (prizeAmount != null && prizeAmount > 0)
          Container(
            margin: const EdgeInsets.only(bottom: 4),
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: Colors.black54,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: color, width: 1),
            ),
            child: Text(
              "+$prizeAmount 🍀",
              style: TextStyle(
                  color: color, fontSize: 10, fontWeight: FontWeight.bold),
            ),
          ),

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
