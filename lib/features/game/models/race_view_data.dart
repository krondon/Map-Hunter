import 'package:flutter/material.dart';
import 'i_targetable.dart';
import 'progress_group.dart';

class RaceViewData {
  final List<RacerViewModel> racers;
  final String motivationText;
  
  /// Groups of racers at the same progress (for overlap detection)
  final List<ProgressGroup> progressGroups;
  
  const RaceViewData({
    required this.racers,
    required this.motivationText,
    this.progressGroups = const [],
  });
  
  /// Gets the group containing the specified player ID, if any overlap exists
  ProgressGroup? getGroupForPlayer(String playerId) {
    final normalizedId = playerId.trim().toLowerCase();
    for (final group in progressGroups) {
      if (group.hasOverlap && 
          group.memberIds.any((id) => id.trim().toLowerCase() == normalizedId)) {
        return group;
      }
    }
    return null;
  }
}

class RacerViewModel {
  final ITargetable data; // The underlying model (Player)
  final int lane; // -1: Ahead, 0: Me, 1: Behind
  final bool isMe;
  final bool isLeader;
  final bool isTargetable;
  final double opacity;
  final IconData? statusIcon;
  final Color? statusColor;

  const RacerViewModel({
    required this.data,
    required this.lane,
    required this.isMe,
    required this.isLeader,
    this.isTargetable = true,
    this.opacity = 1.0,
    this.statusIcon,
    this.statusColor,
  });
}
