/// Transaction model for wallet audit trail.
/// 
/// Every financial operation in the system creates a Transaction record
/// for complete auditability and traceability.
library;

/// Transaction types for the wallet system.
enum TransactionType {
  /// Money added to wallet.
  topUp,
  
  /// Entry fee paid to join an event.
  entryFee,
  
  /// Winnings distributed from a pot.
  winnings,
  
  /// Refund for a cancelled event.
  refund,
  
  /// Purchase of in-game items.
  purchase,
  
  /// Transfer between users.
  transfer,
}

/// Transaction status.
enum TransactionStatus {
  /// Transaction is being processed.
  pending,
  
  /// Transaction completed successfully.
  completed,
  
  /// Transaction failed.
  failed,
  
  /// Transaction was cancelled/reversed.
  cancelled,
}

/// Transaction record for the wallet audit trail.
class Transaction {
  final String id;
  final String userId;
  final double amount;
  final TransactionType type;
  final TransactionStatus status;
  final DateTime createdAt;
  final DateTime? completedAt;
  final String? eventId;
  final String? description;
  final Map<String, dynamic>? metadata;

  const Transaction({
    required this.id,
    required this.userId,
    required this.amount,
    required this.type,
    required this.status,
    required this.createdAt,
    this.completedAt,
    this.eventId,
    this.description,
    this.metadata,
  });

  /// Create a transaction from a database map.
  factory Transaction.fromMap(Map<String, dynamic> map) {
    return Transaction(
      id: map['id'] as String,
      userId: map['user_id'] as String,
      amount: (map['amount'] as num).toDouble(),
      type: TransactionType.values.firstWhere(
        (e) => e.name == map['type'],
        orElse: () => TransactionType.purchase,
      ),
      status: TransactionStatus.values.firstWhere(
        (e) => e.name == map['status'],
        orElse: () => TransactionStatus.pending,
      ),
      createdAt: DateTime.parse(map['created_at'] as String),
      completedAt: map['completed_at'] != null 
          ? DateTime.parse(map['completed_at'] as String)
          : null,
      eventId: map['event_id'] as String?,
      description: map['description'] as String?,
      metadata: map['metadata'] as Map<String, dynamic>?,
    );
  }

  /// Convert to a database map.
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'user_id': userId,
      'amount': amount,
      'type': type.name,
      'status': status.name,
      'created_at': createdAt.toIso8601String(),
      if (completedAt != null) 'completed_at': completedAt!.toIso8601String(),
      if (eventId != null) 'event_id': eventId,
      if (description != null) 'description': description,
      if (metadata != null) 'metadata': metadata,
    };
  }

  /// Check if transaction is a debit (money out).
  bool get isDebit => type == TransactionType.entryFee || 
                       type == TransactionType.purchase ||
                       type == TransactionType.transfer;

  /// Check if transaction is a credit (money in).
  bool get isCredit => type == TransactionType.topUp ||
                        type == TransactionType.winnings ||
                        type == TransactionType.refund;

  /// Display-friendly amount with sign.
  String get displayAmount {
    final sign = isCredit ? '+' : '-';
    return '$sign${amount.toStringAsFixed(2)} 🍀';
  }

  @override
  String toString() => 'Transaction($id, $type, $amount, $status)';
}
