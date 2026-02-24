import 'package:flutter/material.dart';
import 'dart:ui';
import 'package:confetti/confetti.dart';
import 'package:provider/provider.dart';
import 'dart:math';
import '../providers/game_provider.dart';
import '../../auth/providers/player_provider.dart';
import '../../../core/theme/app_theme.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'scenarios_screen.dart';
import 'game_mode_selector_screen.dart';
import '../../auth/screens/login_screen.dart';

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
  late ConfettiController _fireworkLeftController;
  late ConfettiController _fireworkRightController;
  late ConfettiController _fireworkCenterController;
  late int _currentPosition; // Mutable state for position
  late int _finalPosition;
  int _completedClues = 0;
  bool _isLoading = true; // NEW: Start with loading state
  bool _podiumFetchCompleted = false; // Guards _isLoading until podium DB query finishes
  Map<String, int> _prizes = {};

  // Podium Winners Data (from game_players.final_placement)
  List<Map<String, dynamic>> _podiumWinners = [];
  bool _isLoadingPodium = true;

  @override
  void initState() {
    super.initState();
    debugPrint("🏆 WinnerCelebrationScreen INIT: Prize = ${widget.prizeWon}");
    _currentPosition = widget.playerPosition;
    _finalPosition = widget.playerPosition > 0 ? widget.playerPosition : 0;
    _completedClues = widget.totalCluesCompleted;
    _confettiController =
        ConfettiController(duration: const Duration(seconds: 10));
    _fireworkLeftController =
        ConfettiController(duration: const Duration(seconds: 2));
    _fireworkRightController =
        ConfettiController(duration: const Duration(seconds: 2));
    _fireworkCenterController =
        ConfettiController(duration: const Duration(seconds: 2));

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
      // Fetch podium winners from DB (final_placement)
      _fetchPodiumWinners();

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

      // Safety timeout: If after 30 seconds we still loading, force show content
      Future.delayed(const Duration(seconds: 30), () {
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

  /// Fetches podium winners directly from game_players.final_placement
  Future<void> _fetchPodiumWinners() async {
    try {
      final supabase = Supabase.instance.client;

      int retries = 0;
      const int maxRetries = 15;
      List<dynamic> topPlayers = [];

      while (retries < maxRetries) {
        if (!mounted) return;

        // Query game_players with final_placement set, ordered by placement
        topPlayers = await supabase
            .from('game_players')
            .select('user_id, final_placement, completed_clues_count')
            .eq('event_id', widget.eventId)
            .not('final_placement', 'is', null)
            .neq('status', 'spectator')
            .order('final_placement', ascending: true)
            .limit(3);

        if (topPlayers.isNotEmpty) {
          // Also verify OUR OWN placement is included (for last finisher).
          // The last finisher's final_placement may not have propagated yet.
          final pp = Provider.of<PlayerProvider>(context, listen: false);
          final curUid = pp.currentPlayer?.userId ?? pp.currentPlayer?.id;
          final myPlacementExists = curUid == null ||
              topPlayers.any((p) => p['user_id'].toString() == curUid);
          if (myPlacementExists || retries >= 5) {
            break; // Data arrived (or partial after 5 retries — show what we have)
          }
          debugPrint(
              "⏳ Podium: Data found but MY placement missing. Waiting... (Retry $retries/$maxRetries)");
        }

        retries++;
        debugPrint("⏳ Podium DB empty. Waiting for backend... (Retry $retries/$maxRetries)");
        await Future.delayed(const Duration(seconds: 1));
      }

      debugPrint("🏆 Podium DB: Found ${topPlayers.length} finishers with final_placement");

      if (topPlayers.isEmpty) {
        if (mounted) {
          setState(() {
            _podiumWinners = [];
            _isLoadingPodium = false;
            _podiumFetchCompleted = true;
            if (_isLoading) _isLoading = false;
          });
        }
        return;
      }

      // Fetch profiles for these users
      final List<String> userIds =
          topPlayers.map((p) => p['user_id'].toString()).toList();

      Map<String, Map<String, dynamic>> profilesMap = {};
      if (userIds.isNotEmpty) {
        final profiles = await supabase
            .from('profiles')
            .select('id, name, avatar_id, avatar_url')
            .inFilter('id', userIds);

        for (var p in profiles) {
          profilesMap[p['id'] as String] = p;
        }
      }

      // Build podium data
      final List<Map<String, dynamic>> winners = [];
      for (var p in topPlayers) {
        final uid = p['user_id'] as String;
        final profile = profilesMap[uid] ?? {};
        winners.add({
          'user_id': uid,
          'name': profile['name'] ?? 'Jugador',
          'avatar_id': profile['avatar_id'],
          'avatar_url': profile['avatar_url'] ?? '',
          'final_placement': (p['final_placement'] as num).toInt(),
          'completed_clues_count': (p['completed_clues_count'] as num?)?.toInt() ?? 0,
        });
      }

      // Also fetch the current user's final_placement to set _currentPosition
      final playerProvider = Provider.of<PlayerProvider>(context, listen: false);
      final currentUserId = playerProvider.currentPlayer?.userId ?? playerProvider.currentPlayer?.id;

      if (currentUserId != null) {
        try {
          final myPlacement = await supabase
              .from('game_players')
              .select('final_placement, completed_clues_count')
              .eq('event_id', widget.eventId)
              .eq('user_id', currentUserId)
              .maybeSingle();

          if (myPlacement != null) {
            final int dbPosition = myPlacement['final_placement'] != null ? (myPlacement['final_placement'] as num).toInt() : 0;
            final int clues = myPlacement['completed_clues_count'] != null ? (myPlacement['completed_clues_count'] as num).toInt() : 0;
            
            debugPrint("🏆 My DB final_placement: $dbPosition, Clues completed: $clues");
            if (mounted) {
              setState(() {
                if (dbPosition > 0) _finalPosition = dbPosition;
                if (clues > 0) _completedClues = clues;
                _isLoading = false;
              });
              if (dbPosition >= 1 && dbPosition <= 3) {
                _confettiController.play();
                _startFireworks();
              }
            }
          }
        } catch (e) {
          debugPrint("⚠️ Error fetching my placement: $e");
        }
      }

      if (mounted) {
        setState(() {
          _podiumWinners = winners;
          _isLoadingPodium = false;
          _podiumFetchCompleted = true;
          // Release the main loading gate now that podium data is resolved
          if (_isLoading) _isLoading = false;
        });
        debugPrint("🏆 Podium winners loaded: ${winners.map((w) => '${w['name']}=#${w['final_placement']}').join(', ')}");
      }
    } catch (e) {
      debugPrint("⚠️ Error fetching podium winners: $e");
      if (mounted) {
        setState(() {
          _isLoadingPodium = false;
          _podiumFetchCompleted = true;
          if (_isLoading) _isLoading = false;
        });
      }
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
          // Update _finalPosition from leaderboard as fallback if DB hasn't provided it yet
          if (_finalPosition == 0 && newPos > 0) {
            _finalPosition = newPos;
          }
          // Only release loading gate if podium fetch has completed
          // This prevents showing "No participaste" before DB data arrives
          if (_podiumFetchCompleted) {
            _isLoading = false;
          }
        });

        if (newPos >= 1 && newPos <= 3) {
          _confettiController.play();
          _startFireworks();
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

  void _startFireworks() {
    // Staggered firework bursts for a spectacular effect
    Future.delayed(const Duration(milliseconds: 300), () {
      if (mounted) _fireworkCenterController.play();
    });
    Future.delayed(const Duration(milliseconds: 800), () {
      if (mounted) _fireworkLeftController.play();
    });
    Future.delayed(const Duration(milliseconds: 1300), () {
      if (mounted) _fireworkRightController.play();
    });
    // Second wave
    Future.delayed(const Duration(milliseconds: 2500), () {
      if (mounted) _fireworkCenterController.play();
    });
    Future.delayed(const Duration(milliseconds: 3000), () {
      if (mounted) _fireworkRightController.play();
    });
    Future.delayed(const Duration(milliseconds: 3500), () {
      if (mounted) _fireworkLeftController.play();
    });
    // Third wave
    Future.delayed(const Duration(milliseconds: 5000), () {
      if (mounted) _fireworkLeftController.play();
    });
    Future.delayed(const Duration(milliseconds: 5500), () {
      if (mounted) _fireworkCenterController.play();
    });
    Future.delayed(const Duration(milliseconds: 6000), () {
      if (mounted) _fireworkRightController.play();
    });
  }

  @override
  void dispose() {
    // Remove listener safely
    try {
      Provider.of<GameProvider>(context, listen: false)
          .removeListener(_updatePositionFromLeaderboard);
    } catch (_) {}

    _confettiController.dispose();
    _fireworkLeftController.dispose();
    _fireworkRightController.dispose();
    _fireworkCenterController.dispose();
    super.dispose();
  }

  String _getMedalEmoji() {
    switch (_finalPosition) {
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
    if (_finalPosition == 1) {
      return '¡Eres el Campeón!';
    } else if (_finalPosition >= 1 && _finalPosition <= 3) {
      return '¡Podio Merecido!';
    } else {
      return '¡Carrera Completada!';
    }
  }

  Color _getPositionColor() {
    switch (_finalPosition) {
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

  void _showLogoutDialog() {
    final playerProvider = Provider.of<PlayerProvider>(context, listen: false);
    const Color currentRed = Color(0xFFE33E5D);
    const Color cardBg = Color(0xFF151517);

    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 40),
        child: Container(
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: currentRed.withOpacity(0.2),
            borderRadius: BorderRadius.circular(28),
            border: Border.all(color: currentRed.withOpacity(0.5), width: 1),
          ),
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: cardBg,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: currentRed, width: 2),
              boxShadow: [
                BoxShadow(
                  color: currentRed.withOpacity(0.1),
                  blurRadius: 20,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: currentRed, width: 2),
                  ),
                  child: const Icon(
                    Icons.logout_rounded,
                    color: currentRed,
                    size: 32,
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Cerrar Sesión',
                  style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),
                const Text(
                  '¿Estás seguro que deseas cerrar sesión?',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.white70, fontSize: 14),
                ),
                const SizedBox(height: 24),
                Row(
                  children: [
                    Expanded(
                      child: TextButton(
                        onPressed: () => Navigator.pop(ctx),
                        child: const Text('CANCELAR', style: TextStyle(color: Colors.white54, fontWeight: FontWeight.bold)),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () async {
                          Navigator.pop(ctx);
                          await playerProvider.logout();
                          if (mounted) {
                            Navigator.of(context).pushAndRemoveUntil(
                              MaterialPageRoute(builder: (_) => const LoginScreen()),
                              (route) => false,
                            );
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: currentRed,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        child: const Text('SALIR', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final gameProvider = Provider.of<GameProvider>(context);
    final playerProvider = Provider.of<PlayerProvider>(context);
    final currentPlayerId = playerProvider.currentPlayer?.userId ?? playerProvider.currentPlayer?.id ?? '';
    final isNightImage = playerProvider.isDarkMode;

    debugPrint("🏆 WinnerScreen Build: eventId=${widget.eventId}, leaderboardSize=${gameProvider.leaderboard.length}, isLoading=${gameProvider.isLoading}, internalIsLoading=$_isLoading");

    return WillPopScope(
      onWillPop: () async => false, // Prevent back button
      child: Scaffold(
        backgroundColor: AppTheme.dSurface0,
        body: Stack(
          children: [
            // BACKGROUND IMAGE (day/night)
            Positioned.fill(
              child: isNightImage
                  ? Opacity(
                      opacity: 0.5,
                      child: Image.asset(
                        'assets/images/hero.png',
                        fit: BoxFit.cover,
                        alignment: Alignment.center,
                      ),
                    )
                  : Stack(
                      children: [
                        Image.asset(
                          'assets/images/loginclaro.png',
                          fit: BoxFit.cover,
                          alignment: Alignment.center,
                          width: double.infinity,
                          height: double.infinity,
                        ),
                        Container(color: Colors.black.withOpacity(0.3)),
                      ],
                    ),
            ),
            // Dark overlay for readability
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.black.withOpacity(0.4),
                      Colors.black.withOpacity(0.7),
                      Colors.black.withOpacity(0.5),
                    ],
                  ),
                ),
              ),
            ),
              // Confetti overlay - main rain
              Align(
                alignment: Alignment.topCenter,
                child: ConfettiWidget(
                  confettiController: _confettiController,
                  blastDirection: pi / 2, // Down
                  maxBlastForce: 5,
                  minBlastForce: 2,
                  emissionFrequency: 0.03,
                  numberOfParticles: 30,
                  gravity: 0.2,
                  shouldLoop: true,
                  colors: const [
                    Colors.green,
                    Colors.blue,
                    Colors.pink,
                    Colors.orange,
                    Colors.purple,
                    Color(0xFFFFD700),
                    Colors.cyan,
                    Colors.redAccent,
                  ],
                ),
              ),
              // Firework - Left burst
              Align(
                alignment: const Alignment(-0.8, 0.3),
                child: ConfettiWidget(
                  confettiController: _fireworkLeftController,
                  blastDirectionality: BlastDirectionality.explosive,
                  maxBlastForce: 25,
                  minBlastForce: 10,
                  emissionFrequency: 0.0,
                  numberOfParticles: 40,
                  gravity: 0.15,
                  particleDrag: 0.05,
                  colors: const [
                    Color(0xFFFFD700),
                    Colors.orange,
                    Colors.redAccent,
                    Colors.yellowAccent,
                  ],
                ),
              ),
              // Firework - Right burst
              Align(
                alignment: const Alignment(0.8, 0.2),
                child: ConfettiWidget(
                  confettiController: _fireworkRightController,
                  blastDirectionality: BlastDirectionality.explosive,
                  maxBlastForce: 25,
                  minBlastForce: 10,
                  emissionFrequency: 0.0,
                  numberOfParticles: 40,
                  gravity: 0.15,
                  particleDrag: 0.05,
                  colors: const [
                    Colors.cyan,
                    Colors.blue,
                    Colors.purpleAccent,
                    Colors.greenAccent,
                  ],
                ),
              ),
              // Firework - Center burst
              Align(
                alignment: const Alignment(0.0, -0.2),
                child: ConfettiWidget(
                  confettiController: _fireworkCenterController,
                  blastDirectionality: BlastDirectionality.explosive,
                  maxBlastForce: 30,
                  minBlastForce: 12,
                  emissionFrequency: 0.0,
                  numberOfParticles: 50,
                  gravity: 0.12,
                  particleDrag: 0.05,
                  colors: const [
                    Color(0xFFFFD700),
                    Colors.pink,
                    Colors.white,
                    Colors.amber,
                    Colors.deepPurple,
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
                        // Title
                        const Text(
                          'Resultados del Evento',
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFFFFD700),
                          ),
                          textAlign: TextAlign.center,
                        ),
                            const SizedBox(height: 10),
                            if (_finalPosition > 0)
                              ClipRRect(
                                borderRadius: BorderRadius.circular(24),
                                child: BackdropFilter(
                                  filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                                  child: Container(
                                    padding: const EdgeInsets.all(5),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF0D0D0F).withOpacity(0.6),
                                      borderRadius: BorderRadius.circular(24),
                                      border: Border.all(
                                          color: _getPositionColor().withOpacity(0.6),
                                          width: 1.5),
                                    ),
                                    child: Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 30, vertical: 15),
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(
                                      color: _getPositionColor().withOpacity(0.2),
                                      width: 1.0),
                                  color: _getPositionColor().withOpacity(0.02),
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
                                            '#$_finalPosition',
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
                                  ),
                                  ),
                                ),
                              )
                            else if (_isLoadingPodium)
                              // Still loading podium data — don't show "No participaste" yet
                              ClipRRect(
                                borderRadius: BorderRadius.circular(24),
                                child: BackdropFilter(
                                  filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                                  child: Container(
                                    padding: const EdgeInsets.all(5),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF0D0D0F).withOpacity(0.6),
                                      borderRadius: BorderRadius.circular(24),
                                      border: Border.all(
                                          color: AppTheme.accentGold.withOpacity(0.6),
                                          width: 1.5),
                                    ),
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 20, vertical: 16),
                                      decoration: BoxDecoration(
                                        borderRadius: BorderRadius.circular(20),
                                        border: Border.all(
                                            color: AppTheme.accentGold.withOpacity(0.2),
                                            width: 1.0),
                                        color: AppTheme.accentGold.withOpacity(0.02),
                                      ),
                                      child: const Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          SizedBox(
                                            width: 18,
                                            height: 18,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2,
                                              color: AppTheme.accentGold,
                                            ),
                                          ),
                                          SizedBox(width: 12),
                                          Text(
                                            'Cargando tu posición...',
                                            textAlign: TextAlign.center,
                                            style: TextStyle(
                                                color: Colors.white70, fontSize: 14),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              )
                            else
                              ClipRRect(
                                borderRadius: BorderRadius.circular(24),
                                child: BackdropFilter(
                                  filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                                  child: Container(
                                    padding: const EdgeInsets.all(5),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF0D0D0F).withOpacity(0.6),
                                      borderRadius: BorderRadius.circular(24),
                                      border: Border.all(
                                          color: AppTheme.primaryPurple.withOpacity(0.6),
                                          width: 1.5),
                                    ),
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 20, vertical: 12),
                                      decoration: BoxDecoration(
                                        borderRadius: BorderRadius.circular(20),
                                        border: Border.all(
                                            color: AppTheme.primaryPurple.withOpacity(0.2),
                                            width: 1.0),
                                        color: AppTheme.primaryPurple.withOpacity(0.02),
                                      ),
                                      child: const Text(
                                        'No participaste en esta competencia.\nAquí tienes el podio final:',
                                        textAlign: TextAlign.center,
                                        style: TextStyle(
                                            color: Colors.white70, fontSize: 14),
                                      ),
                                    ),
                                  ),
                                ),
                              ),

                        const Spacer(),

                        // Top 3 Podium (from game_players.final_placement)
                        if (_podiumWinners.isNotEmpty)
                          Builder(builder: (context) {
                            final first = _podiumWinners.firstWhere(
                                (w) => w['final_placement'] == 1,
                                orElse: () => {});
                            final second = _podiumWinners.firstWhere(
                                (w) => w['final_placement'] == 2,
                                orElse: () => {});
                            final third = _podiumWinners.firstWhere(
                                (w) => w['final_placement'] == 3,
                                orElse: () => {});

                            return Column(
                              children: [
                                const Text(
                                  'PODIO DE LA CARRERA',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: 2,
                                    fontFamily: 'Orbitron',
                                  ),
                                ),
                                const SizedBox(height: 20),
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(24),
                                  child: BackdropFilter(
                                    filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                                    child: Container(
                                      padding: const EdgeInsets.all(5),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFF0D0D0F).withOpacity(0.6),
                                        borderRadius: BorderRadius.circular(24),
                                        border: Border.all(
                                            color: AppTheme.accentGold.withOpacity(0.6),
                                            width: 1.5),
                                      ),
                                      child: Container(
                                        clipBehavior: Clip.antiAlias,
                                        decoration: BoxDecoration(
                                          borderRadius: BorderRadius.circular(20),
                                          border: Border.all(
                                              color: AppTheme.accentGold.withOpacity(0.2),
                                              width: 1.0),
                                          color: AppTheme.accentGold.withOpacity(0.02),
                                        ),
                                        child: IntrinsicHeight(
                                          child: Row(
                                            crossAxisAlignment: CrossAxisAlignment.end,
                                            children: [
                                              // 2nd place
                                              if (second.isNotEmpty)
                                                Expanded(
                                                  child: _buildPodiumColumn(
                                                    second, 2, 90,
                                                    const Color(0xFFC0C0C0),
                                                  ),
                                                )
                                              else
                                                const Expanded(child: SizedBox()),
                                              // 1st place
                                              if (first.isNotEmpty)
                                                Expanded(
                                                  child: _buildPodiumColumn(
                                                    first, 1, 120,
                                                    const Color(0xFFFFD700),
                                                  ),
                                                )
                                              else
                                                const Expanded(child: SizedBox()),
                                              // 3rd place
                                              if (third.isNotEmpty)
                                                Expanded(
                                                  child: _buildPodiumColumn(
                                                    third, 3, 70,
                                                    const Color(0xFFCD7F32),
                                                  ),
                                                )
                                              else
                                                const Expanded(child: SizedBox()),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            );
                          })
                        else if (_isLoadingPodium)
                          const CircularProgressIndicator(color: AppTheme.accentGold)
                        else
                          const Text(
                            'No hay resultados disponibles',
                            style: TextStyle(color: Colors.white54),
                          ),

                        const Spacer(),

                        // Final Info and Button
                        Column(
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(16),
                              child: BackdropFilter(
                                filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 20, vertical: 12),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withOpacity(0.08),
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(Icons.stars,
                                          color: Colors.white, size: 20),
                                      const SizedBox(width: 10),
                                      Text(
                                        '$_completedClues Pistas completadas',
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 16,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 24),
                            SizedBox(
                              width: double.infinity,
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(24),
                                child: BackdropFilter(
                                  filter:
                                      ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                                  child: Container(
                                    padding: const EdgeInsets.all(5),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF0D0D0F).withOpacity(0.6),
                                      borderRadius: BorderRadius.circular(24),
                                      border: Border.all(
                                          color: const Color(0xFF9D4EDD).withOpacity(0.6),
                                          width: 1.5),
                                    ),
                                    child: Container(
                                      decoration: BoxDecoration(
                                        borderRadius: BorderRadius.circular(20),
                                        border: Border.all(
                                            color: const Color(0xFF9D4EDD).withOpacity(0.2),
                                            width: 1.0),
                                        color: const Color(0xFF9D4EDD).withOpacity(0.02),
                                      ),
                                      child: TextButton(
                                        onPressed: () {
                                          Navigator.of(context).pushAndRemoveUntil(
                                            MaterialPageRoute(
                                                builder: (_) =>
                                                    const ScenariosScreen()),
                                            (route) => false,
                                          );
                                        },
                                        style: TextButton.styleFrom(
                                          foregroundColor: Colors.white,
                                          padding: const EdgeInsets.symmetric(
                                              vertical: 18),
                                          shape: RoundedRectangleBorder(
                                            borderRadius:
                                                BorderRadius.circular(20),
                                          ),
                                        ),
                                        child: const Text(
                                          'VOLVER AL INICIO',
                                          style: TextStyle(
                                            fontSize: 18,
                                            fontWeight: FontWeight.bold,
                                            letterSpacing: 1.5,
                                            fontFamily: 'Orbitron',
                                            color: Colors.white,
                                          ),
                                        ),
                                      ),
                                    ),
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
              // Logout button - top right corner
              Positioned(
                top: 0,
                right: 0,
                child: SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.only(top: 10, right: 8),
                    child: GestureDetector(
                      onTap: _showLogoutDialog,
                      child: Container(
                        padding: const EdgeInsets.all(2),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: AppTheme.dangerRed.withOpacity(0.3),
                            width: 1,
                          ),
                        ),
                        child: Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: AppTheme.dangerRed.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: AppTheme.dangerRed,
                              width: 2,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: AppTheme.dangerRed.withOpacity(0.3),
                                blurRadius: 8,
                                spreadRadius: 1,
                              )
                            ],
                          ),
                          child: const Icon(
                            Icons.logout_rounded,
                            color: AppTheme.dangerRed,
                            size: 22,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
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

  /// Builds one full podium column from a Map (from _podiumWinners DB data)
  Widget _buildPodiumColumn(Map<String, dynamic> winner, int position, double barHeight, Color color) {
    final String name = winner['name'] ?? 'Jugador';
    String? avatarId = winner['avatar_id']?.toString();
    final String avatarUrl = winner['avatar_url']?.toString() ?? '';

    if (avatarId != null) {
      avatarId = avatarId.split('/').last;
      avatarId = avatarId.replaceAll('.png', '').replaceAll('.jpg', '');
    }

    return Column(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        // Avatar with Laurel Wreath (as per reference design)
        SizedBox(
          width: 82,
          height: 82,
          child: CustomPaint(
            painter: _LaurelWreathPainter(color: color),
            child: Center(
              child: Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.black,
                  border: Border.all(color: color, width: 2.0),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(22),
                  child: Builder(
                    builder: (context) {
                      if (avatarId != null && avatarId!.isNotEmpty) {
                        return Image.asset(
                          'assets/images/avatars/$avatarId.png',
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) =>
                              const Icon(Icons.person, color: Colors.white70, size: 22),
                        );
                      }
                      if (avatarUrl.isNotEmpty && avatarUrl.startsWith('http')) {
                        return Image.network(
                          avatarUrl,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => const Icon(Icons.person,
                              color: Colors.white70, size: 22),
                        );
                      }
                      return const Icon(Icons.person, color: Colors.white70, size: 22);
                    },
                  ),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 4),

        // Name
        SizedBox(
          width: 80,
          child: Text(
            name,
            style: const TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        const SizedBox(height: 4),

        // Pedestal bar with position number at the bottom
        Container(
          width: double.infinity,
          height: barHeight,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                color.withOpacity(0.45),
                color.withOpacity(0.12),
              ],
            ),
            border: Border(
              top: BorderSide(color: color, width: 2),
              left: BorderSide(color: color.withOpacity(0.3), width: 0.5),
              right: BorderSide(color: color.withOpacity(0.3), width: 0.5),
            ),
          ),
          child: Align(
            alignment: Alignment.bottomRight,
            child: Padding(
              padding: const EdgeInsets.only(right: 4),
              child: Text(
                '$position',
                style: TextStyle(
                  fontSize: 56,
                  fontWeight: FontWeight.w900,
                  height: 0.8,
                  color: color.withOpacity(0.7),
                  shadows: [
                    Shadow(
                      color: Colors.black.withOpacity(0.5),
                      blurRadius: 4,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// Custom painter that draws a laurel wreath around the avatar matching the reference design
class _LaurelWreathPainter extends CustomPainter {
  final Color color;

  _LaurelWreathPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width / 2) - 2;

    final stemPaint = Paint()
      ..color = color.withOpacity(0.85)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.8;

    final leafPaint = Paint()
      ..color = color.withOpacity(0.85)
      ..style = PaintingStyle.fill;

    // Draw U-shaped stem arc (open at the top) - brought closer to avatar
    final rect = Rect.fromCircle(center: center, radius: radius * 0.68);
    // Start at ~1:30 o'clock and sweep through the bottom to ~10:30 o'clock
    canvas.drawArc(rect, -4/14 * pi, 22/14 * pi, false, stemPaint);

    // Draw leaves in a circular "clock" distribution with a gap at the top
    final int totalLeaves = 14; 
    for (int i = 0; i < totalLeaves; i++) {
      // Skip the top 3 positions to leave it open at the top (11, 12, 1 o'clock)
      if (i == 0 || i == 1 || i == totalLeaves - 1) continue;
      
      // Distribute evenly around the circle
      final angle = (2 * pi * i / totalLeaves) - pi / 2;
      
      _drawReferenceLeaf(canvas, center, radius * 0.68, angle, leafPaint, isOuter: true);
      _drawReferenceLeaf(canvas, center, radius * 0.68, angle, leafPaint, isOuter: false);
    }
  }

  void _drawReferenceLeaf(
      Canvas canvas, Offset center, double radius, double angle, Paint paint,
      {required bool isOuter}) {
    final x = center.dx + radius * cos(angle);
    final y = center.dy + radius * sin(angle);

    canvas.save();
    canvas.translate(x, y);

    // Point leaf radially with a strong tilt to the right (+0.5 radians)
    double rotation = isOuter ? angle + 0.5 : angle + pi + 0.5;
    
    canvas.rotate(rotation + pi / 2);

    // Make inner leaves slightly smaller for better aesthetics
    final scale = isOuter ? 1.0 : 0.75;
    canvas.scale(scale, scale);

    final path = Path();
    final len = 13.0;
    final width = 5.0;

    // Pointed oval leaf (wider in middle, sharp tip)
    path.moveTo(0, 0);
    path.quadraticBezierTo(width * 1.2, -len * 0.45, 0, -len); // Outer curve
    path.quadraticBezierTo(-width * 1.2, -len * 0.45, 0, 0); // Inner curve
    path.close();

    canvas.drawPath(path, paint);
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

