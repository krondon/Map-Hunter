class ActivePowerEffect {
  final String id;
  final String powerSlug;
  final DateTime expiresAt;

  ActivePowerEffect({
    required this.id,
    required this.powerSlug,
    required this.expiresAt,
  });

  bool get isExpired => DateTime.now().toUtc().isAfter(expiresAt);
}