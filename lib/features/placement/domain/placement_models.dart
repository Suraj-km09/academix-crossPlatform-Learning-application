import 'package:cloud_firestore/cloud_firestore.dart';

class PlacementSubject {
  final String id;
  final String name;
  final String? icon;
  final int order;

  PlacementSubject({
    required this.id,
    required this.name,
    this.icon,
    required this.order,
  });

  factory PlacementSubject.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return PlacementSubject(
      id: doc.id,
      name: data['name'] ?? '',
      icon: data['icon'],
      order: data['order'] ?? 0,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'name': name,
      'icon': icon,
      'order': order,
    };
  }
}

class CourseMaterial {
  final String id;
  final String subjectId;
  final String title;
  final String type; // 'pdf' | 'text' | 'link'
  final String fileUrl;
  final String description;

  CourseMaterial({
    required this.id,
    required this.subjectId,
    required this.title,
    required this.type,
    required this.fileUrl,
    required this.description,
  });

  factory CourseMaterial.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return CourseMaterial(
      id: doc.id,
      subjectId: data['subjectId'] ?? '',
      title: data['title'] ?? '',
      type: data['type'] ?? 'link',
      fileUrl: data['file_url'] ?? '',
      description: data['description'] ?? '',
    );
  }
}

class PracticeLink {
  final String id;
  final String subjectId;
  final String title;
  final String platform;
  final String url;

  PracticeLink({
    required this.id,
    required this.subjectId,
    required this.title,
    required this.platform,
    required this.url,
  });

  factory PracticeLink.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return PracticeLink(
      id: doc.id,
      subjectId: data['subjectId'] ?? '',
      title: data['title'] ?? '',
      platform: data['platform'] ?? '',
      url: data['url'] ?? '',
    );
  }
}

class InterviewQuestion {
  final String id;
  final String subjectId;
  final String question;
  final String answer;
  final List<String> companyTags;

  InterviewQuestion({
    required this.id,
    required this.subjectId,
    required this.question,
    required this.answer,
    required this.companyTags,
  });

  factory InterviewQuestion.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return InterviewQuestion(
      id: doc.id,
      subjectId: data['subjectId'] ?? '',
      question: data['question'] ?? '',
      answer: data['answer'] ?? '',
      companyTags: List<String>.from(data['company_tags'] ?? []),
    );
  }
}

class DsaTopic {
  final String id;
  final String name;
  final int order;

  DsaTopic({
    required this.id,
    required this.name,
    required this.order,
  });

  factory DsaTopic.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return DsaTopic(
      id: doc.id,
      name: data['name'] ?? '',
      order: data['order'] ?? 0,
    );
  }
}

class DsaQuestion {
  final String id;
  final String topicId;
  final String difficulty; // Easy, Medium, Hard
  final String title;
  final String link;
  final String platform;

  DsaQuestion({
    required this.id,
    required this.topicId,
    required this.difficulty,
    required this.title,
    required this.link,
    required this.platform,
  });

  factory DsaQuestion.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return DsaQuestion(
      id: doc.id,
      topicId: data['topicId'] ?? '',
      difficulty: data['difficulty'] ?? 'Easy',
      title: data['title'] ?? '',
      link: data['link'] ?? '',
      platform: data['platform'] ?? 'LeetCode',
    );
  }
}

class DsaSheet {
  final String id;
  final String title;
  final String link;

  DsaSheet({
    required this.id,
    required this.title,
    required this.link,
  });

  factory DsaSheet.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return DsaSheet(
      id: doc.id,
      title: data['title'] ?? '',
      link: data['link'] ?? '',
    );
  }
}
