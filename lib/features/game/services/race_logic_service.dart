import 'package:flutter/material.dart';
import '../../../../shared/models/player.dart';
import '../../../../shared/extensions/player_extensions.dart';
import '../models/race_view_data.dart';
import '../models/power_effect.dart';
import '../models/i_targetable.dart';
import '../models/progress_group.dart';

/// Maximum number of participants to display in the race track
const int kMaxRaceParticipants = 10;

/// Number of players to show ahead of the current user
const int kPlayersAhead = 4;

/// Number of players to show behind the current user
const int kPlayersBehind = 5;

class RaceLogicService {
  /// Generates the pure view data for the race track.
  ///
  /// Principles:
  /// - Filtering: Max 10 participants (4 ahead + 5 behind + me)
  /// - Sorting: Based on `completed_clues_count` (totalXP).
  /// - Visibility: Invisible rivals are excluded.
  /// - Grouping: Players at same progress are grouped.
  /// - Status: Visual states (icons, opacity) calculated here.
  RaceViewData buildRaceView({
    required List<Player> leaderboard,
    required String currentUserId,
    required List<PowerEffect> activePowers,
    required int totalClues,
  }) {
    // Normalize current user ID for comparison (Expects userId)
    final normalizedCurrentUserId = _normalizeId(currentUserId);

    // 1. Find Me using userId (more robust than generic id)
    final myIndex = leaderboard
        .indexWhere((p) => _normalizeId(p.userId) == normalizedCurrentUserId);
    Player? me = myIndex != -1 ? leaderboard[myIndex] : null;

    // 2. Sort leaderboard explicitly by progress (completed_clues_count)
    // [FIX] Usar mismos criterios que game_service.dart (Ranking):
    //       1. completed_clues DESC
    //       2. last_completion_time ASC (quien terminó primero gana)
    final sortedPlayers = List<Player>.from(leaderboard);
    sortedPlayers.sort((a, b) {
      // Primary: Completed Clues (Descending)
      final progressCompare =
          b.completedCluesCount.compareTo(a.completedCluesCount);
      if (progressCompare != 0) return progressCompare;

      // Secondary: Last Completion Time (Ascending - menor = terminó primero = líder)
      final aTime =
          a.lastCompletionTime ?? DateTime.fromMillisecondsSinceEpoch(0);
      final bTime =
          b.lastCompletionTime ?? DateTime.fromMillisecondsSinceEpoch(0);
      return aTime.compareTo(bTime);
    });

    // Re-find me in sorted list
    final meSortedIndex = sortedPlayers
        .indexWhere((p) => _normalizeId(p.userId) == normalizedCurrentUserId);

    // 3. Helper to check visibility
    bool isVisible(Player p) {
      if (_normalizeId(p.userId) == normalizedCurrentUserId)
        return true; // I always see myself
      // Check active powers for invisibility
      final isStealthed = activePowers.any((e) =>
          _normalizeId(e.targetId) ==
              _normalizeId(p
                  .id) && // Powers target by GamePlayerID (usually) but let's keep generic ID here as powers use ID
          (e.powerSlug == 'invisibility' || e.powerSlug == 'stealth') &&
          !e.isExpired);
      if (isStealthed) return false;
      if (p.isInvisible) return false;
      return true;
    }

    // 4. Filter for visibility
    final visibleRacers = sortedPlayers.where(isVisible).toList();

    // 5. Apply 10-participant limit: 4 ahead + me + 5 behind
    final filteredRacers = _filterParticipants(
      visibleRacers: visibleRacers,
      currentUserId: normalizedCurrentUserId,
    );

    // 6. Identify Leader from filtered list
    Player? leader = filteredRacers.isNotEmpty ? filteredRacers.first : null;

    // 7. Build View Models
    final List<RacerViewModel> viewModels = [];
    final Set<String> addedIds = {};

    // Find my position in filtered list for lane calculation
    final meFilteredIndex = filteredRacers
        .indexWhere((p) => _normalizeId(p.userId) == normalizedCurrentUserId);

    void addRacer(Player p, int lane) {
      // Use UserID for uniqueness check in this context
      final normalizedUserId = _normalizeId(p.userId);
      if (addedIds.contains(normalizedUserId)) return;

      final bool isMe = normalizedUserId == normalizedCurrentUserId;
      // Leader check also by userId
      final bool isLeader = (leader != null &&
          _normalizeId(p.userId) == _normalizeId(leader.userId));

      // Calculate visual state
      double opacity = 1.0;
      if (isMe) {
        final amInvisible = activePowers.any((e) =>
            _normalizeId(e.targetId) == _normalizeId(p.id) &&
            (e.powerSlug == 'invisibility' || e.powerSlug == 'stealth') &&
            !e.isExpired);
        if (amInvisible || p.isInvisible) opacity = 0.5;
      }

      IconData? statusIcon;
      Color? statusColor;

      // Check for debuffs on this player (Powers use ID/GamePlayerID)
      final activeDebuffs = activePowers
          .where((e) =>
              _normalizeId(e.targetId) == _normalizeId(p.id) && !e.isExpired)
          .toList();

      // Priority icons
      if (activeDebuffs.any((e) => e.powerSlug == 'freeze')) {
        statusIcon = Icons.ac_unit;
        statusColor = Colors.cyanAccent;
      } else if (activeDebuffs.any(
          (e) => e.powerSlug == 'black_screen' || e.powerSlug == 'blind')) {
        statusIcon = Icons.visibility_off;
        statusColor = Colors.black;
      } else if (p.status == PlayerStatus.shielded) {
        statusIcon = Icons.shield;
        statusColor = Colors.indigoAccent;
      }

      viewModels.add(RacerViewModel(
        data: p,
        lane: lane,
        isMe: isMe,
        isLeader: isLeader,
        isTargetable:
            isVisible(p), // Can target self (for defense) and visible rivals
        opacity: opacity,
        statusIcon: statusIcon,
        statusColor: statusColor,
      ));

      addedIds.add(normalizedUserId);
    }

    // Add racers with lane calculation based on position relative to me
    for (int i = 0; i < filteredRacers.length; i++) {
      final player = filteredRacers[i];
      int lane;

      if (meFilteredIndex == -1) {
        // I'm not in the list, treat all as ahead
        lane = -1;
      } else if (i < meFilteredIndex) {
        lane = -1; // Ahead
      } else if (i > meFilteredIndex) {
        lane = 1; // Behind
      } else {
        lane = 0; // Me
      }

      addRacer(player, lane);
    }

    // If me was not in filtered list but exists, add them
    if (me != null && !addedIds.contains(normalizedCurrentUserId)) {
      addRacer(me, 0);
    }

    // 8. Generate Progress Groups for UI overlap detection
    final progressGroups = _buildProgressGroups(viewModels, totalClues);

    // 9. Motivation Text
    String motivation = "";
    if (me != null) {
      if (me.completedCluesCount == 0)
        motivation = "¡La carrera comienza! 🏃💨";
      else if (me.completedCluesCount >= totalClues && totalClues > 0)
        motivation = "¡META ALCANZADA! 🎉";
      else if (leader != null && _normalizeId(me.id) == _normalizeId(leader.id))
        motivation = "¡Vas LÍDER! 🏆";
      else
        motivation =
            "Pista ${me.completedCluesCount} de $totalClues. ¡Sigue así! 🚀";
    }

    return RaceViewData(
      racers: viewModels,
      motivationText: motivation,
      progressGroups: progressGroups,
    );
  }

  /// Filters participants to max 10: 4 ahead + current user + 5 behind
  List<Player> _filterParticipants({
    required List<Player> visibleRacers,
    required String currentUserId,
  }) {
    if (visibleRacers.length <= kMaxRaceParticipants) {
      return visibleRacers;
    }

    final meIndex =
        visibleRacers.indexWhere((p) => _normalizeId(p.id) == currentUserId);

    if (meIndex == -1) {
      // User not in list, return first 10
      return visibleRacers.take(kMaxRaceParticipants).toList();
    }

    // Calculate range: up to 4 ahead, up to 5 behind
    int startIndex =
        (meIndex - kPlayersAhead).clamp(0, visibleRacers.length - 1);
    int endIndex =
        (meIndex + kPlayersBehind + 1).clamp(0, visibleRacers.length);

    // Adjust if we have room on one side but not the other
    final aheadCount = meIndex - startIndex;
    final behindCount = endIndex - meIndex - 1;

    if (aheadCount < kPlayersAhead &&
        behindCount < visibleRacers.length - meIndex - 1) {
      // Room to expand behind
      final extraBehind = kPlayersAhead - aheadCount;
      endIndex = (endIndex + extraBehind).clamp(0, visibleRacers.length);
    }

    if (behindCount < kPlayersBehind && aheadCount < meIndex) {
      // Room to expand ahead
      final extraAhead = kPlayersBehind - behindCount;
      startIndex = (startIndex - extraAhead).clamp(0, visibleRacers.length - 1);
    }

    // Ensure max 10 total
    final result = visibleRacers.sublist(startIndex, endIndex);
    if (result.length > kMaxRaceParticipants) {
      // Trim from behind if over limit
      return result.take(kMaxRaceParticipants).toList();
    }

    return result;
  }

  /// Groups racers by their integer progress count for overlap detection
  List<ProgressGroup> _buildProgressGroups(
      List<RacerViewModel> racers, int totalClues) {
    final Map<int, List<RacerViewModel>> grouped = {};

    for (final racer in racers) {
      final progressCount = racer.data.progress.toInt();
      grouped.putIfAbsent(progressCount, () => []).add(racer);
    }

    return grouped.entries.map((entry) {
      final progress = totalClues > 0 ? entry.key / totalClues : 0.0;
      return ProgressGroup(
        progress: progress.clamp(0.0, 1.0),
        progressCount: entry.key,
        memberIds: entry.value.map((r) => r.data.id).toList(),
        members: entry.value,
      );
    }).toList()
      ..sort((a, b) => b.progressCount.compareTo(a.progressCount));
  }

  /// Normalizes an ID for consistent comparison (handles UUID type mismatches)
  String _normalizeId(String? id) {
    if (id == null) return '';
    return id.toString().trim().toLowerCase();
  }
}
