import 'package:flutter/material.dart';

class GameRequest {
  final String id;
  final String playerId;
  final String eventId;
  final String status;
  final DateTime createdAt;
  
  // Optional fields for UI display (joined data)
  final String? playerName;
  final String? playerEmail;
  final String? eventTitle;

  GameRequest({
    required this.id,
    required this.playerId,
    required this.eventId,
    required this.status,
    required this.createdAt,
    this.playerName,
    this.playerEmail,
    this.eventTitle,
  });

  factory GameRequest.fromJson(Map<String, dynamic> json) {
    return GameRequest(
      id: json['id'] as String,
      playerId: json['user_id'] as String,
      eventId: json['event_id'] as String,
      status: json['status'] as String,
      createdAt: DateTime.parse(json['created_at'] as String),
      playerName: json['profiles']?['name'] as String?,
      playerEmail: json['profiles']?['email'] as String?,
      eventTitle: json['events']?['title'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'user_id': playerId,
      'event_id': eventId,
      'status': status,
    };
  }

  bool get isApproved => status == 'approved';
  bool get isRejected => status == 'rejected';
  bool get isPending => status == 'pending';

  Color get statusColor {
    switch (status) {
      case 'approved':
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
      case 'rejected':
        return 'Rechazado';
      default:
        return 'Pendiente';
    }
  }
}
