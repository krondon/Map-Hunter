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

      debugPrint(
          '[AppConfigService] No exchange rate found, using fallback 1.0');
      return 1.0;
    } catch (e) {
      debugPrint('[AppConfigService] Error fetching exchange rate: $e');
      return 1.0;
    }
  }

  /// Checks if the BCV exchange rate is fresh (updated within 26 hours).
  /// Returns FALSE if the rate is stale or on any error (fail-safe).
  /// Used by the UI to show maintenance banners and disable withdrawal buttons.
  Future<bool> isBcvRateValid() async {
    try {
      final response = await _supabase
          .from('app_config')
          .select('updated_at')
          .eq('key', 'bcv_exchange_rate')
          .maybeSingle();

      if (response == null || response['updated_at'] == null) return false;

      final updatedAt = DateTime.parse(response['updated_at'] as String);
      final now = DateTime.now().toUtc();
      final hoursSinceUpdate = now.difference(updatedAt).inHours;

      debugPrint(
        '[AppConfigService] BCV rate age: ${hoursSinceUpdate}h '
        '(threshold: 26h, valid: ${hoursSinceUpdate < 26})',
      );
      return hoursSinceUpdate < 26;
    } catch (e) {
      debugPrint('[AppConfigService] Error checking rate validity: $e');
      return false; // Fail-safe: assume stale on error
    }
  }

  /// Updates the BCV exchange rate.
  /// Only admins can perform this operation (enforced by RLS).
  Future<bool> updateExchangeRate(double rate) async {
    try {
      final userId = _supabase.auth.currentUser?.id;

      await _supabase
          .from('app_config')
          .update({
            'value': rate,
            'updated_at': DateTime.now().toIso8601String(),
            'updated_by': userId?.toString(),
          })
          .eq('key', 'bcv_exchange_rate');

      debugPrint('[AppConfigService] Exchange rate updated to $rate');
      return true;
    } catch (e) {
      debugPrint('[AppConfigService] Error updating exchange rate: $e');
      return false;
    }
  }

  /// Fetches the gateway fee percentage for visual display.
  /// Returns the fee as a double (e.g., 3.0 for 3%), or 0.0 as fallback.
  Future<double> getGatewayFeePercentage() async {
    try {
      final response = await _supabase
          .from('app_config')
          .select('value')
          .eq('key', 'gateway_fee_percentage')
          .maybeSingle();

      if (response != null && response['value'] != null) {
        final value = response['value'];
        if (value is num) {
          return value.toDouble();
        } else if (value is String) {
          return double.tryParse(value) ?? 0.0;
        }
      }

      debugPrint('[AppConfigService] No gateway fee found, using 0.0');
      return 0.0;
    } catch (e) {
      debugPrint('[AppConfigService] Error fetching gateway fee: $e');
      return 0.0;
    }
  }

  /// Updates the gateway fee percentage.
  /// Only admins can perform this operation (enforced by RLS).
  Future<bool> updateGatewayFeePercentage(double fee) async {
    try {
      final userId = _supabase.auth.currentUser?.id;

      await _supabase
          .from('app_config')
          .update({
            'value': fee,
            'updated_at': DateTime.now().toIso8601String(),
            'updated_by': userId?.toString(),
          })
          .eq('key', 'gateway_fee_percentage');

      debugPrint('[AppConfigService] Gateway fee updated to $fee%');
      return true;
    } catch (e) {
      debugPrint('[AppConfigService] Error updating gateway fee: $e');
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

  /// Generic update for any config key.
  Future<bool> updateConfig(String key, dynamic value) async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      await _supabase.from('app_config').upsert({
        'key': key,
        'value': value,
        'updated_at': DateTime.now().toIso8601String(),
        'updated_by': userId,
      });
      return true;
    } catch (e) {
      debugPrint('[AppConfigService] Error updating config $key: $e');
      return false;
    }
  }

  /// Fetches all auto-event settings in a single RPC call (Supabase-First).
  Future<Map<String, dynamic>> getAutoEventSettings() async {
    try {
      final response = await _supabase.rpc('get_auto_event_settings');
      return Map<String, dynamic>.from(response);
    } catch (e) {
      debugPrint(
          '[AppConfigService] Error calling get_auto_event_settings: $e');
      return {
        'enabled': false,
        'interval_minutes': 30,
        'min_players': 10,
        'max_players': 30,
        'min_games': 4,
        'max_games': 10,
        'min_fee': 0,
        'max_fee': 100,
        'fee_step': 5,
      };
    }
  }

  /// Updates all auto-event settings using a single RPC call.
  Future<bool> updateAutoEventSettings(Map<String, dynamic> settings) async {
    try {
      await _supabase.rpc('update_auto_event_settings', params: {
        'p_settings': settings,
      });
      return true;
    } catch (e) {
      debugPrint(
          '[AppConfigService] Error calling update_auto_event_settings: $e');
      return false;
    }
  }
}
