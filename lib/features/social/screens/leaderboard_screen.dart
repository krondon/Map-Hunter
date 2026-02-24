import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:treasure_hunt_rpg/features/game/providers/game_provider.dart';
import 'package:treasure_hunt_rpg/features/auth/providers/player_provider.dart';
import 'package:treasure_hunt_rpg/core/theme/app_theme.dart';
import '../widgets/leaderboard_card.dart';
import '../../../shared/widgets/animated_cyber_background.dart';
import '../../../shared/models/player.dart';
import '../../auth/providers/player_provider.dart';

class LeaderboardScreen extends StatefulWidget {
  const LeaderboardScreen({super.key});

  @override
  State<LeaderboardScreen> createState() => _LeaderboardScreenState();
}

class _LeaderboardScreenState extends State<LeaderboardScreen> {
  
  @override
  void initState() {
    super.initState();
    // Cargar el ranking y comenzar el polling cada 20s
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<GameProvider>(context, listen: false).startLeaderboardUpdates();
    });
  }

  @override
  void dispose() {
    // Detener el timer al salir para ahorrar recursos
    Provider.of<GameProvider>(context, listen: false).stopLeaderboardUpdates();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final gameProvider = Provider.of<GameProvider>(context);
    final leaderboard = gameProvider.leaderboard;
    final isDarkMode = true; // UI always dark-styled
    const Color currentText = Colors.white;
    const Color currentTextSec = Colors.white70;
    const Color currentSurface = AppTheme.dSurface1;
    final currentUserGameId = gameProvider.targetPlayerId; 
    
    // FILTER LOGIC FOR INVISIBILITY
    final activePowers = gameProvider.activePowerEffects;
    final currentUserId = Provider.of<PlayerProvider>(context, listen: false).currentPlayer?.userId ?? '';

    bool isVisible(Player p) {
       // Always see myself
       if (p.userId == currentUserId) return true;

       // Check active powers for invisibility
       final isStealthed = activePowers.any((e) {
          final target = e.targetId.trim().toLowerCase();
          final pid = p.id.trim().toLowerCase();
          final pgid = (p.gamePlayerId ?? '').trim().toLowerCase();
          
          final isMatch = (target == pid || target == pgid);
          return isMatch && (e.powerSlug == 'invisibility' || e.powerSlug == 'stealth') && !e.isExpired;
       });

       if (isStealthed) return false;
       if (p.isInvisible) return false;
       
       return true;
    }

    final filteredLeaderboard = leaderboard.where(isVisible).toList();
    // Re-assign to use filtered list for UI
    final displayLeaderboard = filteredLeaderboard;
    
    return AnimatedCyberBackground(
      child: Stack(
        children: [
          Positioned.fill(
            child: Image.asset(
              Provider.of<PlayerProvider>(context).isDarkMode ? 'assets/images/fotogrupalnoche.png' : 'assets/images/personajesgrupal.png',
              fit: BoxFit.cover,
              alignment: Alignment.center,
            ),
          ),
          SafeArea(
            child: Column(
              children: [
            // Winner Celebration Section
            if (displayLeaderboard.isNotEmpty && displayLeaderboard[0].totalXP >= gameProvider.totalClues && gameProvider.totalClues > 0)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
                margin: const EdgeInsets.only(bottom: 10),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [AppTheme.accentGold.withOpacity(0.2), Colors.transparent],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ),
                ),
                child: Column(
                  children: [
                    TweenAnimationBuilder<double>(
                      tween: Tween(begin: 0.0, end: 1.0),
                      duration: const Duration(seconds: 1),
                      curve: Curves.elasticOut,
                      builder: (context, value, child) {
                        return Transform.scale(scale: value, child: child);
                      },
                      child: const Icon(Icons.emoji_events, size: 60, color: AppTheme.accentGold),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      "¡FELICIDADES ${displayLeaderboard[0].name.toUpperCase()}!",
                      style: const TextStyle(
                        color: AppTheme.accentGold,
                        fontWeight: FontWeight.w900,
                        fontSize: 20,
                        letterSpacing: 2,
                        shadows: [Shadow(blurRadius: 10, color: AppTheme.accentGold)],
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 5),
                    const Text(
                      "Ha recolectado TODOS los tréboles",
                      style: TextStyle(color: Colors.white70, fontSize: 12),
                    ),
                  ],
                ),
              ),

            // Header
            Padding(
              padding: const EdgeInsets.all(20.0),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Ranking',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 28,
                            fontWeight: FontWeight.w900,
                            fontFamily: 'Orbitron',
                            letterSpacing: 1.5,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Más pistas completadas',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      gradient: AppTheme.goldGradient,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: AppTheme.accentGold.withOpacity(0.3),
                          blurRadius: 15,
                          spreadRadius: 2,
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.emoji_events,
                      color: Colors.white,
                      size: 32,
                    ),
                  ),
                ],
              ),
            ),
            
            // Top 3 Podium
            if (displayLeaderboard.length >= 3)
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 16),
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: currentSurface,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    // 2nd place
                    _buildPodiumPosition(
                      displayLeaderboard[1],
                      2,
                      80,
                      Colors.grey,
                    ),
                    // 1st place
                    _buildPodiumPosition(
                      displayLeaderboard[0],
                      1,
                      100,
                      AppTheme.accentGold,
                    ),
                    // 3rd place
                    _buildPodiumPosition(
                      displayLeaderboard[2],
                      3,
                      70,
                      const Color(0xFFCD7F32),
                    ),
                  ],
                ),
              ),
            
            // Si hay menos de 3, mostrar mensaje o lista simple
            if (displayLeaderboard.isEmpty)
               Expanded(child: Center(child: Text("Cargando ranking...", style: TextStyle(color: currentTextSec)))),

            // Rest of the leaderboard
            if (displayLeaderboard.isNotEmpty)
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: displayLeaderboard.length,
                itemBuilder: (context, index) {
                  final player = displayLeaderboard[index];
                  return LeaderboardCard(
                    player: player,
                    rank: index + 1,
                    isTopThree: index < 3,
                  );
                },
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}
  
  Widget _buildPodiumPosition(dynamic player, int position, double height, Color color) {
    const bool isDarkMode = true;
    const Color currentText = Colors.white;
    const Color currentTextSec = Colors.white70;

    return Column(
      children: [
        Stack(
          alignment: Alignment.center,
          children: [
            Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: color, width: 3),
                boxShadow: [
                  BoxShadow(
                    color: color.withOpacity(0.4),
                    blurRadius: 10,
                    spreadRadius: 2,
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(30),
                child: Builder(
                  builder: (context) {
                    final avatarId = player.avatarId;
                    
                    // 1. Prioridad: Avatar Local
                    if (avatarId != null && avatarId.isNotEmpty) {
                      return Image.asset(
                        'assets/images/avatars/$avatarId.png',
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => const Center(child: Icon(Icons.person, color: Colors.white70, size: 30)),
                      );
                    }
                    
                    // 2. Fallback: Foto de perfil (URL)
                    if (player.avatarUrl.isNotEmpty && player.avatarUrl.startsWith('http')) {
                      return Image.network(
                        player.avatarUrl,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => const Center(child: Icon(Icons.person, color: Colors.white70, size: 30)),
                      );
                    }
                    
                    // 3. Fallback: Icono genérico
                    return const Center(child: Icon(Icons.person, color: Colors.white70, size: 30));
                  },
                ),
              ),
            ),
            Positioned(
              bottom: 0,
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: color,
                  shape: BoxShape.circle,
                ),
                child: Text(
                  '$position',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        SizedBox(
          width: 80,
          child: Text(
            player.name,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: currentText,
            ),
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Lvl ${player.level}',
          style: TextStyle(
            fontSize: 11,
            color: currentTextSec,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          width: 80,
          height: height,
          decoration: BoxDecoration(
            color: color.withOpacity(0.2),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(8)),
            border: Border.all(color: color, width: 2),
          ),
          child: Center(
            child: Text(
              '${player.totalXP} Pistas', // CAMBIO AQUI: XP -> Pistas
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