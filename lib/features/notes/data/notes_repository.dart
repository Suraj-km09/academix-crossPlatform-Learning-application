import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:crypto/crypto.dart';
import 'package:file_picker/file_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';

import '../../../core/constants/firestore_paths.dart';
import '../../../core/constants/storage_bucket_config.dart';
import '../../../core/errors/app_exception.dart';
import '../../../shared/services/write_rate_limiter.dart';
import '../../../shared/services/security_config_service.dart';
import 'note_model.dart';

class NotesRepository {
  NotesRepository({FirebaseFirestore? firestore, FirebaseStorage? storage})
    : _firestore = firestore ?? FirebaseFirestore.instance,
      _storage =
          storage ??
          FirebaseStorage.instanceFor(
            bucket: StorageBucketConfig.activeBucketGsUri,
          ),
      _rateLimiter = WriteRateLimiter(
        firestore: firestore ?? FirebaseFirestore.instance,
      );

  final FirebaseFirestore _firestore;
  final FirebaseStorage _storage;
  final WriteRateLimiter _rateLimiter;

  static const int defaultRecentNotesLimit = 60;
  static const int defaultOlderNotesPageSize = 40;
  static const int maxNotePdfSizeBytes = 50 * 1024 * 1024;
  static const int _noteUploadsPerHourStudent = 8;
  static const int _noteUploadsPerHourAlumni = 10;
  static const int _noteUploadsPerHourTeacher = 16;
  static const int _noteUploadsPerHourAdmin = 30;
  static final Set<String> _missingPagedQueryKeys = <String>{};

  Stream<List<NoteModel>> getRecentNotes(
    String collegeId, {
    int limit = defaultRecentNotesLimit,
    String? type,
    String? uploadedBy,
    String? course,
    String? branch,
  }) async* {
    final normalizedCollegeId = collegeId.trim();
    final queryKey = _pagedQueryKey(
      collegeId: normalizedCollegeId,
      type: type,
      uploadedBy: uploadedBy,
      course: course,
      branch: branch,
    );

    if (_missingPagedQueryKeys.contains(queryKey)) {
      yield* _recentNotesFallbackStream(
        collegeId: normalizedCollegeId,
        limit: limit,
        type: type,
        uploadedBy: uploadedBy,
      );
      return;
    }

    try {
      final query = _buildPagedNotesQuery(
        collegeId: normalizedCollegeId,
        type: type,
        uploadedBy: uploadedBy,
        course: course,
        branch: branch,
      ).limit(limit);

      await for (final snapshot in query.snapshots()) {
        final notes = snapshot.docs
            .map((doc) => NoteModel.fromMap(doc.data(), doc.id))
            .toList();
        yield notes;
      }
      return;
    } on FirebaseException catch (error) {
      if (!_isMissingIndexError(error)) {
        rethrow;
      }
      _missingPagedQueryKeys.add(queryKey);
    }

    yield* _recentNotesFallbackStream(
      collegeId: normalizedCollegeId,
      limit: limit,
      type: type,
      uploadedBy: uploadedBy,
      course: course,
      branch: branch,
    );
  }

  Stream<List<NoteModel>> _recentNotesFallbackStream({
    required String collegeId,
    required int limit,
    String? type,
    String? uploadedBy,
    String? course,
    String? branch,
  }) async* {
    final fallbackQuery = _firestore
        .collection(FirestorePaths.notes)
        .where('collegeId', isEqualTo: collegeId);

    await for (final snapshot in fallbackQuery.snapshots()) {
      final notes =
          snapshot.docs
              .map((doc) => NoteModel.fromMap(doc.data(), doc.id))
              .where(
                (note) => _matchesPagedFilter(
                  note,
                  type: type,
                  uploadedBy: uploadedBy,
                  course: course,
                  branch: branch,
                ),
              )
              .toList()
            ..sort((a, b) => b.uploadedAt.compareTo(a.uploadedAt));

      if (notes.length > limit) {
        yield notes.take(limit).toList();
      } else {
        yield notes;
      }
    }
  }

  Future<List<NoteModel>> getOlderNotesPage(
    String collegeId, {
    required DateTime before,
    int limit = defaultOlderNotesPageSize,
    String? type,
    String? uploadedBy,
    String? course,
    String? branch,
  }) async {
    final normalizedCollegeId = collegeId.trim();
    final queryKey = _pagedQueryKey(
      collegeId: normalizedCollegeId,
      type: type,
      uploadedBy: uploadedBy,
      course: course,
      branch: branch,
    );

    if (_missingPagedQueryKeys.contains(queryKey)) {
      return _getOlderNotesFallback(
        collegeId: normalizedCollegeId,
        before: before,
        limit: limit,
        type: type,
        uploadedBy: uploadedBy,
      );
    }

    try {
      final snapshot = await _buildPagedNotesQuery(
        collegeId: normalizedCollegeId,
        type: type,
        uploadedBy: uploadedBy,
        course: course,
        branch: branch,
      ).startAfter([Timestamp.fromDate(before)]).limit(limit).get();

      final notes = snapshot.docs
          .map((doc) => NoteModel.fromMap(doc.data(), doc.id))
          .toList();
      return notes;
    } on FirebaseException catch (error) {
      if (!_isMissingIndexError(error)) {
        rethrow;
      }
      _missingPagedQueryKeys.add(queryKey);
    }

    return _getOlderNotesFallback(
      collegeId: normalizedCollegeId,
      before: before,
      limit: limit,
      type: type,
      uploadedBy: uploadedBy,
      course: course,
      branch: branch,
    );
  }

  Future<List<NoteModel>> _getOlderNotesFallback({
    required String collegeId,
    required DateTime before,
    required int limit,
    String? type,
    String? uploadedBy,
    String? course,
    String? branch,
  }) async {
    final fallbackSnapshot = await _firestore
        .collection(FirestorePaths.notes)
        .where('collegeId', isEqualTo: collegeId)
        .get();

    final notes =
        fallbackSnapshot.docs
            .map((doc) => NoteModel.fromMap(doc.data(), doc.id))
            .where(
              (note) => _matchesPagedFilter(
                note,
                type: type,
                uploadedBy: uploadedBy,
                course: course,
                branch: branch,
              ),
            )
            .where((note) => note.uploadedAt.isBefore(before))
            .toList()
          ..sort((a, b) => b.uploadedAt.compareTo(a.uploadedAt));

    if (notes.length > limit) {
      return notes.take(limit).toList();
    }
    return notes;
  }

  String _pagedQueryKey({
    required String collegeId,
    String? type,
    String? uploadedBy,
    String? course,
    String? branch,
  }) {
    final normalizedType = type?.trim().toLowerCase() ?? '';
    final normalizedUploader = uploadedBy?.trim() ?? '';
    final normalizedCourse = course?.trim().toLowerCase() ?? '';
    final normalizedBranch = branch?.trim().toLowerCase() ?? '';
    return '${collegeId.trim()}|$normalizedType|$normalizedUploader|$normalizedCourse|$normalizedBranch';
  }

  Future<String> uploadNote(
    PlatformFile file,
    String title,
    String subject,
    String course,
    String branch,
    String semester,
    String year,
    List<String> tags,
    String type,
    String section,
    int? pyqYear,
    String collegeId,
    String uploaderUid,
    String uploaderName, {
    void Function(double progress)? onProgress,
  }) async {
    final normalizedType = type.trim().toLowerCase() == 'pyq' ? 'pyq' : 'notes';
    final normalizedSection = _normalizeSection(section);

    final uploaderRole = await _assertUploaderHasUploadAccess(uploaderUid);

    await _rateLimiter.enforce(
      uid: uploaderUid,
      action: 'note_upload',
      maxRequests: _noteUploadsPerHourForRole(uploaderRole),
      window: const Duration(hours: 1),
      messagePrefix: 'Note upload limit reached',
    );

    if (!_isPdf(file)) {
      throw const AppException(message: 'Only PDF files are allowed for notes');
    }

    if (file.size <= 0) {
      throw const AppException(message: 'Selected PDF is empty');
    }

    if (file.size > maxNotePdfSizeBytes) {
      throw const AppException(message: 'PDF size must be less than 50 MB');
    }

    Uint8List sourcePdfBytes = await _readFileBytes(file);
    if (sourcePdfBytes.isEmpty) {
      throw const AppException(message: 'Selected PDF is empty');
    }

    onProgress?.call(0.05);
    final compressedBytes = await _compressPdf(sourcePdfBytes);
    final finalBytes = compressedBytes ?? sourcePdfBytes;

    final fileHash = _computeHashFromBytes(finalBytes);
    await _assertNotDuplicateUpload(
      fileHash: fileHash,
      fileName: file.name,
      fileSize: finalBytes.length,
      collegeId: collegeId,
    );

    final noteRef = _firestore.collection(FirestorePaths.notes).doc(fileHash);
    final noteId = fileHash;
    final storageRef = _storage.ref().child('notes').child('$noteId.pdf');

    final metadata = SettableMetadata(
      contentType: 'application/pdf',
      customMetadata: {
        'originalSize': sourcePdfBytes.length.toString(),
        'compressedSize': finalBytes.length.toString(),
        'wasCompressed': (compressedBytes != null).toString(),
      },
    );

    final uploadTask = storageRef.putData(finalBytes, metadata);

    final subscription = uploadTask.snapshotEvents.listen((snapshot) {
      final total = snapshot.totalBytes;
      if (total <= 0) {
        return;
      }
      final progress = 0.1 + (snapshot.bytesTransferred / total) * 0.9;
      onProgress?.call(progress.clamp(0, 1));
    });

    try {
      await uploadTask;
      await subscription.cancel();

      final downloadUrl = await storageRef.getDownloadURL();
      final now = DateTime.now();

      final note = NoteModel(
        noteId: noteId,
        fileHash: fileHash,
        title: title.trim(),
        subject: subject.trim(),
        course: course.trim(),
        branch: branch.trim(),
        semester: semester.trim(),
        year: year.trim(),
        section: normalizedSection,
        tags: tags,
        fileUrl: downloadUrl,
        fileName: file.name.trim().isEmpty ? '$noteId.pdf' : file.name.trim(),
        fileSize: finalBytes.length,
        type: normalizedType,
        pyqYear: normalizedType == 'pyq' ? pyqYear : null,
        collegeId: collegeId,
        uploadedBy: uploaderUid,
        uploaderName: uploaderName.trim(),
        isVerified: false,
        verifiedBy: null,
        downloadCount: 0,
        uploadedAt: now,
        isRejected: false,
        rejectionReason: null,
      );

      await _firestore.runTransaction<void>((transaction) async {
        final snapshot = await transaction.get(noteRef);
        if (snapshot.exists) {
          throw const AppException(
            message:
                'This document is already available on the platform. Duplicate uploads are not allowed.',
          );
        }
        transaction.set(noteRef, note.toMap());
      });
      return noteId;
    } on FirebaseException catch (error) {
      if (error.code == 'already-exists') {
        throw const AppException(
          message:
              'This document is already available on the platform. Duplicate uploads are not allowed.',
        );
      }
      rethrow;
    } catch (error) {
      await subscription.cancel();
      rethrow;
    }
  }

  Future<Uint8List?> _compressPdf(Uint8List bytes) async {
    try {
      final PdfDocument document = PdfDocument(inputBytes: bytes);
      document.compressionLevel = PdfCompressionLevel.best;
      final List<int> compressed = await document.save();
      document.dispose();
      if (compressed.length < bytes.length) {
        return Uint8List.fromList(compressed);
      }
      return null;
    } catch (e) {
      return null;
    }
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

    try {
      final security = SecurityConfigService.instance(_firestore);
      final allowedForNotes = security.isRoleResourceAllowed(role, 'notes');
      if (!allowedForNotes) {
        throw AppException(
          message: 'Uploads by $role are currently disabled by admin.',
        );
      }
    } catch (_) {}

    return role.isEmpty ? 'student' : role;
  }

  int _noteUploadsPerHourForRole(String normalizedRole) {
    switch (normalizedRole) {
      case 'admin':
        return _noteUploadsPerHourAdmin;
      case 'teacher':
        return _noteUploadsPerHourTeacher;
      case 'alumni':
        return _noteUploadsPerHourAlumni;
      default:
        return _noteUploadsPerHourStudent;
    }
  }

  Future<void> deleteNote({
    required String noteId,
    required String actorUid,
    required String actorRole,
  }) async {
    final noteRef = _firestore.collection(FirestorePaths.notes).doc(noteId);
    final noteSnapshot = await noteRef.get();
    final data = noteSnapshot.data();

    if (!noteSnapshot.exists || data == null) {
      throw const AppException(message: 'Note not found');
    }

    final note = NoteModel.fromMap(data, noteSnapshot.id);
    final normalizedRole = actorRole.trim().toLowerCase();
    final isAdmin = normalizedRole == 'admin';
    final isOwner = actorUid.trim().isNotEmpty && note.uploadedBy == actorUid;
    if (!isAdmin && !isOwner) {
      throw const AppException(message: 'You can only delete your own uploads');
    }

    try {
      await noteRef.delete();
    } on FirebaseException catch (error) {
      if (error.code != 'not-found') {
        rethrow;
      }
    }

    final fileUrl = note.fileUrl.trim();
    if (fileUrl.isNotEmpty) {
      try {
        await _storage.refFromURL(fileUrl).delete();
      } on FirebaseException {}
    } else {
      try {
        await _storage.ref().child('notes/$noteId.pdf').delete();
      } on FirebaseException {}
    }

    try {
      await _deleteSubcollectionDocs(noteRef, 'downloads');
    } catch (_) {}

    try {
      await _deleteBookmarksForNote(noteId);
    } catch (_) {}
  }

  Future<List<NoteModel>> getNotes({
    required String collegeId,
    String? subject,
    String? semester,
    String? year,
    String? course,
    String? branch,
    String? type,
    String? searchQuery,
  }) async {
    Query<Map<String, dynamic>> query = _firestore
        .collection(FirestorePaths.notes)
        .where('collegeId', isEqualTo: collegeId.trim())
        .where('isRejected', isEqualTo: false);

    if (subject != null && subject.trim().isNotEmpty) {
      query = query.where('subject', isEqualTo: subject.trim());
    }
    if (semester != null && semester.trim().isNotEmpty) {
      query = query.where('semester', isEqualTo: semester.trim());
    }
    if (year != null && year.trim().isNotEmpty) {
      query = query.where('year', isEqualTo: year.trim());
    }
    if (course != null && course.trim().isNotEmpty) {
      query = query.where('course', isEqualTo: course.trim());
    }
    if (branch != null && branch.trim().isNotEmpty) {
      query = query.where('branch', isEqualTo: branch.trim());
    }
    if (type != null && type.trim().isNotEmpty) {
      query = query.where('type', isEqualTo: type.trim().toLowerCase());
    }

    final snapshot = await query.get();

    var notes = snapshot.docs
        .map((doc) => NoteModel.fromMap(doc.data(), doc.id))
        .toList();

    if (searchQuery != null && searchQuery.trim().isNotEmpty) {
      final q = searchQuery.trim().toLowerCase();
      notes = notes.where((note) {
        final haystack = <String>[
          note.title,
          note.subject,
          note.course,
          note.branch,
          note.section,
          note.semester,
          note.year,
          note.fileName,
          note.uploaderName,
          ...note.tags,
        ].join(' ').toLowerCase();
        return haystack.contains(q);
      }).toList();
    }

    notes.sort((a, b) => b.uploadedAt.compareTo(a.uploadedAt));
    return notes;
  }

  Future<bool> registerUniqueDownload(String noteId, String uid) {
    final noteRef = _firestore.collection(FirestorePaths.notes).doc(noteId);
    final downloadRef = noteRef.collection('downloads').doc(uid);

    return _firestore.runTransaction<bool>((transaction) async {
      final noteSnapshot = await transaction.get(noteRef);
      if (!noteSnapshot.exists) {
        throw const AppException(message: 'Note not found');
      }

      final downloadSnapshot = await transaction.get(downloadRef);
      if (downloadSnapshot.exists) {
        return false;
      }

      transaction.set(downloadRef, {
        'uid': uid,
        'downloadedAt': FieldValue.serverTimestamp(),
      });
      transaction.set(noteRef, {
        'downloadCount': FieldValue.increment(1),
      }, SetOptions(merge: true));

      return true;
    });
  }

  Future<void> verifyNote(String noteId, String verifierUid) {
    return _firestore.collection(FirestorePaths.notes).doc(noteId).set({
      'isVerified': true,
      'verifiedBy': verifierUid,
      'isRejected': false,
      'rejectionReason': null,
    }, SetOptions(merge: true));
  }

  Future<void> rejectNote(String noteId, String reason) async {
    final noteRef = _firestore.collection(FirestorePaths.notes).doc(noteId);
    final noteSnapshot = await noteRef.get();
    
    if (noteSnapshot.exists) {
      final data = noteSnapshot.data()!;
      final fileUrl = (data['fileUrl'] as String? ?? '').trim();
      
      // Remove from Storage
      if (fileUrl.isNotEmpty) {
        try {
          await _storage.refFromURL(fileUrl).delete();
        } on FirebaseException {}
      } else {
        try {
          await _storage.ref().child('notes/$noteId.pdf').delete();
        } on FirebaseException {}
      }

      // Cleanup subcollections
      try {
        await _deleteSubcollectionDocs(noteRef, 'downloads');
      } catch (_) {}

      try {
        await _deleteBookmarksForNote(noteId);
      } catch (_) {}

      // Delete from Firestore
      await noteRef.delete();
    }
  }

  Future<void> bookmarkNote(String uid, String noteId) {
    return _firestore
        .collection(FirestorePaths.users)
        .doc(uid)
        .collection('bookmarks')
        .doc(noteId)
        .set({'noteId': noteId, 'bookmarkedAt': FieldValue.serverTimestamp()});
  }

  Future<void> removeBookmark(String uid, String noteId) {
    return _firestore
        .collection(FirestorePaths.users)
        .doc(uid)
        .collection('bookmarks')
        .doc(noteId)
        .delete();
  }

  Future<bool> isBookmarked(String uid, String noteId) async {
    final doc = await _firestore
        .collection(FirestorePaths.users)
        .doc(uid)
        .collection('bookmarks')
        .doc(noteId)
        .get();
    return doc.exists;
  }

  Future<List<NoteModel>> getBookmarks(String uid) async {
    final bookmarksSnapshot = await _firestore
        .collection(FirestorePaths.users)
        .doc(uid)
        .collection('bookmarks')
        .orderBy('bookmarkedAt', descending: true)
        .get();

    final noteIds = bookmarksSnapshot.docs.map((doc) => doc.id).toList();
    if (noteIds.isEmpty) {
      return <NoteModel>[];
    }

    final notesById = <String, NoteModel>{};
    const chunkSize = 10;

    for (var index = 0; index < noteIds.length; index += chunkSize) {
      final end = (index + chunkSize > noteIds.length)
          ? noteIds.length
          : index + chunkSize;
      final chunk = noteIds.sublist(index, end);

      final querySnapshot = await _firestore
          .collection(FirestorePaths.notes)
          .where(FieldPath.documentId, whereIn: chunk)
          .get();

      for (final doc in querySnapshot.docs) {
        notesById[doc.id] = NoteModel.fromMap(doc.data(), doc.id);
      }
    }

    final ordered = <NoteModel>[];
    for (final id in noteIds) {
      final note = notesById[id];
      if (note != null && !note.isRejected) {
        ordered.add(note);
      }
    }

    return ordered;
  }

  Future<List<NoteModel>> getPendingNotes(String collegeId) async {
    final snapshot = await _firestore
        .collection(FirestorePaths.notes)
        .where('collegeId', isEqualTo: collegeId)
        .where('isVerified', isEqualTo: false)
        .where('isRejected', isEqualTo: false)
        .get();

    final notes =
        snapshot.docs
            .map((doc) => NoteModel.fromMap(doc.data(), doc.id))
            .toList()
          ..sort((a, b) => b.uploadedAt.compareTo(a.uploadedAt));

    return notes;
  }

  Future<NoteModel?> getNoteById(String noteId) async {
    final snapshot = await _firestore
        .collection(FirestorePaths.notes)
        .doc(noteId)
        .get();
    if (!snapshot.exists || snapshot.data() == null) {
      return null;
    }
    return NoteModel.fromMap(snapshot.data()!, snapshot.id);
  }

  bool _isPdf(PlatformFile file) {
    final ext = (file.extension ?? '').toLowerCase();
    return ext == 'pdf' || file.name.toLowerCase().endsWith('.pdf');
  }

  String _computeHashFromBytes(Uint8List bytes) {
    return sha256.convert(bytes).toString();
  }

  Future<void> _assertNotDuplicateUpload({
    required String fileHash,
    required String fileName,
    required int fileSize,
    required String collegeId,
  }) async {
    final directDoc = await _firestore
        .collection(FirestorePaths.notes)
        .doc(fileHash)
        .get();
    if (directDoc.exists) {
      throw const AppException(
        message:
            'This document is already available on the platform. Duplicate uploads are not allowed.',
      );
    }

    final hashSnapshot = await _firestore
        .collection(FirestorePaths.notes)
        .where('fileHash', isEqualTo: fileHash)
        .limit(1)
        .get();
    if (hashSnapshot.docs.isNotEmpty) {
      throw const AppException(
        message:
            'This document is already available on the platform. Duplicate uploads are not allowed.',
      );
    }

    final normalizedName = fileName.trim().toLowerCase();
    if (normalizedName.isEmpty || fileSize <= 0) {
      return;
    }

    final sameSizeSnapshot = await _firestore
        .collection(FirestorePaths.notes)
        .where('collegeId', isEqualTo: collegeId.trim())
        .where('fileSize', isEqualTo: fileSize)
        .limit(50)
        .get();

    for (final doc in sameSizeSnapshot.docs) {
      final existingName = (doc.data()['fileName'] as String? ?? '')
          .trim()
          .toLowerCase();
      if (existingName.isNotEmpty && existingName == normalizedName) {
        throw const AppException(
          message:
              'This document is already available on the platform. Duplicate uploads are not allowed.',
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
      throw const AppException(message: 'Unable to read selected file');
    }
    final f = File(path);
    if (!await f.exists()) {
      throw const AppException(message: 'Selected file does not exist');
    }
    return f.readAsBytes();
  }

  Future<void> _deleteSubcollectionDocs(
    DocumentReference<Map<String, dynamic>> parent,
    String subcollection,
  ) async {
    while (true) {
      final snapshot = await parent.collection(subcollection).limit(400).get();
      if (snapshot.docs.isEmpty) {
        break;
      }
      final batch = _firestore.batch();
      for (final doc in snapshot.docs) {
        batch.delete(doc.reference);
      }
      await batch.commit();
    }
  }

  Future<void> _deleteBookmarksForNote(String noteId) async {
    try {
      while (true) {
        final snapshot = await _firestore
            .collectionGroup('bookmarks')
            .where('noteId', isEqualTo: noteId)
            .limit(400)
            .get();

        if (snapshot.docs.isEmpty) {
          break;
        }
        final batch = _firestore.batch();
        for (final doc in snapshot.docs) {
          batch.delete(doc.reference);
        }
        await batch.commit();
      }
    } on FirebaseException catch (error) {
      if (!_isMissingIndexError(error)) rethrow;
      await _deleteBookmarksForNoteByUserScan(noteId);
    }
  }

  Future<void> _deleteBookmarksForNoteByUserScan(String noteId) async {
    DocumentSnapshot<Map<String, dynamic>>? cursor;
    while (true) {
      Query<Map<String, dynamic>> usersQuery = _firestore
          .collection(FirestorePaths.users)
          .orderBy(FieldPath.documentId)
          .limit(400);

      if (cursor != null) {
        usersQuery = usersQuery.startAfterDocument(cursor);
      }

      final usersSnapshot = await usersQuery.get();
      if (usersSnapshot.docs.isEmpty) break;

      final batch = _firestore.batch();
      for (final userDoc in usersSnapshot.docs) {
        final bookmarkRef = userDoc.reference
            .collection('bookmarks')
            .doc(noteId);
        batch.delete(bookmarkRef);
      }
      await batch.commit();
      if (usersSnapshot.docs.length < 400) break;
      cursor = usersSnapshot.docs.last;
    }
  }

  String _normalizeSection(String section) {
    final raw = section.trim().toLowerCase();
    if (raw == 'pyq') return 'pyq';
    if (raw == 'sessional') return 'sessional';
    if (raw == 'put') return 'put';
    return 'notes';
  }

  Query<Map<String, dynamic>> _buildPagedNotesQuery({
    required String collegeId,
    String? type,
    String? uploadedBy,
    String? course,
    String? branch,
  }) {
    Query<Map<String, dynamic>> query = _firestore
        .collection(FirestorePaths.notes)
        .where('collegeId', isEqualTo: collegeId.trim())
        .where('isRejected', isEqualTo: false)
        .orderBy('uploadedAt', descending: true);

    final normalizedType = type?.trim().toLowerCase();
    if (normalizedType == 'notes' || normalizedType == 'pyq') {
      query = query.where('type', isEqualTo: normalizedType);
    }
    final normalizedUploaderUid = uploadedBy?.trim();
    if (normalizedUploaderUid != null && normalizedUploaderUid.isNotEmpty) {
      query = query.where('uploadedBy', isEqualTo: normalizedUploaderUid);
    }
    final normalizedCourse = course?.trim();
    if (normalizedCourse != null && normalizedCourse.isNotEmpty) {
      query = query.where('course', isEqualTo: normalizedCourse);
    }
    final normalizedBranch = branch?.trim();
    if (normalizedBranch != null) {
      query = query.where('branch', isEqualTo: normalizedBranch);
    }
    return query;
  }

  bool _matchesPagedFilter(
    NoteModel note, {
    String? type,
    String? uploadedBy,
    String? course,
    String? branch,
  }) {
    if (note.isRejected) return false;
    final normalizedType = type?.trim().toLowerCase();
    if ((normalizedType == 'notes' || normalizedType == 'pyq') &&
        note.type != normalizedType)
      return false;
    final normalizedUploaderUid = uploadedBy?.trim();
    if (normalizedUploaderUid != null &&
        normalizedUploaderUid.isNotEmpty &&
        note.uploadedBy != normalizedUploaderUid)
      return false;
    if (course != null &&
        course.trim().isNotEmpty &&
        note.course.trim().toLowerCase() != course.trim().toLowerCase())
      return false;
    if (branch != null) {
      final nb = branch.trim();
      if (nb.isEmpty) {
        if (note.branch.trim().isNotEmpty) return false;
      } else if (note.branch.trim().toLowerCase() != nb.toLowerCase()) {
        return false;
      }
    }
    return true;
  }

  bool _isMissingIndexError(FirebaseException error) {
    if (error.code != 'failed-precondition') return false;
    final message = (error.message ?? '').toLowerCase();
    return message.contains('requires an index') ||
        message.contains('create it here');
  }
}
