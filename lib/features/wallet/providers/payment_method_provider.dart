import 'package:flutter/foundation.dart';
import '../repositories/payment_method_repository.dart';
import '../../../shared/interfaces/i_resettable.dart';

/// Provider for managing payment method state
/// 
/// Responsibilities:
/// - Hold the list of payment methods
/// - Manage loading and error states
/// - Coordinate with PaymentMethodRepository for CRUD operations
/// - Implement IResettable for cleanup on logout
class PaymentMethodProvider extends ChangeNotifier implements IResettable {
  final IPaymentMethodRepository _repository;

  List<Map<String, dynamic>> _methods = [];
  bool _isLoading = false;
  String? _error;

  PaymentMethodProvider({required IPaymentMethodRepository repository})
      : _repository = repository;

  // Getters
  List<Map<String, dynamic>> get methods => _methods;
  bool get isLoading => _isLoading;
  String? get error => _error;

  /// Load payment methods for a user
  Future<void> loadMethods(String userId) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      _methods = await _repository.getPaymentMethods(userId);
      _error = null;
    } catch (e) {
      _error = 'Error cargando métodos: $e';
      _methods = [];
      debugPrint('PaymentMethodProvider: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Create a new payment method
  Future<bool> createMethod(PaymentMethodCreate data) async {
    try {
      await _repository.createPaymentMethod(data);
      // Reload methods after creation
      await loadMethods(data.userId);
      return true;
    } catch (e) {
      _error = 'Error: $e';
      notifyListeners();
      return false;
    }
  }

  /// Update an existing payment method
  Future<bool> updateMethod(String id, PaymentMethodCreate data) async {
    try {
      await _repository.updatePaymentMethod(id, data);
      await loadMethods(data.userId);
      return true;
    } catch (e) {
      _error = 'Error actualizando: $e';
      notifyListeners();
      return false;
    }
  }

  /// Delete a payment method by ID
  Future<bool> deleteMethod(String id, String userId) async {
    try {
      await _repository.deletePaymentMethod(id);
      // Optimistically remove from local list
      _methods.removeWhere((m) => m['id'] == id);
      notifyListeners();
      return true;
    } catch (e) {
      _error = 'Error eliminando método: $e';
      notifyListeners();
      return false;
    }
  }

  /// Clear error message
  void clearError() {
    _error = null;
    notifyListeners();
  }

  /// Reset state on logout (IResettable implementation)
  @override
  void resetState() {
    _methods = [];
    _isLoading = false;
    _error = null;
    notifyListeners();
  }
}
