import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';
import '../models/race_view_data.dart';
import '../models/progress_group.dart';

/// Dialog for selecting a specific player from a group of overlapping players.
/// 
/// Used when multiple players are at the same progress percentage and their
/// avatars would overlap on the race track.
class PlayerGroupSelector extends StatelessWidget {
  /// The group of players to select from
  final ProgressGroup group;
  
  /// Callback when a player is selected
  final void Function(RacerViewModel racer) onPlayerSelected;

  const PlayerGroupSelector({
    super.key,
    required this.group,
    required this.onPlayerSelected,
  });

  /// Shows the dialog and returns the selected racer, or null if dismissed
  static Future<RacerViewModel?> show({
    required BuildContext context,
    required ProgressGroup group,
  }) async {
    return showDialog<RacerViewModel>(
      context: context,
      barrierColor: Colors.black54,
      builder: (dialogContext) => PlayerGroupSelector(
        group: group,
        onPlayerSelected: (racer) => Navigator.pop(dialogContext, racer),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final racers = group.members.cast<RacerViewModel>();
    
    return Center(
      child: Container(
        margin: const EdgeInsets.all(32),
        constraints: const BoxConstraints(maxWidth: 320),
        decoration: BoxDecoration(
          color: AppTheme.cardBg,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppTheme.primaryPurple.withOpacity(0.4)),
          boxShadow: [
            BoxShadow(
              color: AppTheme.primaryPurple.withOpacity(0.2),
              blurRadius: 20,
              spreadRadius: 2,
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppTheme.primaryPurple.withOpacity(0.1),
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppTheme.accentGold.withOpacity(0.2),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.people,
                        color: AppTheme.accentGold,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '¿A QUIÉN ELIGES?',
                            style: TextStyle(
                              color: AppTheme.accentGold,
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                              letterSpacing: 1,
                            ),
                          ),
                          Text(
                            'Varios jugadores en la misma posición',
                            style: TextStyle(
                              color: Colors.white54,
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close, color: Colors.white54, size: 20),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                  ],
                ),
              ),
              
              // Player list
              ConstrainedBox(
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.of(context).size.height * 0.4,
                ),
                child: ListView.separated(
                  shrinkWrap: true,
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  itemCount: racers.length,
                  separatorBuilder: (_, __) => const Divider(
                    color: Colors.white12,
                    height: 1,
                    indent: 16,
                    endIndent: 16,
                  ),
                  itemBuilder: (context, index) {
                    final racer = racers[index];
                    return _PlayerTile(
                      racer: racer,
                      onTap: () => onPlayerSelected(racer),
                    );
                  },
                ),
              ),
              
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }
}

class _PlayerTile extends StatelessWidget {
  final RacerViewModel racer;
  final VoidCallback onTap;

  const _PlayerTile({
    required this.racer,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final avatarUrl = racer.data.avatarUrl;
    final hasValidAvatar = avatarUrl != null && avatarUrl.startsWith('http');
    final label = racer.data.label ?? 'Jugador';
    
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            // Avatar
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: racer.isMe 
                      ? AppTheme.accentGold 
                      : (racer.isLeader ? Colors.amber : Colors.white24),
                  width: racer.isMe ? 2 : 1,
                ),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(22),
                child: Container(
                  color: racer.isMe ? AppTheme.primaryPurple : Colors.grey[800],
                  child: Builder(
                    builder: (context) {
                      final avatarId = racer.data.avatarId;
                      final avatarUrl = racer.data.avatarUrl;
                      
                      // 1. Prioridad: Avatar Local
                      if (avatarId != null && avatarId.isNotEmpty) {
                        return Image.asset(
                          'assets/images/avatars/$avatarId.png',
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => _buildInitials(label),
                        );
                      }
                      
                      // 2. Fallback: Foto de perfil (URL)
                      if (avatarUrl != null && avatarUrl.startsWith('http')) {
                        return Image.network(
                          avatarUrl,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => _buildInitials(label),
                        );
                      }
                      
                      // 3. Fallback: Iniciales
                      return _buildInitials(label);
                    },
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            
            // Name and status
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          racer.isMe ? 'Tú' : label,
                          style: TextStyle(
                            color: racer.isMe ? AppTheme.accentGold : Colors.white,
                            fontWeight: racer.isMe ? FontWeight.bold : FontWeight.normal,
                            fontSize: 14,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (racer.isLeader) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.amber.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Text(
                            'LÍDER',
                            style: TextStyle(
                              color: Colors.amber,
                              fontSize: 9,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  Text(
                    'Progreso: ${racer.data.progress.toInt()}',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.5),
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
            
            // Status icon
            if (racer.statusIcon != null)
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: (racer.statusColor ?? Colors.white).withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  racer.statusIcon,
                  color: racer.statusColor ?? Colors.white,
                  size: 16,
                ),
              )
            else
              Icon(
                Icons.chevron_right,
                color: Colors.white.withOpacity(0.3),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildInitials(String label) {
    return Center(
      child: Text(
        label.isNotEmpty ? label[0].toUpperCase() : '?',
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}
