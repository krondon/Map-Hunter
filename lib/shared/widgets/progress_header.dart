import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../features/game/providers/game_provider.dart';
import '../../features/auth/providers/player_provider.dart';
import '../../core/theme/app_theme.dart';

class ProgressHeader extends StatelessWidget {
  final VoidCallback? onExit;
  const ProgressHeader({super.key, this.onExit});

  @override
  Widget build(BuildContext context) {
  return Consumer2<GameProvider, PlayerProvider>(
    builder: (context, gameProvider, playerProvider, child) {
      final player = playerProvider.currentPlayer;
      if (player == null) return const SizedBox.shrink();

      final isDarkMode = Theme.of(context).brightness == Brightness.dark;
      final Color currentText = isDarkMode ? Colors.white : const Color(0xFF1A1A1D);
      final Color currentTextSec = isDarkMode ? Colors.white70 : const Color(0xFF4A4A5A);
      final Color currentSurface = isDarkMode ? AppTheme.dSurface1 : AppTheme.lSurface1;

      // ✅ SINGLE SOURCE OF TRUTH: Solo GameProvider para vidas globales
      final int displayLives = gameProvider.lives;
        
        return Container(
          margin: const EdgeInsets.all(16),
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: AppTheme.mainGradient(context),
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: (isDarkMode ? AppTheme.primaryPurple : Colors.indigo).withOpacity(0.3),
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
                  ClipRRect(
                    borderRadius: BorderRadius.circular(25),
                    child: Container(
                      width: 50,
                      height: 50,
                      color: Colors.white24,
                      child: Builder(
                        builder: (context) {
                          // 1. Prioridad: Avatar Local
                          if (player.avatarId != null && player.avatarId!.isNotEmpty) {
                            return Image.asset(
                              'assets/images/avatars/${player.avatarId}.png',
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) {
                                debugPrint('❌ ERROR: No se pudo cargar asset: assets/images/avatars/${player.avatarId}.png');
                                return Center(
                                  child: Text(player.name.isNotEmpty ? player.name[0].toUpperCase() : '?',
                                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                                );
                              },
                            );
                          }
                          
                          // 2. Fallback: Foto de perfil (URL)
                          if (player.avatarUrl != null && player.avatarUrl!.startsWith('http')) {
                            return Image.network(
                              player.avatarUrl!,
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) => Center(
                                child: Text(player.name.isNotEmpty ? player.name[0].toUpperCase() : '?',
                                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                              ),
                            );
                          }
                          
                          // 3. Fallback: Iniciales
                          return Center(
                            child: Text(player.name.isNotEmpty ? player.name[0].toUpperCase() : '?',
                              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                          );
                        },
                      ),
                    ),
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
                        if (player.role == 'spectator')
                          Container(
                            margin: const EdgeInsets.only(top: 4),
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.blueAccent.withOpacity(0.3),
                              borderRadius: BorderRadius.circular(5),
                              border: Border.all(color: Colors.blueAccent, width: 1),
                            ),
                            child: const Text(
                              'MODO ESPECTADOR',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: Colors.blueAccent,
                              ),
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
                        // ✅ Reactivo: Se actualiza automáticamente con Realtime
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
                  
                  if (onExit != null) ...[
                    const SizedBox(width: 8),
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.redAccent.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(15),
                      ),
                      child: IconButton(
                        icon: const Icon(Icons.exit_to_app, color: Colors.white, size: 20),
                        onPressed: onExit,
                        tooltip: "Salir del Evento",
                        constraints: const BoxConstraints(),
                        padding: const EdgeInsets.all(8),
                      ),
                    ),
                  ],
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