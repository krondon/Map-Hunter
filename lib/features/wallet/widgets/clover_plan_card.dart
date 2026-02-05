import 'package:flutter/material.dart';
import '../models/clover_plan.dart';
import '../../../core/theme/app_theme.dart';

/// A selectable card widget for displaying a clover purchase plan.
/// 
/// Shows plan name, clover quantity, and USD price.
/// Changes appearance when selected.
class CloverPlanCard extends StatelessWidget {
  final CloverPlan plan;
  final bool isSelected;
  final VoidCallback onTap;

  const CloverPlanCard({
    super.key,
    required this.plan,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final Color accentColor = isSelected 
        ? AppTheme.accentGold 
        : Colors.white.withOpacity(0.5);

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: isSelected
                ? [AppTheme.accentGold.withOpacity(0.3), AppTheme.accentGold.withOpacity(0.1)]
                : [Colors.white.withOpacity(0.1), Colors.white.withOpacity(0.05)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: accentColor,
            width: isSelected ? 2 : 1,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: AppTheme.accentGold.withOpacity(0.3),
                    blurRadius: 12,
                    spreadRadius: 1,
                  ),
                ]
              : null,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Icon/Emoji
            Text(
              plan.iconUrl ?? '🍀',
              style: const TextStyle(fontSize: 32),
            ),
            const SizedBox(height: 8),
            
            // Plan Name
            Text(
              plan.name,
              style: TextStyle(
                color: isSelected ? AppTheme.accentGold : Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 4),
            
            // Clovers Quantity
            Text(
              '${plan.cloversQuantity} Tréboles',
              style: TextStyle(
                color: Colors.white.withOpacity(0.7),
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 8),
            
            // Price (USD)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: isSelected 
                    ? AppTheme.accentGold.withOpacity(0.2) 
                    : Colors.black26,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                plan.formattedPrice,
                style: TextStyle(
                  color: isSelected ? AppTheme.accentGold : Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
            
            // Selection indicator
            if (isSelected) ...[
              const SizedBox(height: 8),
              Icon(
                Icons.check_circle,
                color: AppTheme.accentGold,
                size: 20,
              ),
            ],
          ],
        ),
      ),
    );
  }
}
