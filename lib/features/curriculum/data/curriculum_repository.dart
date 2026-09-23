import 'dart:io';
import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:crypto/crypto.dart';
import 'package:file_picker/file_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';

import '../../../core/constants/firestore_paths.dart';
import '../../../core/constants/storage_bucket_config.dart';
import '../../../core/errors/app_exception.dart';
import '../../../shared/services/security_config_service.dart';
import 'curriculum_item_model.dart';

class CurriculumRepository {
  CurriculumRepository({FirebaseFirestore? firestore, FirebaseStorage? storage})
    : _firestore = firestore ?? FirebaseFirestore.instance,
      _storage =
          storage ??
          FirebaseStorage.instanceFor(
            bucket: StorageBucketConfig.activeBucketGsUri,
          );

  static const int descriptionLimit = 1200;
  static const int maxDocumentSizeBytes = 10 * 1024 * 1024;
  static const int _minCompressionSizeBytes = 128 * 1024;
  static const double _compressionSavingsThreshold = 0.98;

  final FirebaseFirestore _firestore;
  final FirebaseStorage _storage;
  static const int defaultRecentCurriculumLimit = 40;
  static const int defaultOlderCurriculumPageSize = 40;
  static final Set<String> _missingPagedQueryKeys = <String>{};

  Future<String> createCurriculumItem({
    required String title,
    required String subject,
    required String description,
    required String course,
    required String semester,
    required String branch,
    required String category,
    required String collegeId,
    required String uploadedBy,
    required String uploaderName,
    required String uploaderRole,
    required bool isPinned,
    PlatformFile? documentFile,
  }) async {
    final cleanDescription = description.trim();
    if (cleanDescription.isEmpty) {
      throw const AppException(message: 'Description is required');
    }

    if (cleanDescription.length > descriptionLimit) {
      throw AppException(
        message: 'Description cannot exceed $descriptionLimit characters',
      );
    }

    _validateDocument(documentFile);

    final docRef = _firestore.collection(FirestorePaths.curriculum).doc();
    final now = DateTime.now();

    String documentUrl = '';
    String documentName = '';
    int documentSize = 0;
    String documentHash = '';

    if (documentFile != null) {
      final sourceBytes = await _readFileBytes(documentFile);
      documentHash = sha256.convert(sourceBytes).toString();
      await _assertNotDuplicateDocument(
        documentHash: documentHash,
        documentName: documentFile.name,
        documentSize: sourceBytes.length,
      );

      final uploaded = await _uploadDocument(
        file: documentFile,
        sourceBytes: sourceBytes,
        curriculumId: docRef.id,
        uploaderUid: uploadedBy,
      );
      documentUrl = uploaded.url;
      documentName = uploaded.name;
      documentSize = uploaded.size;
    }

    // Verify uploader has upload access controlled by admin.
    await _assertUploaderHasUploadAccess(uploadedBy);

    final item = CurriculumItemModel(
      curriculumId: docRef.id,
      title: title.trim(),
      subject: subject.trim(),
      description: cleanDescription,
      course: course.trim(),
      semester: semester.trim(),
      branch: branch.trim(),
      category: _normalizeCategory(category),
      collegeId: collegeId.trim(),
      uploadedBy: uploadedBy.trim(),
      uploaderName: uploaderName.trim(),
      uploaderRole: uploaderRole.trim().toLowerCase(),
      documentUrl: documentUrl,
      documentName: documentName,
      documentSize: documentSize,
      isPinned: isPinned,
      createdAt: now,
      updatedAt: now,
    );

    final payload = item.toMap()..addAll({'documentHash': documentHash});

    await docRef.set(payload);
    return docRef.id;
  }

  Future<void> deleteCurriculumItem({
    required String curriculumId,
    required String actorUid,
    required String actorRole,
  }) async {
    final docRef = _firestore
        .collection(FirestorePaths.curriculum)
        .doc(curriculumId);
    final snapshot = await docRef.get();
    final data = snapshot.data();

    if (!snapshot.exists || data == null) {
      throw const AppException(message: 'Curriculum item not found');
    }

    final item = CurriculumItemModel.fromMap(data, snapshot.id);
    final role = actorRole.trim().toLowerCase();
    final isAdmin = role == 'admin';
    final isOwner = actorUid.trim().isNotEmpty && item.uploadedBy == actorUid;
    if (!isAdmin && !isOwner) {
      throw const AppException(
        message: 'You can only delete your own uploaded resources',
      );
    }

    final documentUrl = item.documentUrl.trim();
    if (documentUrl.isNotEmpty) {
      try {
        await _storage.refFromURL(documentUrl).delete();
      } on FirebaseException catch (error) {
        if (error.code != 'object-not-found') {
          rethrow;
        }
      }
    }

    await docRef.delete();
  }

  Stream<List<CurriculumItemModel>> getCurriculumItems(
    String collegeId, {
    String? course,
    String? semester,
    String? branch,
    String? category,
  }) {
    // Build a Firestore query with only the safe equality filters provided.
    Query<Map<String, dynamic>> query = _firestore
        .collection(FirestorePaths.curriculum)
        .where('collegeId', isEqualTo: collegeId);

    final normalizedCourse = course?.trim();
    if (normalizedCourse != null && normalizedCourse.isNotEmpty) {
      query = query.where('course', isEqualTo: normalizedCourse);
    }
    final normalizedSemester = semester?.trim();
    if (normalizedSemester != null && normalizedSemester.isNotEmpty) {
      query = query.where('semester', isEqualTo: normalizedSemester);
    }
    final normalizedBranch = branch?.trim();
    if (normalizedBranch != null && normalizedBranch.isNotEmpty) {
      query = query.where('branch', isEqualTo: normalizedBranch);
    }
    final normalizedCategory = category?.trim().toLowerCase();
    if (normalizedCategory != null && normalizedCategory.isNotEmpty) {
      query = query.where('category', isEqualTo: normalizedCategory);
    }

    try {
      return query.snapshots().map((snapshot) {
        final items = snapshot.docs
            .map((doc) => CurriculumItemModel.fromMap(doc.data(), doc.id))
            .toList();

        items.sort((a, b) {
          if (a.isPinned != b.isPinned) {
            return a.isPinned ? -1 : 1;
          }
          return b.createdAt.compareTo(a.createdAt);
        });

        return items;
      });
    } on FirebaseException catch (error) {
      // If a missing index or other constraint prevents the compound query,
      // fall back to a safe college-wide stream and rely on client-side
      // filtering in the UI. This avoids crashing and keeps behavior stable.
      if (error.code == 'failed-precondition' ||
          (error.message ?? '').toLowerCase().contains('requires an index')) {
        return _firestore
            .collection(FirestorePaths.curriculum)
            .where('collegeId', isEqualTo: collegeId)
            .snapshots()
            .map((snapshot) {
              final items = snapshot.docs
                  .map((doc) => CurriculumItemModel.fromMap(doc.data(), doc.id))
                  .toList();

              items.sort((a, b) {
                if (a.isPinned != b.isPinned) {
                  return a.isPinned ? -1 : 1;
                }
                return b.createdAt.compareTo(a.createdAt);
              });

              return items;
            });
      }
      rethrow;
    }
  }

  Stream<List<CurriculumItemModel>> getRecentCurriculumItems(
    String collegeId, {
    int limit = defaultRecentCurriculumLimit,
    String? course,
    String? semester,
    String? branch,
    String? category,
  }) async* {
    final normalizedCollegeId = collegeId.trim();
    final queryKey = _pagedCurriculumQueryKey(
      collegeId: normalizedCollegeId,
      course: course,
      semester: semester,
      branch: branch,
      category: category,
    );

    if (_missingPagedQueryKeys.contains(queryKey)) {
      yield* _recentCurriculumFallbackStream(
        collegeId: normalizedCollegeId,
        limit: limit,
        course: course,
        semester: semester,
        branch: branch,
        category: category,
      );
      return;
    }

    try {
      final query = _buildPagedCurriculumQuery(
        collegeId: normalizedCollegeId,
        course: course,
        semester: semester,
        branch: branch,
        category: category,
      ).limit(limit);

      await for (final snapshot in query.snapshots()) {
        final items = snapshot.docs
            .map((doc) => CurriculumItemModel.fromMap(doc.data(), doc.id))
            .toList();

        items.sort((a, b) {
          if (a.isPinned != b.isPinned) return a.isPinned ? -1 : 1;
          return b.createdAt.compareTo(a.createdAt);
        });

        yield items;
      }
      return;
    } on FirebaseException catch (error) {
      if (!_isMissingIndexError(error)) {
        rethrow;
      }
      _missingPagedQueryKeys.add(queryKey);
    }

    yield* _recentCurriculumFallbackStream(
      collegeId: normalizedCollegeId,
      limit: limit,
      course: course,
      semester: semester,
      branch: branch,
      category: category,
    );
  }

  Stream<List<CurriculumItemModel>> _recentCurriculumFallbackStream({
    required String collegeId,
    required int limit,
    String? course,
    String? semester,
    String? branch,
    String? category,
  }) async* {
    final fallbackQuery = _firestore
        .collection(FirestorePaths.curriculum)
        .where('collegeId', isEqualTo: collegeId);

    await for (final snapshot in fallbackQuery.snapshots()) {
      final items = snapshot.docs
          .map((doc) => CurriculumItemModel.fromMap(doc.data(), doc.id))
          .where(
            (item) => _matchesPagedCurriculumFilter(
              item,
              course: course,
              semester: semester,
              branch: branch,
              category: category,
            ),
          )
          .toList();

      items.sort((a, b) {
        if (a.isPinned != b.isPinned) return a.isPinned ? -1 : 1;
        return b.createdAt.compareTo(a.createdAt);
      });

      if (items.length > limit) {
        yield items.take(limit).toList();
      } else {
        yield items;
      }
    }
  }

  Future<List<CurriculumItemModel>> getOlderCurriculumPage(
    String collegeId, {
    required DateTime before,
    int limit = defaultOlderCurriculumPageSize,
    String? course,
    String? semester,
    String? branch,
    String? category,
  }) async {
    final normalizedCollegeId = collegeId.trim();
    final queryKey = _pagedCurriculumQueryKey(
      collegeId: normalizedCollegeId,
      course: course,
      semester: semester,
      branch: branch,
      category: category,
    );

    if (_missingPagedQueryKeys.contains(queryKey)) {
      return _getOlderCurriculumFallback(
        collegeId: normalizedCollegeId,
        before: before,
        limit: limit,
        course: course,
        semester: semester,
        branch: branch,
        category: category,
      );
    }

    try {
      final snapshot = await _buildPagedCurriculumQuery(
        collegeId: normalizedCollegeId,
        course: course,
        semester: semester,
        branch: branch,
        category: category,
      ).startAfter([Timestamp.fromDate(before)]).limit(limit).get();

      final items = snapshot.docs
          .map((doc) => CurriculumItemModel.fromMap(doc.data(), doc.id))
          .toList();

      items.sort((a, b) {
        if (a.isPinned != b.isPinned) return a.isPinned ? -1 : 1;
        return b.createdAt.compareTo(a.createdAt);
      });

      return items;
    } on FirebaseException catch (error) {
      if (!_isMissingIndexError(error)) rethrow;
      _missingPagedQueryKeys.add(queryKey);
    }

    return _getOlderCurriculumFallback(
      collegeId: normalizedCollegeId,
      before: before,
      limit: limit,
      course: course,
      semester: semester,
      branch: branch,
      category: category,
    );
  }

  Future<List<CurriculumItemModel>> _getOlderCurriculumFallback({
    required String collegeId,
    required DateTime before,
    required int limit,
    String? course,
    String? semester,
    String? branch,
    String? category,
  }) async {
    final fallbackSnapshot = await _firestore
        .collection(FirestorePaths.curriculum)
        .where('collegeId', isEqualTo: collegeId)
        .get();

    final items = fallbackSnapshot.docs
        .map((doc) => CurriculumItemModel.fromMap(doc.data(), doc.id))
        .where(
          (item) => _matchesPagedCurriculumFilter(
            item,
            course: course,
            semester: semester,
            branch: branch,
            category: category,
          ),
        )
        .where((item) => item.createdAt.isBefore(before))
        .toList();

    items.sort((a, b) {
      if (a.isPinned != b.isPinned) return a.isPinned ? -1 : 1;
      return b.createdAt.compareTo(a.createdAt);
    });

    if (items.length > limit) {
      return items.take(limit).toList();
    }
    return items;
  }

  Query<Map<String, dynamic>> _buildPagedCurriculumQuery({
    required String collegeId,
    String? course,
    String? semester,
    String? branch,
    String? category,
  }) {
    Query<Map<String, dynamic>> query = _firestore
        .collection(FirestorePaths.curriculum)
        .where('collegeId', isEqualTo: collegeId.trim())
        .orderBy('createdAt', descending: true);

    final normalizedCourse = course?.trim();
    if (normalizedCourse != null && normalizedCourse.isNotEmpty) {
      query = query.where('course', isEqualTo: normalizedCourse);
    }
    final normalizedSemester = semester?.trim();
    if (normalizedSemester != null && normalizedSemester.isNotEmpty) {
      query = query.where('semester', isEqualTo: normalizedSemester);
    }
    final normalizedBranch = branch?.trim();
    if (normalizedBranch != null && normalizedBranch.isNotEmpty) {
      query = query.where('branch', isEqualTo: normalizedBranch);
    }
    final normalizedCategory = category?.trim().toLowerCase();
    if (normalizedCategory != null && normalizedCategory.isNotEmpty) {
      query = query.where('category', isEqualTo: normalizedCategory);
    }

    return query;
  }

  bool _matchesPagedCurriculumFilter(
    CurriculumItemModel item, {
    String? course,
    String? semester,
    String? branch,
    String? category,
  }) {
    if (course != null && course.trim().isNotEmpty) {
      if (item.course.trim().toLowerCase() != course.trim().toLowerCase()) {
        return false;
      }
    }

    if (semester != null && semester.trim().isNotEmpty) {
      if (item.semester.trim().toLowerCase() != semester.trim().toLowerCase()) {
        return false;
      }
    }

    if (branch != null && branch.trim().isNotEmpty) {
      if (item.branch.trim().toLowerCase() != branch.trim().toLowerCase()) {
        return false;
      }
    }

    if (category != null && category.trim().isNotEmpty) {
      if (item.category.trim().toLowerCase() != category.trim().toLowerCase()) {
        return false;
      }
    }

    return true;
  }

  String _pagedCurriculumQueryKey({
    required String collegeId,
    String? course,
    String? semester,
    String? branch,
    String? category,
  }) {
    final normalizedCourse = course?.trim().toLowerCase() ?? '';
    final normalizedSemester = semester?.trim() ?? '';
    final normalizedBranch = branch?.trim().toLowerCase() ?? '';
    final normalizedCategory = category?.trim().toLowerCase() ?? '';
    return '${collegeId.trim()}|$normalizedCourse|$normalizedSemester|$normalizedBranch|$normalizedCategory';
  }

  bool _isMissingIndexError(FirebaseException error) {
    if (error.code != 'failed-precondition') return false;
    final message = (error.message ?? '').toLowerCase();
    return message.contains('requires an index') ||
        message.contains('create it here');
  }

  Future<String> _assertUploaderHasUploadAccess(String uploaderUid) async {
    final uid = uploaderUid.trim();
    if (uid.isEmpty) {
      throw const AppException(message: 'Invalid uploader profile');
    }

    final userSnapshot = await _firestore
        .collection(FirestorePaths.users)
        .doc(uid)
        .get();

    final userData = userSnapshot.data();
    if (!userSnapshot.exists || userData == null) {
      throw const AppException(message: 'Uploader profile not found');
    }

    if (userData['isBanned'] == true) {
      throw const AppException(
        message: 'Your account is restricted. Contact support.',
      );
    }

    final role = (userData['role'] as String? ?? '').trim().toLowerCase();
    if (role == 'admin') {
      return role;
    }

    final canUploadNotesPyqs = userData['canUploadNotesPyqs'] as bool? ?? true;
    if (!canUploadNotesPyqs) {
      throw const AppException(
        message: 'Your notes and PYQ upload access has been disabled by admin.',
      );
    }

    // Respect global role-level upload controls from security config (cached).
    try {
      final security = SecurityConfigService.instance(_firestore);
      final allowedForCurriculum = security.isRoleResourceAllowed(
        role,
        'curriculum',
      );
      if (!allowedForCurriculum) {
        throw AppException(
          message: 'Uploads by $role are currently disabled by admin.',
        );
      }
    } catch (_) {
      // Fail-open: if security service cannot be read, allow uploads rather than blocking unexpectedly.
    }

    return role.isEmpty ? 'student' : role;
  }

  void _validateDocument(PlatformFile? file) {
    if (file == null) {
      return;
    }

    if (file.size <= 0) {
      throw const AppException(message: 'Selected document is empty');
    }

    if (file.size > maxDocumentSizeBytes) {
      throw const AppException(
        message: 'Document size must be less than 10 MB',
      );
    }

    final extension = (file.extension ?? '').trim().toLowerCase();
    const allowed = <String>{'pdf', 'txt', 'doc', 'docx'};
    if (!allowed.contains(extension)) {
      throw const AppException(
        message: 'Only PDF, TXT, DOC, and DOCX files are allowed',
      );
    }
  }

  Future<_UploadedDocument> _uploadDocument({
    required PlatformFile file,
    required Uint8List sourceBytes,
    required String curriculumId,
    String? uploaderUid,
  }) async {
    final ext = _fileExtension(file);
    final path = 'curriculum/$curriculumId.$ext';
    final ref = _storage.ref().child(path);

    final payload = _prepareDocumentUploadPayload(
      sourceBytes: sourceBytes,
      extension: ext,
    );

    final custom = <String, String>{
      'storageCompression': payload.isCompressed ? 'gzip' : 'none',
      'originalBytes': sourceBytes.length.toString(),
      'storedBytes': payload.bytes.length.toString(),
    };
    if (uploaderUid != null && uploaderUid.isNotEmpty) {
      custom['uploaderUid'] = uploaderUid;
    }
    custom['curriculumId'] = curriculumId;

    final metadata = SettableMetadata(
      contentType: _contentTypeFor(ext),
      contentEncoding: payload.isCompressed ? 'gzip' : null,
      customMetadata: custom,
    );

    final task = ref.putData(payload.bytes, metadata);

    await task;
    final url = await ref.getDownloadURL();

    return _UploadedDocument(
      url: url,
      name: file.name.trim(),
      size: sourceBytes.length,
    );
  }

  Future<void> _assertNotDuplicateDocument({
    required String documentHash,
    required String documentName,
    required int documentSize,
  }) async {
    if (documentHash.trim().isEmpty) {
      return;
    }

    final hashSnapshot = await _firestore
        .collection(FirestorePaths.curriculum)
        .where('documentHash', isEqualTo: documentHash)
        .limit(1)
        .get();

    if (hashSnapshot.docs.isNotEmpty) {
      throw const AppException(
        message:
            'This resource document is already available on the platform. Duplicate uploads are not allowed.',
      );
    }

    final normalizedName = documentName.trim().toLowerCase();
    if (normalizedName.isEmpty || documentSize <= 0) {
      return;
    }

    final sameSizeSnapshot = await _firestore
        .collection(FirestorePaths.curriculum)
        .where('documentSize', isEqualTo: documentSize)
        .limit(50)
        .get();

    for (final doc in sameSizeSnapshot.docs) {
      final existingName = (doc.data()['documentName'] as String? ?? '')
          .trim()
          .toLowerCase();
      if (existingName.isNotEmpty && existingName == normalizedName) {
        throw const AppException(
          message:
              'This resource document is already available on the platform. Duplicate uploads are not allowed.',
        );
      }
    }
  }

  Future<Uint8List> _readFileBytes(PlatformFile file) async {
    if (file.bytes != null && file.bytes!.isNotEmpty) {
      return file.bytes!;
    }

    final path = file.path;
    if (path == null || path.trim().isEmpty) {
      throw const AppException(message: 'Selected document is invalid');
    }

    final localFile = File(path);
    if (!await localFile.exists()) {
      throw const AppException(message: 'Selected document does not exist');
    }

    return localFile.readAsBytes();
  }

  _PreparedDocumentUpload _prepareDocumentUploadPayload({
    required Uint8List sourceBytes,
    required String extension,
  }) {
    final supportsCompression = extension == 'pdf';
    if (!supportsCompression || sourceBytes.length < _minCompressionSizeBytes) {
      return _PreparedDocumentUpload(bytes: sourceBytes, isCompressed: false);
    }

    final compressedBytes = Uint8List.fromList(gzip.encode(sourceBytes));
    final shouldUseCompressed =
        compressedBytes.length <
        (sourceBytes.length * _compressionSavingsThreshold).round();
    if (!shouldUseCompressed) {
      return _PreparedDocumentUpload(bytes: sourceBytes, isCompressed: false);
    }

    return _PreparedDocumentUpload(bytes: compressedBytes, isCompressed: true);
  }

  String _fileExtension(PlatformFile file) {
    final ext = (file.extension ?? '').trim().toLowerCase();
    if (ext.isNotEmpty) {
      return ext;
    }

    final name = file.name.trim().toLowerCase();
    final index = name.lastIndexOf('.');
    if (index > -1 && index + 1 < name.length) {
      return name.substring(index + 1);
    }
    return 'pdf';
  }

  String _normalizeCategory(String raw) {
    final value = raw.trim().toLowerCase();
    const allowed = <String>{
      'syllabus',
      'subject_info',
      'exam_guideline',
      'useful_info',
    };
    if (allowed.contains(value)) {
      return value;
    }
    return 'useful_info';
  }

  String _contentTypeFor(String extension) {
    switch (extension) {
      case 'txt':
        return 'text/plain';
      case 'doc':
        return 'application/msword';
      case 'docx':
        return 'application/vnd.openxmlformats-officedocument.wordprocessingml.document';
      case 'pdf':
      default:
        return 'application/pdf';
    }
  }
}

class _UploadedDocument {
  const _UploadedDocument({
    required this.url,
    required this.name,
    required this.size,
  });

  final String url;
  final String name;
  final int size;
}

class _PreparedDocumentUpload {
  const _PreparedDocumentUpload({
    required this.bytes,
    required this.isCompressed,
  });

  final Uint8List bytes;
  final bool isCompressed;
}
