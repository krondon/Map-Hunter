import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/models/player.dart';
import '../../game/models/race_view_data.dart';
import '../providers/power_interfaces.dart';
import '../providers/game_provider.dart';
import '../../auth/providers/player_provider.dart';
import '../services/race_logic_service.dart';
import 'power_selector_bottom_sheet.dart';
import 'player_group_selector.dart';
import '../../../shared/widgets/loading_indicator.dart';

/// RaceTrackWidget displays the race progress with interactive avatar selection.
/// 
/// Implements tactical interactions following SOLID principles:
/// - SRP: Widget only handles rendering, delegates logic to RaceLogicService
/// - ISP: Power filtering based on target type (attack vs defense)
/// - DIP: Uses PowerActionDispatcher for execution orchestration
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
    this.compact = false,
  });

  final bool compact;

  @override
  Widget build(BuildContext context) {
    final playerProvider = Provider.of<PlayerProvider>(context, listen: false);
    final effectProvider = Provider.of<PowerEffectManager>(context);
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

    /// Handles avatar tap: Opens power selector or player group selector
    Future<void> handleAvatarTap(RacerViewModel vm) async {
      if (gameProvider.isPowerActionLoading) return;
      
      final me = playerProvider.currentPlayer;
      if (me == null || myGamePlayerId == null) return;

      // Check if this avatar is part of a group (overlapping players)
      final group = raceView.getGroupForPlayer(vm.data.id);
      
      RacerViewModel selectedRacer = vm;
      
      // If group has multiple members, show player selector first
      if (group != null && group.hasOverlap) {
        final selected = await PlayerGroupSelector.show(
          context: context,
          group: group,
        );
        if (selected == null) return; // User dismissed
        selectedRacer = selected;
      }

      // Determine if target is self
      final normalizedMyId = myGamePlayerId.trim().toLowerCase();
      final normalizedTargetId = selectedRacer.data.id.trim().toLowerCase();
      final isTargetSelf = normalizedMyId == normalizedTargetId;

      // Show power selector with ISP filtering
      final selectedPower = await PowerSelectorBottomSheet.show(
        context: context,
        targetName: selectedRacer.isMe ? 'Ti mismo' : (selectedRacer.data.label ?? 'Rival'),
        isTargetSelf: isTargetSelf,
        inventory: me.inventory,
      );

      if (selectedPower == null || !context.mounted) return;

      // Execute the power
      await _executePower(
        context: context,
        powerSlug: selectedPower.id,
        targetId: selectedRacer.data.id,
        targetName: selectedRacer.data.label ?? 'Rival',
        isTargetSelf: isTargetSelf,
        playerProvider: playerProvider,
        effectProvider: effectProvider,
        gameProvider: gameProvider,
      );
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
      child: Stack(
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
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
              
              // Tactical hint - HIDDEN IN COMPACT MODE
              if (!compact)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    '👆 Toca un avatar para usar poderes',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.4),
                      fontSize: 10,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ),
              
              SizedBox(height: compact ? 8 : 16),

              // --- RACE TRACK (RENDERING ONLY via RaceViewData) ---
              SizedBox(
                height: compact ? 60 : 120,
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    return Stack(
                      alignment: Alignment.centerLeft,
                      clipBehavior: Clip.none,
                      children: [
                        // 1. Base Line
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

                        // Markers
                        const Positioned(left: 0, top: 65, child: Text("START", style: TextStyle(fontSize: 8, color: Colors.white30))),
                        const Positioned(right: 0, top: 65, child: Text("META", style: TextStyle(fontSize: 8, color: Colors.white30))),

                        // Flag
                        const Positioned(
                          right: -8,
                          top: 25,
                          child: Icon(Icons.flag_circle, color: AppTheme.accentGold, size: 36),
                        ),

                        // 2. Render View Models (Using ITargetable, decoupled from Player)
                        ...raceView.racers.map((vm) => _RacerAvatarWidget(
                          vm: vm,
                          trackWidth: constraints.maxWidth,
                          totalClues: totalClues,
                          isSelected: gameProvider.targetPlayerId == vm.data.id, 
                          onTap: () => handleAvatarTap(vm),
                          compact: compact,
                        )),
                      ],
                    );
                  },
                ),
              ),



              // Dynamic legend (Pre-calculated in Service) - HIDDEN IN COMPACT MODE
              if (!compact) ...[
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
            ],
          ),
          
          // Loading overlay
          if (gameProvider.isPowerActionLoading)
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.5),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const LoadingIndicator(fontSize: 14),
                      SizedBox(height: 8),
                      Text(
                        'Ejecutando poder...',
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  /// Executes a power using PlayerProvider (DIP: delegated execution)
  Future<void> _executePower({
    required BuildContext context,
    required String powerSlug,
    required String targetId,
    required String targetName,
    required bool isTargetSelf,
    required PlayerProvider playerProvider,
    required PowerEffectManager effectProvider,
    required GameProvider gameProvider,
  }) async {
    // Set loading state
    gameProvider.setPowerActionLoading(true);

    try {
      final result = await playerProvider.usePower(
        powerSlug: powerSlug,
        targetGamePlayerId: targetId,
        effectProvider: effectProvider,
        gameProvider: gameProvider,
      );

      if (!context.mounted) return;

      final bool success = result == PowerUseResult.success;

      if (result == PowerUseResult.error) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No se pudo lanzar el poder'),
            backgroundColor: AppTheme.dangerRed,
          ),
        );
      } else if (result == PowerUseResult.blocked) {
        // Handled by SabotageOverlay via PowerEffectProvider.notifyAttackBlocked()
      } else if (success) {
        final suppressed = effectProvider.lastDefenseAction == DefenseAction.stealFailed;
        if (!suppressed) {
          showDialog(
            context: context,
            barrierDismissible: true,
            builder: (_) => _PowerExecutedDialog(
              isAttack: !isTargetSelf,
              targetName: targetName,
            ),
          );
        }
      }
    } finally {
      gameProvider.setPowerActionLoading(false);
    }
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
    this.compact = false,
  });

  final bool compact;

  @override
  Widget build(BuildContext context) {
    // Calculo visual puro usando ITargetable.progress (double)
    final double count = vm.data.progress;
    final progress = totalClues > 0 ? (count / totalClues).clamp(0.0, 1.0) : 0.0;
    
    double laneOffset = 0;
    if (vm.lane == -1) laneOffset = -35;
    if (vm.lane == 1) laneOffset = 35;
    
    final double avatarSize = (vm.isMe || isSelected) ? 40 : 30;
    final double maxScroll = trackWidth - avatarSize;
    final double topPosition = (compact ? 30 : 60) + laneOffset - (avatarSize / 2);

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
                  // Highlight ring for targetable avatars
                  if (vm.isTargetable || vm.isMe)
                    Container(
                      width: avatarSize + 6,
                      height: avatarSize + 6,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: vm.isMe 
                              ? AppTheme.successGreen.withOpacity(0.5)
                              : AppTheme.dangerRed.withOpacity(0.3),
                          width: 2,
                          strokeAlign: BorderSide.strokeAlignOutside,
                        ),
                      ),
                    ),
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
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(avatarSize / 2),
                      child: Container(
                        color: vm.isMe ? AppTheme.primaryPurple : Colors.grey[800],
                        child: Builder(
                          builder: (context) {
                            // 1. Prioridad: Avatar Local
                            if (vm.data.avatarId != null && vm.data.avatarId!.isNotEmpty) {
                              return Image.asset(
                                'assets/images/avatars/${vm.data.avatarId}.png',
                                fit: BoxFit.cover,
                                errorBuilder: (context, error, stackTrace) {
                                  return Center(
                                    child: Text(
                                      (vm.data.label?.isNotEmpty == true) ? vm.data.label![0].toUpperCase() : '?',
                                      style: TextStyle(color: Colors.white, fontSize: avatarSize * 0.4, fontWeight: FontWeight.bold),
                                    ),
                                  );
                                },
                              );
                            }
                            
                            // 2. Fallback: Foto de perfil (URL)
                            if (vm.data.avatarUrl != null && vm.data.avatarUrl!.startsWith('http')) {
                              return Image.network(
                                vm.data.avatarUrl!,
                                fit: BoxFit.cover,
                                errorBuilder: (context, error, stackTrace) => Center(
                                  child: Text(
                                    (vm.data.label?.isNotEmpty == true) ? vm.data.label![0].toUpperCase() : '?',
                                    style: TextStyle(color: Colors.white, fontSize: avatarSize * 0.4, fontWeight: FontWeight.bold),
                                  ),
                                ),
                              );
                            }
                            
                            // 3. Fallback: Iniciales
                            return Center(
                              child: Text(
                                (vm.data.label?.isNotEmpty == true) ? vm.data.label![0].toUpperCase() : '?',
                                style: TextStyle(color: Colors.white, fontSize: avatarSize * 0.4, fontWeight: FontWeight.bold),
                              ),
                            );
                          },
                        ),
                      ),
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

class _PowerExecutedDialog extends StatefulWidget {
  final bool isAttack;
  final String targetName;
  final String? customTitle;
  final Color? customColor;
  
  const _PowerExecutedDialog({
    required this.isAttack,
    required this.targetName,
    this.customTitle,
    this.customColor,
  });

  @override
  State<_PowerExecutedDialog> createState() => _PowerExecutedDialogState();
}

class _PowerExecutedDialogState extends State<_PowerExecutedDialog>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  late Animation<double> _opacityAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1500));
    _scaleAnimation = TweenSequence<double>([
      TweenSequenceItem(
          tween: Tween(begin: 0.0, end: 1.5)
              .chain(CurveTween(curve: Curves.elasticOut)),
          weight: 40),
      TweenSequenceItem(
          tween: Tween(begin: 1.5, end: 1.2)
              .chain(CurveTween(curve: Curves.easeInOut)),
          weight: 20),
      TweenSequenceItem(
          tween: Tween(begin: 1.2, end: 5.0)
              .chain(CurveTween(curve: Curves.fastOutSlowIn)),
          weight: 40),
    ]).animate(_controller);

    _opacityAnimation = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0.0, end: 1.0), weight: 20),
      TweenSequenceItem(tween: ConstantTween(1.0), weight: 60),
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 0.0), weight: 20),
    ]).animate(_controller);

    _controller.forward().then((_) {
      if (mounted) Navigator.pop(context);
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          return Opacity(
            opacity: _opacityAnimation.value,
            child: Transform.scale(
              scale: _scaleAnimation.value,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    widget.isAttack ? '⚡' : '🛡️',
                    style: const TextStyle(fontSize: 80),
                  ),
                  const SizedBox(height: 10),
                  Material(
                    color: Colors.transparent,
                    child: Text(
                      widget.customTitle ?? (widget.isAttack ? '¡ATAQUE ENVIADO!' : '¡PODER ACTIVADO!'),
                      style: TextStyle(
                        color: widget.customColor ?? AppTheme.accentGold,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 2,
                      ),
                    ),
                  ),
                  if (widget.targetName.isNotEmpty) ...[
                    const SizedBox(height: 5),
                    Material(
                      color: Colors.transparent,
                      child: Text(
                        widget.isAttack 
                            ? 'Objetivo: ${widget.targetName}'
                            : 'Aplicado a: ${widget.targetName}',
                        style: const TextStyle(color: Colors.white, fontSize: 10),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
