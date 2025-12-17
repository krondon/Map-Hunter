import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../features/game/providers/game_provider.dart';
import '../../features/auth/providers/player_provider.dart';
import '../../core/theme/app_theme.dart';

class ProgressHeader extends StatelessWidget {
  const ProgressHeader({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer2<GameProvider, PlayerProvider>(
      builder: (context, gameProvider, playerProvider, child) {
        final player = playerProvider.currentPlayer;
        
        if (player == null) return const SizedBox.shrink();

        // MODIFICACIÓN: Lógica de prioridad para vidas.
        // Si hay un evento activo en GameProvider, usamos sus vidas.
        // Si no (por ejemplo, al cargar), usamos player.lives que ya viene sincronizado por PlayerProvider.
        final int displayLives = (gameProvider.currentEventId != null) 
            ? gameProvider.lives 
            : player.lives;
        
        return Container(
          margin: const EdgeInsets.all(16),
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: AppTheme.primaryGradient,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: AppTheme.primaryPurple.withOpacity(0.3),
                blurRadius: 20,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    radius: 25,
                    backgroundImage: NetworkImage(player.avatarUrl),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          player.name,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        Text(
                          'Nivel ${player.level} • ${player.profession}',
                          style: const TextStyle(
                            fontSize: 14,
                            color: Colors.white70,
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Coins
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.monetization_on, size: 16, color: Colors.amber),
                        const SizedBox(width: 4),
                        Text(
                          '${player.coins}',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                  
                  const SizedBox(width: 8),

                  // Lives
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.favorite, size: 16, color: Colors.redAccent),
                        const SizedBox(width: 4),
                        // MODIFICACIÓN: Usamos displayLives y una Key que incluya el EventID 
                        // para forzar el refresco visual al cambiar de evento.
                        Text(
                          '$displayLives',
                          key: ValueKey('lives_${gameProvider.currentEventId}_$displayLives'),
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              
              const SizedBox(height: 16),
              
              // Progress
              Row(
                children: [
                  const Icon(Icons.check_circle, color: Colors.white, size: 20),
                  const SizedBox(width: 8),
                  Text(
                    'Progreso: ${gameProvider.completedClues}/${gameProvider.totalClues}',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: LinearProgressIndicator(
                  value: gameProvider.totalClues > 0
                      ? gameProvider.completedClues / gameProvider.totalClues
                      : 0,
                  minHeight: 8,
                  backgroundColor: Colors.white.withOpacity(0.3),
                  valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}