import 'package:latlong2/latlong.dart';

class GameEvent {
  final String id;
  final String title;
  final String description; // Esta sería la "pista para solucionar el puzzle"
  final String locationName;
  final double latitude;
  final double longitude;
  final DateTime date;
  final String createdByAdminId;
  final String imageUrl;
  final String clue;        // <--- CAMBIO: Ahora es obligatorio (Pista de victoria)
  final int maxParticipants;
  final String pin;
  final String status;      // Status: 'pending', 'active', 'completed'
  final DateTime? completedAt;
  final String? winnerId;
  final String type;
  final int entryFee;
  final int currentParticipants;
  final int configuredWinners; // NEW: Controls how many people get prizes (1, 2, or 3)

  GameEvent({
    required this.id,
    required this.title,
    required this.description,
    required this.locationName,
    required this.latitude,
    required this.longitude,
    required this.date,
    required this.createdByAdminId,
    required this.clue,     // <--- CAMBIO: Ahora es 'required'
    this.imageUrl = '',
    this.maxParticipants = 0,
    this.pin = '',
    this.status = 'pending',
    this.completedAt,
    this.winnerId,
    this.type = 'on_site',
    this.entryFee = 0,
    this.currentParticipants = 0,
    this.configuredWinners = 3,
  });

  LatLng get location => LatLng(latitude, longitude);
  
  bool get isCompleted => status == 'completed';
  bool get isActive => status == 'active';
  bool get isPending => status == 'pending';

  factory GameEvent.fromJson(Map<String, dynamic> json) {
    return GameEvent(
      id: json['id'] as String,
      title: json['title'] as String,
      description: json['description'] as String,
      locationName: json['location_name'] ?? '',
      latitude: (json['latitude'] is num) ? (json['latitude'] as num).toDouble() : 0.0,
      longitude: (json['longitude'] is num) ? (json['longitude'] as num).toDouble() : 0.0,
      date: DateTime.parse(json['date']),
      createdByAdminId: json['created_by_admin_id'] ?? '',
      clue: json['clue'] ?? '',
      imageUrl: json['image_url'] ?? '',
      maxParticipants: (json['max_participants'] as num?)?.toInt() ?? 0,
      pin: json['pin'] ?? '',
      status: json['status'] ?? 'pending',
      completedAt: json['completed_at'] != null ? DateTime.parse(json['completed_at']) : null,
      winnerId: json['winner_id'],
      type: json['type'] ?? 'on_site',
      entryFee: (json['entry_fee'] as num?)?.toInt() ?? 0,
      currentParticipants: (json['current_participants'] as num?)?.toInt() ?? 0,
      configuredWinners: (json['configured_winners'] as num?)?.toInt() ?? 3,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'location_name': locationName,
      'latitude': latitude,
      'longitude': longitude,
      'date': date.toIso8601String(),
      'created_by_admin_id': createdByAdminId,
      'clue': clue,
      'image_url': imageUrl,
      'max_participants': maxParticipants,
      'pin': pin,
      'status': status,
      'completed_at': completedAt?.toIso8601String(),
      'winner_id': winnerId,
      'type': type,
      'entry_fee': entryFee,
      'current_participants': currentParticipants,
    };
  }
}