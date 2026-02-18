import 'package:flutter/material.dart';
import '../models/clue.dart';
import '../../../core/theme/app_theme.dart';

import 'package:provider/provider.dart';
import 'package:treasure_hunt_rpg/features/auth/providers/player_provider.dart';
import '../../../core/providers/app_mode_provider.dart';

class ClueCard extends StatelessWidget {
  final Clue clue;
  final bool isLocked;
  final VoidCallback onTap;
  
  const ClueCard({
    super.key,
    required this.clue,
    required this.isLocked,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    // Check mode
    final isOnline = Provider.of<AppModeProvider>(context).isOnlineMode;
    final isDarkMode = Provider.of<PlayerProvider>(context).isDarkMode;
    const Color currentCard = AppTheme.dSurface1; // Reverted to dark theme
    const Color currentText = Colors.white;
    const Color currentTextSec = Colors.white70;
    
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: isLocked || clue.isCompleted ? null : onTap,
          borderRadius: BorderRadius.circular(16),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: clue.isCompleted
                  ? const Color(0xFF0A3D2A) // Dark matrix/cyber green background
                  : isLocked
                      ? const Color(0xFF1A1A1D)
                      : const Color(0xFF151517),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: clue.isCompleted
                    ? const Color(0xFF00FF88) // Neon/cyber green border
                    : isLocked
                        ? Colors.white12
                        : AppTheme.secondaryPink.withOpacity(0.5),
                width: 1.5,
              ),
              boxShadow: isLocked ? [] : [
                BoxShadow(
                  color: Colors.black.withOpacity(0.4),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              children: [
                // Icon
                Container(
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    gradient: clue.isCompleted
                        ? const LinearGradient(
                            colors: [AppTheme.successGreen, Color(0xFF00B894)],
                          )
                        : isLocked
                            ? LinearGradient(
                                colors: [Colors.grey.shade700, Colors.grey.shade800],
                              )
                            : (clue.type == ClueType.minigame)
                                ? LinearGradient(
                                    colors: _getStampGradient(clue.sequenceIndex),
                                  )
                                : AppTheme.primaryGradient,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Center(
                    child: clue.isCompleted
                        ? const Icon(Icons.check_circle_rounded, color: Colors.white, size: 32)
                        : isLocked
                            ? const Icon(Icons.lock_rounded, color: Colors.white24, size: 32)
                            : (clue.type == ClueType.minigame)
                                ? Icon(
                                    _getStampIcon(clue.sequenceIndex),
                                    color: Colors.white,
                                    size: 32,
                                  )
                                : isOnline 
                                    ? const Icon(Icons.flash_on, color: Colors.white, size: 28)
                                    : Text(
                                        clue.typeIcon,
                                        style: const TextStyle(fontSize: 28),
                                      ),
                  ),
                ),
                
                const SizedBox(width: 16),
                
                // Content
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        clue.title,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w900,
                          fontFamily: 'Orbitron',
                          letterSpacing: 1.0,
                          color: isLocked ? Colors.white24 : Colors.white,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        clue.isCompleted
                            ? 'Completada'
                            : isLocked
                                ? 'Bloqueada'
                                : isOnline 
                                    ? 'Misión Disponible'
                                    : clue.typeName,
                        style: TextStyle(
                          fontSize: 12,
                          color: clue.isCompleted
                              ? AppTheme.successGreen
                              : isLocked
                                  ? currentText.withOpacity(0.3)
                                  : AppTheme.secondaryPink,
                        ),
                      ),
                      if (!isLocked && !clue.isCompleted) ...[
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            
                            // const Icon(
                            //   Icons.monetization_on,
                            //   size: 14,
                            //   color: AppTheme.accentGold,
                            // ),
                            // const SizedBox(width: 4),
                            // Text(
                            //   '${clue.coinReward}',
                            //   style: const TextStyle(
                            //     fontSize: 12,
                            //     color: Colors.white70,
                            //   ),
                            // ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
                
                // Arrow
                if (!isLocked && !clue.isCompleted)
                  const Icon(
                    Icons.chevron_right,
                    color: AppTheme.secondaryPink,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
  IconData _getStampIcon(int index) {
    return Icons.eco;
  }

  List<Color> _getStampGradient(int index) {
    return [const Color(0xFFFFD700), const Color(0xfff5c71a)];
  }
}
