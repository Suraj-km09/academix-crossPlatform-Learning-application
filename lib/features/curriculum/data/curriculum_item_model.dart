import 'package:cloud_firestore/cloud_firestore.dart';

class CurriculumItemModel {
  const CurriculumItemModel({
    required this.curriculumId,
    required this.title,
    required this.subject,
    required this.description,
    required this.course,
    required this.semester,
    required this.branch,
    required this.category,
    required this.collegeId,
    required this.uploadedBy,
    required this.uploaderName,
    required this.uploaderRole,
    required this.documentUrl,
    required this.documentName,
    required this.documentSize,
    required this.isPinned,
    required this.createdAt,
    required this.updatedAt,
  });

  final String curriculumId;
  final String title;
  final String subject;
  final String description;
  final String course;
  final String semester;
  final String branch;
  final String category;
  final String collegeId;
  final String uploadedBy;
  final String uploaderName;
  final String uploaderRole;
  final String documentUrl;
  final String documentName;
  final int documentSize;
  final bool isPinned;
  final DateTime createdAt;
  final DateTime updatedAt;

  factory CurriculumItemModel.fromMap(
    Map<String, dynamic> map,
    String curriculumId,
  ) {
    return CurriculumItemModel(
      curriculumId: (map['curriculumId'] as String? ?? curriculumId).trim(),
      title: (map['title'] as String? ?? '').trim(),
      subject: (map['subject'] as String? ?? '').trim(),
      description: (map['description'] as String? ?? '').trim(),
      course: (map['course'] as String? ?? '').trim(),
      semester: (map['semester'] as String? ?? '').trim(),
      branch: (map['branch'] as String? ?? '').trim(),
      category: (map['category'] as String? ?? 'useful_info').trim(),
      collegeId: (map['collegeId'] as String? ?? '').trim(),
      uploadedBy: (map['uploadedBy'] as String? ?? '').trim(),
      uploaderName: (map['uploaderName'] as String? ?? '').trim(),
      uploaderRole: (map['uploaderRole'] as String? ?? '').trim(),
      documentUrl: (map['documentUrl'] as String? ?? '').trim(),
      documentName: (map['documentName'] as String? ?? '').trim(),
      documentSize: _toInt(map['documentSize']) ?? 0,
      isPinned: map['isPinned'] as bool? ?? false,
      createdAt: _toDateTime(map['createdAt']),
      updatedAt: _toDateTime(map['updatedAt']),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'curriculumId': curriculumId,
      'title': title,
      'subject': subject,
      'description': description,
      'course': course,
      'semester': semester,
      'branch': branch,
      'category': category,
      'collegeId': collegeId,
      'uploadedBy': uploadedBy,
      'uploaderName': uploaderName,
      'uploaderRole': uploaderRole,
      'documentUrl': documentUrl,
      'documentName': documentName,
      'documentSize': documentSize,
      'isPinned': isPinned,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
    };
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
