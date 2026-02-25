import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../game/models/game_request.dart';
import '../../game/providers/game_request_provider.dart';
import '../../auth/providers/player_provider.dart';
import '../../../shared/models/player.dart';
import '../services/admin_service.dart';

/// Widget tile para mostrar solicitudes de acceso a eventos
/// y participantes inscritos con su estado y progreso.
class RequestTile extends StatefulWidget {
  final GameRequest request;
  final bool isReadOnly;
  final int? rank;
  final int? progress;
  final String? currentStatus; // Override status (e.g. from game_players)
  final VoidCallback? onBanToggled; // Callback to refresh parent UI
  final int? coins;
  final int? lives;
  final String? eventId;
  final VoidCallback? onStatsUpdated; // Callback after coins/lives change

  const RequestTile({
    super.key,
    required this.request, 
    this.isReadOnly = false,
    this.rank,
    this.progress,
    this.currentStatus,
    this.onBanToggled,
    this.coins,
    this.lives,
    this.eventId,
    this.onStatsUpdated,
  });

  @override
  State<RequestTile> createState() => _RequestTileState();
}

class _RequestTileState extends State<RequestTile> {
  bool _isApproving = false;
  bool _isAdjusting = false;

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

  /// Muestra un diálogo para ajustar monedas o vidas del jugador.
  void _showAdjustDialog(BuildContext context, String field, int currentValue) {
    final label = field == 'coins' ? 'Monedas' : 'Vidas';
    final icon = field == 'coins' ? Icons.monetization_on : Icons.favorite;
    final color = field == 'coins' ? AppTheme.accentGold : Colors.redAccent;
    final controller = TextEditingController(text: currentValue.toString());
    final maxValue = field == 'lives' ? 3 : 99999;

    showDialog(
      context: context,
      builder: (ctx) {
        int tempValue = currentValue;
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: AppTheme.cardBg,
              title: Row(
                children: [
                  Icon(icon, color: color, size: 22),
                  const SizedBox(width: 8),
                  Text('Ajustar $label', style: const TextStyle(color: Colors.white)),
                ],
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    widget.request.playerName ?? 'Jugador',
                    style: const TextStyle(color: Colors.white70, fontSize: 14),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.remove_circle, color: Colors.redAccent, size: 32),
                        onPressed: tempValue > 0
                            ? () {
                                setDialogState(() {
                                  tempValue--;
                                  controller.text = tempValue.toString();
                                });
                              }
                            : null,
                      ),
                      const SizedBox(width: 12),
                      SizedBox(
                        width: 80,
                        child: TextField(
                          controller: controller,
                          keyboardType: TextInputType.number,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: color,
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                          ),
                          decoration: InputDecoration(
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: BorderSide(color: color.withOpacity(0.3)),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: BorderSide(color: color.withOpacity(0.3)),
                            ),
                            contentPadding: const EdgeInsets.symmetric(vertical: 8),
                          ),
                          onChanged: (v) {
                            final parsed = int.tryParse(v);
                            if (parsed != null) {
                              setDialogState(() => tempValue = parsed.clamp(0, maxValue));
                            }
                          },
                        ),
                      ),
                      const SizedBox(width: 12),
                      IconButton(
                        icon: const Icon(Icons.add_circle, color: Colors.greenAccent, size: 32),
                        onPressed: tempValue < maxValue
                            ? () {
                                setDialogState(() {
                                  tempValue++;
                                  controller.text = tempValue.toString();
                                });
                              }
                            : null,
                      ),
                    ],
                  ),
                  if (field == 'lives')
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text('Máximo: 3 vidas', style: TextStyle(color: Colors.white38, fontSize: 11)),
                    ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Cancelar'),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: color),
                  onPressed: () async {
                    Navigator.pop(ctx);
                    final finalValue = int.tryParse(controller.text) ?? tempValue;
                    await _applyStatChange(field, finalValue.clamp(0, maxValue));
                  },
                  child: const Text('Guardar', style: TextStyle(color: Colors.white)),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _applyStatChange(String field, int newValue) async {
    if (_isAdjusting || widget.eventId == null) return;
    setState(() => _isAdjusting = true);
    try {
      final adminService = Provider.of<AdminService>(context, listen: false);
      await adminService.setPlayerStat(
        userId: widget.request.playerId,
        eventId: widget.eventId!,
        field: field,
        value: newValue,
      );
      if (mounted) {
        final label = field == 'coins' ? 'Monedas' : 'Vidas';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✅ $label actualizado a $newValue'),
            backgroundColor: Colors.green,
          ),
        );
        widget.onStatsUpdated?.call();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isAdjusting = false);
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
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Column(
              children: [
                ListTile(
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
                // --- Coins & Lives Row (only for approved/read-only participants) ---
                if (widget.isReadOnly && (widget.coins != null || widget.lives != null))
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                    child: Row(
                      children: [
                        if (widget.rank != null)
                          const SizedBox(width: 40), // align with ListTile leading
                        // Coins chip
                        if (widget.coins != null)
                          _StatChip(
                            icon: Icons.monetization_on,
                            value: widget.coins!,
                            color: AppTheme.accentGold,
                            label: 'Monedas',
                            onTap: widget.eventId != null && !_isAdjusting
                                ? () => _showAdjustDialog(context, 'coins', widget.coins!)
                                : null,
                          ),
                        const SizedBox(width: 12),
                        // Lives chip
                        if (widget.lives != null)
                          _StatChip(
                            icon: Icons.favorite,
                            value: widget.lives!,
                            color: Colors.redAccent,
                            label: 'Vidas',
                            onTap: widget.eventId != null && !_isAdjusting
                                ? () => _showAdjustDialog(context, 'lives', widget.lives!)
                                : null,
                          ),
                        if (_isAdjusting)
                          const Padding(
                            padding: EdgeInsets.only(left: 12),
                            child: SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white54),
                            ),
                          ),
                      ],
                    ),
                  ),
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

/// Chip compacto para mostrar una estadística (monedas/vidas) con opción de editar.
class _StatChip extends StatelessWidget {
  final IconData icon;
  final int value;
  final Color color;
  final String label;
  final VoidCallback? onTap;

  const _StatChip({
    required this.icon,
    required this.value,
    required this.color,
    required this.label,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: color),
            const SizedBox(width: 4),
            Text(
              '$value',
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.bold,
                fontSize: 13,
              ),
            ),
            if (onTap != null) ...[
              const SizedBox(width: 4),
              Icon(Icons.edit, size: 11, color: color.withOpacity(0.6)),
            ],
          ],
        ),
      ),
    );
  }
}
