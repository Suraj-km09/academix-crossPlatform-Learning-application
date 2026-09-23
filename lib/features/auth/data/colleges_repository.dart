import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/services.dart';

import '../../../core/constants/firestore_paths.dart';
import '../../../shared/models/college_model.dart';

class CollegesPage {
  const CollegesPage({
    required this.colleges,
    required this.lastDocument,
    required this.hasMore,
  });

  final List<CollegeModel> colleges;
  final DocumentSnapshot<Map<String, dynamic>>? lastDocument;
  final bool hasMore;
}

class CollegesRepository {
  CollegesRepository({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;
  List<CollegeModel>? _cachedAssetColleges;

  Future<List<CollegeModel>> _getAssetColleges() async {
    if (_cachedAssetColleges != null && _cachedAssetColleges!.isNotEmpty) {
      return _cachedAssetColleges!;
    }
    try {
      _cachedAssetColleges = await _parseCollegeListFromAsset();
      return _cachedAssetColleges!;
    } catch (_) {
      return const [];
    }
  }

  Future<CollegesPage> fetchColleges({
    required String searchQuery,
    required int pageSize,
    DocumentSnapshot<Map<String, dynamic>>? startAfter,
    int offset = 0,
  }) async {
    final normalized = _normalize(searchQuery);

    try {
      final field = _searchFieldFor(normalized);

      Query<Map<String, dynamic>> query = _firestore
          .collection(FirestorePaths.colleges)
          .orderBy(field)
          .limit(pageSize);

      if (normalized.isNotEmpty) {
        query = query.startAt([normalized]).endAt(['$normalized\uf8ff']);
      }

      if (startAfter != null) {
        query = query.startAfterDocument(startAfter);
      }

      final snapshot = await query.get();
      final docs = snapshot.docs;

      if (docs.isNotEmpty) {
        final colleges = docs
            .map((doc) => CollegeModel.fromMap(doc.data(), doc.id))
            .toList();

        return CollegesPage(
          colleges: colleges,
          lastDocument: docs.isEmpty ? startAfter : docs.last,
          hasMore: docs.length == pageSize,
        );
      }
    } catch (_) {
      // Gracefully fall back to local asset if Firestore fails (e.g. unauthenticated during registration, network error, or permission denied)
    }

    final allColleges = await _getAssetColleges();
    final filtered = normalized.isEmpty
        ? allColleges
        : allColleges.where((c) {
            final nameMatch = c.name.toLowerCase().contains(normalized);
            final idMatch = c.collegeId.toLowerCase().contains(normalized);
            final cityMatch = c.city.toLowerCase().contains(normalized);
            return nameMatch || idMatch || cityMatch;
          }).toList();

    final paged = filtered.skip(offset).take(pageSize).toList();
    final hasMore = (offset + pageSize) < filtered.length;

    return CollegesPage(
      colleges: paged,
      lastDocument: null,
      hasMore: hasMore,
    );
  }

  Future<int> seedCollegesFromAsset() async {
    final parsed = await _parseCollegeListFromAsset();
    if (parsed.isEmpty) {
      return 0;
    }

    const chunkSize = 400;
    var uploaded = 0;

    for (var i = 0; i < parsed.length; i += chunkSize) {
      final end = (i + chunkSize < parsed.length)
          ? i + chunkSize
          : parsed.length;
      final chunk = parsed.sublist(i, end);

      final batch = _firestore.batch();
      for (final college in chunk) {
        final ref = _firestore
            .collection(FirestorePaths.colleges)
            .doc(college.collegeId);
        batch.set(ref, _collegeDocMap(college), SetOptions(merge: true));
      }

      await batch.commit();
      uploaded += chunk.length;
    }

    return uploaded;
  }

  Map<String, dynamic> _collegeDocMap(CollegeModel college) {
    final nameLower = _normalize(college.name);
    final collegeIdLower = _normalize(college.collegeId);

    return {
      ...college.toMap(),
      'nameLower': nameLower,
      'collegeIdLower': collegeIdLower,
      'stateLower': _normalize(college.state),
      'cityLower': _normalize(college.city),
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }

  Future<List<CollegeModel>> _parseCollegeListFromAsset() async {
    final raw = await rootBundle.loadString('assets/data/college-list.txt');
    final lines = raw.split(RegExp(r'\r?\n'));

    final collegeById = <String, CollegeModel>{};
    var currentCity = 'Agra';

    for (final rawLine in lines) {
      final line = rawLine.trim();
      if (line.isEmpty) {
        continue;
      }

      final lower = line.toLowerCase();
      if (lower.startsWith('s.no')) {
        continue;
      }

      if (!line.contains('\t')) {
        currentCity = line
            .replaceAll(RegExp(r'\bdistrict\b', caseSensitive: false), '')
            .trim();
        continue;
      }

      final parts = line
          .split('\t')
          .map((value) => value.trim())
          .where((value) => value.isNotEmpty)
          .toList();

      if (parts.length < 3) {
        continue;
      }

      if (int.tryParse(parts.first) == null) {
        continue;
      }

      final code = parts[1];
      final name = parts.sublist(2).join(' ').trim();
      if (code.isEmpty || name.isEmpty) {
        continue;
      }

      collegeById[code] = CollegeModel(
        collegeId: code,
        name: name,
        state: 'Uttar Pradesh',
        city: currentCity,
        emailDomain: '',
      );
    }

    final colleges = collegeById.values.toList()
      ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));

    return colleges;
  }

  String _normalize(String input) {
    return input.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');
  }

  String _searchFieldFor(String normalizedQuery) {
    if (normalizedQuery.isEmpty) {
      return 'nameLower';
    }

    final hasDigit = RegExp(r'\d').hasMatch(normalizedQuery);
    return hasDigit ? 'collegeIdLower' : 'nameLower';
  }
}
