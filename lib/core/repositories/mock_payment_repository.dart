import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';
import '../interfaces/i_payment_repository.dart';
import '../models/transaction.dart';

/// Mock implementation of the payment repository for development/testing.
/// 
/// This stub maintains an in-memory balance and transaction history,
/// enabling wallet UI development without backend integration.
class MockPaymentRepository implements IPaymentRepository {
  final Map<String, double> _balances = {};
  final Map<String, List<Transaction>> _transactions = {};
  final _uuid = const Uuid();

  /// Default starting balance for new users.
  static const double defaultStartingBalance = 100.0;

  @override
  Future<PaymentResult> processTopUp({
    required String userId,
    required double amount,
    required GatewayType gateway,
  }) async {
    // Simulate network delay
    await Future.delayed(const Duration(milliseconds: 500));

    if (amount <= 0) {
      return PaymentResult.failure('El monto debe ser mayor a 0');
    }

    final currentBalance = _balances[userId] ?? defaultStartingBalance;
    final newBalance = currentBalance + amount;
    _balances[userId] = newBalance;

    // Record transaction
    final transaction = Transaction(
      id: _uuid.v4(),
      userId: userId,
      amount: amount,
      type: TransactionType.topUp,
      status: TransactionStatus.completed,
      createdAt: DateTime.now(),
      completedAt: DateTime.now(),
      description: 'Recarga vía ${gateway.name}',
    );
    _addTransaction(userId, transaction);

    debugPrint('[MockPaymentRepo] TopUp: +$amount for $userId. New balance: $newBalance');

    return PaymentResult.success(
      transactionId: transaction.id,
      newBalance: newBalance,
    );
  }

  @override
  Future<PaymentResult> handlePoteDistribution({
    required String eventId,
    required double totalPot,
    required DistributionFormula formula,
    required List<String> winnerIds,
  }) async {
    await Future.delayed(const Duration(milliseconds: 300));

    if (winnerIds.isEmpty) {
      return PaymentResult.failure('No hay ganadores para distribuir');
    }

    final distributions = _calculateDistribution(totalPot, formula, winnerIds.length);
    
    for (int i = 0; i < winnerIds.length && i < distributions.length; i++) {
      final winnerId = winnerIds[i];
      final amount = distributions[i];
      
      final currentBalance = _balances[winnerId] ?? defaultStartingBalance;
      _balances[winnerId] = currentBalance + amount;

      final transaction = Transaction(
        id: _uuid.v4(),
        userId: winnerId,
        amount: amount,
        type: TransactionType.winnings,
        status: TransactionStatus.completed,
        createdAt: DateTime.now(),
        completedAt: DateTime.now(),
        eventId: eventId,
        description: 'Premio - Posición ${i + 1}',
      );
      _addTransaction(winnerId, transaction);

      debugPrint('[MockPaymentRepo] Winnings: +$amount for $winnerId (position ${i + 1})');
    }

    return PaymentResult.success(
      transactionId: _uuid.v4(),
      newBalance: _balances[winnerIds.first] ?? 0,
    );
  }

  @override
  Future<PaymentResult> deductEntryFee({
    required String userId,
    required String eventId,
    required double amount,
  }) async {
    await Future.delayed(const Duration(milliseconds: 300));

    final currentBalance = _balances[userId] ?? defaultStartingBalance;
    
    if (currentBalance < amount) {
      return PaymentResult.failure(
        'Saldo insuficiente. Tienes ${currentBalance.toStringAsFixed(2)} 🍀, necesitas ${amount.toStringAsFixed(2)} 🍀',
      );
    }

    final newBalance = currentBalance - amount;
    _balances[userId] = newBalance;

    final transaction = Transaction(
      id: _uuid.v4(),
      userId: userId,
      amount: amount,
      type: TransactionType.entryFee,
      status: TransactionStatus.completed,
      createdAt: DateTime.now(),
      completedAt: DateTime.now(),
      eventId: eventId,
      description: 'Inscripción a evento',
    );
    _addTransaction(userId, transaction);

    debugPrint('[MockPaymentRepo] EntryFee: -$amount for $userId. New balance: $newBalance');

    return PaymentResult.success(
      transactionId: transaction.id,
      newBalance: newBalance,
    );
  }

  @override
  Future<double> getBalance(String userId) async {
    await Future.delayed(const Duration(milliseconds: 100));
    return _balances[userId] ?? defaultStartingBalance;
  }

  @override
  Future<List<Map<String, dynamic>>> getTransactionHistory({
    required String userId,
    int limit = 50,
  }) async {
    await Future.delayed(const Duration(milliseconds: 200));
    
    final userTransactions = _transactions[userId] ?? [];
    return userTransactions
        .take(limit)
        .map((t) => t.toMap())
        .toList();
  }

  // --- Private Helpers ---

  void _addTransaction(String userId, Transaction transaction) {
    _transactions.putIfAbsent(userId, () => []);
    _transactions[userId]!.insert(0, transaction); // Most recent first
  }

  List<double> _calculateDistribution(double total, DistributionFormula formula, int winnerCount) {
    switch (formula) {
      case DistributionFormula.winnerTakesAll:
        return [total];
      
      case DistributionFormula.topThree:
        if (winnerCount == 1) return [total];
        if (winnerCount == 2) return [total * 0.7, total * 0.3];
        return [total * 0.5, total * 0.3, total * 0.2];
      
      case DistributionFormula.proportional:
        return List.generate(winnerCount, (_) => total / winnerCount);
    }
  }
}
