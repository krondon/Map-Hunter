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
                  
                  // 1. Prioridad: Avatar Local
                  if (avatarId != null && avatarId.isNotEmpty) {
                    return Image.asset(
                      'assets/images/avatars/$avatarId.png',
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => const Center(child: Icon(Icons.person, color: Colors.white70, size: 24)),
                    );
                  }
                  
                  // 2. Fallback: Foto de perfil (URL)
                  if (player.avatarUrl.isNotEmpty && player.avatarUrl.startsWith('http')) {
                    return Image.network(
                      player.avatarUrl,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => const Center(child: Icon(Icons.person, color: Colors.white70, size: 24)),
                    );
                  }
                  
                  // 3. Fallback: Icono genérico
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
              // Sellos Visuales (Iconos)
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
    );
  }

  List<Color> _getStampGradient(int index) {
      const gradients = [
        [Color(0xFF3B82F6), Color(0xFF06B6D4)],
        [Color(0xFF06B6D4), Color(0xFF10B981)],
        [Color(0xFF10B981), Color(0xFF84CC16)],
        [Color(0xFF84CC16), Color(0xFFF59E0B)],
        [Color(0xFFF59E0B), Color(0xFFEF4444)],
        [Color(0xFFEF4444), Color(0xFFEC4899)],
        [Color(0xFFEC4899), Color(0xFFD946EF)],
        [Color(0xFFD946EF), Color(0xFF8B5CF6)],
        [Color(0xFF8B5CF6), Color(0xFF6366F1)],
      ];
      return gradients[index % gradients.length];
  }
}