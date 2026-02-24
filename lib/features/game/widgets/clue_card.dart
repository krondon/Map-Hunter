import 'dart:ui';
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
    final isOnline = Provider.of<AppModeProvider>(context).isOnlineMode;
    final isDarkMode = Provider.of<PlayerProvider>(context).isDarkMode;

    // Color de acento según estado
    final Color accentColor = clue.isCompleted
        ? const Color(0xFF00FF88)
        : isLocked
            ? Colors.white24
            : AppTheme.primaryPurple;
    
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: isLocked || clue.isCompleted ? null : onTap,
          borderRadius: BorderRadius.circular(24),
          child: Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: accentColor.withOpacity(0.05),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: accentColor.withOpacity(0.2),
                width: 1,
              ),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: clue.isCompleted
                        ? const Color(0xFF0A3D2A).withOpacity(0.6)
                        : const Color(0xFF150826).withOpacity(isLocked ? 0.3 : 0.7),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: accentColor.withOpacity(0.6),
                      width: 2,
                    ),
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
                                        ? Colors.white30
                                        : AppTheme.secondaryPink,
                              ),
                            ),
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
