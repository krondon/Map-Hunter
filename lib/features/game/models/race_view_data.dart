import 'package:flutter/material.dart';
import 'i_targetable.dart';

class RaceViewData {
  final List<RacerViewModel> racers;
  final String motivationText;
  
  const RaceViewData({
    required this.racers,
    required this.motivationText,
  });
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
