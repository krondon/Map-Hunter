import 'package:flutter/material.dart';
import '../../../../shared/models/player.dart';
import '../../../../shared/extensions/player_extensions.dart';
import '../models/race_view_data.dart';
import '../models/power_effect.dart';
import '../models/i_targetable.dart';

class RaceLogicService {
  /// Generates the pure view data for the race track.
  /// 
  /// Principles:
  /// - Sorting: Based on `completed_clues_count` (totalXP).
  /// - Filtering: Invisible rivals are excluded.
  /// - Status: Visual states (icons, opacity) calculated here.
  /// - Structure: Returns me, leader, ahead, behind.
  RaceViewData buildRaceView({
    required List<Player> leaderboard,
    required String currentUserId,
    required List<PowerEffect> activePowers,
    required int totalClues,
  }) {
    // 1. Find Me
    final myIndex = leaderboard.indexWhere((p) => p.id == currentUserId);
    Player? me = myIndex != -1 ? leaderboard[myIndex] : null;

    // 2. Sort leaderboard explicitly by progress (completed_clues_count)
    // We trust the API order generally, but for "Ahead/Behind" logic we want strict sort.
    final sortedPlayers = List<Player>.from(leaderboard);
    sortedPlayers.sort((a, b) {
      // Primary: Completed Clues (Descending)
      final progressCompare = b.completedCluesCount.compareTo(a.completedCluesCount);
      if (progressCompare != 0) return progressCompare;
      
      // Secondary: Name (for stability) or Time if available
      return a.name.compareTo(b.name);
    });
    
    // Re-find me in sorted list
    final meSortedIndex = sortedPlayers.indexWhere((p) => p.id == currentUserId);

    // 3. Identify Candidates (Leader, Ahead, Behind)
    Player? leader = sortedPlayers.isNotEmpty ? sortedPlayers.first : null;
    
    // For Ahead/Behind, we need to skip "Invisible" players unless it's Me (I always see myself).
    // And actually, if *I* am invisible, I see myself with opacity. 
    // If *Rival* is invisible, I don't see them at all -> they shouldn't occupy a lane.
    
    // Helper to check visibility
    bool isVisible(Player p) {
      if (p.id == currentUserId) return true; // I always see myself
      // Check active powers for invisibility
      final isStealthed = activePowers.any((e) => 
          e.targetId == p.id && // Using ITargetable.id (which is gamePlayerId)
          (e.powerSlug == 'invisibility' || e.powerSlug == 'stealth') && 
          !e.isExpired
      );
      if (isStealthed) return false;
      // Also check granular status from model if mapped
      if (p.isInvisible) return false; 
      return true;
    }

    // Filter sorted list for visibility from MY perspective
    final visibleRacers = sortedPlayers.where(isVisible).toList();
    
    // Re-find me in visible list
    final meVisibleIndex = visibleRacers.indexWhere((p) => p.id == currentUserId);
    
    Player? ahead;
    Player? behind;

    if (meVisibleIndex != -1) {
      if (meVisibleIndex > 0) ahead = visibleRacers[meVisibleIndex - 1];
      if (meVisibleIndex < visibleRacers.length - 1) behind = visibleRacers[meVisibleIndex + 1];
    } else {
      // If I am not in the list (e.g. not joined yet, or somehow filtered out - shouldn't happen),
      // we might just show last visible as ahead?
      if (visibleRacers.isNotEmpty) ahead = visibleRacers.last;
    }

    // 4. Build View Models
    final List<RacerViewModel> viewModels = [];
    final Set<String> addedIds = {};

    void addRacer(Player p, int lane) {
      if (addedIds.contains(p.id)) return;

      final bool isMe = p.id == currentUserId;
      final bool isLeader = (leader != null && p.id == leader.id);
      
      // Calculate visual state
      double opacity = 1.0;
      if (isMe) {
        // If I am invisible, I see myself semi-transparent
        final amInvisible = activePowers.any((e) => 
            e.targetId == p.gamePlayerId && 
            (e.powerSlug == 'invisibility' || e.powerSlug == 'stealth') && 
            !e.isExpired
        );
         if (amInvisible || p.isInvisible) opacity = 0.5;
      }
      
      IconData? statusIcon;
      Color? statusColor;
      
      // Check for debuffs on this player (using ITargetable.id which is gamePlayerId)
      final activeDebuffs = activePowers.where((e) => e.targetId == p.id && !e.isExpired).toList();
      
      // Priority icons
      if (activeDebuffs.any((e) => e.powerSlug == 'freeze')) {
        statusIcon = Icons.ac_unit;
        statusColor = Colors.cyanAccent;
      } else if (activeDebuffs.any((e) => e.powerSlug == 'black_screen' || e.powerSlug == 'blind')) {
        statusIcon = Icons.visibility_off;
        statusColor = Colors.black;
      } else if (p.status == PlayerStatus.shielded) {
        // Shield might be a buff, verify generic status
        statusIcon = Icons.shield;
        statusColor = Colors.indigoAccent;
      }

      viewModels.add(RacerViewModel(
        data: p,
        lane: lane,
        isMe: isMe,
        isLeader: isLeader,
        isTargetable: isVisible(p) && !isMe, // Can't target self, can't target invisible (already filtered)
        opacity: opacity,
        statusIcon: statusIcon,
        statusColor: statusColor,
      ));
      
      addedIds.add(p.id);
    }

    // Order of addition matters for Z-Index (Stack). Last added is ON TOP.
    // We want Me to be on top.
    
    // Rivales
    if (leader != null && leader.id != currentUserId) {
        // If leader is invisible to me, they wouldn't be in visibleRacers, but let's check explicit object
        if (isVisible(leader)) addRacer(leader, -1);
    }
    
    if (ahead != null && ahead.id != currentUserId) addRacer(ahead, -1);
    if (behind != null && behind.id != currentUserId) addRacer(behind, 1);
    
    // Me (Last for top Z-Index)
    if (me != null) addRacer(me, 0);
    else {
        // Dummy me if not in leaderboard yet
        // We need a dummy player object
        final dummyMe = Player(userId: currentUserId, name: 'Tú', email: '', gamePlayerId: currentUserId); 
        // Logic might need gamePlayerId from provider but we only have ID here. 
        // If 'me' was null, it means I am not in leaderboard.
        // We will skip rendering me if I am not in leaderboard data? 
        // Or create a temporary one.
        // Better to skip if data invalid, but usually GameProvider has user.
    }

    // Motivation Text
    String motivation = "";
    if (me != null) {
      if (me.completedCluesCount == 0) motivation = "¡La carrera comienza! 🏃💨";
      else if (me.completedCluesCount >= totalClues && totalClues > 0) motivation = "¡META ALCANZADA! 🎉";
      else if (leader != null && me.id == leader.id) motivation = "¡Vas LÍDER! 🏆";
      else motivation = "Pista ${me.completedCluesCount} de $totalClues. ¡Sigue así! 🚀";
    }

    return RaceViewData(racers: viewModels, motivationText: motivation);
  }
}
