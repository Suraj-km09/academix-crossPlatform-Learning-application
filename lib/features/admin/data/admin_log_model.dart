import 'package:cloud_firestore/cloud_firestore.dart';

class AdminLogModel {
  const AdminLogModel({
    required this.logId,
    required this.adminUid,
    required this.action,
    required this.targetId,
    required this.targetType,
    required this.timestamp,
  });

  final String logId;
  final String adminUid;
  final String action;
  final String targetId;
  final String targetType;
  final DateTime timestamp;

  factory AdminLogModel.fromMap(Map<String, dynamic> map, String id) {
    return AdminLogModel(
      logId: (map['logId'] as String? ?? id).trim(),
      adminUid: (map['adminUid'] as String? ?? '').trim(),
      action: (map['action'] as String? ?? '').trim(),
      targetId: (map['targetId'] as String? ?? '').trim(),
      targetType: (map['targetType'] as String? ?? '').trim(),
      timestamp: _toDateTime(map['timestamp']),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'logId': logId,
      'adminUid': adminUid,
      'action': action,
      'targetId': targetId,
      'targetType': targetType,
      'timestamp': Timestamp.fromDate(timestamp),
    };
  }

  static DateTime _toDateTime(dynamic value) {
    if (value is Timestamp) {
      return value.toDate();
    }
    if (value is DateTime) {
      return value;
    }
    return DateTime.now();
  }
}
