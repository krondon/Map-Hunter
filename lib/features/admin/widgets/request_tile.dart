import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../game/models/game_request.dart';
import '../../game/providers/game_request_provider.dart';
import '../../auth/providers/player_provider.dart';
import '../../../shared/models/player.dart';

/// Widget tile para mostrar solicitudes de acceso a eventos
/// y participantes inscritos con su estado y progreso.
class RequestTile extends StatefulWidget {
  final GameRequest request;
  final bool isReadOnly;
  final int? rank;
  final int? progress;
  final String? currentStatus; // Override status (e.g. from game_players)
  final VoidCallback? onBanToggled; // Callback to refresh parent UI

  const RequestTile({
    super.key,
    required this.request, 
    this.isReadOnly = false,
    this.rank,
    this.progress,
    this.currentStatus,
    this.onBanToggled,
  });

  @override
  State<RequestTile> createState() => _RequestTileState();
}

class _RequestTileState extends State<RequestTile> {
  bool _isApproving = false;

  /// Formatea la fecha en formato legible dd/MM/yyyy HH:mm
  String _formatDate(DateTime date) {
    final day = date.day.toString().padLeft(2, '0');
    final month = date.month.toString().padLeft(2, '0');
    final year = date.year;
    final hour = date.hour.toString().padLeft(2, '0');
    final minute = date.minute.toString().padLeft(2, '0');
    return '$day/$month/$year $hour:$minute';
  }

  void _toggleBan(BuildContext context, PlayerProvider provider, String userId, String eventId, bool isBanned) {
    debugPrint('RequestTile: _toggleBan CLICKED. User: $userId, Event: $eventId, CurrentlyBanned: $isBanned');
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.cardBg,
        title: Text(isBanned ? "Desbanear de Competencia" : "Banear de Competencia", style: const TextStyle(color: Colors.white)),
        content: Text(
          isBanned 
            ? "¿Permitir el acceso nuevamente a este usuario a esta competencia?" 
            : "¿Estás seguro? El usuario será expulsado de esta competencia.",
          style: const TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () {
              debugPrint('RequestTile: Ban dialog CANCELLED');
              Navigator.pop(ctx);
            },
            child: const Text("Cancelar"),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: isBanned ? Colors.green : Colors.red),
            onPressed: () async {
              debugPrint('RequestTile: Ban dialog CONFIRMED. Calling toggleGameBanUser...');
              Navigator.pop(ctx);
              try {
                // Changed to Event-Specific Ban
                await provider.toggleGameBanUser(userId, eventId, !isBanned);
                debugPrint('RequestTile: toggleGameBanUser SUCCESS');
                
                // Notify parent to refresh UI
                if (widget.onBanToggled != null) {
                  debugPrint('RequestTile: Calling onBanToggled callback');
                  widget.onBanToggled!();
                }
                
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(isBanned ? "Usuario desbaneado de competencia" : "Usuario baneado de competencia")),
                  );
                }
              } catch (e) {
                debugPrint('RequestTile: toggleGameBanUser ERROR: $e');
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

  Future<void> _handleApprove(BuildContext context) async {
    if (_isApproving) return; // Prevent double-tap
    setState(() => _isApproving = true);

    try {
      final provider = Provider.of<GameRequestProvider>(context, listen: false);
      final result = await provider.approveRequest(widget.request.id);

      if (!mounted) return;

      final success = result['success'] == true;
      if (success) {
        final paid = result['paid'] == true;
        final amount = result['amount'] ?? 0;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(paid
                ? '✅ Aprobado y cobrado: $amount 🍀'
                : '✅ Aprobado (evento gratuito)'),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        final error = result['error'] ?? 'UNKNOWN';
        String message;
        switch (error) {
          case 'PAYMENT_FAILED':
            final paymentError = result['payment_error'] ?? '';
            message = paymentError == 'INSUFFICIENT_CLOVERS'
                ? '❌ Saldo insuficiente del usuario'
                : '❌ Error en el pago: $paymentError';
            break;
          case 'REQUEST_NOT_PENDING':
            message = '⚠️ La solicitud ya no está pendiente (${result['current_status']})';
            break;
          case 'REQUEST_NOT_FOUND':
            message = '⚠️ Solicitud no encontrada';
            break;
          default:
            message = '❌ Error: $error';
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(message), backgroundColor: Colors.red),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al aprobar: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isApproving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<PlayerProvider>(
      builder: (context, playerProvider, _) {
        // Priorizar el estado local pasado explícitamente (game_players)
        // Si no existe, buscamos el global (fallback)
        final bool isBanned;
        
        if (widget.currentStatus != null) {
          // Aceptamos 'banned' o 'suspended' como estado de baneo local
          isBanned = widget.currentStatus == 'banned' || widget.currentStatus == 'suspended';
        } else {
           final globalStatus = playerProvider.allPlayers
            .firstWhere((p) => p.id == widget.request.playerId,
                 orElse: () => Player(userId: '', email: '', name: '', role: '', status: PlayerStatus.active))
            .status;
            isBanned = globalStatus == PlayerStatus.banned;
        }

        return Card(
          color: isBanned ? Colors.red.withOpacity(0.1) : AppTheme.cardBg,
          margin: const EdgeInsets.only(bottom: 10),
          child: ListTile(
            leading: (widget.isReadOnly && widget.rank != null) 
              ? CircleAvatar(
                  backgroundColor: _getRankColor(widget.rank!),
                  foregroundColor: Colors.white,
                  child: Text("#${widget.rank}", style: const TextStyle(fontWeight: FontWeight.bold)),
                )
              : null,
            title: Text(
              widget.request.playerName ?? 'Desconocido', 
              style: TextStyle(
                color: isBanned ? Colors.redAccent : Colors.white,
                decoration: isBanned ? TextDecoration.lineThrough : null,
                fontWeight: FontWeight.bold,
              )
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(widget.request.playerEmail ?? 'No email', style: const TextStyle(color: Colors.white54)),
                // Fecha de creación de la solicitud
                if (widget.request.createdAt != null)
                  Text(
                    'Solicitud: ${_formatDate(widget.request.createdAt!)}',
                    style: const TextStyle(color: Colors.white38, fontSize: 11),
                  ),
                if (widget.isReadOnly && widget.progress != null)
                   Text("Pistas completadas: ${widget.progress}", style: const TextStyle(color: AppTheme.accentGold, fontSize: 12)),
              ],
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (widget.isReadOnly) ...[
                   // Si está baneado, mostramos estado 'SUSPENDIDO' en lugar del check
                   if (isBanned)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.red.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(color: Colors.redAccent),
                        ),
                        child: const Text("SUSPENDIDO", style: TextStyle(color: Colors.redAccent, fontSize: 10, fontWeight: FontWeight.bold)),
                      )
                   else
                      const Icon(Icons.check_circle, color: Colors.green),

                   const SizedBox(width: 8),
                   IconButton(
                     icon: Icon(isBanned ? Icons.lock_open : Icons.block),
                     color: isBanned ? Colors.greenAccent : Colors.red,
                     tooltip: isBanned ? "Desbanear" : "Banear",
                     onPressed: () => _toggleBan(context, playerProvider, widget.request.playerId, widget.request.eventId, isBanned),
                   ),
                ] else ...[
                   IconButton(
                    icon: const Icon(Icons.close, color: Colors.red),
                    onPressed: _isApproving ? null : () => Provider.of<GameRequestProvider>(context, listen: false).rejectRequest(widget.request.id),
                  ),
                  if (_isApproving)
                    const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2))
                  else
                    IconButton(
                      icon: const Icon(Icons.check, color: Colors.green),
                      onPressed: () => _handleApprove(context),
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
