import 'package:flutter/material.dart';
import '../../../core/interfaces/i_payment_repository.dart';
import '../../../core/models/transaction.dart';
import '../services/payment_service.dart';


/// Wallet provider for managing user's Tréboles balance.
/// 
/// This is a stub provider that consumes the IPaymentRepository interface,
/// enabling wallet UI development independently of the backend.
/// 
/// Responsibilities (SRP):
/// - Balance management
/// - Transaction history
/// - Payment operations coordination
class WalletProvider extends ChangeNotifier {
  final IPaymentRepository _paymentRepository;
  final PaymentService? _paymentService; // Optional for backward compatibility/stubbing if needed, but intended to be required.

  double _balance = 0.0;
  List<Transaction> _transactions = [];
  bool _isLoading = false;
  String? _errorMessage;
  String? _currentUserId;

  WalletProvider({
    required IPaymentRepository paymentRepository,
    PaymentService? paymentService,
  })  : _paymentRepository = paymentRepository,
        _paymentService = paymentService;

  // --- Getters ---
  double get balance => _balance;
  List<Transaction> get transactions => _transactions;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  bool get hasError => _errorMessage != null;

  /// Formatted balance for display.
  String get formattedBalance => '${_balance.toStringAsFixed(2)} tréboles';

  /// Check if user can afford an amount.
  bool canAfford(double amount) => _balance >= amount;

  // --- State Management ---

  /// Initialize wallet for a user.
  Future<void> initialize(String userId) async {
    if (_currentUserId == userId && _balance > 0) {
      // Already initialized for this user
      return;
    }

    _currentUserId = userId;
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      _balance = await _paymentRepository.getBalance(userId);
      await _loadTransactions();
      debugPrint('[WalletProvider] Initialized for $userId with balance: $_balance');
    } catch (e) {
      _errorMessage = 'Error al cargar el wallet: $e';
      debugPrint('[WalletProvider] Error initializing: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Refresh balance from repository.
  Future<void> refreshBalance() async {
    if (_currentUserId == null) return;

    try {
      _balance = await _paymentRepository.getBalance(_currentUserId!);
      notifyListeners();
    } catch (e) {
      debugPrint('[WalletProvider] Error refreshing balance: $e');
    }
  }

  /// Process a top-up.
  Future<bool> topUp({
    required double amount,
    GatewayType gateway = GatewayType.internal,
  }) async {
    if (_currentUserId == null) return false;

    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final result = await _paymentRepository.processTopUp(
        userId: _currentUserId!,
        amount: amount,
        gateway: gateway,
      );

      if (result.success) {
        _balance = result.newBalance ?? _balance;
        await _loadTransactions();
        notifyListeners();
        return true;
      } else {
        _errorMessage = result.errorMessage;
        notifyListeners();
        return false;
      }
    } catch (e) {
      _errorMessage = 'Error procesando recarga: $e';
      notifyListeners();
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Pay entry fee for an event.
  Future<bool> payEntryFee({
    required String eventId,
    required double amount,
  }) async {
    if (_currentUserId == null) return false;

    if (!canAfford(amount)) {
      _errorMessage = 'Saldo insuficiente';
      notifyListeners();
      return false;
    }

    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final result = await _paymentRepository.deductEntryFee(
        userId: _currentUserId!,
        eventId: eventId,
        amount: amount,
      );

      if (result.success) {
        _balance = result.newBalance ?? _balance;
        await _loadTransactions();
        return true;
      } else {
        _errorMessage = result.errorMessage;
        return false;
      }
    } catch (e) {
      _errorMessage = 'Error procesando pago: $e';
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Clear wallet state (e.g., on logout).
  void clear() {
    _currentUserId = null;
    _balance = 0.0;
    _transactions = [];
    _errorMessage = null;
    notifyListeners();
  }

  /// Clear error message.
  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }

  /// Initiate external payment flow via Pago a Pago
  Future<void> initiateExternalTopUp(double amount) async {
    if (_paymentService == null) {
      _errorMessage = "Servicio de pagos no configurado";
      notifyListeners();
      return;
    }
    if (_currentUserId == null) return;

    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final url = await _paymentService!.createPaymentOrder(
        amount: amount,
        userId: _currentUserId!,
      );

      if (url != null) {
        // await _paymentService!.launchPaymentUrl(url); // Disabled per user request
        debugPrint('[WalletProvider] Redirection disabled. URL: $url');
      }
    } catch (e) {
      _errorMessage = 'Error iniciando pago: $e';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // --- Private Methods ---

  Future<void> _loadTransactions() async {
    if (_currentUserId == null || _paymentService == null) return;

    try {
      // Fetch directly from the Unified View
      final feed = await _paymentService!.getUserActivityFeed(_currentUserId!);
      
      _transactions = feed.map((data) {
        // Map view columns to Transaction object. 
        // Note: Transaction object might expect 'created_at' as DateTime, etc.
        // We'll map carefully.
        
        // Handling 'type' from view: 'deposit', 'withdrawal', 'purchase'.
        // Transaction model might rely on amount sign or explicit type.
        // Let's coerce based on amount if needed, or update Transaction model logic later.
        
        // For now, mapping to Transaction entity.
        return Transaction(
          id: data['id'] ?? '',
          userId: data['user_id'] ?? '',
          amount: (data['amount'] as num).toDouble(),
          type: _parseTransactionType(data['type'], (data['amount'] as num).toDouble()),
          status: _parseTransactionStatus(data['status']),
          description: data['description'] ?? 'Transacción',
          createdAt: DateTime.parse(data['created_at']),
          metadata: {
            'payment_url': data['payment_url'], // crucial for resuming
          }
        );
      }).toList();
      
    } catch (e) {
      debugPrint('[WalletProvider] Error loading activity feed: $e');
      // Fallback to repo if service fails? No, view is primary source now.
    }
  }

  TransactionType _parseTransactionType(String? type, double amount) {
    if (type == 'deposit') return TransactionType.deposit;
    if (type == 'withdrawal') return TransactionType.withdrawal;
    if (type == 'purchase') return TransactionType.purchase;
    // Fallback based on amount
    return amount >= 0 ? TransactionType.deposit : TransactionType.withdrawal;
  }

  TransactionStatus _parseTransactionStatus(String? status) {
    switch (status?.toLowerCase()) {
      case 'completed':
      case 'success':
      case 'paid':
        return TransactionStatus.completed;
      case 'pending':
        return TransactionStatus.pending;
      case 'failed':
      case 'error':
        return TransactionStatus.failed;
      case 'expired':
        // TransactionStatus enum needs to support 'expired' or map to failed/cancelled?
        // If enum doesn't have expired, we might need to add it or map to failed.
        // Let's assume we mapped to a custom status or check enum definition.
        // Since I can't see the enum definition right now, I'll map 'expired' to 'failed' 
        // OR if I checked it earlier... Step 244 check?
        // I will trust 'failed' is safe, but ideally updated enum.
        return TransactionStatus.failed; 
      default:
        return TransactionStatus.completed;
    }
  }
}
