import 'dart:async';
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:file_picker/file_picker.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';

import '../../../core/constants/firestore_paths.dart';
import '../../../core/constants/storage_bucket_config.dart';
import '../../../core/errors/app_exception.dart';
import '../../../shared/services/cache_policy.dart';
import '../../../shared/services/local_json_cache_service.dart';
import '../../../shared/services/write_rate_limiter.dart';
import 'bulletin_model.dart';

class BulletinRepository {
  BulletinRepository({
    FirebaseFirestore? firestore,
    FirebaseStorage? storage,
    FirebaseAuth? auth,
  }) : _firestore = firestore ?? FirebaseFirestore.instance,
       _storage =
           storage ??
           FirebaseStorage.instanceFor(
             bucket: StorageBucketConfig.activeBucketGsUri,
           ),
       _auth = auth ?? FirebaseAuth.instance,
       _rateLimiter = WriteRateLimiter(
         firestore: firestore ?? FirebaseFirestore.instance,
       );

  final FirebaseFirestore _firestore;
  final FirebaseStorage _storage;
  final FirebaseAuth _auth;
  final WriteRateLimiter _rateLimiter;
  static const String _cachePrefix = 'bulletins::';
  static const int _bulletinPostsPerHourTeacher = 6;
  static const int _bulletinPostsPerHourAdmin = 20;

  CollectionReference<Map<String, dynamic>> get _bulletinsRef =>
      _firestore.collection(FirestorePaths.bulletins);

  CollectionReference<Map<String, dynamic>> get _usersRef =>
      _firestore.collection(FirestorePaths.users);

  Stream<List<BulletinModel>> getBulletins(
    String collegeId, {
    int? semester,
    String? course,
    String? role,
  }) async* {
    final normalizedCourse = (course ?? '').trim().toLowerCase();
    final normalizedRole = (role ?? 'student').trim().toLowerCase();
    final isAdminOrTeacher = normalizedRole == 'admin' || normalizedRole == 'teacher';

    final cacheKey = _cacheKey(
      collegeId: collegeId,
      semester: semester,
      course: normalizedCourse,
      role: normalizedRole,
    );

    final cachedItems = await _readCachedBulletins(cacheKey);
    if (cachedItems.isNotEmpty) {
      yield cachedItems;
    }

    Query<Map<String, dynamic>> query = _bulletinsRef.where(
      'collegeId',
      isEqualTo: collegeId.trim(),
    );

    final stream = query.snapshots().map((snapshot) {
      final items = snapshot.docs
          .map((doc) => BulletinModel.fromMap(doc.data(), doc.id))
          .where((item) {
            // Admins and Teachers see all bulletins for their college
            if (isAdminOrTeacher) return true;

            // Students see global bulletins or those matching their semester/course
            final matchesSemester =
                item.targetSemester == null ||
                (semester != null && item.targetSemester == semester);

            final itemCourse = (item.targetCourse ?? '').trim().toLowerCase();
            final matchesCourse =
                itemCourse.isEmpty ||
                (normalizedCourse.isNotEmpty && itemCourse == normalizedCourse);

            return matchesSemester && matchesCourse;
          })
          .toList();

      items.sort((a, b) {
        if (a.isPinned != b.isPinned) return b.isPinned ? -1 : 1;
        return b.createdAt.compareTo(a.createdAt);
      });

      return items;
    });

    await for (final items in stream) {
      unawaited(_writeCachedBulletins(cacheKey, items));
      yield items;
    }
  }

  Stream<BulletinModel?> getBulletinById(String bulletinId) {
    return _bulletinsRef.doc(bulletinId).snapshots().map((snapshot) {
      if (!snapshot.exists || snapshot.data() == null) return null;
      return BulletinModel.fromMap(snapshot.data()!, snapshot.id);
    });
  }

  Future<void> postBulletin(
    String title,
    String desc,
    String category,
    String collegeId,
    String posterUid,
    String posterName,
    String posterRole, {
    int? targetSemester,
    String? targetCourse,
    DateTime? eventDate,
    PlatformFile? attachmentFile,
    void Function(double progress)? onUploadProgress,
  }) async {
    final trimmedTitle = title.trim();
    final trimmedDesc = desc.trim();
    final normalizedCategory = category.trim().toLowerCase();
    final normalizedRole = posterRole.trim().toLowerCase();

    if (trimmedTitle.isEmpty || trimmedDesc.isEmpty) {
      throw const AppException(message: 'Title and description are required');
    }

    if (!_allowedCategories.contains(normalizedCategory)) {
      throw const AppException(message: 'Invalid bulletin category');
    }

    if (normalizedRole != 'teacher' && normalizedRole != 'admin') {
      throw const AppException(
        message: 'Only teacher or admin can post bulletins',
      );
    }

    if (normalizedCategory == 'event' && eventDate == null) {
      throw const AppException(message: 'Event date is required for events');
    }

    await _rateLimiter.enforce(
      uid: posterUid,
      action: 'bulletin_post',
      maxRequests: _bulletinPostsPerHourForRole(normalizedRole),
      window: const Duration(hours: 1),
      messagePrefix: 'Bulletin post limit reached',
    );

    String? attachmentUrl;
    String? attachmentName;
    final bulletinRef = _bulletinsRef.doc();
    final bulletinId = bulletinRef.id;

    if (attachmentFile != null) {
      final ext = (attachmentFile.extension ?? '').toLowerCase();
      if (ext != 'pdf' && !attachmentFile.name.toLowerCase().endsWith('.pdf')) {
        throw const AppException(message: 'Only PDF attachments are allowed');
      }

      final storageRef = _storage
          .ref()
          .child('bulletins')
          .child(bulletinId)
          .child('attachment');
      final task = _uploadAttachment(storageRef, attachmentFile);
      final sub = task.snapshotEvents.listen((snapshot) {
        if (snapshot.totalBytes > 0) {
          onUploadProgress?.call(
            (snapshot.bytesTransferred / snapshot.totalBytes).clamp(0, 1),
          );
        }
      });

      try {
        await task;
        attachmentUrl = await storageRef.getDownloadURL();
        attachmentName = attachmentFile.name.trim().isEmpty
            ? 'attachment.pdf'
            : attachmentFile.name.trim();
      } finally {
        await sub.cancel();
      }
    }

    final model = BulletinModel(
      bulletinId: bulletinId,
      title: trimmedTitle,
      description: trimmedDesc,
      category: normalizedCategory,
      attachmentUrl: attachmentUrl,
      attachmentName: attachmentName,
      collegeId: collegeId,
      targetSemester: targetSemester,
      targetCourse: (targetCourse ?? '').trim().isEmpty
          ? null
          : targetCourse!.trim(),
      postedBy: posterUid,
      postedByName: posterName.trim(),
      postedByRole: normalizedRole,
      createdAt: DateTime.now(),
      eventDate: eventDate,
      readBy: [posterUid],
      isPinned: false,
    );

    await bulletinRef.set(model.toMap());
    await LocalJsonCacheService.instance.clearPrefix(_cachePrefix);
  }

  Future<void> markAsRead(String bulletinId, String uid) async {
    await _bulletinsRef.doc(bulletinId).update({
      'readBy': FieldValue.arrayUnion([uid]),
    });
    await LocalJsonCacheService.instance.clearPrefix(_cachePrefix);
  }

  Future<void> pinBulletin(String bulletinId) async {
    final currentUid = _auth.currentUser?.uid;
    if (currentUid == null) throw const AppException(message: 'Login required');

    final userDoc = await _usersRef.doc(currentUid).get();
    if ((userDoc.data()?['role'] as String? ?? '').trim().toLowerCase() !=
        'admin') {
      throw const AppException(message: 'Only admin can pin bulletin');
    }

    await _bulletinsRef.doc(bulletinId).update({'isPinned': true});
    await LocalJsonCacheService.instance.clearPrefix(_cachePrefix);
  }

  Future<void> deleteBulletin(String bulletinId) async {
    final currentUid = _auth.currentUser?.uid;
    if (currentUid == null) throw const AppException(message: 'Login required');

    final bulletinDoc = await _bulletinsRef.doc(bulletinId).get();
    final data = bulletinDoc.data();
    if (data == null) throw const AppException(message: 'Bulletin not found');

    final bulletin = BulletinModel.fromMap(data, bulletinDoc.id);
    final userDoc = await _usersRef.doc(currentUid).get();
    final role = (userDoc.data()?['role'] as String? ?? '')
        .trim()
        .toLowerCase();

    if (bulletin.postedBy != currentUid && role != 'admin') {
      throw const AppException(message: 'Unauthorized deletion');
    }

    if ((bulletin.attachmentUrl ?? '').isNotEmpty) {
      try {
        await _storage.refFromURL(bulletin.attachmentUrl!).delete();
      } catch (_) {}
    }

    await _bulletinsRef.doc(bulletinId).delete();
    await LocalJsonCacheService.instance.clearPrefix(_cachePrefix);
  }

  UploadTask _uploadAttachment(Reference ref, PlatformFile file) {
    final metadata = SettableMetadata(contentType: 'application/pdf');
    if (file.bytes != null) return ref.putData(file.bytes!, metadata);
    return ref.putFile(File(file.path!), metadata);
  }

  static const Set<String> _allowedCategories = {
    'notice',
    'event',
    'deadline',
    'placement',
    'holiday',
  };

  int _bulletinPostsPerHourForRole(String normalizedRole) {
    return normalizedRole == 'admin'
        ? _bulletinPostsPerHourAdmin
        : _bulletinPostsPerHourTeacher;
  }

  String _cacheKey({
    required String collegeId,
    int? semester,
    String course = '',
    String role = '',
  }) {
    return '$_cachePrefix${collegeId.trim()}::${semester ?? 0}::${course.trim()}::${role.trim()}';
  }

  Future<List<BulletinModel>> _readCachedBulletins(String key) async {
    final entry = await LocalJsonCacheService.instance.read(key);
    if (entry == null || !entry.isFresh(CachePolicy.bulletinsMaxAge)) {
      return const [];
    }
    final payload = entry.payload;
    if (payload is! List) {
      return const [];
    }

    return payload.map((item) {
      final map = Map<String, dynamic>.from(item as Map);
      if (map['createdAtMs'] is int) {
        map['createdAt'] = DateTime.fromMillisecondsSinceEpoch(
          map['createdAtMs'],
        );
      }
      if (map['eventDateMs'] is int) {
        map['eventDate'] = DateTime.fromMillisecondsSinceEpoch(
          map['eventDateMs'],
        );
      }
      return BulletinModel.fromMap(map, '');
    }).toList()..sort((a, b) {
      if (a.isPinned != b.isPinned) return b.isPinned ? -1 : 1;
      return b.createdAt.compareTo(a.createdAt);
    });
  }

  Future<void> _writeCachedBulletins(String key, List<BulletinModel> items) {
    final payload = items
        .map(
          (item) => item.toMap()
            ..addAll({
              'createdAtMs': item.createdAt.millisecondsSinceEpoch,
              'eventDateMs': item.eventDate?.millisecondsSinceEpoch,
            }),
        )
        .toList();
    return LocalJsonCacheService.instance.write(key, payload);
  }
}
