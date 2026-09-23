import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:crypto/crypto.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';

import '../../../core/constants/firestore_paths.dart';
import '../../../core/constants/storage_bucket_config.dart';
import '../../../core/constants/course_branch_options.dart';
import '../../../core/errors/app_exception.dart';
import '../../../shared/models/college_model.dart';
import '../../../shared/models/user_model.dart';
import 'admin_log_model.dart';
import 'report_model.dart';

class AdminCollegesPage {
  const AdminCollegesPage({
    required this.colleges,
    required this.lastDocument,
    required this.hasMore,
  });

  final List<CollegeModel> colleges;
  final DocumentSnapshot<Map<String, dynamic>>? lastDocument;
  final bool hasMore;
}

class AdminUsersPage {
  const AdminUsersPage({
    required this.users,
    required this.lastDocument,
    required this.hasMore,
  });

  final List<UserModel> users;
  final DocumentSnapshot<Map<String, dynamic>>? lastDocument;
  final bool hasMore;
}

class AdminLogsPage {
  const AdminLogsPage({
    required this.logs,
    required this.lastDocument,
    required this.hasMore,
  });

  final List<AdminLogModel> logs;
  final DocumentSnapshot<Map<String, dynamic>>? lastDocument;
  final bool hasMore;
}

class AdminRepository {
  AdminRepository({FirebaseFirestore? firestore, FirebaseStorage? storage})
    : _firestore = firestore ?? FirebaseFirestore.instance,
      _storage =
          storage ??
          FirebaseStorage.instanceFor(
            bucket: StorageBucketConfig.activeBucketGsUri,
          );

  final FirebaseFirestore _firestore;
  final FirebaseStorage _storage;

  CollectionReference<Map<String, dynamic>> get _usersRef =>
      _firestore.collection(FirestorePaths.users);

  CollectionReference<Map<String, dynamic>> get _collegesRef =>
      _firestore.collection(FirestorePaths.colleges);

  CollectionReference<Map<String, dynamic>> get _notesRef =>
      _firestore.collection(FirestorePaths.notes);

  CollectionReference<Map<String, dynamic>> get _bulletinsRef =>
      _firestore.collection(FirestorePaths.bulletins);

  CollectionReference<Map<String, dynamic>> get _curriculumRef =>
      _firestore.collection(FirestorePaths.curriculum);

  CollectionReference<Map<String, dynamic>> get _referralsRef =>
      _firestore.collection(FirestorePaths.referrals);

  CollectionReference<Map<String, dynamic>> get _reportsRef =>
      _firestore.collection(FirestorePaths.reports);

  CollectionReference<Map<String, dynamic>> get _adminLogsRef =>
      _firestore.collection(FirestorePaths.adminLogs);

  DocumentReference<Map<String, dynamic>> get _securityConfigRef =>
      _firestore.collection(FirestorePaths.appConfig).doc('security');

  DocumentReference<Map<String, dynamic>> get _academicOptionsConfigRef =>
      _firestore.collection(FirestorePaths.appConfig).doc('academic_options');

  static const Set<String> _chatMessagingModes = {
    'none',
    'specific_users',
    'all_users',
    'only_teachers',
    'only_students',
    'only_alumni',
  };

  Stream<Map<String, int>> getDashboardStats() async* {
    while (true) {
      final now = DateTime.now();
      final dayStart = DateTime(now.year, now.month, now.day);
      final dayStartTs = Timestamp.fromDate(dayStart);

      final results = await Future.wait([
        _usersRef.count().get(),
        _collegesRef.count().get(),
        _notesRef
            .where('uploadedAt', isGreaterThanOrEqualTo: dayStartTs)
            .count()
            .get(),
        _referralsRef
            .where('createdAt', isGreaterThanOrEqualTo: dayStartTs)
            .count()
            .get(),
      ]);

      yield {
        'users': results[0].count ?? 0,
        'colleges': results[1].count ?? 0,
        'notesToday': results[2].count ?? 0,
        'referralsToday': results[3].count ?? 0,
      };

      await Future<void>.delayed(const Duration(seconds: 30));
    }
  }

  Stream<List<UserModel>> getAllUsers({String? role, String? collegeId}) {
    final normalizedRole = (role ?? '').trim().toLowerCase();
    final normalizedCollegeId = (collegeId ?? '').trim();

    return _usersRef.snapshots().map((snapshot) {
      final users = snapshot.docs
          .map((doc) => UserModel.fromMap(doc.data(), doc.id))
          .where(
            (user) =>
                (normalizedRole.isEmpty || user.role == normalizedRole) &&
                (normalizedCollegeId.isEmpty ||
                    user.collegeId == normalizedCollegeId),
          )
          .toList();

      users.sort(
        (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
      );
      return users;
    });
  }

  Stream<List<UserModel>> streamPendingTeacherRequests() {
    return _usersRef
        .where('teacherRequestStatus', isEqualTo: 'pending')
        .snapshots()
        .map((snapshot) {
          final users = snapshot.docs
              .map((doc) => UserModel.fromMap(doc.data(), doc.id))
              .toList();
          users.sort(
            (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
          );
          return users;
        });
  }

  Future<List<UserModel>> fetchPendingTeacherRequests() async {
    final snapshot = await _usersRef
        .where('teacherRequestStatus', isEqualTo: 'pending')
        .get();

    final users = snapshot.docs
        .map((doc) => UserModel.fromMap(doc.data(), doc.id))
        .toList();

    users.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    return users;
  }

  Future<AdminUsersPage> fetchUsersPage({
    String? role,
    String? collegeId,
    String? search,
    bool? isBanned,
    int pageSize = 30,
    DocumentSnapshot<Map<String, dynamic>>? startAfter,
  }) async {
    try {
      final normalizedRole = (role ?? '').trim().toLowerCase();
      final normalizedCollegeId = (collegeId ?? '').trim();
      final normalizedSearch = (search ?? '').trim();

      Query<Map<String, dynamic>> query = _usersRef;

      if (normalizedRole.isNotEmpty) {
        query = query.where('role', isEqualTo: normalizedRole);
      }
      if (normalizedCollegeId.isNotEmpty) {
        query = query.where('collegeId', isEqualTo: normalizedCollegeId);
      }
      if (isBanned != null) {
        query = query.where('isBanned', isEqualTo: isBanned);
      }

      if (normalizedSearch.isNotEmpty) {
        if (normalizedSearch.contains('@')) {
          query = query.where('email', isEqualTo: normalizedSearch);
          query = query.orderBy('name');
        } else {
          final end = '$normalizedSearch\uf8ff';
          query = query.orderBy('name').startAt([normalizedSearch]).endAt([
            end,
          ]);
        }
      } else {
        query = query.orderBy('name');
      }

      query = query.limit(pageSize);

      if (startAfter != null) {
        query = query.startAfterDocument(startAfter);
      }

      final snapshot = await query.get();
      final docs = snapshot.docs;
      final users = docs
          .map((doc) => UserModel.fromMap(doc.data(), doc.id))
          .toList();

      return AdminUsersPage(
        users: users,
        lastDocument: docs.isEmpty ? startAfter : docs.last,
        hasMore: docs.length == pageSize,
      );
    } catch (e) {
      if (kDebugMode) {
        print('--- FIRESTORE QUERY ERROR ---');
        print(e);
        print('-----------------------------');
      }
      rethrow;
    }
  }

  Future<void> banUser(String uid, {String? adminUid}) async {
    final targetUid = uid.trim();
    if (targetUid.isEmpty) return;

    await _usersRef.doc(targetUid).set({
      'isBanned': true,
      'activeSessionId': FieldValue.delete(),
      'activeSessionUpdatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    if (adminUid != null && adminUid.trim().isNotEmpty) {
      await logAdminAction(adminUid, 'ban_user', targetUid, 'user');
    }
  }

  Future<void> unbanUser(String uid, {String? adminUid}) async {
    final targetUid = uid.trim();
    if (targetUid.isEmpty) return;

    await _usersRef.doc(targetUid).update({'isBanned': false});

    if (adminUid != null && adminUid.trim().isNotEmpty) {
      await logAdminAction(adminUid, 'unban_user', targetUid, 'user');
    }
  }

  Future<void> deleteUser(String uid, {required String adminUid}) async {
    final trimmedUid = uid.trim();
    if (trimmedUid.isEmpty) {
      throw const AppException(message: 'Invalid user selected');
    }

    await _usersRef.doc(trimmedUid).delete();

    await logAdminAction(adminUid, 'delete_user', trimmedUid, 'user');
  }

  Future<void> changeUserRole(
    String uid,
    String newRole, {
    String? adminUid,
  }) async {
    final targetUid = uid.trim();
    if (targetUid.isEmpty) return;

    final normalizedRole = newRole.trim().toLowerCase();
    if (normalizedRole != 'student' &&
        normalizedRole != 'teacher' &&
        normalizedRole != 'alumni' &&
        normalizedRole != 'admin') {
      throw const AppException(message: 'Invalid role selected');
    }

    await _usersRef.doc(targetUid).set({
      'role': normalizedRole,
    }, SetOptions(merge: true));
    if (adminUid != null && adminUid.trim().isNotEmpty) {
      await logAdminAction(
        adminUid,
        'change_role:$normalizedRole',
        targetUid,
        'user',
      );
    }
  }

  Future<void> verifyAlumni(String uid, {String? adminUid}) async {
    final targetUid = uid.trim();
    if (targetUid.isEmpty) return;

    await _usersRef.doc(targetUid).set({
      'isVerified': true,
    }, SetOptions(merge: true));

    if (adminUid != null && adminUid.trim().isNotEmpty) {
      await logAdminAction(adminUid, 'verify_alumni', targetUid, 'user');
    }
  }

  Future<void> setNotesUploadAccess(
    String uid, {
    required bool canUpload,
    required String adminUid,
  }) async {
    final targetUid = uid.trim();
    if (targetUid.isEmpty) return;

    final normalizedAdminUid = adminUid.trim();
    if (normalizedAdminUid.isEmpty) {
      throw const AppException(message: 'Invalid admin session');
    }

    await _usersRef.doc(targetUid).set({
      'canUploadNotesPyqs': canUpload,
    }, SetOptions(merge: true));

    await logAdminAction(
      normalizedAdminUid,
      canUpload ? 'enable_notes_pyq_upload' : 'disable_notes_pyq_upload',
      targetUid,
      'user',
    );
  }

  Stream<List<ReportModel>> getPendingReports() {
    return _reportsRef.where('status', isEqualTo: 'pending').snapshots().map((
      snapshot,
    ) {
      final reports = snapshot.docs
          .map((doc) => ReportModel.fromMap(doc.data(), doc.id))
          .toList();
      reports.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return reports;
    });
  }

  Future<void> resolveReport(
    String reportId,
    String action, {
    required String adminUid,
  }) async {
    final reportDoc = await _reportsRef.doc(reportId).get();
    final reportData = reportDoc.data();
    if (reportData == null) {
      throw const AppException(message: 'Report not found');
    }

    final report = ReportModel.fromMap(reportData, reportDoc.id);
    final normalizedAction = action.trim().toLowerCase();

    if (normalizedAction == 'remove_content') {
      await _removeReportedContent(reportData, report, adminUid);
    } else if (normalizedAction == 'ban_reporter') {
      await banUser(report.reporterUid, adminUid: adminUid);
    } else if (normalizedAction == 'ban_target_user') {
      final targetUid = _resolveTargetUserUid(reportData, report);
      if (targetUid.isNotEmpty) {
        await banUser(targetUid, adminUid: adminUid);
      }
    }

    await _reportsRef.doc(reportId).set({
      'status': 'resolved',
      'resolvedAction': normalizedAction,
      'resolvedAt': FieldValue.serverTimestamp(),
      'resolvedBy': adminUid,
    }, SetOptions(merge: true));

    await logAdminAction(
      adminUid,
      'resolve_report:$normalizedAction',
      reportId,
      'report',
    );
  }

  Stream<List<CollegeModel>> getAllColleges() {
    return _collegesRef.snapshots().map((snapshot) {
      final colleges = snapshot.docs
          .map((doc) => CollegeModel.fromMap(doc.data(), doc.id))
          .toList();
      colleges.sort(
        (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
      );
      return colleges;
    });
  }

  Future<AdminCollegesPage> fetchCollegesPage({
    int pageSize = 25,
    DocumentSnapshot<Map<String, dynamic>>? startAfter,
  }) async {
    Query<Map<String, dynamic>> query = _collegesRef
        .orderBy('name')
        .limit(pageSize);

    if (startAfter != null) {
      query = query.startAfterDocument(startAfter);
    }

    final snapshot = await query.get();
    final docs = snapshot.docs;
    final colleges = docs
        .map((doc) => CollegeModel.fromMap(doc.data(), doc.id))
        .toList();

    return AdminCollegesPage(
      colleges: colleges,
      lastDocument: docs.isEmpty ? startAfter : docs.last,
      hasMore: docs.length == pageSize,
    );
  }

  Future<void> addCollege(
    String name,
    String state,
    String city,
    String emailDomain, {
    String? adminUid,
  }) async {
    final trimmedName = name.trim();
    if (trimmedName.isEmpty) {
      throw const AppException(message: 'College name is required');
    }

    final ref = _collegesRef.doc();
    final collegeId = ref.id;

    final normalizedName = _normalize(trimmedName);
    final normalizedCollegeId = _normalize(collegeId);

    await ref.set({
      'collegeId': collegeId,
      'name': trimmedName,
      'state': state.trim(),
      'city': city.trim(),
      'emailDomain': emailDomain.trim().toLowerCase(),
      'nameLower': normalizedName,
      'collegeIdLower': normalizedCollegeId,
      'stateLower': _normalize(state),
      'cityLower': _normalize(city),
      'updatedAt': FieldValue.serverTimestamp(),
    });

    if (adminUid != null && adminUid.trim().isNotEmpty) {
      await logAdminAction(adminUid, 'add_college', collegeId, 'college');
    }
  }

  Future<void> updateCollege({
    required String collegeId,
    required String name,
    required String state,
    required String city,
    required String emailDomain,
    required String adminUid,
  }) async {
    final trimmedCollegeId = collegeId.trim();
    final trimmedName = name.trim();
    if (trimmedCollegeId.isEmpty || trimmedName.isEmpty) {
      throw const AppException(message: 'College id and name are required');
    }

    await _collegesRef.doc(trimmedCollegeId).set({
      'collegeId': trimmedCollegeId,
      'name': trimmedName,
      'state': state.trim(),
      'city': city.trim(),
      'emailDomain': emailDomain.trim().toLowerCase(),
      'nameLower': _normalize(trimmedName),
      'collegeIdLower': _normalize(trimmedCollegeId),
      'stateLower': _normalize(state),
      'cityLower': _normalize(city),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    await logAdminAction(
      adminUid,
      'update_college',
      trimmedCollegeId,
      'college',
    );
  }

  Future<void> deleteCollege(
    String collegeId, {
    required String adminUid,
  }) async {
    final trimmedCollegeId = collegeId.trim();
    if (trimmedCollegeId.isEmpty) {
      throw const AppException(message: 'Invalid college selected');
    }

    final dependentChecks = await Future.wait([
      _usersRef.where('collegeId', isEqualTo: trimmedCollegeId).limit(1).get(),
      _notesRef.where('collegeId', isEqualTo: trimmedCollegeId).limit(1).get(),
      _curriculumRef
          .where('collegeId', isEqualTo: trimmedCollegeId)
          .limit(1)
          .get(),
      _bulletinsRef
          .where('collegeId', isEqualTo: trimmedCollegeId)
          .limit(1)
          .get(),
    ]);

    final hasDependencies = dependentChecks.any(
      (snapshot) => snapshot.docs.isNotEmpty,
    );
    if (hasDependencies) {
      throw const AppException(
        message:
            'Cannot delete this college because users or uploaded content are linked to it.',
      );
    }

    await _collegesRef.doc(trimmedCollegeId).delete();
    await logAdminAction(
      adminUid,
      'delete_college',
      trimmedCollegeId,
      'college',
    );
  }

  Future<void> saveAcademicOptions({
    required List<String> courses,
    required List<String> branches,
    required String adminUid,
  }) async {
    final normalizedAdminUid = adminUid.trim();
    if (normalizedAdminUid.isEmpty) {
      throw const AppException(message: 'Invalid admin session');
    }

    final normalizedCourses = _sanitizeAcademicOptions(courses);
    final normalizedBranches = _sanitizeAcademicOptions(branches);

    final safeCourses = normalizedCourses.isEmpty
        ? CourseBranchOptions.courses
        : normalizedCourses;
    final safeBranches = normalizedBranches.isEmpty
        ? CourseBranchOptions.branches
        : normalizedBranches;

    await _academicOptionsConfigRef.set({
      'courses': safeCourses,
      'branches': safeBranches,
      'updatedBy': normalizedAdminUid,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    await logAdminAction(
      normalizedAdminUid,
      'update_academic_options',
      'academic_options',
      'config',
    );
  }

  Future<void> logAdminAction(
    String adminUid,
    String action,
    String targetId,
    String targetType,
  ) async {
    final ref = _adminLogsRef.doc();
    final log = AdminLogModel(
      logId: ref.id,
      adminUid: adminUid.trim(),
      action: action.trim(),
      targetId: targetId.trim(),
      targetType: targetType.trim(),
      timestamp: DateTime.now(),
    );
    await ref.set(log.toMap());
  }

  Stream<List<AdminLogModel>> getRecentAdminLogs() {
    return _adminLogsRef
        .orderBy('timestamp', descending: true)
        .limit(3)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => AdminLogModel.fromMap(doc.data(), doc.id))
              .toList(),
        );
  }

  Future<AdminLogsPage> fetchAdminLogsPage({
    int pageSize = 5,
    DocumentSnapshot<Map<String, dynamic>>? startAfter,
  }) async {
    Query<Map<String, dynamic>> query = _adminLogsRef
        .orderBy('timestamp', descending: true)
        .limit(pageSize);

    if (startAfter != null) {
      query = query.startAfterDocument(startAfter);
    }

    final snapshot = await query.get();
    final docs = snapshot.docs;
    final logs = docs
        .map((doc) => AdminLogModel.fromMap(doc.data(), doc.id))
        .toList();

    return AdminLogsPage(
      logs: logs,
      lastDocument: docs.isEmpty ? startAfter : docs.last,
      hasMore: docs.length == pageSize,
    );
  }

  Stream<int> getPendingAlumniVerificationCount() {
    return _usersRef
        .where('role', isEqualTo: 'alumni')
        .where('isVerified', isEqualTo: false)
        .snapshots()
        .map((snapshot) => snapshot.docs.length);
  }

  Future<int> fetchPendingAlumniVerificationCount() async {
    final snapshot = await _usersRef
        .where('role', isEqualTo: 'alumni')
        .where('isVerified', isEqualTo: false)
        .count()
        .get();
    return snapshot.count ?? 0;
  }

  Stream<int> getPendingTeacherRequestCount() {
    return _usersRef
        .where('teacherRequestStatus', isEqualTo: 'pending')
        .snapshots()
        .map((snapshot) => snapshot.docs.length);
  }

  Future<int> fetchPendingTeacherRequestCount() async {
    final snapshot = await _usersRef
        .where('teacherRequestStatus', isEqualTo: 'pending')
        .count()
        .get();
    return snapshot.count ?? 0;
  }

  Stream<Map<String, dynamic>> getTeacherCodeConfig() {
    return _securityConfigRef.snapshots().map((doc) => doc.data() ?? {});
  }

  Stream<Map<String, dynamic>> getUploadAccessConfig() {
    return _securityConfigRef.snapshots().map((doc) {
      final data = doc.data() ?? <String, dynamic>{};
      final uploads =
          data['uploadsAllowedForRoles'] as Map<String, dynamic>? ?? {};

      Map<String, dynamic> roleEntry(Map<String, dynamic>? uploadsForRole) {
        if (uploadsForRole == null) {
          return {'notes': true, 'curriculum': true};
        }
        final notes = uploadsForRole['notes'] as bool? ?? true;
        final curriculum = uploadsForRole['curriculum'] as bool? ?? true;
        return {'notes': notes, 'curriculum': curriculum};
      }

      final studentEntry = uploads['student'];
      final teacherEntry = uploads['teacher'];
      final alumniEntry = uploads['alumni'];

      return {
        'student': studentEntry is Map<String, dynamic>
            ? roleEntry(studentEntry)
            : {
                'notes': studentEntry is bool ? studentEntry : true,
                'curriculum': studentEntry is bool ? studentEntry : true,
              },
        'teacher': teacherEntry is Map<String, dynamic>
            ? roleEntry(teacherEntry)
            : {
                'notes': teacherEntry is bool ? teacherEntry : true,
                'curriculum': teacherEntry is bool ? teacherEntry : true,
              },
        'alumni': alumniEntry is Map<String, dynamic>
            ? roleEntry(alumniEntry)
            : {
                'notes': alumniEntry is bool ? alumniEntry : true,
                'curriculum': alumniEntry is bool ? alumniEntry : true,
              },
        'uploadAccessUpdatedBy': data['uploadAccessUpdatedBy'] as String? ?? '',
        'uploadAccessUpdatedAt': data['uploadAccessUpdatedAt'],
      };
    });
  }

  Stream<Map<String, dynamic>> getChatMessagingControlConfig() {
    return _securityConfigRef.snapshots().map((doc) {
      final data = doc.data() ?? <String, dynamic>{};
      return {
        'chatMessagingRestrictionMode': _normalizeChatMessagingMode(
          data['chatMessagingRestrictionMode'] as String?,
        ),
        'chatMessagingDisabledUserUids': _sanitizeUidList(
          data['chatMessagingDisabledUserUids'],
        ),
        'chatMessagingBlockedRoles':
            data['chatMessagingBlockedRoles'] as Map<String, dynamic>? ?? {},
        'chatMessagingUpdatedBy':
            (data['chatMessagingUpdatedBy'] as String? ?? '').trim(),
        'chatMessagingUpdatedAt': data['chatMessagingUpdatedAt'],
      };
    });
  }

  Future<void> setChatMessagingRestrictionMode({
    required String adminUid,
    required String mode,
  }) async {
    final normalizedAdminUid = adminUid.trim();
    if (normalizedAdminUid.isEmpty) {
      throw const AppException(message: 'Invalid admin session');
    }

    final normalizedMode = _normalizeChatMessagingMode(mode);

    await _securityConfigRef.set({
      'chatMessagingRestrictionMode': normalizedMode,
      'chatMessagingUpdatedBy': normalizedAdminUid,
      'chatMessagingUpdatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    await logAdminAction(
      normalizedAdminUid,
      'set_chat_messaging_mode:$normalizedMode',
      'security',
      'config',
    );
  }

  Future<void> setRoleMessagingAccess({
    required String adminUid,
    required String role,
    required bool blocked,
  }) async {
    final normalizedAdminUid = adminUid.trim();
    final normalizedRole = role.trim().toLowerCase();

    if (normalizedAdminUid.isEmpty) {
      throw const AppException(message: 'Invalid admin session');
    }

    final updates = {
      'chatMessagingBlockedRoles.$normalizedRole': blocked,
      'chatMessagingUpdatedBy': normalizedAdminUid,
      'chatMessagingUpdatedAt': FieldValue.serverTimestamp(),
    };

    try {
      await _securityConfigRef.update(updates);
    } catch (_) {
      await _securityConfigRef.set(updates, SetOptions(merge: true));
    }

    await logAdminAction(
      normalizedAdminUid,
      blocked
          ? 'disable_role_chat:$normalizedRole'
          : 'enable_role_chat:$normalizedRole',
      'security',
      'config',
    );
  }

  Future<void> setRoleUploadAccess({
    required String adminUid,
    required String role,
    required String resource,
    required bool canUpload,
  }) async {
    final normalizedAdminUid = adminUid.trim();
    final normalizedRole = role.trim().toLowerCase();
    final normalizedResource = resource.trim().toLowerCase();

    if (normalizedAdminUid.isEmpty) {
      throw const AppException(message: 'Invalid admin session');
    }

    if (normalizedRole != 'student' &&
        normalizedRole != 'teacher' &&
        normalizedRole != 'alumni') {
      throw const AppException(message: 'Invalid role');
    }

    if (normalizedResource != 'notes' && normalizedResource != 'curriculum') {
      throw const AppException(message: 'Invalid resource');
    }

    await _securityConfigRef.set({
      'uploadsAllowedForRoles': {
        normalizedRole: {normalizedResource: canUpload},
      },
      'uploadAccessUpdatedBy': normalizedAdminUid,
      'uploadAccessUpdatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    await logAdminAction(
      normalizedAdminUid,
      canUpload
          ? 'enable_role_upload:$normalizedRole:$normalizedResource'
          : 'disable_role_upload:$normalizedRole:$normalizedResource',
      '$normalizedRole:$normalizedResource',
      'config',
    );
  }

  Future<void> setUserMessagingAccess({
    required String uid,
    required bool canMessage,
    required String adminUid,
  }) async {
    final normalizedAdminUid = adminUid.trim();
    final normalizedUid = uid.trim();

    if (normalizedAdminUid.isEmpty) {
      throw const AppException(message: 'Invalid admin session');
    }
    if (normalizedUid.isEmpty) {
      throw const AppException(message: 'Invalid user selected');
    }

    final configSnapshot = await _securityConfigRef.get();
    final configData = configSnapshot.data() ?? <String, dynamic>{};
    final disabledUserUids = _sanitizeUidList(
      configData['chatMessagingDisabledUserUids'],
    );

    if (canMessage) {
      disabledUserUids.remove(normalizedUid);
    } else {
      disabledUserUids.add(normalizedUid);
    }

    await _securityConfigRef.set({
      'chatMessagingDisabledUserUids': disabledUserUids.toList()..sort(),
      'chatMessagingUpdatedBy': normalizedAdminUid,
      'chatMessagingUpdatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    await logAdminAction(
      normalizedAdminUid,
      canMessage ? 'enable_user_chat_messaging' : 'disable_user_chat_messaging',
      normalizedUid,
      'user',
    );
  }

  Future<void> setStudentMessagingAccess({
    required String uid,
    required bool canMessage,
    required String adminUid,
  }) async {
    final normalizedUid = uid.trim();
    if (normalizedUid.isEmpty) {
      throw const AppException(message: 'Invalid user selected');
    }

    final userSnapshot = await _usersRef.doc(normalizedUid).get();
    final userData = userSnapshot.data();
    final role = (userData?['role'] as String? ?? '').trim().toLowerCase();

    if (role != 'student') {
      throw const AppException(
        message:
            'Specific-user messaging control currently supports students only.',
      );
    }

    await setUserMessagingAccess(
      uid: normalizedUid,
      canMessage: canMessage,
      adminUid: adminUid,
    );
  }

  Future<void> setTeacherAccessCode({
    required String adminUid,
    required String rawCode,
  }) async {
    final trimmed = rawCode.trim();
    if (trimmed.length < 6) {
      throw const AppException(
        message: 'Teacher access code must be at least 6 characters',
      );
    }

    final codeHash = sha256.convert(trimmed.codeUnits).toString();

    await _securityConfigRef.set({
      'teacherCodeHash': codeHash,
      'teacherCodeEnabled': true,
      'teacherCodeUpdatedBy': adminUid,
      'teacherCodeUpdatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    await logAdminAction(adminUid, 'set_teacher_code', 'security', 'config');
  }

  Future<void> disableTeacherAccessCode({required String adminUid}) async {
    await _securityConfigRef.set({
      'teacherCodeEnabled': false,
      'teacherCodeHash': null,
      'teacherCodeUpdatedBy': adminUid,
      'teacherCodeUpdatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    await logAdminAction(
      adminUid,
      'disable_teacher_code',
      'security',
      'config',
    );
  }

  Future<void> approveTeacherRequest(
    String uid, {
    required String adminUid,
  }) async {
    await _usersRef.doc(uid).set({
      'role': 'teacher',
      'teacherRequestStatus': 'approved',
      'teacherApprovedBy': adminUid,
      'teacherApprovedAt': FieldValue.serverTimestamp(),
      'requestedRole': null,
      'isApproved': true,
      'approvalMessageShown': false,
    }, SetOptions(merge: true));

    await logAdminAction(adminUid, 'approve_teacher_request', uid, 'user');
    try {
      final notifRef = _firestore
          .collection(FirestorePaths.notifications)
          .doc();
      await notifRef.set({
        'notifId': notifRef.id,
        'recipientUid': uid,
        'title': 'Teacher Request Approved',
        'body': 'You have been approved as Teacher. Welcome!',
        'type': 'teacher_approval',
        'targetRoute': '/home',
        'isRead': false,
        'createdAt': FieldValue.serverTimestamp(),
        'data': {'approvedBy': adminUid},
      });
    } catch (_) {}
  }

  Future<void> rejectTeacherRequest(
    String uid, {
    required String adminUid,
    String? reason,
  }) async {
    await _usersRef.doc(uid).set({
      'teacherRequestStatus': 'rejected',
      'teacherRejectedBy': adminUid,
      'teacherRejectedAt': FieldValue.serverTimestamp(),
      'teacherRejectReason': (reason ?? '').trim(),
      'requestedRole': null,
      'isApproved': false,
      'approvalMessageShown': false,
    }, SetOptions(merge: true));

    await logAdminAction(adminUid, 'reject_teacher_request', uid, 'user');
    try {
      final notifRef = _firestore
          .collection(FirestorePaths.notifications)
          .doc();
      await notifRef.set({
        'notifId': notifRef.id,
        'recipientUid': uid,
        'title': 'Teacher Request Rejected',
        'body': reason == null || reason.trim().isEmpty
            ? 'Your teacher request was rejected by the admin.'
            : 'Your teacher request was rejected: ${reason.trim()}',
        'type': 'teacher_rejection',
        'targetRoute': '/profile',
        'isRead': false,
        'createdAt': FieldValue.serverTimestamp(),
        'data': {'rejectedBy': adminUid, 'reason': (reason ?? '').trim()},
      });
    } catch (_) {}
  }

  Future<Map<String, int>> deleteAllResourcesByUploader({
    required String adminUid,
    required String uploaderUid,
  }) async {
    final targetUid = uploaderUid.trim();
    if (targetUid.isEmpty) {
      throw const AppException(message: 'Invalid uploader selected');
    }

    final notesSnapshot = await _notesRef
        .where('uploadedBy', isEqualTo: targetUid)
        .get();
    var notesDeleted = 0;
    for (final doc in notesSnapshot.docs) {
      final data = doc.data();
      final fileUrl = (data['fileUrl'] as String? ?? '').trim();
      await _deleteStorageObject(fileUrl, fallbackPath: 'notes/${doc.id}.pdf');
      await _deleteSubcollectionDocs(doc.reference, 'downloads');
      await _deleteBookmarksForNote(doc.id);
      await doc.reference.delete();
      notesDeleted++;
    }

    final curriculumSnapshot = await _curriculumRef
        .where('uploadedBy', isEqualTo: targetUid)
        .get();
    var curriculumDeleted = 0;
    for (final doc in curriculumSnapshot.docs) {
      final data = doc.data();
      final documentUrl = (data['documentUrl'] as String? ?? '').trim();
      await _deleteStorageObject(documentUrl);
      await doc.reference.delete();
      curriculumDeleted++;
    }

    final bulletinSnapshot = await _bulletinsRef
        .where('postedBy', isEqualTo: targetUid)
        .get();
    var bulletinsDeleted = 0;
    for (final doc in bulletinSnapshot.docs) {
      final data = doc.data();
      final attachmentUrl = (data['attachmentUrl'] as String? ?? '').trim();
      await _deleteStorageObject(attachmentUrl);
      await doc.reference.delete();
      bulletinsDeleted++;
    }

    await logAdminAction(
      adminUid,
      'delete_all_uploads',
      targetUid,
      'user_resources',
    );

    return {
      'notes': notesDeleted,
      'curriculum': curriculumDeleted,
      'bulletins': bulletinsDeleted,
    };
  }

  Stream<int> getPendingReportsCount() {
    return _reportsRef
        .where('status', isEqualTo: 'pending')
        .snapshots()
        .map((snapshot) => snapshot.docs.length);
  }

  Future<int> fetchPendingReportsCount() async {
    final snapshot = await _reportsRef
        .where('status', isEqualTo: 'pending')
        .count()
        .get();
    return snapshot.count ?? 0;
  }

  Stream<int> getPendingNotesCount() {
    return _notesRef
        .where('isVerified', isEqualTo: false)
        .where('isRejected', isEqualTo: false)
        .snapshots()
        .map((snapshot) => snapshot.docs.length);
  }

  Future<int> fetchPendingNotesCount() async {
    final snapshot = await _notesRef
        .where('isVerified', isEqualTo: false)
        .where('isRejected', isEqualTo: false)
        .count()
        .get();
    return snapshot.count ?? 0;
  }

  Future<void> _removeReportedContent(
    Map<String, dynamic> rawReport,
    ReportModel report,
    String adminUid,
  ) async {
    final targetType = report.targetType;
    final targetId = report.targetId;

    if (targetType == 'note' && targetId.isNotEmpty) {
      final noteDoc = await _notesRef.doc(targetId).get();
      if (noteDoc.exists) {
        final data = noteDoc.data()!;
        final fileUrl = (data['fileUrl'] as String? ?? '').trim();
        await _deleteStorageObject(fileUrl, fallbackPath: 'notes/$targetId.pdf');
        await _deleteSubcollectionDocs(noteDoc.reference, 'downloads');
        await _deleteBookmarksForNote(targetId);
        await noteDoc.reference.delete();
      }
      return;
    }

    if (targetType == 'message' && targetId.isNotEmpty) {
      final messageQuery = await _firestore
          .collectionGroup(FirestorePaths.messages)
          .where('messageId', isEqualTo: targetId)
          .limit(1)
          .get();

      if (messageQuery.docs.isNotEmpty) {
        await messageQuery.docs.first.reference.set({
          'isDeleted': true,
          'content': '',
          'fileUrl': null,
          'fileName': null,
        }, SetOptions(merge: true));
      }
      return;
    }

    if (targetType == 'user') {
      final targetUid = _resolveTargetUserUid(rawReport, report);
      if (targetUid.isNotEmpty) {
        await banUser(targetUid, adminUid: adminUid);
      }
    }
  }

  String _resolveTargetUserUid(
    Map<String, dynamic> rawReport,
    ReportModel report,
  ) {
    final raw =
        (rawReport['targetUid'] as String? ??
                rawReport['targetUserUid'] as String? ??
                (report.targetType == 'user' ? report.targetId : ''))
            .trim();
    return raw;
  }

  String _normalize(String value) {
    return value.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');
  }

  String _normalizeChatMessagingMode(String? mode) {
    final normalized = (mode ?? '').trim().toLowerCase();
    if (_chatMessagingModes.contains(normalized)) {
      return normalized;
    }
    return 'none';
  }

  Set<String> _sanitizeUidList(dynamic value) {
    if (value is! List) {
      return <String>{};
    }

    final output = <String>{};
    for (final item in value) {
      final uid = item.toString().trim();
      if (uid.isNotEmpty) {
        output.add(uid);
      }
    }
    return output;
  }

  List<String> _sanitizeAcademicOptions(List<String> values) {
    final seen = <String>{};
    final sanitized = <String>[];
    for (final item in values) {
      final value = item.trim();
      if (value.isEmpty) {
        continue;
      }
      final key = value.toLowerCase();
      if (seen.add(key)) {
        sanitized.add(value);
      }
    }
    return sanitized;
  }

  Future<void> _deleteStorageObject(
    String value, {
    String? fallbackPath,
  }) async {
    final input = value.trim();

    try {
      if (input.isNotEmpty) {
        if (input.startsWith('http://') || input.startsWith('https://')) {
          await _storage.refFromURL(input).delete();
          return;
        }
        await _storage.ref().child(input).delete();
        return;
      }

      if (fallbackPath != null && fallbackPath.trim().isNotEmpty) {
        await _storage.ref().child(fallbackPath.trim()).delete();
      }
    } on FirebaseException catch (error) {
      if (error.code != 'object-not-found') {
        rethrow;
      }
    }
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
  }
}
