import 'package:flutter/material.dart';
import '../models/clue.dart';
import '../../../core/theme/app_theme.dart';

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
                  ? AppTheme.successGreen.withOpacity(0.1)
                  : isLocked
                      ? AppTheme.cardBg.withOpacity(0.5)
                      : AppTheme.cardBg,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: clue.isCompleted
                    ? AppTheme.successGreen
                    : isLocked
                        ? Colors.white12
                        : AppTheme.primaryPurple.withOpacity(0.3),
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
                            : AppTheme.primaryGradient,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Center(
                    child: Text(
                      clue.isCompleted
                          ? '✓'
                          : isLocked
                              ? '🔒'
                              : clue.typeIcon,
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
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: isLocked ? Colors.white38 : Colors.white,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        clue.isCompleted
                            ? 'Completada'
                            : isLocked
                                ? 'Bloqueada'
                                : clue.typeName,
                        style: TextStyle(
                          fontSize: 12,
                          color: clue.isCompleted
                              ? AppTheme.successGreen
                              : isLocked
                                  ? Colors.white24
                                  : AppTheme.secondaryPink,
                        ),
                      ),
                      if (!isLocked && !clue.isCompleted) ...[
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            const Icon(
                              Icons.star,
                              size: 14,
                              color: AppTheme.accentGold,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              '${clue.xpReward} XP',
                              style: const TextStyle(
                                fontSize: 12,
                                color: Colors.white70,
                              ),
                            ),
                            const SizedBox(width: 12),
                            const Icon(
                              Icons.monetization_on,
                              size: 14,
                              color: AppTheme.accentGold,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              '${clue.coinReward}',
                              style: const TextStyle(
                                fontSize: 12,
                                color: Colors.white70,
                              ),
                            ),
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
}
