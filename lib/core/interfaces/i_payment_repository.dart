/// Payment repository interface for Wallet abstraction.
/// 
/// This interface defines the contract for all payment-related operations,
/// allowing the application to be decoupled from specific payment gateways
/// or database implementations.
library;

/// Available payment gateway types for top-ups.
enum GatewayType {
  stripe,
  paypal,
  internal, // For in-game currency transfers
}

/// Distribution formula types for pot distribution.
enum DistributionFormula {
  winnerTakesAll,
  topThree,
  proportional,
}

/// Result of a payment operation.
class PaymentResult {
  final bool success;
  final String? transactionId;
  final String? errorMessage;
  final double? newBalance;

  const PaymentResult({
    required this.success,
    this.transactionId,
    this.errorMessage,
    this.newBalance,
  });

  factory PaymentResult.success({
    required String transactionId,
    required double newBalance,
  }) => PaymentResult(
    success: true,
    transactionId: transactionId,
    newBalance: newBalance,
  );

  factory PaymentResult.failure(String message) => PaymentResult(
    success: false,
    errorMessage: message,
  );
}

/// Contract for payment repository implementations.
/// 
/// Implementations may include:
/// - SupabasePaymentRepository (production)
/// - MockPaymentRepository (testing)
/// - StripePaymentRepository (external gateway)
abstract class IPaymentRepository {
  
  /// Process a top-up to the user's wallet.
  /// 
  /// [userId] The user receiving the top-up.
  /// [amount] The amount to add (in Tréboles).
  /// [gateway] The payment gateway used for processing.
  Future<PaymentResult> processTopUp({
    required String userId,
    required double amount,
    required GatewayType gateway,
  });

  /// Handle pot distribution after an event ends.
  /// 
  /// [eventId] The event whose pot is being distributed.
  /// [totalPot] The total pot amount to distribute.
  /// [formula] The distribution formula to apply.
  /// [winnerIds] List of winner user IDs in rank order.
  Future<PaymentResult> handlePoteDistribution({
    required String eventId,
    required double totalPot,
    required DistributionFormula formula,
    required List<String> winnerIds,
  });

  /// Deduct an entry fee from a user's wallet.
  /// 
  /// [userId] The user paying the fee.
  /// [eventId] The event being joined.
  /// [amount] The fee amount in Tréboles.
  Future<PaymentResult> deductEntryFee({
    required String userId,
    required String eventId,
    required double amount,
  });

  /// Get the current wallet balance for a user.
  /// 
  /// [userId] The user to query.
  Future<double> getBalance(String userId);

  /// Get transaction history for a user.
  /// 
  /// [userId] The user to query.
  /// [limit] Maximum number of transactions to return.
  Future<List<Map<String, dynamic>>> getTransactionHistory({
    required String userId,
    int limit = 50,
  });
}
