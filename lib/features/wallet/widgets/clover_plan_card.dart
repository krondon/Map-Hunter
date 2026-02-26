import 'dart:ui';
import 'package:flutter/material.dart';
import '../models/clover_plan.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/coin_image.dart';

/// A selectable card widget for displaying a clover purchase plan.
/// 
/// Shows plan name, clover quantity, and USD price.
/// When selected and a fee percentage is provided, shows estimated total.
class CloverPlanCard extends StatelessWidget {
  final CloverPlan plan;
  final bool isSelected;
  final VoidCallback onTap;
  /// Gateway fee percentage (e.g., 3.0 for 3%). If 0 or null, no fee is shown.
  final double? feePercentage;

  const CloverPlanCard({
    super.key,
    required this.plan,
    required this.isSelected,
    required this.onTap,
    this.feePercentage,
  });

  @override
  Widget build(BuildContext context) {
    // Calculate clovers to show based on quantity for visual feedback
    int cloverIconCount = 1;
    if (plan.cloversQuantity >= 500) cloverIconCount = 3;
    else if (plan.cloversQuantity >= 150) cloverIconCount = 2;

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        decoration: BoxDecoration(
          color: const Color(0xFF1A1A1D),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? AppTheme.accentGold : Colors.white.withOpacity(0.1),
            width: isSelected ? 1.5 : 1,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: AppTheme.accentGold.withOpacity(0.15),
                    blurRadius: 10,
                    spreadRadius: 1,
                  ),
                ]
              : null,
        ),
      padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 12),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Coin Icons at top
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(cloverIconCount, (index) => 
               Padding(
                padding: const EdgeInsets.symmetric(horizontal: 1),
                child: CoinImage(size: 20 + (index * 2)),
              ),
            ),
          ),
              
              const SizedBox(height: 12),
              
              // Plan Name
              Text(
                plan.name,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
              
              // Quantity
              Text(
                '${plan.cloversQuantity} tréboles',
                style: TextStyle(
                  color: Colors.white.withOpacity(0.4),
                  fontSize: 11,
                ),
              ),
              
              const SizedBox(height: 16),
              
              // Price Chip
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                decoration: BoxDecoration(
                  color: const Color(0xFF0D0D0F),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.white.withOpacity(0.05)),
                ),
                child: Text(
                  plan.formattedPrice,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),
        ),
    );
  }
}
