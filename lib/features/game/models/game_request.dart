import 'package:flutter/material.dart';

class GameRequest {
  final String id;
  final String userId;
  final String eventId;
  final String status;
  final DateTime? createdAt;

  // Optional fields for UI display (joined data)
  final String? userName;
  final String? userEmail;
  final String? eventName;

  GameRequest({
    required this.id,
    required this.userId,
    required this.eventId,
    required this.status,
    this.createdAt,
    this.userName,
    this.userEmail,
    this.eventName,
  });

  // Backward compatibility getters
  String get playerId => userId;
  String get playerName =>
      userName ?? 'Cazador'; // Fallback to avoid 'null' display
  String? get playerEmail => userEmail;
  String? get eventTitle => eventName;

  factory GameRequest.fromJson(Map<String, dynamic> json) {
    // Helper to extract nested data that might be a List or a Map
    dynamic getNested(dynamic data, String field) {
      if (data == null) return null;
      if (data is List && data.isNotEmpty) return data.first[field];
      if (data is Map) return data[field];
      return null;
    }

    return GameRequest(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      eventId: json['event_id'] as String,
      status: json['status'] as String,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : null,
      userName: getNested(json['profiles'], 'name') as String?,
      userEmail: getNested(json['profiles'], 'email') as String?,
      eventName: getNested(json['events'], 'name') as String? ??
          getNested(json['events'], 'title') as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'user_id': userId,
      'event_id': eventId,
      'status': status,
    };
  }

  bool get isApproved => status == 'approved' || status == 'paid';
  bool get isPaid => status == 'paid';
  bool get isRejected => status == 'rejected';
  bool get isPending => status == 'pending';

  Color get statusColor {
    switch (status) {
      case 'approved':
      case 'paid':
        return Colors.green;
      case 'rejected':
        return Colors.red;
      default:
        return Colors.orange;
    }
  }

  String get statusText {
    switch (status) {
      case 'approved':
        return 'Aprobado';
      case 'paid':
        return 'Pagado';
      case 'rejected':
        return 'Rechazado';
      default:
        return 'Pendiente';
    }
  }
}
