import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/models/player.dart';
import '../../game/models/race_view_data.dart';
import '../../game/models/i_targetable.dart';
import '../providers/power_effect_provider.dart';
import '../providers/game_provider.dart';
import '../../auth/providers/player_provider.dart';
import '../../mall/models/power_item.dart';
import 'power_gesture_wrapper.dart';
import '../services/race_logic_service.dart';

class RaceTrackWidget extends StatelessWidget {
  final List<Player> leaderboard;
  final String currentPlayerId;
  final int totalClues;
  final VoidCallback? onSurrender;

  const RaceTrackWidget({
    super.key,
    required this.leaderboard,
    required this.currentPlayerId,
    required this.totalClues,
    this.onSurrender,
  });

  @override
  Widget build(BuildContext context) {
    final playerProvider = Provider.of<PlayerProvider>(context, listen: false);
    final effectProvider = Provider.of<PowerEffectProvider>(context);
    final gameProvider = Provider.of<GameProvider>(context);
    final String? myGamePlayerId = playerProvider.currentPlayer?.gamePlayerId;

    // --- LOGIC LAYER (Service Use) ---
    final raceService = RaceLogicService();
    
    // SOLID: Widget consumes View Model via Service. No business logic here.
    final raceView = raceService.buildRaceView(
      leaderboard: leaderboard, 
      currentUserId: currentPlayerId, 
      activePowers: gameProvider.activePowerEffects, 
      totalClues: totalClues
    );

    Future<void> handleSwipeAttack() async {
      final me = playerProvider.currentPlayer;
      if (me == null) return;

      final offensiveSlugs = <String>{'freeze', 'black_screen', 'life_steal', 'blur_screen'};
      final String selectedPowerSlug = me.inventory.firstWhere(
        (slug) => offensiveSlugs.contains(slug),
        orElse: () => '',
      );

      if (selectedPowerSlug.isEmpty) {
        if (context.mounted) {
           ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('No tienes poderes ofensivos disponibles')),
          );
        }
        return;
      }

      if (leaderboard.isEmpty) return; // Should not happen if race is active

      // Targeting Logic
      String? targetGameId;
      
      // 1. Explicit Target
      final explicitTargetId = gameProvider.targetPlayerId;
      if (explicitTargetId != null) {
          // Find in view models first (most reliable for race context)
          final targetVM = raceView.racers.where((vm) => vm.data.id == explicitTargetId).firstOrNull;
          if (targetVM != null) {
              targetGameId = targetVM.data.id;
          } else {
             // Fallback: Check leaderboard for finding ID by auth ID if needed?
             // But explicitTargetId should already be the gamePlayerId/targetId if set via interface.
             // If set via clicking avatar, it IS the targetId.
             targetGameId = explicitTargetId;
          }
      }

      // 2. Auto-Target (Leader if I am not, or Second place if I am leader)
      if (targetGameId == null) {
         final RacerViewModel? leaderVM = raceView.racers.where((vm) => vm.isLeader).firstOrNull;
         if (leaderVM != null && !leaderVM.isMe) {
             targetGameId = leaderVM.data.id;
         } else {
             // Fallback: Ahead?
             final aheadVM = raceView.racers.where((vm) => vm.lane == -1 && !vm.isMe).firstOrNull;
             if (aheadVM != null) targetGameId = aheadVM.data.id;
         }
      }

      if (targetGameId == null || targetGameId.isEmpty) {
        if (context.mounted) {
           ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('No se encontró un objetivo válido')),
          );
        }
        return;
      }

      final result = await playerProvider.usePower(
        powerSlug: selectedPowerSlug,
        targetGamePlayerId: targetGameId,
        effectProvider: effectProvider,
        gameProvider: gameProvider,
      );

      final bool success = result == PowerUseResult.success;

      if (result == PowerUseResult.error && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No se pudo lanzar el sabotaje')),
        );
      } else if (success && context.mounted) {
        final suppressed = effectProvider.lastDefenseAction == DefenseAction.stealFailed;
        if (!suppressed) {
          showDialog(
            context: context,
            barrierDismissible: true,
            builder: (_) => const _AttackSentDialog(),
          );
        }
      }
    }

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 20),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.cardBg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTheme.primaryPurple.withOpacity(0.3)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 10,
            spreadRadius: 2,
          ),
        ],
      ),
      child: PowerGestureWrapper(
        onSwipeUp: handleSwipeAttack,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Cabecera
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Text(
                      '🏁 CARRERA EN VIVO',
                      style: TextStyle(
                        color: AppTheme.accentGold,
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(width: 8),
                    const _LiveIndicator(),
                  ],
                ),
                if (onSurrender != null)
                  GestureDetector(
                    onTap: onSurrender,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppTheme.dangerRed.withOpacity(0.1),
                        border: Border.all(
                            color: AppTheme.dangerRed.withOpacity(0.5)),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Text(
                        'RENDIRSE',
                        style: TextStyle(
                          color: AppTheme.dangerRed,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 24),

            // --- PISTA DE CARRERAS (RENDERING ONLY via RaceViewData) ---
            SizedBox(
              height: 120,
              child: LayoutBuilder(
                builder: (context, constraints) {
                  return Stack(
                    alignment: Alignment.centerLeft,
                    clipBehavior: Clip.none,
                    children: [
                      // 1. Línea Base
                      Center(
                        child: Container(
                          height: 8,
                          width: double.infinity,
                          decoration: BoxDecoration(
                            color: Colors.grey[800],
                            borderRadius: BorderRadius.circular(4),
                            gradient: LinearGradient(
                              colors: [Colors.grey[800]!, Colors.grey[700]!],
                            ),
                          ),
                        ),
                      ),

                      // Marcas
                      const Positioned(left: 0, top: 65, child: Text("START", style: TextStyle(fontSize: 8, color: Colors.white30))),
                      const Positioned(right: 0, top: 65, child: Text("META", style: TextStyle(fontSize: 8, color: Colors.white30))),

                      // Bandera
                      const Positioned(
                        right: -8,
                        top: 25,
                        child: Icon(Icons.flag_circle, color: AppTheme.accentGold, size: 36),
                      ),

                      // 2. Renderizar View Models (Using ITargetable, decoupled from Player)
                      ...raceView.racers.map((vm) => _RacerAvatarWidget(
                        vm: vm,
                        trackWidth: constraints.maxWidth,
                        totalClues: totalClues,
                        isSelected: gameProvider.targetPlayerId == vm.data.id, 
                        onTap: () {
                           if (!vm.isTargetable) return;
                           gameProvider.setTargetPlayerId(vm.data.id);
                        },
                      )),
                    ],
                  );
                },
              ),
            ),

            // Leyenda inferior dinámica (Pre-calculada en Service)
            const SizedBox(height: 8),
            Center(
              child: Text(
                raceView.motivationText,
                style: TextStyle(
                  color: Colors.white.withOpacity(0.5),
                  fontSize: 10,
                  fontStyle: FontStyle.italic,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RacerAvatarWidget extends StatelessWidget {
  final RacerViewModel vm;
  final double trackWidth;
  final int totalClues;
  final bool isSelected;
  final VoidCallback onTap;

  const _RacerAvatarWidget({
    required this.vm,
    required this.trackWidth,
    required this.totalClues,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    // Calculo visual puro usando ITargetable.progress (double)
    // progress is already usually count/totalXP. User defined ITargetable.progress as "Mapea a completed_clues_count". 
    // Wait, totalXP is count. 
    // Normalized progress for UI = count / totalClues.
    
    final double count = vm.data.progress;
    final progress = totalClues > 0 ? (count / totalClues).clamp(0.0, 1.0) : 0.0;
    
    double laneOffset = 0;
    if (vm.lane == -1) laneOffset = -35;
    if (vm.lane == 1) laneOffset = 35;
    
    final double avatarSize = (vm.isMe || isSelected) ? 40 : 30;
    final double maxScroll = trackWidth - avatarSize;
    final double topPosition = 60 + laneOffset - (avatarSize / 2);

    return Positioned(
      left: maxScroll * progress,
      top: topPosition,
      child: Opacity(
        opacity: vm.opacity,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (vm.isMe || isSelected)
              Padding(
                padding: const EdgeInsets.only(bottom: 2),
                child: Icon(Icons.arrow_drop_down,
                    color: isSelected ? Colors.redAccent : AppTheme.accentGold, 
                    size: 18),
              ),
            
            GestureDetector(
              onTap: onTap,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Container(
                    width: avatarSize,
                    height: avatarSize,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: isSelected 
                           ? Colors.redAccent 
                           : (vm.isMe
                              ? AppTheme.accentGold
                              : (vm.isLeader ? Colors.amber : Colors.white24)),
                        width: (vm.isMe || isSelected) ? 2 : 1,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: isSelected 
                              ? Colors.red.withOpacity(0.5)
                              : (vm.isMe
                                ? AppTheme.accentGold.withOpacity(0.3)
                                : Colors.black26),
                          blurRadius: (vm.isMe || isSelected) ? 8 : 4,
                          spreadRadius: 1,
                        )
                      ],
                    ),
                    child: CircleAvatar(
                      backgroundColor: vm.isMe ? AppTheme.primaryPurple : Colors.grey[800],
                      backgroundImage: (vm.data.avatarUrl != null && vm.data.avatarUrl!.startsWith('http'))
                          ? NetworkImage(vm.data.avatarUrl!)
                          : null,
                      child: (vm.data.avatarUrl == null || !vm.data.avatarUrl!.startsWith('http'))
                          ? Text(
                              (vm.data.label?.isNotEmpty == true)
                                  ? vm.data.label![0].toUpperCase()
                                  : '?',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: vm.isMe ? 14 : 10,
                                fontWeight: FontWeight.bold,
                              ),
                            )
                          : null,
                    ),
                  ),
                  
                  // Status Icon Overlay
                  if (vm.statusIcon != null)
                    Container(
                      width: avatarSize,
                      height: avatarSize,
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.5),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(vm.statusIcon, color: vm.statusColor ?? Colors.white, size: avatarSize * 0.6),
                    ),
                ],
              ),
            ),
            
            const SizedBox(height: 3),
            Container(
               padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
               decoration: BoxDecoration(
                 color: isSelected ? Colors.red : (vm.isMe ? AppTheme.accentGold : Colors.black.withOpacity(0.7)),
                 borderRadius: BorderRadius.circular(6),
               ),
               child: Row(
                 mainAxisSize: MainAxisSize.min,
                 children: [
                   Text(
                     vm.isMe ? 'TÚ' : (vm.isLeader ? 'TOP 1' : _getShortName(vm.data.label ?? 'J')),
                     style: TextStyle(
                        color: vm.isMe ? Colors.black : Colors.white,
                        fontSize: 9, 
                        fontWeight: FontWeight.w700,
                     ),
                   ),
                   if (vm.isMe || vm.isLeader || isSelected) ...[
                     const SizedBox(width: 3),
                     Text(
                       '${vm.data.progress.toInt()}', // Display count
                       style: TextStyle(
                         color: vm.isMe ? Colors.black87 : Colors.white70,
                         fontSize: 9, 
                         fontWeight: FontWeight.w500,
                       ),
                     )
                   ]
                 ],
               ),
            )
          ],
        ),
      ),
    );
  }

  String _getShortName(String fullName) {
    if (fullName.isEmpty) return 'J';
    final parts = fullName.split(' ');
    if (parts.isNotEmpty) {
      String name = parts[0];
      if (name.length > 5) name = name.substring(0, 5); 
      return name;
    }
    return fullName.substring(0, 3);
  }
}

class _LiveIndicator extends StatefulWidget {
  const _LiveIndicator();

  @override
  State<_LiveIndicator> createState() => _LiveIndicatorState();
}

class _LiveIndicatorState extends State<_LiveIndicator>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _controller,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
            color: Colors.red,
            borderRadius: BorderRadius.circular(4),
            boxShadow: [
              BoxShadow(color: Colors.red.withOpacity(0.5), blurRadius: 6)
            ]),
        child: const Text(
          'LIVE',
          style: TextStyle(
            color: Colors.white,
            fontSize: 8,
            fontWeight: FontWeight.bold,
            letterSpacing: 1,
          ),
        ),
      ),
    );
  }
}

class _AttackSentDialog extends StatelessWidget {
  const _AttackSentDialog();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.8),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppTheme.accentGold, width: 2),
          boxShadow: [
            BoxShadow(
                color: AppTheme.accentGold.withOpacity(0.4), blurRadius: 12),
          ],
        ),
        child: const Text(
          '¡ATAQUE ENVIADO!',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 16,
            letterSpacing: 1.5,
          ),
        ),
      ),
    );
  }
}
