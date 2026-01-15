class PowerEffect {
  final String id;
  final String powerSlug; // 'black_screen', 'freeze', 'invisibility', etc.
  final String targetId;
  final String casterId;
  final DateTime expiresAt;
  final DateTime createdAt;

  const PowerEffect({
    required this.id,
    required this.powerSlug,
    required this.targetId,
    required this.casterId,
    required this.expiresAt,
    required this.createdAt,
  });

  factory PowerEffect.fromMap(Map<String, dynamic> map) {
    return PowerEffect(
      id: map['id']?.toString() ?? '',
      powerSlug: map['power_slug'] as String? ?? map['slug'] as String? ?? '',
      targetId: map['target_id']?.toString() ?? '',
      casterId: map['caster_id']?.toString() ?? '',
      expiresAt: DateTime.tryParse(map['expires_at']?.toString() ?? '') ?? DateTime.now(),
      createdAt: DateTime.tryParse(map['created_at']?.toString() ?? '') ?? DateTime.now(),
    );
  }

  bool get isExpired => DateTime.now().toUtc().isAfter(expiresAt.toUtc());
}
