import 'package:cloud_firestore/cloud_firestore.dart';

class InterviewPdf {
  final String id;
  final String subjectId;
  final String title;
  final String pdfUrl;
  final int size;
  final DateTime? createdAt;
  final bool isActive;
  final int order;

  InterviewPdf({
    required this.id,
    required this.subjectId,
    required this.title,
    required this.pdfUrl,
    this.size = 0,
    this.createdAt,
    this.isActive = true,
    this.order = 0,
  });

  factory InterviewPdf.fromMap(Map<String, dynamic> map, String id) {
    return InterviewPdf(
      id: id,
      subjectId: map['subjectId'] ?? '',
      title: map['title'] ?? '',
      pdfUrl: map['pdfUrl'] ?? '',
      size: map['size'] ?? 0,
      createdAt: (map['createdAt'] as Timestamp?)?.toDate(),
      isActive: map['isActive'] ?? true,
      order: map['order'] ?? 0,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'subjectId': subjectId,
      'title': title,
      'pdfUrl': pdfUrl,
      'size': size,
      'createdAt': createdAt != null ? Timestamp.fromDate(createdAt!) : FieldValue.serverTimestamp(),
      'isActive': isActive,
      'order': order,
    };
  }
}
