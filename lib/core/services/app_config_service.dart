import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Service for managing global app configuration stored in app_config table.
/// 
/// Currently handles:
/// - BCV Exchange Rate (bcv_exchange_rate)
class AppConfigService {
  final SupabaseClient _supabase;

  AppConfigService({required SupabaseClient supabaseClient})
      : _supabase = supabaseClient;

  /// Fetches the current BCV exchange rate (USD -> VES).
  /// Returns the rate as a double, or 1.0 as fallback.
  Future<double> getExchangeRate() async {
    try {
      final response = await _supabase
          .from('app_config')
          .select('value')
          .eq('key', 'bcv_exchange_rate')
          .maybeSingle();

      if (response != null && response['value'] != null) {
        // Value is stored as JSONB, parse it
        final value = response['value'];
        if (value is num) {
          return value.toDouble();
        } else if (value is String) {
          return double.tryParse(value) ?? 1.0;
        }
      }
      
      debugPrint('[AppConfigService] No exchange rate found, using fallback 1.0');
      return 1.0;
    } catch (e) {
      debugPrint('[AppConfigService] Error fetching exchange rate: $e');
      return 1.0;
    }
  }

  /// Updates the BCV exchange rate.
  /// Only admins can perform this operation (enforced by RLS).
  Future<bool> updateExchangeRate(double rate) async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      
      await _supabase.from('app_config').upsert({
        'key': 'bcv_exchange_rate',
        'value': rate,
        'updated_at': DateTime.now().toIso8601String(),
        'updated_by': userId,
      });

      debugPrint('[AppConfigService] Exchange rate updated to $rate');
      return true;
    } catch (e) {
      debugPrint('[AppConfigService] Error updating exchange rate: $e');
      return false;
    }
  }

  /// Fetches a generic config value by key.
  Future<dynamic> getConfig(String key) async {
    try {
      final response = await _supabase
          .from('app_config')
          .select('value')
          .eq('key', key)
          .maybeSingle();

      return response?['value'];
    } catch (e) {
      debugPrint('[AppConfigService] Error fetching config $key: $e');
      return null;
    }
  }
}
