import 'package:flutter/material.dart';
import '../../../shared/models/player.dart';
import '../../../core/theme/app_theme.dart';

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
        return Colors.transparent;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isTopThree
            ? AppTheme.cardBg.withOpacity(0.8)
            : AppTheme.cardBg.withOpacity(0.5),
        borderRadius: BorderRadius.circular(12),
        border: isTopThree
            ? Border.all(color: _getRankColor().withOpacity(0.3), width: 2)
            : null,
      ),
      child: Row(
        children: [
          // Rank
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: isTopThree ? _getRankColor() : Colors.white12,
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
            width: 44, // Equivalente a radius 22 * 2
            height: 44,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.grey[800],
              image: (player.avatarUrl.isNotEmpty && player.avatarUrl.startsWith('http'))
                  ? DecorationImage(
                      image: NetworkImage(player.avatarUrl),
                      fit: BoxFit.cover,
                      onError: (_, __) {},
                    )
                  : null,
            ),
            child: (player.avatarUrl.isEmpty || !player.avatarUrl.startsWith('http'))
                ? const Center(child: Icon(Icons.person, color: Colors.white70, size: 24))
                : null,
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
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.white.withOpacity(0.6),
                  ),
                ),
              ],
            ),
          ),
          
          // Stats (Ahora muestra Pistas en lugar de XP)
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
              // Aquí mostramos "Pistas" porque el provider inyectó el conteo en totalXP
              Text(
                '${player.totalXP} Pistas', 
                style: const TextStyle(
                  fontSize: 12,
                  color: Colors.white70,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}