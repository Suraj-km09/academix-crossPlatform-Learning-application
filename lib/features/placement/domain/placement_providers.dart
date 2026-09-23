import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/firestore_paths.dart';
import '../../auth/domain/auth_providers.dart';
import 'placement_models.dart';

final firestoreProvider = Provider((ref) => FirebaseFirestore.instance);

// --- Placement Subjects (Core CS Subjects) ---
final placementSubjectsProvider = FutureProvider<List<PlacementSubject>>((ref) async {
  final firestore = ref.watch(firestoreProvider);
  try {
    // Attempt to fetch from Firestore (allows admin to add/update)
    final snapshot = await firestore
        .collection(FirestorePaths.placementSubjects)
        .orderBy('order')
        .get(const GetOptions(source: Source.serverAndCache));
    
    // Filter out Aptitude and Verbal from the subjects list as they are handled as core cards
    final subjects = snapshot.docs
        .map((doc) => PlacementSubject.fromFirestore(doc))
        .where((s) => s.id != 'aptitude' && s.id != 'verbal')
        .toList();

    if (subjects.isEmpty) {
      return _staticPlacementSubjects.where((s) => s.id != 'aptitude' && s.id != 'verbal').toList();
    }
    return subjects;
  } catch (e) {
    return _staticPlacementSubjects.where((s) => s.id != 'aptitude' && s.id != 'verbal').toList();
  }
});

final _staticPlacementSubjects = [
  PlacementSubject(id: 'aptitude', name: 'Aptitude', order: 1),
  PlacementSubject(id: 'verbal', name: 'Verbal Review', order: 2),
  PlacementSubject(id: 'ds', name: 'Data Structures', order: 3),
  PlacementSubject(id: 'algo', name: 'Algorithms', order: 4),
  PlacementSubject(id: 'dbms', name: 'DBMS', order: 5),
  PlacementSubject(id: 'os', name: 'Operating System', order: 6),
  PlacementSubject(id: 'cn', name: 'Computer Networks', order: 7),
];

// --- Course Materials (Notes/PDFs) - Fetched from Firestore ---
final courseMaterialsProvider = FutureProvider.family<List<CourseMaterial>, String>((ref, subjectId) async {
  final firestore = ref.watch(firestoreProvider);
  final snapshot = await firestore
      .collection(FirestorePaths.placementCourseMaterial)
      .where('subjectId', isEqualTo: subjectId)
      .get(const GetOptions(source: Source.serverAndCache));
  return snapshot.docs.map((doc) => CourseMaterial.fromFirestore(doc)).toList();
});

// --- Practice Links (MCQs) - Fetched from Firestore ---
final practiceLinksProvider = FutureProvider.family<List<PracticeLink>, String>((ref, subjectId) async {
  final firestore = ref.watch(firestoreProvider);
  final snapshot = await firestore
      .collection(FirestorePaths.placementPracticeLinks)
      .where('subjectId', isEqualTo: subjectId)
      .get(const GetOptions(source: Source.serverAndCache));
  return snapshot.docs.map((doc) => PracticeLink.fromFirestore(doc)).toList();
});

// --- Interview Questions - Fetched from Firestore ---
final interviewQuestionsProvider = FutureProvider.family<List<InterviewQuestion>, String>((ref, subjectId) async {
  final firestore = ref.watch(firestoreProvider);
  final snapshot = await firestore
      .collection(FirestorePaths.placementInterviewQuestions)
      .where('subjectId', isEqualTo: subjectId)
      .get(const GetOptions(source: Source.serverAndCache));
  return snapshot.docs.map((doc) => InterviewQuestion.fromFirestore(doc)).toList();
});

// --- DSA Topics (Static with Firestore override) ---
final dsaTopicsProvider = FutureProvider<List<DsaTopic>>((ref) async {
  final firestore = ref.watch(firestoreProvider);
  try {
    final snapshot = await firestore
        .collection('dsa_topics')
        .orderBy('order')
        .get(const GetOptions(source: Source.serverAndCache));
    
    if (snapshot.docs.isEmpty) return _staticDsaTopics;
    return snapshot.docs.map((doc) => DsaTopic.fromFirestore(doc)).toList();
  } catch (e) {
    return _staticDsaTopics;
  }
});

final _staticDsaTopics = [
  DsaTopic(id: 'arrays', name: 'Arrays', order: 1),
  DsaTopic(id: 'strings', name: 'Strings', order: 2),
  DsaTopic(id: 'linked_list', name: 'Linked List', order: 3),
  DsaTopic(id: 'stack_queue', name: 'Stack & Queue', order: 4),
  DsaTopic(id: 'trees', name: 'Trees', order: 5),
  DsaTopic(id: 'graphs', name: 'Graphs', order: 6),
  DsaTopic(id: 'dp', name: 'Dynamic Programming', order: 7),
  DsaTopic(id: 'maths', name: 'Maths', order: 8),
];

// --- DSA Questions - Fetched from Firestore ---
final dsaQuestionsByTopicProvider = FutureProvider.family<List<DsaQuestion>, String>((ref, topicId) async {
  final firestore = ref.watch(firestoreProvider);
  final snapshot = await firestore
      .collection('dsa_questions')
      .where('topicId', isEqualTo: topicId)
      .get(const GetOptions(source: Source.serverAndCache));
  
  return snapshot.docs.map((doc) => DsaQuestion.fromFirestore(doc)).toList();
});

// --- DSA Sheets (Standard Links) ---
final dsaSheetsProvider = FutureProvider<List<DsaSheet>>((ref) async {
  final firestore = ref.watch(firestoreProvider);
  try {
    final snapshot = await firestore.collection('dsa_sheets').get(const GetOptions(source: Source.serverAndCache));
    if (snapshot.docs.isEmpty) return _staticDsaSheets;
    return snapshot.docs.map((doc) => DsaSheet.fromFirestore(doc)).toList();
  } catch (e) {
    return _staticDsaSheets;
  }
});

final _staticDsaSheets = [
  DsaSheet(id: 'striver', title: 'Striver SDE Sheet', link: 'https://takeuforward.org/interviews/strivers-sde-sheet-top-coding-interview-problems/'),
  DsaSheet(id: 'babbar', title: 'Love Babbar Sheet', link: 'https://www.geeksforgeeks.org/love-babbar-dsa-sheet-solutions/'),
  DsaSheet(id: 'blind75', title: 'Blind 75', link: 'https://leetcode.com/discuss/general-discussion/460515/blind-75-leetcode-questions-by-a-facebook-engineer'),
];

// --- User Progress & Bookmarks (Real-time small streams) ---
final placementBookmarksProvider = StreamProvider<List<String>>((ref) {
  final user = ref.watch(currentUserProvider).valueOrNull;
  if (user == null) return Stream.value([]);
  
  final firestore = ref.watch(firestoreProvider);
  return firestore
      .collection(FirestorePaths.users)
      .doc(user.uid)
      .collection('placement_bookmarks')
      .snapshots()
      .map((snapshot) => snapshot.docs.map((doc) => doc.id).toList());
});

final completedItemsProvider = StreamProvider<List<String>>((ref) {
  final user = ref.watch(currentUserProvider).valueOrNull;
  if (user == null) return Stream.value([]);
  
  final firestore = ref.watch(firestoreProvider);
  return firestore
      .collection(FirestorePaths.users)
      .doc(user.uid)
      .collection('placement_completed')
      .snapshots()
      .map((snapshot) => snapshot.docs.map((doc) => doc.id).toList());
});

final placementRepositoryProvider = Provider((ref) => PlacementRepository(ref.watch(firestoreProvider)));

class PlacementRepository {
  final FirebaseFirestore _firestore;
  PlacementRepository(this._firestore);

  Future<void> toggleBookmark(String uid, String itemId) async {
    final ref = _firestore.collection(FirestorePaths.users).doc(uid).collection('placement_bookmarks').doc(itemId);
    final doc = await ref.get();
    if (doc.exists) {
      await ref.delete();
    } else {
      await ref.set({'timestamp': FieldValue.serverTimestamp()});
    }
  }

  Future<void> toggleCompletion(String uid, String itemId) async {
    final ref = _firestore.collection(FirestorePaths.users).doc(uid).collection('placement_completed').doc(itemId);
    final doc = await ref.get();
    if (doc.exists) {
      await ref.delete();
    } else {
      await ref.set({'timestamp': FieldValue.serverTimestamp()});
    }
  }

  Future<void> deleteMaterial(String materialId) async {
    await _firestore.collection(FirestorePaths.placementCourseMaterial).doc(materialId).delete();
  }
}
