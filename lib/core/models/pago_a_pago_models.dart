class PaymentOrderRequest {
  final double amount;
  final String currency;
  final String email;
  final String phone;
  final String motive;
  final String dni; // Cédula
  final String typeOrder;
  final String expiresAt;
  final String alias;
  final bool convertFromUsd;
  final Map<String, dynamic> extraData;

  PaymentOrderRequest({
    required this.amount,
    this.currency = 'VES',
    required this.email,
    required this.phone,
    required this.motive,
    required this.dni,
    this.typeOrder = 'EXTERNAL',
    required this.expiresAt,
    this.alias = 'JUEGO_QR_RECHARGE',
    this.convertFromUsd = true,
    required this.extraData,
  });

  Map<String, dynamic> toJson() {
    return {
      'amount': amount,
      'currency': currency,
      'email': email,
      'phone': phone,
      'motive': motive,
      'dni': dni,
      'type_order': typeOrder,
      'expires_at': expiresAt,
      'alias': alias,
      'convert_from_usd': convertFromUsd,
      'extra_data': extraData,
    };
  }
}

class PaymentOrderResponse {
  final bool success;
  final String message;
  final String? orderId;
  final String? paymentUrl;

  PaymentOrderResponse({
    required this.success,
    required this.message,
    this.orderId,
    this.paymentUrl,
  });

  factory PaymentOrderResponse.fromJson(Map<String, dynamic> json) {
    bool success = json['success'] ?? false;
    String message = json['message'] ?? '';
    Map<String, dynamic>? data = json['data'];

    return PaymentOrderResponse(
      success: success,
      message: message,
      orderId: data?['order_id'],
      paymentUrl: data?['payment_url'],
    );
  }
}

class WithdrawalRequest {
  final double amount;
  final String bank;
  final String dni;
  final String? phone;
  final String? cta;

  WithdrawalRequest({
    required this.amount,
    required this.bank,
    required this.dni,
    this.phone,
    this.cta,
  });

  Map<String, dynamic> toJson() {
    return {
      'amount': amount,
      'bank': bank,
      'dni': dni,
      if (phone != null) 'phone': phone,
      if (cta != null) 'cta': cta,
    };
  }
}

class WithdrawalResponse {
  final bool success;
  final String message;
  final Map<String, dynamic>? data;

  WithdrawalResponse({
    required this.success,
    required this.message,
    this.data,
  });

  factory WithdrawalResponse.fromJson(Map<String, dynamic> json) {
    return WithdrawalResponse(
      success: json['success'] ?? false,
      message: json['message'] ?? (json['error'] ?? 'Unknown error'),
      data: json['data'],
    );
  }
}
