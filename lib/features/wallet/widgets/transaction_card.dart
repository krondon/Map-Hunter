import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../../core/theme/app_theme.dart';
import '../models/transaction_item.dart';

class TransactionCard extends StatelessWidget {
  final TransactionItem item;
  final VoidCallback? onResumePayment;

  const TransactionCard({
    super.key,
    required this.item,
    this.onResumePayment,
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

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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
                        item.description,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        dateFormat.format(item.date),
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    // Clover Amount (Primary)
                    Text(
                      '${item.isCredit ? '+' : ''}${item.amount.toInt()} 🍀',
                      style: TextStyle(
                        color: item.isCredit ? AppTheme.successGreen : AppTheme.dangerRed, 
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                      ),
                    ),
                    // Fiat Amount (Secondary) - Show ONLY if present AND successful
                    if (item.fiatAmount != null && 
                        item.fiatAmount! > 0 && 
                        ['completed', 'success', 'paid'].contains(item.status.toLowerCase()))
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Text(
                          '${item.isCredit ? 'Pagado' : 'Recibido'}: \$${item.fiatAmount!.toStringAsFixed(2)}', 
                          style: const TextStyle(
                            color: Colors.white54,
                            fontSize: 11,
                          ),
                        ),
                      ),
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: color.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        statusText,
                        style: TextStyle(
                          color: color,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
            if (item.canResumePayment) ...[
              const Divider(height: 24, color: Colors.white10),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: onResumePayment,
                  icon: const Icon(Icons.payment, size: 18),
                  label: const Text('Continuar Pago'),
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
            ],
          ],
        ),
      ),
    );
  }
}
