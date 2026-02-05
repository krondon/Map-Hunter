class TransactionItem {
  final DateTime date;
  final double amount;
  final String description;
  final String status; // 'completed', 'pending', 'failed'
  final String type; // 'deposit', 'withdrawal'
  final String? paymentUrl;

  const TransactionItem({
    required this.date,
    required this.amount,
    required this.description,
    required this.status,
    required this.type,
    this.paymentUrl,
  });
}
