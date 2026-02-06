import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/transaction_item.dart';

abstract class ITransactionRepository {
  Future<List<TransactionItem>> getMyTransactions({int? limit});
  Future<bool> cancelOrder(String orderId);
}

class SupabaseTransactionRepository implements ITransactionRepository {
  final SupabaseClient _supabase;

  SupabaseTransactionRepository({SupabaseClient? supabase})
      : _supabase = supabase ?? Supabase.instance.client;

  @override
  Future<List<TransactionItem>> getMyTransactions({int? limit}) async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) {
        return [];
      }

      var query = _supabase
          .from('user_activity_feed')
          .select('*')
          .eq('user_id', user.id)
          .order('created_at', ascending: false);

      if (limit != null) {
        query = query.limit(limit);
      }

      final response = await query;

      if (response == null) {
        return [];
      }

      final List<dynamic> data = response as List<dynamic>;
      return data.map((e) => TransactionItem.fromMap(e as Map<String, dynamic>)).toList();
    } catch (e) {
      throw Exception('Error cargando transacciones: $e');
    }
  }
  @override
  Future<bool> cancelOrder(String orderId) async {
    try {
      final response = await _supabase.functions.invoke(
        'api_cancel_order',
        body: {'order_id': orderId},
      );

      if (response.status != 200) {
        throw Exception('Error cancelling order: ${response.data}');
      }
      
      return true;
    } catch (e) {
      debugPrint('Error cancelling order: $e');
      return false;
    }
  }
}
