import 'package:cloud_firestore/cloud_firestore.dart';

class ReferralRequestModel {
  const ReferralRequestModel({
    required this.requestId,
    required this.studentUid,
    required this.studentName,
    required this.alumniUid,
    required this.alumniName,
    required this.targetCompany,
    required this.targetRole,
    required this.message,
    required this.resumeUrl,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
    this.chatId,
    this.rejectionReason,
  });

  final String requestId;
  final String studentUid;
  final String studentName;
  final String alumniUid;
  final String alumniName;
  final String targetCompany;
  final String targetRole;
  final String message;
  final String resumeUrl;
  final String status;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String? chatId;
  final String? rejectionReason;

  factory ReferralRequestModel.fromMap(Map<String, dynamic> map, String id) {
    return ReferralRequestModel(
      requestId: (map['requestId'] as String? ?? id).trim(),
      studentUid: (map['studentUid'] as String? ?? '').trim(),
      studentName: (map['studentName'] as String? ?? '').trim(),
      alumniUid: (map['alumniUid'] as String? ?? '').trim(),
      alumniName: (map['alumniName'] as String? ?? '').trim(),
      targetCompany: (map['targetCompany'] as String? ?? '').trim(),
      targetRole: (map['targetRole'] as String? ?? '').trim(),
      message: (map['message'] as String? ?? '').trim(),
      resumeUrl: (map['resumeUrl'] as String? ?? '').trim(),
      status: (map['status'] as String? ?? 'pending').trim().toLowerCase(),
      createdAt: _toDateTime(map['createdAt']),
      updatedAt: _toDateTime(map['updatedAt']),
      chatId: map['chatId'] as String?,
      rejectionReason: map['rejectionReason'] as String?,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'requestId': requestId,
      'studentUid': studentUid,
      'studentName': studentName,
      'alumniUid': alumniUid,
      'alumniName': alumniName,
      'targetCompany': targetCompany,
      'targetRole': targetRole,
      'message': message,
      'resumeUrl': resumeUrl,
      'status': status,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
      'chatId': chatId,
      'rejectionReason': rejectionReason,
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
