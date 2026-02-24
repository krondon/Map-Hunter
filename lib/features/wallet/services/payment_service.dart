import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/clover_plan.dart';

class PaymentService {
  final SupabaseClient _supabase;

  PaymentService(this._supabase);

  /// Creates a payment order for Tréboles (Clovers).
  ///
  /// Flow:
  /// 1. Fetches user profile data (email, phone, dni).
  /// 2. Calls Edge Function `api_pay_orders`.
  /// 3. Creates a local record in `clover_orders`.
  /// 4. Returns the payment URL for redirection.
  Future<String?> createPaymentOrder({
    required double amount,
    required String userId,
  }) async {
    try {
      debugPrint('[PaymentService] Starting payment order creation for user: $userId, amount: $amount');

      // 1. Fetch User Profile Data
      final profileData = await _supabase
          .from('profiles')
          .select('email, phone, dni')
          .eq('id', userId)
          .single();

      final String? email = profileData['email'];
      // Ensure phone and DNI are treated as Strings (DB update compatibility)
      final String? phone = profileData['phone']?.toString();
      final String? dni = profileData['dni']?.toString();

      if (email == null || phone == null || dni == null) {
        throw Exception('Perfil incompleto. Verifique email, teléfono y DNI.');
      }

      // Calculate expiration (15 minutes)
      final DateTime expirationDate = DateTime.now().add(const Duration(minutes: 15));
      final String expiresAt = expirationDate.toIso8601String();

      // 2. Call Edge Function (Secure Proxy to Pago a Pago)
      debugPrint('[PaymentService] Calling api_pay_orders Edge Function...');
      
      final functionResponse = await _supabase.functions.invoke(
        'api_pay_orders',
        body: {
          'amount': amount,
          'currency': 'VES',
          'email': email,
          'phone': phone,
          'dni': dni,
          'motive': 'Recarga de Tréboles - Map Hunter',
          'type_order': 'EXTERNAL',
          'expires_at': expiresAt,
          'extra_data': {
            'user_id': userId,
            'clovers_amount': amount,
          }
        },
      );

      if (functionResponse.status != 200) {
        throw Exception('Error en servicio de pagos (${functionResponse.status}): ${functionResponse.data}');
      }

      final responseData = functionResponse.data;
      if (kDebugMode) {
        debugPrint('[PaymentService] RAW RESPONSE: $responseData');
      }

      if (responseData == null) {
         throw Exception('Respuesta vacía del servicio de pagos');
      }
      
      if (responseData['success'] == false) {
         throw Exception('API Error: ${responseData['message'] ?? responseData['error'] ?? "Unknown error"}');
      }

      // Parsing response
      final Map<String, dynamic> dataObj = responseData['data'] ?? responseData['result'] ?? responseData;
      
      final String? orderId = dataObj['order_id']?.toString() ?? dataObj['id']?.toString();
      final String? rawPaymentUrl = dataObj['payment_url']?.toString() ?? dataObj['url']?.toString();

      if (orderId == null || orderId.isEmpty || rawPaymentUrl == null || rawPaymentUrl.isEmpty) {
        throw Exception('Datos de orden incompletos en la respuesta: $responseData');
      }

      // 3. Prepare Redirect URL with Return Parameter
      // This ensures the user comes back to the app after payment
      final Uri originalUri = Uri.parse(rawPaymentUrl);
      final Map<String, String> updatedParams = Map.from(originalUri.queryParameters);
      updatedParams['urlReturn'] = 'io.supabase.treasurehunt://payment-return';
      
      final String finalPaymentUrl = originalUri.replace(queryParameters: updatedParams).toString();

      // 4. Persistence: "Truth of Intent" (Client-Side)
      if (kDebugMode) {
        debugPrint('[PaymentService] PRE-INSERT CHECK:');
        debugPrint(' - user_id type: ${userId.runtimeType} ($userId)');
        debugPrint(' - order_id type: ${orderId.runtimeType} ($orderId)');
        debugPrint(' - amount type: ${amount.runtimeType} ($amount)');
        debugPrint(' - status: pending');
        
        debugPrint('[PaymentService] Persisting order $orderId to DB (clover_orders)...');
      }
      
      try {
        await _supabase.from('clover_orders').insert({
          'user_id': userId,
          'pago_pago_order_id': orderId, // DB Column: pago_pago_order_id (TEXT)
          'amount': amount,              // DB Column: amount (NUMERIC)
          'currency': 'VES',
          'status': 'pending',           // DB Column: status (TEXT)
          'payment_url': finalPaymentUrl,
          'expires_at': expiresAt,
          'extra_data': {
            'initiated_at': DateTime.now().toIso8601String(),
            'original_url': rawPaymentUrl, 
            'client_device': 'mobile',
            'clovers_amount': amount,
          }
        });
        
        debugPrint('[PaymentService] INSERT SUCCESS for order $orderId'); // Block check passed

      } on PostgrestException catch (error) {
        if (kDebugMode) {
          // 1. Logs de Postgrest
          debugPrint('[PaymentService] POSTGRES ERROR CAUGHT!');
          debugPrint(' - error.message: ${error.message}');
          debugPrint(' - error.code: ${error.code}'); // e.g. 23503 (FK), 42703 (Column)
          debugPrint(' - error.hint: ${error.hint}');
          debugPrint(' - error.details: ${error.details}');
          
          // 2. Verificación de Integridad Referencial (Foreign Keys)
          if (error.code == '23503') {
             debugPrint('[PaymentService] ALERT: Llave foránea violada. El user_id $userId podría no existir en public.profiles?');
          }
        }
        
        throw Exception('DB Error: ${error.message} (Code: ${error.code})');
        
      } catch (dbError) {
        // Critical Failure Block
        debugPrint('[PaymentService] CRITICAL GENERIC PERSISTENCE ERROR: $dbError');
        throw Exception('Error de conexión: No se pudo registrar la orden. Por favor intente nuevamente.');
      }

      debugPrint('[PaymentService] Order saved successfully. Returning URL.');
      return finalPaymentUrl;

    } catch (e) {
      debugPrint('[PaymentService] Error creating payment order: $e');
      rethrow; 
    }
  }

  /// Launches the payment URL in the browser/external app.
  Future<void> launchPaymentUrl(String url) async {
    final uri = Uri.parse(url);
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      throw Exception('No se pudo abrir el enlace de pago: $url');
    }
  }

  /// Fetches unified activity feed (ledger + orders) from user_activity_feed view.
  Future<List<Map<String, dynamic>>> getUserActivityFeed(String userId) async {
    try {
      final response = await _supabase
          .from('user_activity_feed')
          .select()
          .eq('user_id', userId)
          .order('created_at', ascending: false);
      
      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      debugPrint('[PaymentService] Error fetching activity feed: $e');
      return [];
    }
  }

  /// Fetches pending or failed orders for a user.
  Future<List<Map<String, dynamic>>> getPendingOrders(String userId) async {
    try {
      final response = await _supabase
          .from('clover_orders')
          .select()
          .eq('user_id', userId)
          .inFilter('status', ['pending', 'failed'])
          .order('created_at', ascending: false);
      
      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      debugPrint('[PaymentService] Error fetching pending orders: $e');
      return [];
    }
  }

  /// Fetches available clover purchase plans.
  Future<List<CloverPlan>> getCloverPlans() async {
    try {
      final response = await _supabase
          .from('clover_plans')
          .select()
          .order('price_usd', ascending: true);
      
      return (response as List).map((e) => CloverPlan.fromJson(e)).toList();
    } catch (e) {
      debugPrint('Error fetching clover plans: $e');
      return [];
    }
  }
}
