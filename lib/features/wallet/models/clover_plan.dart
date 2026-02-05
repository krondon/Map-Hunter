/// Model representing a clover purchase plan.
/// 
/// Plans are defined server-side in `clover_plans` table and fetched
/// dynamically. Prices are in USD for security - validated server-side.
class CloverPlan {
  final String id;
  final String name;
  final int cloversQuantity;
  final double priceUsd;
  final String? iconUrl;
  final int sortOrder;
  final bool isActive;

  const CloverPlan({
    required this.id,
    required this.name,
    required this.cloversQuantity,
    required this.priceUsd,
    this.iconUrl,
    this.sortOrder = 0,
    this.isActive = true,
  });

  factory CloverPlan.fromJson(Map<String, dynamic> json) {
    return CloverPlan(
      id: json['id'] as String,
      name: json['name'] as String,
      cloversQuantity: json['clovers_quantity'] as int,
      priceUsd: (json['price_usd'] as num).toDouble(),
      iconUrl: json['icon_url'] as String?,
      sortOrder: json['sort_order'] as int? ?? 0,
      isActive: json['is_active'] as bool? ?? true,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'clovers_quantity': cloversQuantity,
    'price_usd': priceUsd,
    'icon_url': iconUrl,
    'sort_order': sortOrder,
    'is_active': isActive,
  };

  /// Formatted price string for display
  String get formattedPrice => '\$${priceUsd.toStringAsFixed(2)}';
}
