import 'package:flutter/material.dart';
import '../../../core/interfaces/i_payment_repository.dart';
import '../../../core/models/transaction.dart';


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

  double _balance = 0.0;
  List<Transaction> _transactions = [];
  bool _isLoading = false;
  String? _errorMessage;
  String? _currentUserId;

  WalletProvider({required IPaymentRepository paymentRepository})
      : _paymentRepository = paymentRepository;

  // --- Getters ---
  double get balance => _balance;
  List<Transaction> get transactions => _transactions;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  bool get hasError => _errorMessage != null;

  /// Formatted balance for display.
  String get formattedBalance => '${_balance.toStringAsFixed(2)} 🍀';

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

  // --- Private Methods ---

  Future<void> _loadTransactions() async {
    if (_currentUserId == null) return;

    try {
      final history = await _paymentRepository.getTransactionHistory(
        userId: _currentUserId!,
      );
      _transactions = history.map((m) => Transaction.fromMap(m)).toList();
    } catch (e) {
      debugPrint('[WalletProvider] Error loading transactions: $e');
    }
  }
}
