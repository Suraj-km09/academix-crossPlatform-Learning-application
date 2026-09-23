import 'package:cloud_firestore/cloud_firestore.dart';

class AlumniQAModel {
  const AlumniQAModel({
    required this.threadId,
    required this.studentUid,
    required this.alumniUid,
    required this.question,
    required this.answer,
    required this.isPublic,
    required this.createdAt,
    this.answeredAt,
    required this.collegeId,
  });

  final String threadId;
  final String studentUid;
  final String alumniUid;
  final String question;
  final String answer;
  final bool isPublic;
  final DateTime createdAt;
  final DateTime? answeredAt;
  final String collegeId;

  factory AlumniQAModel.fromMap(Map<String, dynamic> map, String id) {
    return AlumniQAModel(
      threadId: (map['threadId'] as String? ?? id).trim(),
      studentUid: (map['studentUid'] as String? ?? '').trim(),
      alumniUid: (map['alumniUid'] as String? ?? '').trim(),
      question: (map['question'] as String? ?? '').trim(),
      answer: (map['answer'] as String? ?? '').trim(),
      isPublic: map['isPublic'] as bool? ?? false,
      createdAt: _toDateTime(map['createdAt']),
      answeredAt: _toNullableDateTime(map['answeredAt']),
      collegeId: (map['collegeId'] as String? ?? '').trim(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'threadId': threadId,
      'studentUid': studentUid,
      'alumniUid': alumniUid,
      'question': question,
      'answer': answer,
      'isPublic': isPublic,
      'createdAt': Timestamp.fromDate(createdAt),
      'answeredAt': answeredAt == null ? null : Timestamp.fromDate(answeredAt!),
      'collegeId': collegeId,
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

  static DateTime? _toNullableDateTime(dynamic value) {
    if (value == null) {
      return null;
    }
    if (value is Timestamp) {
      return value.toDate();
    }
    if (value is DateTime) {
      return value;
    }
    return null;
  }
}
