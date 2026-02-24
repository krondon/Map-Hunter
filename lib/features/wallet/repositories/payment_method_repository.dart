import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Data Transfer Object for creating a payment method
class PaymentMethodCreate {
  final String userId;
  final String bankCode;
  final String phoneNumber;
  final String dni;
  final bool isDefault;

  PaymentMethodCreate({
    required this.userId,
    required this.bankCode,
    required this.phoneNumber,
    required this.dni,
    this.isDefault = false,
  });

  Map<String, dynamic> toJson() => {
        'user_id': userId,
        'bank_code': bankCode,
        'phone_number': phoneNumber,
        'dni': dni,
        'is_default': isDefault,
      };
}

/// Repository interface for payment method operations
abstract class IPaymentMethodRepository {
  Future<List<Map<String, dynamic>>> getPaymentMethods(String userId);
  Future<void> createPaymentMethod(PaymentMethodCreate data);
  Future<void> updatePaymentMethod(String id, PaymentMethodCreate data);
  Future<void> deletePaymentMethod(String id);
}

/// Supabase implementation of payment method repository
class PaymentMethodRepository implements IPaymentMethodRepository {
  final SupabaseClient _supabase;

  PaymentMethodRepository({required SupabaseClient supabaseClient})
      : _supabase = supabaseClient;

  @override
  Future<List<Map<String, dynamic>>> getPaymentMethods(String userId) async {
    try {
      final response = await _supabase
          .from('user_payment_methods')
          .select()
          .eq('user_id', userId)
          .order('created_at', ascending: false);

      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      debugPrint('PaymentMethodRepository: Error fetching methods: $e');
      rethrow;
    }
  }

  @override
  Future<void> createPaymentMethod(PaymentMethodCreate data) async {
    try {
      await _supabase.from('user_payment_methods').insert(data.toJson());
    } catch (e) {
      debugPrint('PaymentMethodRepository: Error creating method: $e');
      rethrow;
    }
  }

  @override
  Future<void> updatePaymentMethod(String id, PaymentMethodCreate data) async {
    try {
      await _supabase.from('user_payment_methods').update({
        'bank_code': data.bankCode,
        'phone_number': data.phoneNumber,
        'dni': data.dni,
        'is_default': data.isDefault,
      }).eq('id', id);
    } catch (e) {
      debugPrint('PaymentMethodRepository: Error updating method: $e');
      rethrow;
    }
  }

  @override
  Future<void> deletePaymentMethod(String id) async {
    try {
      await _supabase.from('user_payment_methods').delete().eq('id', id);
    } catch (e) {
      debugPrint('PaymentMethodRepository: Error deleting method: $e');
      rethrow;
    }
  }
}
