import 'package:flutter/material.dart';
import '../models/clue.dart';
import '../../../core/theme/app_theme.dart';

import 'package:provider/provider.dart'; // IMPORT AGREGADO
import '../../../core/providers/app_mode_provider.dart'; // IMPORT AGREGADO

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
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final Color currentCard = isDarkMode ? AppTheme.dSurface1 : AppTheme.lSurface1;
    final Color currentText = isDarkMode ? Colors.white : const Color(0xFF1A1A1D);
    final Color currentTextSec = isDarkMode ? Colors.white70 : const Color(0xFF4A4A5A);
    
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
                      ? currentCard.withOpacity(0.5)
                      : currentCard,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: clue.isCompleted
                    ? AppTheme.successGreen
                    : isLocked
                        ? (isDarkMode ? Colors.white12 : Colors.black12)
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
                            : (clue.type == ClueType.minigame)
                                ? LinearGradient(
                                    colors: _getStampGradient(clue.sequenceIndex),
                                  )
                                : AppTheme.primaryGradient,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Center(
                    child: clue.isCompleted
                        ? const Text('✓', style: TextStyle(fontSize: 28))
                        : isLocked
                            ? const Text('🔒', style: TextStyle(fontSize: 28))
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
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: isLocked ? currentText.withOpacity(0.4) : currentText,
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
    const icons = [
      Icons.extension,
      Icons.lock_open,
      Icons.history_edu,
      Icons.warning_amber,
      Icons.cable,
      Icons.palette,
      Icons.visibility,
      Icons.settings_suggest,
      Icons.flash_on,
    ];
    return icons[index % icons.length];
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
