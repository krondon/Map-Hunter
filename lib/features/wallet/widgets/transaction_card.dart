import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../../core/theme/app_theme.dart';
import '../models/transaction_item.dart';

class TransactionCard extends StatelessWidget {
  final TransactionItem item;
  final VoidCallback? onResumePayment;
  final VoidCallback? onCancelOrder;

  const TransactionCard({
    super.key,
    required this.item,
    this.onResumePayment,
    this.onCancelOrder,
  });

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('dd/MM/yyyy HH:mm');
    final color = item.statusColor;
    
    // Status Text Map
    String statusText;
    IconData icon;
    
    switch (item.status.toLowerCase()) {
       case 'completed':
       case 'success':
       case 'paid':
         statusText = 'Exitoso';
         icon = Icons.eco_rounded;
         break;
       case 'pending':
         statusText = 'Pendiente';
         icon = Icons.access_time_rounded;
         break;
       case 'failed':
       case 'error':
         statusText = 'Fallido';
         icon = Icons.error_outline_rounded;
         break;
       case 'expired':
         statusText = 'Expirado';
         icon = Icons.timer_off_rounded;
         break;
       default:
         statusText = item.status;
         icon = Icons.info_outline;
    }

    // Override icon/text for special types if needed, or rely on status
    if (item.type == 'withdrawal' && (item.status == 'completed' || item.status == 'success')) {
       icon = Icons.arrow_upward_rounded;
       statusText = 'Retiro';
    }

    // Humanize and Clean Description (Removing technical IDs)
    String displayDescription = item.description;
    
    // 1. Map specific DB descriptions to user-friendly labels
    final lowerDesc = displayDescription.toLowerCase();
    
    // --- Specific descriptions from wallet_ledger (highest priority) ---
    if (lowerDesc.contains('comisión por ataque')) {
      displayDescription = 'COMISIÓN POR ATAQUE';
    } else if (lowerDesc.contains('premio') || lowerDesc.contains('podio') || lowerDesc.contains('prize')) {
      displayDescription = 'PREMIO OBTENIDO';
    } else if (lowerDesc.contains('apuesta') || lowerDesc.contains('bet payout') || lowerDesc.contains('ganancia apuesta')) {
      displayDescription = 'GANANCIA DE APUESTA';
    } else if (lowerDesc.contains('spectator_buy') || lowerDesc.contains('compra espectador')) {
      displayDescription = 'COMPRA DE PODER';
    } else if (lowerDesc.contains('event entry') || lowerDesc.contains('entrada')) {
      displayDescription = 'ENTRADA A EVENTO';
    } else if (lowerDesc.contains('winnings')) {
      displayDescription = 'PREMIO OBTENIDO';
    } else if (lowerDesc.contains('clover_payment') && item.amount < 0) {
      displayDescription = 'PAGO CON TRÉBOLES';
    // --- Generic purchase (clover orders pending/failed) ---
    } else if (lowerDesc.contains('compra de tréboles') || lowerDesc.contains('purchase')) {
      displayDescription = 'COMPRA DE TRÉBOLES';
    } else if (item.type == 'withdrawal') {
      displayDescription = 'RETIRO DE SALDO';
    // --- Deposit fallback: only for truly generic entries ---
    } else if (item.type == 'deposit' && (lowerDesc == 'recarga' || lowerDesc.isEmpty || lowerDesc == 'transacción')) {
      displayDescription = 'RECARGA DE SALDO';
    } else {
      // 2. Generic Cleaning: Remove anything that looks like a long ID (#123, UUIDs, etc.)
      displayDescription = displayDescription
          .replaceAll(RegExp(r'#[0-9a-zA-Z-]+'), '') // Remove #ID
          .replaceAll(RegExp(r'[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}.*'), '') // Remove UUID fragments
          .trim();
          
      if (displayDescription.isEmpty) displayDescription = 'TRANSACCIÓN';
    }

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      color: Colors.white.withOpacity(0.05), // Subtle cyber glass
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(icon, color: color, size: 24),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        displayDescription.toUpperCase(),
                        maxLines: 2,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                          color: Colors.white,
                          fontFamily: 'Orbitron',
                          letterSpacing: 0.3,
                          height: 1.2,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        dateFormat.format(item.date),
                        style: const TextStyle(
                          color: Colors.white30,
                          fontSize: 10,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    // Clover Amount (Primary)
                    Text(
                      '${item.isCredit ? '+' : ''}${item.amount.toInt()} 🍀',
                      style: TextStyle(
                        fontFamily: 'Orbitron',
                        color: item.isCredit ? AppTheme.successGreen : AppTheme.dangerRed, 
                        fontWeight: FontWeight.w900,
                        fontSize: 15,
                      ),
                    ),
                    // Fiat Amount (Secondary)
                    if (item.fiatAmount != null && 
                        item.fiatAmount! > 0 && 
                        ['completed', 'success', 'paid'].contains(item.status.toLowerCase()))
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Text(
                          '\$${item.fiatAmount!.toStringAsFixed(2)}', 
                          style: const TextStyle(
                            color: Colors.white38,
                            fontSize: 10,
                            fontFamily: 'Orbitron',
                          ),
                        ),
                      ),
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: color.withOpacity(0.05),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: color.withOpacity(0.2)),
                      ),
                      child: Text(
                        statusText.toUpperCase(),
                        style: TextStyle(
                          color: color,
                          fontSize: 8,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
            if (item.canResumePayment || item.canCancel) ...[
              const Divider(height: 24, color: Colors.white10),
              Row(
                children: [
                   if (item.canResumePayment)
                     Expanded(
                      child: ElevatedButton.icon(
                        onPressed: onResumePayment,
                        icon: const Icon(Icons.payment, size: 18),
                        label: const Text('Completar'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.orange,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                      ),
                    ),
                    
                    if (item.canResumePayment && item.canCancel)
                      const SizedBox(width: 8),

                    if (item.canCancel)
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: onCancelOrder,
                          icon: const Icon(Icons.cancel_outlined, size: 18),
                          label: const Text('Cancelar'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.redAccent,
                            side: const BorderSide(color: Colors.redAccent),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                        ),
                      ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}
