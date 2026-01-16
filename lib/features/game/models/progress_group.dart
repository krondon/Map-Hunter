/// Model representing a group of players at the same progress percentage.
///
/// Used by RaceTracker to handle overlapping avatars where multiple players
/// have completed the same number of clues.
class ProgressGroup {
  /// The progress percentage (0.0 to 1.0) shared by all members
  final double progress;
  
  /// The integer progress count (for comparison purposes)
  final int progressCount;
  
  /// List of player IDs in this group
  final List<String> memberIds;
  
  /// List of underlying view models for rendering
  final List<dynamic> members;

  const ProgressGroup({
    required this.progress,
    required this.progressCount,
    required this.memberIds,
    required this.members,
  });

  /// Returns true if this group contains only one member (no overlap)
  bool get isSingleMember => members.length == 1;
  
  /// Returns true if this group contains multiple overlapping players
  bool get hasOverlap => members.length > 1;
  
  /// Get the first member (useful for single-member groups)
  dynamic get firstMember => members.isNotEmpty ? members.first : null;
}
