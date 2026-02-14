import 'package:flutter/foundation.dart';

class AuditLog {
  final String id;
  final String? adminId;
  final String actionType;
  final String targetTable;
  final String? targetId;
  final Map<String, dynamic> details;
  final DateTime createdAt;
  final String? adminEmail; // Optional, joined from profiles

  AuditLog({
    required this.id,
    this.adminId,
    required this.actionType,
    required this.targetTable,
    this.targetId,
    required this.details,
    required this.createdAt,
    this.adminEmail,
  });

  factory AuditLog.fromJson(Map<String, dynamic> json) {
    return AuditLog(
      id: json['id'],
      adminId: json['admin_id'],
      actionType: json['action_type'],
      targetTable: json['target_table'],
      targetId: json['target_id'],
      details: json['details'] ?? {},
      createdAt: DateTime.parse(json['created_at']),
      adminEmail: json['profiles']?['email'], // Assumes join
    );
  }
}
