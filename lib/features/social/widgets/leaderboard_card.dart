import 'dart:ui';
import 'package:flutter/material.dart';
import '../../../shared/models/player.dart';
import 'package:treasure_hunt_rpg/core/theme/app_theme.dart';

class LeaderboardCard extends StatelessWidget {
  final Player player;
  final int rank;
  final bool isTopThree;
  
  const LeaderboardCard({
    super.key,
    required this.player,
    required this.rank,
    this.isTopThree = false,
  });

  Color _getRankColor() {
    switch (rank) {
      case 1:
        return AppTheme.accentGold;
      case 2:
        return Colors.grey;
      case 3:
        return const Color(0xFFCD7F32);
      default:
        return AppTheme.primaryPurple;
    }
  }

  @override
  Widget build(BuildContext context) {
    final Color accentColor = _getRankColor();

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: accentColor.withOpacity(0.05),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: accentColor.withOpacity(0.2),
          width: 1,
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFF150826).withOpacity(0.7),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: accentColor.withOpacity(0.6),
                width: 2,
              ),
            ),
            child: Row(
              children: [
                // Rank
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: isTopThree ? accentColor : Colors.white12,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Center(
                    child: Text(
                      '$rank',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: isTopThree ? Colors.white : Colors.white54,
                      ),
                    ),
                  ),
                ),
                
                const SizedBox(width: 12),
                
                // Avatar
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.grey[800],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(22),
                    child: Builder(
                      builder: (context) {
                        final avatarId = player.avatarId;
                        
                        if (avatarId != null && avatarId.isNotEmpty) {
                          return Image.asset(
                            'assets/images/avatars/$avatarId.png',
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => const Center(child: Icon(Icons.person, color: Colors.white70, size: 24)),
                          );
                        }
                        
                        if (player.avatarUrl.isNotEmpty && player.avatarUrl.startsWith('http')) {
                          return Image.network(
                            player.avatarUrl,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => const Center(child: Icon(Icons.person, color: Colors.white70, size: 24)),
                          );
                        }
                        
                        return const Center(child: Icon(Icons.person, color: Colors.white70, size: 24));
                      },
                    ),
                  ),
                ),
                
                const SizedBox(width: 12),
                
                // Player info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        player.name,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      Text(
                        player.profession,
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.white70,
                        ),
                      ),
                    ],
                  ),
                ),
                
                // Stats
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppTheme.primaryPurple.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        'Lvl ${player.level}',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.secondaryPink,
                        ),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: List.generate(player.totalXP, (index) {
                        return Padding(
                          padding: const EdgeInsets.only(left: 2),
                          child: Container(
                            width: 12,
                            height: 12,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: LinearGradient(colors: _getStampGradient(index)),
                              boxShadow: [
                                 BoxShadow(color: _getStampGradient(index)[0].withOpacity(0.5), blurRadius: 4)
                              ]
                            ),
                          ),
                        );
                      }),
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

  List<Color> _getStampGradient(int index) {
      return [const Color(0xFFFFD700), const Color(0xfff5c71a)];
  }
}