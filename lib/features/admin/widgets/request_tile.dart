import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../game/models/game_request.dart';
import '../../game/providers/game_request_provider.dart';
import '../../auth/providers/player_provider.dart';
import '../../../shared/models/player.dart';

/// Widget tile para mostrar solicitudes de acceso a eventos
/// y participantes inscritos con su estado y progreso.
class RequestTile extends StatelessWidget {
  final GameRequest request;
  final bool isReadOnly;
  final int? rank;
  final int? progress;

  const RequestTile({
    super.key,
    required this.request, 
    this.isReadOnly = false,
    this.rank,
    this.progress,
  });

  /// Formatea la fecha en formato legible dd/MM/yyyy HH:mm
  String _formatDate(DateTime date) {
    final day = date.day.toString().padLeft(2, '0');
    final month = date.month.toString().padLeft(2, '0');
    final year = date.year;
    final hour = date.hour.toString().padLeft(2, '0');
    final minute = date.minute.toString().padLeft(2, '0');
    return '$day/$month/$year $hour:$minute';
  }

  void _toggleBan(BuildContext context, PlayerProvider provider, String userId, bool isBanned) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.cardBg,
        title: Text(isBanned ? "Desbanear Usuario" : "Banear Usuario", style: const TextStyle(color: Colors.white)),
        content: Text(
          isBanned 
            ? "¿Permitir el acceso nuevamente a este usuario?" 
            : "¿Estás seguro? El usuario será expulsado de la app inmediatamente.",
          style: const TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("Cancelar"),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: isBanned ? Colors.green : Colors.red),
            onPressed: () async {
              Navigator.pop(ctx);
              try {
                await provider.toggleBanUser(userId, !isBanned);
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(isBanned ? "Usuario desbaneado" : "Usuario baneado")),
                  );
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e")));
                }
              }
            },
            child: Text(isBanned ? "DESBANEAR" : "BANEAR", style: const TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<PlayerProvider>(
      builder: (context, playerProvider, _) {
        // Buscamos el estado REAL del usuario en la lista de profiles
        final userStatus = playerProvider.allPlayers
            .firstWhere((p) => p.id == request.playerId,
                 orElse: () => Player(userId: '', email: '', name: '', role: '', status: PlayerStatus.active))
            .status;
            
        final isBanned = userStatus == PlayerStatus.banned;

        return Card(
          color: isBanned ? Colors.red.withOpacity(0.1) : AppTheme.cardBg,
          margin: const EdgeInsets.only(bottom: 10),
          child: ListTile(
            leading: (isReadOnly && rank != null) 
              ? CircleAvatar(
                  backgroundColor: _getRankColor(rank!),
                  foregroundColor: Colors.white,
                  child: Text("#$rank", style: const TextStyle(fontWeight: FontWeight.bold)),
                )
              : null,
            title: Text(
              request.playerName ?? 'Desconocido', 
              style: TextStyle(
                color: isBanned ? Colors.redAccent : Colors.white,
                decoration: isBanned ? TextDecoration.lineThrough : null,
                fontWeight: FontWeight.bold,
              )
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(request.playerEmail ?? 'No email', style: const TextStyle(color: Colors.white54)),
                // Fecha de creación de la solicitud
                Text(
                  'Solicitud: ${_formatDate(request.createdAt)}',
                  style: const TextStyle(color: Colors.white38, fontSize: 11),
                ),
                if (isReadOnly && progress != null)
                   Text("Pistas completadas: $progress", style: const TextStyle(color: AppTheme.accentGold, fontSize: 12)),
              ],
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (isReadOnly) ...[
                   // Si está inscrito, mostramos check, pero si está baneado mostramos alerta visual
                   Icon(Icons.check_circle, color: isBanned ? Colors.grey : Colors.green),
                   const SizedBox(width: 8),
                   IconButton(
                     icon: Icon(isBanned ? Icons.lock_open : Icons.block),
                     color: isBanned ? Colors.greenAccent : Colors.red,
                     tooltip: isBanned ? "Desbanear Usuario" : "Banear Usuario",
                     onPressed: () => _toggleBan(context, playerProvider, request.playerId, isBanned),
                   ),
                ] else ...[
                   IconButton(
                    icon: const Icon(Icons.close, color: Colors.red),
                    onPressed: () => Provider.of<GameRequestProvider>(context, listen: false).rejectRequest(request.id),
                  ),
                  IconButton(
                    icon: const Icon(Icons.check, color: Colors.green),
                    onPressed: () => Provider.of<GameRequestProvider>(context, listen: false).approveRequest(request.id),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  Color _getRankColor(int rank) {
    if (rank == 1) return const Color(0xFFFFD700); // Gold
    if (rank == 2) return const Color(0xFFC0C0C0); // Silver
    if (rank == 3) return const Color(0xFFCD7F32); // Bronze
    return AppTheme.primaryPurple;
  }
}
