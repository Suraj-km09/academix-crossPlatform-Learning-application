import 'package:cloud_firestore/cloud_firestore.dart';

class McqPdf {
  final String id;
  final String subjectId;
  final String title;
  final String pdfUrl;
  final int size;
  final DateTime? createdAt;
  final bool isActive;
  final int order;

  McqPdf({
    required this.id,
    required this.subjectId,
    required this.title,
    required this.pdfUrl,
    this.size = 0,
    this.createdAt,
    this.isActive = true,
    this.order = 0,
  });

  factory McqPdf.fromMap(Map<String, dynamic> map, String id) {
    return McqPdf(
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

class McqQuestion {
  final String question;
  final List<String> options;
  final int answerIndex;

  McqQuestion({
    required this.question,
    required this.options,
    required this.answerIndex,
  });

  factory McqQuestion.fromMap(Map<String, dynamic> map) {
    return McqQuestion(
      question: map['question'] ?? '',
      options: List<String>.from(map['options'] ?? []),
      answerIndex: map['answerIndex'] ?? 0,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'question': question,
      'options': options,
      'answerIndex': answerIndex,
    };
  }
}

class McqTest {
  final String id;
  final String subjectId;
  final String title;
  final String difficulty;
  final bool isActive;
  final List<McqQuestion> questions;
  final DateTime? createdAt;

  McqTest({
    required this.id,
    required this.subjectId,
    required this.title,
    this.difficulty = 'easy',
    this.isActive = true,
    required this.questions,
    this.createdAt,
  });

  factory McqTest.fromMap(Map<String, dynamic> map, String id) {
    return McqTest(
      id: id,
      subjectId: map['subjectId'] ?? '',
      title: map['title'] ?? '',
      difficulty: map['difficulty'] ?? 'easy',
      isActive: map['isActive'] ?? true,
      questions: (map['questions'] as List? ?? [])
          .map((q) => McqQuestion.fromMap(Map<String, dynamic>.from(q)))
          .toList(),
      createdAt: (map['createdAt'] as Timestamp?)?.toDate(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'subjectId': subjectId,
      'title': title,
      'difficulty': difficulty,
      'isActive': isActive,
      'questions': questions.map((q) => q.toMap()).toList(),
      'createdAt': createdAt != null ? Timestamp.fromDate(createdAt!) : FieldValue.serverTimestamp(),
    };
  }
}
