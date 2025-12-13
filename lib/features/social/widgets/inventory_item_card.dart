import 'package:flutter/material.dart';
import '../../mall/models/power_item.dart';
import '../../../core/theme/app_theme.dart';

class InventoryItemCard extends StatelessWidget {
  final PowerItem item;
  final VoidCallback onUse;
  
  const InventoryItemCard({
    super.key,
    required this.item,
    required this.onUse,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppTheme.cardBg,
            AppTheme.cardBg.withOpacity(0.8),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppTheme.primaryPurple.withOpacity(0.3),
          width: 2,
        ),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Icon
          Text(
            item.icon,
            style: const TextStyle(fontSize: 48),
          ),
          
          const SizedBox(height: 12),
          
          // Name
          Text(
            item.name,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
            textAlign: TextAlign.center,
          ),
          
          const SizedBox(height: 8),
          
          // Description
          Text(
            item.description,
            style: const TextStyle(
              fontSize: 11,
              color: Colors.white60,
            ),
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          
          const Spacer(),
          
          // Use button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: onUse,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.secondaryPink,
                padding: const EdgeInsets.symmetric(vertical: 8),
              ),
              child: const Text(
                'Usar',
                style: TextStyle(fontSize: 14),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
