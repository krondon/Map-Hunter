import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart'; // Added
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/pago_a_pago_models.dart';
import '../../features/social/screens/wallet_screen.dart'; // To access any constants if needed, or moved here.

class PagoAPagoService {
  // BASE URL from documentation (Your Supabase Project)
  static String get _baseUrl => 
    '${dotenv.env['SUPABASE_URL']}/functions/v1';
  
  static String get _apiKeyPlaceholder => 
    dotenv.env['PAGO_PAGO_API_KEY'] ?? 'PAGO_PAGO_API_KEY_AQUI'; 

  final String apiKey;

  PagoAPagoService({required this.apiKey});

  Future<PaymentOrderResponse> createPaymentOrder(PaymentOrderRequest request, String authToken) async {
    // Legacy/Full implementation
    final url = Uri.parse('$_baseUrl/api_pay_orders');
    try {
      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $authToken',
        },
        body: jsonEncode(request.toJson()),
      );
      if (response.statusCode == 200 || response.statusCode == 201) {
        return PaymentOrderResponse.fromJson(jsonDecode(response.body));
      } else {
         return PaymentOrderResponse(success: false, message: 'Error ${response.statusCode}: ${response.body}');
      }
    } catch (e) {
      return PaymentOrderResponse(success: false, message: 'Excepción: $e');
    }
  }

  // Refactored to use Supabase Functions (Ensures Edge Function logic runs)
  Future<PaymentOrderResponse> createSimplePaymentOrder({required double amountBs}) async {
    try {
      debugPrint('[PagoAPagoService] Invoking Edge Function api_pay_orders for $amountBs Bs...');
      
      final FunctionResponse response = await Supabase.instance.client.functions.invoke(
        'api_pay_orders',
        body: {
          'amount': amountBs,
          'currency': 'VES',
          'motive': 'Recarga de Tréboles', 
        },
      );

      debugPrint('[PagoAPagoService] Edge Function Response: ${response.status}');
      debugPrint('[PagoAPagoService] Data: ${response.data}');

      if (response.status == 200) {
         final data = response.data;
         return PaymentOrderResponse.fromJson(data);
      } else {
         return PaymentOrderResponse(
          success: false, 
          message: 'Error ${response.status}: ${response.data}'
        );
      }
    } catch (e) {
      debugPrint('[PagoAPagoService] Exception invoking function: $e');
      if (e is FunctionException) {
         return PaymentOrderResponse(success: false, message: 'Function Error: ${e.details} (Reason: ${e.reasonPhrase})');
      }
      return PaymentOrderResponse(success: false, message: 'Excepción: $e');
    }
  }

  Future<bool> cancelOrder(String orderId) async {
    final url = Uri.parse('$_baseUrl/api_cancel_order');
    try {
      final response = await http.put(
        url,
         headers: {
          'Content-Type': 'application/json',
          'pago_pago_api': apiKey,
        },
        body: jsonEncode({'order_id': orderId}),
      );
      
      return response.statusCode == 200;
    } catch (e) {
       debugPrint('PagoAPagoService: Cancel error: $e');
       return false;
    }
  }
  Future<WithdrawalResponse> withdrawFunds(WithdrawalRequest request, String authToken) async {
    final url = Uri.parse('$_baseUrl/api_withdraw_funds');
    
    try {
      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $authToken',
        },
        body: jsonEncode(request.toJson()),
      );

      debugPrint('Withdrawal Response: ${response.body}');

      if (response.statusCode == 200 || response.statusCode == 201) {
        return WithdrawalResponse.fromJson(jsonDecode(response.body));
      } else {
         final errorBody = jsonDecode(response.body);
         return WithdrawalResponse(
           success: false, 
           message: errorBody['error'] ?? errorBody['message'] ?? 'Error ${response.statusCode}'
         );
      }
    } catch (e) {
      return WithdrawalResponse(success: false, message: 'Error de red: $e');
    }
  }
}
