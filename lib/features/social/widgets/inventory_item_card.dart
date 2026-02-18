import 'package:flutter/material.dart';
import '../../mall/models/power_item.dart';
import '../../../core/theme/app_theme.dart';
import 'package:provider/provider.dart';
import 'package:treasure_hunt_rpg/features/auth/providers/player_provider.dart';

class InventoryItemCard extends StatelessWidget {
  final PowerItem item;
  final VoidCallback onUse;
  final int count;
  final bool isActive;
  final bool isDisabled;
  final String? disabledLabel;
  
  const InventoryItemCard({
    super.key,
    required this.item,
    required this.onUse,
    this.count = 1,
    this.isActive = false,
    this.isDisabled = false,
    this.disabledLabel,
  });

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Provider.of<PlayerProvider>(context).isDarkMode;
    const Color currentCard = AppTheme.dSurface1; // Reverted to dark theme
    const Color currentText = Colors.white;
    const Color currentTextSec = Colors.white70;

    return Stack(
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: currentCard,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: AppTheme.primaryPurple.withOpacity(0.3),
              width: 2,
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Icon
              Text(
                item.icon,
                style: const TextStyle(fontSize: 32), // Reduced icon size
              ),
              
              const SizedBox(height: 4),
              
              // Name and Description container
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      item.name,
                      style: TextStyle(
                        fontSize: 12, // Reduced font size
                        fontWeight: FontWeight.bold,
                        color: currentText,
                      ),
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      item.description,
                      style: TextStyle(
                        fontSize: 9, // Reduced font size
                        color: currentTextSec,
                      ),
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              
              const SizedBox(height: 4),
              
              // Use button
              SizedBox(
                width: double.infinity,
                height: 30, // Even smaller height
                child: ElevatedButton(
                  onPressed: (isActive || isDisabled) ? null : onUse,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: (isActive || isDisabled)
                        ? Colors.grey.withOpacity(0.5) 
                        : AppTheme.secondaryPink,
                    padding: EdgeInsets.zero,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  child: Text(
                    isActive 
                       ? 'Activo' 
                       : (isDisabled ? (disabledLabel ?? 'Bloqueado') : 'Usar'),
                    style: const TextStyle(fontSize: 10), // Slightly smaller font for long labels
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
            ],
          ),
        ),
        if (count > 1)
          Positioned(
            right: 8,
            top: 8,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: AppTheme.accentGold,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.3),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Text(
                'x$count',
                style: const TextStyle(
                  color: Colors.black,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
            ),
          ),
      ],
    );
  }
}
