import 'package:cloud_firestore/cloud_firestore.dart';

class ReportModel {
  const ReportModel({
    required this.reportId,
    required this.reporterUid,
    required this.targetId,
    required this.targetType,
    required this.reason,
    required this.status,
    required this.createdAt,
  });

  final String reportId;
  final String reporterUid;
  final String targetId;
  final String targetType;
  final String reason;
  final String status;
  final DateTime createdAt;

  factory ReportModel.fromMap(Map<String, dynamic> map, String id) {
    final targetType =
        (map['targetType'] as String? ?? map['category'] as String? ?? '')
            .trim()
            .toLowerCase();

    final targetId =
        (map['targetId'] as String? ??
                map['messageId'] as String? ??
                map['chatId'] as String? ??
                map['targetUid'] as String? ??
                '')
            .trim();

    return ReportModel(
      reportId:
          (map['reportId'] as String? ?? map['notificationId'] as String? ?? id)
              .trim(),
      reporterUid: (map['reporterUid'] as String? ?? '').trim(),
      targetId: targetId,
      targetType: targetType.isEmpty ? 'user' : targetType,
      reason: (map['reason'] as String? ?? '').trim(),
      status: (map['status'] as String? ?? 'pending').trim().toLowerCase(),
      createdAt: _toDateTime(map['createdAt']),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'reportId': reportId,
      'reporterUid': reporterUid,
      'targetId': targetId,
      'targetType': targetType,
      'reason': reason,
      'status': status,
      'createdAt': Timestamp.fromDate(createdAt),
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
