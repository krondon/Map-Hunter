abstract class ITargetable {
  String get id; // Unique Identifier for targeting (game_player_id)
  String? get label; // UI Name
  double get progress; // 0.0 to 1.0 or count depending on usage, User asked for double.
  bool get isSelectable;
  String? get avatarUrl; // Adding for UI decoupling
  String? get avatarId;  // Local asset reference (e.g., 'explorer_m')
}
