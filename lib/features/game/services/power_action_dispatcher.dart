import 'package:flutter/foundation.dart';
import '../../auth/services/power_service.dart';
import '../../auth/providers/player_provider.dart';
import '../providers/game_provider.dart';
import '../providers/power_effect_provider.dart';
import '../strategies/power_response.dart';

/// Orchestrates power execution following DIP (Dependency Inversion Principle).
///
/// This service handles the flow:
/// Target Selection → Power Selection → Execution
///
/// Decouples UI widgets from execution logic by providing a single entry point
/// for power usage that coordinates between PowerService and Providers.
class PowerActionDispatcher {
  final PowerService _powerService;

  PowerActionDispatcher({
    required PowerService powerService,
  }) : _powerService = powerService;

  /// Executes a power against a target using ITargetable.id
  ///
  /// [casterGamePlayerId] - The game_player_id of the current user
  /// [targetId] - The game_player_id of the target (can be self for defense)
  /// [powerSlug] - The power identifier (e.g., 'freeze', 'shield')
  /// [effectProvider] - For triggering visual effects
  /// [gameProvider] - For updating loading state and game context
  /// [playerProvider] - For inventory updates
  /// [rivals] - List of rivals (needed for blur_screen broadcast)
  /// [eventId] - Current event ID (needed for blur_screen)
  ///
  /// Returns the result of the power usage.
  Future<PowerUseResult> dispatchPower({
    required String casterGamePlayerId,
    required String targetId,
    required String powerSlug,
    required PowerEffectProvider effectProvider,
    required GameProvider gameProvider,
    required PlayerProvider playerProvider,
    List<RivalInfo>? rivals,
    String? eventId,
  }) async {
    // Guard: Prevent multiple clicks
    if (gameProvider.isPowerActionLoading) {
      debugPrint(
          '[PowerActionDispatcher] Action already in progress, ignoring');
      return PowerUseResult.error;
    }

    try {
      // Set loading state
      gameProvider.setPowerActionLoading(true);

      // Normalize IDs for comparison
      final normalizedCaster = casterGamePlayerId.trim().toLowerCase();
      final normalizedTarget = targetId.trim().toLowerCase();
      final isTargetSelf = normalizedCaster == normalizedTarget;

      debugPrint(
          '[PowerActionDispatcher] Dispatching $powerSlug from $casterGamePlayerId to $targetId (self: $isTargetSelf)');

      // Execute via PlayerProvider (which handles inventory, effects, etc.)
      final result = await playerProvider.usePower(
        powerSlug: powerSlug,
        targetGamePlayerId: targetId,
        effectProvider: effectProvider,
        gameProvider: gameProvider,
      );

      debugPrint('[PowerActionDispatcher] Result: $result');
      return result;
    } catch (e, stack) {
      debugPrint('[PowerActionDispatcher] Error executing power: $e');
      debugPrint('[PowerActionDispatcher] Stack: $stack');
      return PowerUseResult.error;
    } finally {
      // Clear loading state
      gameProvider.setPowerActionLoading(false);
    }
  }

  /// Validates that a power can be used against the given target type.
  ///
  /// [powerSlug] - The power to validate
  /// [isTargetSelf] - Whether the target is the current user
  ///
  /// Returns true if the power is valid for the target type.
  bool validatePowerForTarget(String powerSlug, bool isTargetSelf) {
    // Attack powers (can only target others)
    const attackPowers = {
      'freeze',
      'black_screen',
      'life_steal',
      'blur_screen'
    };

    // Defense powers (can only target self)
    const defensePowers = {'shield', 'extra_life', 'return', 'invisibility'};

    if (isTargetSelf) {
      return defensePowers.contains(powerSlug);
    } else {
      return attackPowers.contains(powerSlug);
    }
  }
}
