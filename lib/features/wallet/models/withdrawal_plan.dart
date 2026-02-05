/// Model for withdrawal plans.
/// 
/// These are separate from purchase plans (CloverPlan).
/// - clovers_cost: How many clovers the user needs to spend
/// - amount_usd: How much USD the user receives (before VES conversion)
class WithdrawalPlan {
  final String id;
  final String name;
  final int cloversCost;
  final double amountUsd;
  final bool isActive;
  final String? icon;
  final int sortOrder;

  WithdrawalPlan({
    required this.id,
    required this.name,
    required this.cloversCost,
    required this.amountUsd,
    this.isActive = true,
    this.icon,
    this.sortOrder = 0,
  });

  factory WithdrawalPlan.fromJson(Map<String, dynamic> json) {
    return WithdrawalPlan(
      id: json['id'] as String,
      name: json['name'] as String,
      cloversCost: json['clovers_cost'] as int,
      amountUsd: (json['amount_usd'] as num).toDouble(),
      isActive: json['is_active'] as bool? ?? true,
      icon: json['icon'] as String?,
      sortOrder: json['sort_order'] as int? ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'clovers_cost': cloversCost,
      'amount_usd': amountUsd,
      'is_active': isActive,
      'icon': icon,
      'sort_order': sortOrder,
    };
  }

  String get formattedAmountUsd => '\$${amountUsd.toStringAsFixed(2)}';
  String get formattedCloversCost => '$cloversCost 🍀';
}
