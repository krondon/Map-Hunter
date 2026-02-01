import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';
import '../models/pago_a_pago_models.dart';
import '../../features/social/screens/wallet_screen.dart'; // To access any constants if needed, or moved here.

class PagoAPagoService {
  // BASE URL from documentation (Your Supabase Project)
  static const String _baseUrl = 'https://hyjelngckvqoanckqwep.supabase.co/functions/v1';
  
  // API KEY placeholder - SHOULD BE IN .ENV but hardcoded placeholder for now as requested
  static const String _apiKeyPlaceholder = 'PAGO_PAGO_API_KEY_AQUI'; 

  final String apiKey;

  PagoAPagoService({required this.apiKey});

  Future<PaymentOrderResponse> createPaymentOrder(PaymentOrderRequest request, String authToken) async {
    final url = Uri.parse('$_baseUrl/api_pay_orders');
    
    try {
      debugPrint('PagoAPagoService: Creating order for \$${request.amount}');
      
      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $authToken',
        },
        body: jsonEncode(request.toJson()),
      );

      debugPrint('PagoAPagoService: Response status: ${response.statusCode}');
      debugPrint('PagoAPagoService: Response body: ${response.body}');

      if (response.statusCode == 200 || response.statusCode == 201) {
        final jsonResponse = jsonDecode(response.body);
        return PaymentOrderResponse.fromJson(jsonResponse);
      } else {
         return PaymentOrderResponse(
          success: false, 
          message: 'Error HTTP ${response.statusCode}: ${response.body}'
        );
      }
    } catch (e) {
      debugPrint('PagoAPagoService: Exception: $e');
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
