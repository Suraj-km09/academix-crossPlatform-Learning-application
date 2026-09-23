import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../domain/mcq_models.dart';

final mcqRepositoryProvider = Provider((ref) => McqRepository());

class McqRepository {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static const String _pdfBoxName = 'mcq_pdfs_cache';
  static const String _testBoxName = 'mcq_tests_cache';

  Future<List<McqPdf>> getPdfs(String subjectId) async {
    final box = await Hive.openBox(_pdfBoxName);
    
    // Try to get from cache first for immediate UI
    final cachedData = box.get(subjectId);
    List<McqPdf> pdfs = [];
    if (cachedData != null) {
      pdfs = (cachedData as List).map((e) {
        final map = Map<String, dynamic>.from(e);
        return McqPdf.fromMap(map, map['id'] ?? '');
      }).toList();
    }

    try {
      final snapshot = await _firestore
          .collection('mcq_pdfs')
          .where('subjectId', isEqualTo: subjectId)
          .where('isActive', isEqualTo: true)
          .orderBy('order')
          .get();

      final remotePdfs = snapshot.docs.map((doc) => McqPdf.fromMap(doc.data(), doc.id)).toList();
      
      // Update cache
      await box.put(subjectId, remotePdfs.map((e) {
        final map = e.toMap();
        map['id'] = e.id;
        return map;
      }).toList());
      return remotePdfs;
    } catch (e) {
      return pdfs; // Return cached if offline/error
    }
  }

  Future<List<McqTest>> getTests(String subjectId) async {
    final box = await Hive.openBox(_testBoxName);
    final cachedData = box.get(subjectId);
    List<McqTest> tests = [];
    
    if (cachedData != null) {
      tests = (cachedData as List).map((e) {
        final map = Map<String, dynamic>.from(e);
        return McqTest.fromMap(map, map['id'] ?? '');
      }).toList();
    }

    try {
      final snapshot = await _firestore
          .collection('mcq_tests')
          .where('subjectId', isEqualTo: subjectId)
          .where('isActive', isEqualTo: true)
          .get();

      final remoteTests = snapshot.docs.map((doc) => McqTest.fromMap(doc.data(), doc.id)).toList();
      await box.put(subjectId, remoteTests.map((e) {
        final map = e.toMap();
        map['id'] = e.id;
        return map;
      }).toList());
      return remoteTests;
    } catch (e) {
      return tests;
    }
  }
}
