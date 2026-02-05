import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
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
    // Determine visuals based on state and type
    final isPending = item.status == 'pending';
    final isFailed = item.status == 'failed';
    final isWithdrawal = item.type == 'withdrawal';
    final isDeposit = item.type == 'deposit';
    
    Color color;
    IconData icon;
    String statusText;

    if (isPending) {
      color = Colors.orange;
      icon = Icons.access_time_rounded;
      statusText = 'Pendiente';
    } else if (isFailed) {
      color = Colors.red;
      icon = Icons.error_outline_rounded;
      statusText = 'Fallido';
    } else if (isWithdrawal) {
      color = Colors.red;
      icon = Icons.arrow_upward_rounded;
      statusText = 'Retiro';
    } else {
      // Deposit / Completed
      color = Colors.green;
      icon = Icons.eco_rounded; // Clover-like
      statusText = 'Exitoso';
    }

    final dateFormat = DateFormat('dd/MM/yyyy HH:mm');

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        dateFormat.format(item.date),
                        style: TextStyle(
                          color: Colors.grey[600],
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '${isWithdrawal ? '-' : '+'}${item.amount.toStringAsFixed(2)}',
                      style: TextStyle(
                        color: color,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
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
            if (isPending && item.paymentUrl != null) ...[
              const Divider(height: 24),
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
