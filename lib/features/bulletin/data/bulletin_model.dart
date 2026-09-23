import 'package:cloud_firestore/cloud_firestore.dart';

class BulletinModel {
  const BulletinModel({
    required this.bulletinId,
    required this.title,
    required this.description,
    required this.category,
    required this.collegeId,
    required this.postedBy,
    required this.postedByName,
    required this.postedByRole,
    required this.createdAt,
    this.attachmentUrl,
    this.attachmentName,
    this.targetSemester,
    this.targetCourse,
    this.eventDate,
    this.readBy = const <String>[],
    this.isPinned = false,
  });

  final String bulletinId;
  final String title;
  final String description;
  final String category;
  final String? attachmentUrl;
  final String? attachmentName;
  final String collegeId;
  final int? targetSemester;
  final String? targetCourse;
  final String postedBy;
  final String postedByName;
  final String postedByRole;
  final DateTime createdAt;
  final DateTime? eventDate;
  final List<String> readBy;
  final bool isPinned;

  bool get hasAttachment => (attachmentUrl ?? '').trim().isNotEmpty;

  factory BulletinModel.fromMap(Map<String, dynamic> map, String id) {
    return BulletinModel(
      bulletinId: (map['bulletinId'] as String? ?? id).trim(),
      title: (map['title'] as String? ?? '').trim(),
      description: (map['description'] as String? ?? '').trim(),
      category: (map['category'] as String? ?? 'notice').trim().toLowerCase(),
      attachmentUrl: (map['attachmentUrl'] as String?)?.trim(),
      attachmentName: (map['attachmentName'] as String?)?.trim(),
      collegeId: (map['collegeId'] as String? ?? '').trim(),
      targetSemester: _toInt(map['targetSemester']),
      targetCourse: (map['targetCourse'] as String?)?.trim(),
      postedBy: (map['postedBy'] as String? ?? '').trim(),
      postedByName: (map['postedByName'] as String? ?? '').trim(),
      postedByRole: (map['postedByRole'] as String? ?? '').trim().toLowerCase(),
      createdAt: _toDateTime(map['createdAt']),
      eventDate: _toNullableDateTime(map['eventDate']),
      readBy: _toStringList(map['readBy']),
      isPinned: map['isPinned'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'bulletinId': bulletinId,
      'title': title,
      'description': description,
      'category': category,
      'attachmentUrl': attachmentUrl,
      'attachmentName': attachmentName,
      'collegeId': collegeId,
      'targetSemester': targetSemester,
      'targetCourse': targetCourse,
      'postedBy': postedBy,
      'postedByName': postedByName,
      'postedByRole': postedByRole,
      'createdAt': Timestamp.fromDate(createdAt),
      'eventDate': eventDate == null ? null : Timestamp.fromDate(eventDate!),
      'readBy': readBy,
      'isPinned': isPinned,
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

  static int? _toInt(dynamic value) {
    if (value is int) {
      return value;
    }
    if (value is String) {
      return int.tryParse(value);
    }
    return null;
  }

  static List<String> _toStringList(dynamic value) {
    if (value is List) {
      return value
          .map((item) => item.toString().trim())
          .where((item) => item.isNotEmpty)
          .toList();
    }
    return const <String>[];
  }
}
