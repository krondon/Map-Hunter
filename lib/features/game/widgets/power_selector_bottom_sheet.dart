import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';
import '../../mall/models/power_item.dart';

/// Bottom sheet for selecting a power to use on a target.
/// 
/// Implements ISP by filtering powers based on whether the target is self or rival:
/// - Self target: Shows defense/buff powers (shield, extra_life, return, invisibility)
/// - Rival target: Shows attack powers (freeze, black_screen, life_steal, blur_screen)
class PowerSelectorBottomSheet extends StatelessWidget {
  /// The name/label of the target for display purposes
  final String targetName;
  
  /// Whether the target is the current user (self)
  final bool isTargetSelf;
  
  /// Current player's inventory (list of power slugs)
  final List<String> inventory;
  
  /// Callback when a power is selected
  final void Function(PowerItem power) onPowerSelected;

  const PowerSelectorBottomSheet({
    super.key,
    required this.targetName,
    required this.isTargetSelf,
    required this.inventory,
    required this.onPowerSelected,
  });

  /// Shows the bottom sheet and returns the selected power, or null if dismissed
  static Future<PowerItem?> show({
    required BuildContext context,
    required String targetName,
    required bool isTargetSelf,
    required List<String> inventory,
  }) async {
    return showModalBottomSheet<PowerItem>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (modalContext) => PowerSelectorBottomSheet(
        targetName: targetName,
        isTargetSelf: isTargetSelf,
        inventory: inventory,
        onPowerSelected: (power) => Navigator.pop(modalContext, power),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Get all shop items and filter based on inventory and target type
    final allPowers = PowerItem.getShopItems();
    
    // Filter by what's in inventory
    final inventoryPowers = allPowers.where((p) => inventory.contains(p.id)).toList();
    
    // Apply ISP filtering based on target
    final filteredPowers = inventoryPowers.where((p) {
      if (isTargetSelf) {
        return p.type.isDefense;
      } else {
        return p.type.isAttack;
      }
    }).toList();

    // Count occurrences of each power in inventory
    final Map<String, int> powerCounts = {};
    for (var slug in inventory) {
      powerCounts[slug] = (powerCounts[slug] ?? 0) + 1;
    }

    return Container(
      decoration: BoxDecoration(
        color: AppTheme.cardBg,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        border: Border.all(color: AppTheme.primaryPurple.withOpacity(0.3)),
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle bar
            Container(
              margin: const EdgeInsets.symmetric(vertical: 12),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            
            // Header
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: isTargetSelf 
                          ? AppTheme.successGreen.withOpacity(0.2)
                          : AppTheme.dangerRed.withOpacity(0.2),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      isTargetSelf ? Icons.shield : Icons.bolt,
                      color: isTargetSelf ? AppTheme.successGreen : AppTheme.dangerRed,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          isTargetSelf ? 'PROTÉGETE' : 'SABOTEA',
                          style: TextStyle(
                            color: isTargetSelf ? AppTheme.successGreen : AppTheme.dangerRed,
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                            letterSpacing: 1.2,
                          ),
                        ),
                        Text(
                          'Objetivo: $targetName',
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close, color: Colors.white54),
                  ),
                ],
              ),
            ),
            
            const Divider(color: Colors.white12),
            
            // Powers list
            if (filteredPowers.isEmpty)
              Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  children: [
                    Icon(
                      Icons.inventory_2_outlined,
                      size: 48,
                      color: Colors.white.withOpacity(0.3),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      isTargetSelf 
                          ? 'Sin poderes defensivos'
                          : 'Sin poderes de ataque',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.5),
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Visita la tienda para conseguir más',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.3),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              )
            else
              ConstrainedBox(
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.of(context).size.height * 0.4,
                ),
                child: ListView.builder(
                  shrinkWrap: true,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  itemCount: filteredPowers.length,
                  itemBuilder: (context, index) {
                    final power = filteredPowers[index];
                    final count = powerCounts[power.id] ?? 0;
                    
                    return _PowerTile(
                      power: power,
                      count: count,
                      onTap: () => onPowerSelected(power),
                    );
                  },
                ),
              ),
            
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}

class _PowerTile extends StatelessWidget {
  final PowerItem power;
  final int count;
  final VoidCallback onTap;

  const _PowerTile({
    required this.power,
    required this.count,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: power.color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: power.color.withOpacity(0.3)),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                // Icon
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: power.color.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Center(
                    child: Text(
                      power.icon,
                      style: const TextStyle(fontSize: 24),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                
                // Details
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        power.name,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                      Text(
                        power.description,
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.6),
                          fontSize: 11,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                
                // Count badge
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppTheme.accentGold,
                    borderRadius: BorderRadius.circular(12),
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
                
                const SizedBox(width: 8),
                Icon(
                  Icons.chevron_right,
                  color: Colors.white.withOpacity(0.5),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
