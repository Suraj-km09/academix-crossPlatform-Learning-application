import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:crypto/crypto.dart';
import 'package:file_picker/file_picker.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';

import '../../../core/constants/firestore_paths.dart';
import '../../../core/constants/storage_bucket_config.dart';
import '../../../core/errors/app_exception.dart';
import '../../../shared/models/user_model.dart';
import '../../../shared/services/auth_session_service.dart';
import '../../../shared/services/cache_policy.dart';
import '../../../shared/services/local_json_cache_service.dart';

class AuthRepository {
  AuthRepository({
    FirebaseAuth? auth,
    FirebaseFirestore? firestore,
    FirebaseStorage? storage,
  }) : _auth = auth ?? FirebaseAuth.instance,
       _firestore = firestore ?? FirebaseFirestore.instance,
       _storage =
           storage ??
           FirebaseStorage.instanceFor(
             bucket: StorageBucketConfig.activeBucketGsUri,
           );

  final FirebaseAuth _auth;
  final FirebaseFirestore _firestore;
  final FirebaseStorage _storage;

  static const String _teacherInviteCode = String.fromEnvironment(
    'TEACHER_INVITE_CODE',
    defaultValue: '',
  );
  static const String _userCachePrefix = 'user_profile::';

  Future<UserModel> signUp(
    String name,
    String email,
    String password,
    String role,
    String collegeId,
    String? course,
    String? branch,
    int? semester,
    int? batchYear,
    String? company,
    String? jobRole,
    PlatformFile? profileImage,
    PlatformFile? idCardImage,
    String? teacherAccessCode,
  ) async {
    UserCredential? credentials;

    try {
      final requestedRole = role.trim().toLowerCase();
      final isTeacherRequest = requestedRole == 'teacher';

      // Validate teacher access code before creating the Firebase user to
      // avoid creating a partially-initialized account that signs the user in.
      if (isTeacherRequest) {
        await _validateTeacherAccessCode((teacherAccessCode ?? '').trim());
      }

      credentials = await _auth.createUserWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );

      final firebaseUser = credentials.user;
      if (firebaseUser == null) {
        throw const AppException(message: 'Unable to create user account');
      }

      await firebaseUser.updateDisplayName(name.trim());

      final profileStoragePath = await _uploadUserImage(
        uid: firebaseUser.uid,
        file: profileImage,
        folder: 'profile',
      );
      final idCardStoragePath = await _uploadUserImage(
        uid: firebaseUser.uid,
        file: idCardImage,
        folder: 'id_card',
      );

      final collegeSnapshot = await _firestore
          .collection(FirestorePaths.colleges)
          .doc(collegeId)
          .get();
      final collegeData = collegeSnapshot.data() ?? <String, dynamic>{};

      final now = DateTime.now();
      final normalizedRole = _normalizedRole(requestedRole);
      final userModel = UserModel(
        uid: firebaseUser.uid,
        name: name.trim(),
        email: email.trim().toLowerCase(),
        role: normalizedRole,
        collegeId: collegeId,
        collegeName: (collegeData['name'] as String? ?? '').trim(),
        affiliatedUniversityName:
            (collegeData['affiliatedUniversityName'] as String? ??
                    collegeData['universityName'] as String? ??
                    '')
                .trim(),
        course: (course ?? '').trim(),
        branch: (branch ?? '').trim(),
        semester: semester,
        batchYear: batchYear,
        currentCompany: company?.trim().isEmpty == true
            ? null
            : company?.trim(),
        currentRole: jobRole?.trim().isEmpty == true ? null : jobRole?.trim(),
        openToRefer: normalizedRole == 'alumni',
        skills: const <String>[],
        referralsGiven: 0,
        questionsAnswered: 0,
        avgRating: 0,
        totalRatings: 0,
        linkedinUrl: null,
        isVerified: false,
        isBanned: false,
        canUploadNotesPyqs: true,
        createdAt: now,
        photoUrl: profileStoragePath,
        collegeIdCardPhotoUrl: idCardStoragePath,
        teacherRequestStatus: isTeacherRequest ? 'pending' : 'none',
        requestedRole: isTeacherRequest ? 'teacher' : '',
        isApproved: false,
        approvalMessageShown: false,
      );

      final userMap = userModel.toMap();
      if (isTeacherRequest) {
        userMap['requestedRole'] = 'teacher';
        userMap['teacherRequestedAt'] = FieldValue.serverTimestamp();
        userMap['isApproved'] = false;
        userMap['approvalMessageShown'] = false;
        userMap['teacherRequestMessageShown'] = false;
      }

      await _firestore
          .collection(FirestorePaths.users)
          .doc(firebaseUser.uid)
          .set(userMap);

      return userModel;
    } on FirebaseAuthException catch (error) {
      throw AppException(
        message: error.message ?? 'Authentication failed during sign up',
        code: error.code,
      );
    } on FirebaseException catch (error) {
      if (credentials?.user != null) {
        await credentials!.user!.delete();
      }
      throw AppException(
        message: error.message ?? 'Unable to save user profile',
        code: error.code,
      );
    } catch (error) {
      if (credentials?.user != null) {
        await credentials!.user!.delete();
      }
      throw AppException(message: error.toString());
    }
  }

  Future<UserModel> login(String email, String password) async {
    try {
      final credentials = await _auth.signInWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );

      final firebaseUser = credentials.user;
      if (firebaseUser == null) {
        throw const AppException(message: 'Unable to login user');
      }

      await firebaseUser.reload();
      final refreshedUser = _auth.currentUser;
      if (refreshedUser == null) {
        await _auth.signOut();
        throw const AppException(message: 'Unable to refresh user session');
      }

      var userModel = await getUserById(refreshedUser.uid);
      if (userModel == null) {
        await _auth.signOut();
        throw const AppException(message: 'User profile not found');
      }

      if (userModel.isBanned) {
        await _auth.signOut();
        throw const AppException(
          message: 'Your account has been restricted. Contact support.',
          code: 'banned-account',
        );
      }

      if (!refreshedUser.emailVerified) {
        throw const AppException(
          message:
              'Email is not verified. Please verify your email before logging in.',
          code: 'email-not-verified',
        );
      }

      if (!userModel.isVerified) {
        await _firestore
            .collection(FirestorePaths.users)
            .doc(refreshedUser.uid)
            .set({'isVerified': true}, SetOptions(merge: true));
        userModel = userModel.copyWith(isVerified: true);
      }

      return userModel;
    } on FirebaseAuthException catch (error) {
      throw AppException(
        message: error.message ?? 'Login failed',
        code: error.code,
      );
    }
  }

  Future<void> logout({
    String? alertMessage,
    bool clearRemoteSession = true,
  }) async {
    await AuthSessionService.logoutCurrentUser(
      clearRemoteSession: clearRemoteSession,
      alertMessage: alertMessage ?? 'You have been logged out.',
    );
  }

  Stream<User?> authStateChanges() => _auth.authStateChanges();

  Future<void> updateFcmToken(String uid, String token) async {
    await _firestore.collection(FirestorePaths.users).doc(uid).set({
      'fcmToken': token,
    }, SetOptions(merge: true));
  }

  Future<void> markApprovalMessageShown(String uid) async {
    if (uid.trim().isEmpty) return;
    await _firestore.collection(FirestorePaths.users).doc(uid).set({
      'approvalMessageShown': true,
    }, SetOptions(merge: true));
  }

  Future<void> markTeacherRequestMessageShown(String uid) async {
    if (uid.trim().isEmpty) return;
    await _firestore.collection(FirestorePaths.users).doc(uid).set({
      'teacherRequestMessageShown': true,
    }, SetOptions(merge: true));
  }

  Future<void> sendPasswordResetEmail(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email.trim());
    } on FirebaseAuthException catch (error) {
      throw AppException(
        message: error.message ?? 'Unable to send password reset email',
        code: error.code,
      );
    }
  }

  Future<void> sendEmailVerificationToCurrentUser() async {
    final user = _auth.currentUser;
    if (user == null) {
      throw const AppException(message: 'No logged-in user found');
    }

    if (user.emailVerified) {
      return;
    }

    try {
      await user.sendEmailVerification();
    } on FirebaseAuthException catch (error) {
      throw AppException(
        message: error.message ?? 'Unable to send verification email',
        code: error.code,
      );
    }
  }

  Future<void> resendVerificationForCredentials(
    String email,
    String password,
  ) async {
    try {
      final credentials = await _auth.signInWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
      final user = credentials.user;
      if (user == null) {
        throw const AppException(message: 'Unable to access account');
      }

      if (!user.emailVerified) {
        await user.sendEmailVerification();
      }

      await _auth.signOut();
    } on FirebaseAuthException catch (error) {
      throw AppException(
        message: error.message ?? 'Unable to resend verification email',
        code: error.code,
      );
    }
  }

  Future<void> markCurrentUserVerified() async {
    final user = _auth.currentUser;
    if (user == null || !user.emailVerified) {
      return;
    }

    await _firestore.collection(FirestorePaths.users).doc(user.uid).set({
      'isVerified': true,
    }, SetOptions(merge: true));
  }

  Future<UserModel?> getUserById(String uid) async {
    final cacheKey = '$_userCachePrefix$uid';
    final cachedEntry = await LocalJsonCacheService.instance.read(cacheKey);
    final cachedUser = _userFromCacheEntry(cachedEntry, uid);

    if (cachedEntry != null &&
        cachedUser != null &&
        cachedEntry.isFresh(CachePolicy.userProfileMaxAge)) {
      return cachedUser;
    }

    try {
      final snapshot = await _firestore
          .collection(FirestorePaths.users)
          .doc(uid)
          .get();
      if (!snapshot.exists || snapshot.data() == null) {
        return null;
      }

      var user = UserModel.fromMap(snapshot.data()!, snapshot.id);
      if (user.collegeName.trim().isEmpty && user.collegeId.trim().isNotEmpty) {
        try {
          final collegeSnapshot = await _firestore
              .collection(FirestorePaths.colleges)
              .doc(user.collegeId)
              .get();
          final collegeData = collegeSnapshot.data();
          final resolvedCollegeName = (collegeData?['name'] as String? ?? '')
              .trim();
          final resolvedUniversityName =
              (collegeData?['affiliatedUniversityName'] as String? ??
                      collegeData?['universityName'] as String? ??
                      '')
                  .trim();

          if (resolvedCollegeName.isNotEmpty) {
            final updates = <String, dynamic>{
              'collegeName': resolvedCollegeName,
            };
            if (user.affiliatedUniversityName.trim().isEmpty &&
                resolvedUniversityName.isNotEmpty) {
              updates['affiliatedUniversityName'] = resolvedUniversityName;
            }

            await _firestore
                .collection(FirestorePaths.users)
                .doc(uid)
                .set(updates, SetOptions(merge: true));

            user = user.copyWith(
              collegeName: resolvedCollegeName,
              affiliatedUniversityName:
                  user.affiliatedUniversityName.trim().isEmpty
                  ? resolvedUniversityName
                  : user.affiliatedUniversityName,
            );
          }
        } catch (_) {
          // Keep resolved user from user-doc if college lookup fails.
        }
      }

      await LocalJsonCacheService.instance.write(
        cacheKey,
        _userToCacheMap(user),
      );
      return user;
    } catch (_) {
      return cachedUser;
    }
  }

  UserModel? _userFromCacheEntry(LocalJsonCacheEntry? entry, String uid) {
    final payload = entry?.payload;
    if (payload is! Map) {
      return null;
    }

    final map = payload.map((k, v) => MapEntry(k.toString(), v));
    final createdAtMs = map['createdAtMs'];
    if (createdAtMs is int) {
      map['createdAt'] = DateTime.fromMillisecondsSinceEpoch(createdAtMs);
    }

    return UserModel.fromMap(Map<String, dynamic>.from(map), uid);
  }

  Map<String, dynamic> _userToCacheMap(UserModel user) {
    return {
      'uid': user.uid,
      'name': user.name,
      'email': user.email,
      'role': user.role,
      'collegeId': user.collegeId,
      'collegeName': user.collegeName,
      'affiliatedUniversityName': user.affiliatedUniversityName,
      'course': user.course,
      'branch': user.branch,
      'semester': user.semester,
      'collegeIdCardPhotoUrl': user.collegeIdCardPhotoUrl,
      'profileLinks': user.profileLinks,
      'batchYear': user.batchYear,
      'customBio': user.customBio,
      'currentCompany': user.currentCompany,
      'currentRole': user.currentRole,
      'openToRefer': user.openToRefer,
      'skills': user.skills,
      'referralsGiven': user.referralsGiven,
      'questionsAnswered': user.questionsAnswered,
      'avgRating': user.avgRating,
      'totalRatings': user.totalRatings,
      'linkedinUrl': user.linkedinUrl,
      'photoUrl': user.photoUrl,
      'fcmToken': user.fcmToken,
      'teacherRequestStatus': user.teacherRequestStatus,
      'isVerified': user.isVerified,
      'isBanned': user.isBanned,
      'canUploadNotesPyqs': user.canUploadNotesPyqs,
      'createdAtMs': user.createdAt.millisecondsSinceEpoch,
    };
  }

  String _normalizedRole(String role) {
    final value = role.trim().toLowerCase();
    if (value == 'alumni') {
      return value;
    }
    return 'student';
  }

  Future<void> _validateTeacherAccessCode(String rawCode) async {
    if (rawCode.trim().isEmpty) {
      throw AppException(
        message: 'Teacher access code is required',
        code: 'missing_teacher_code',
      );
    }

    final securitySnapshot = await _firestore
        .collection(FirestorePaths.appConfig)
        .doc('security')
        .get();
    final securityConfig = securitySnapshot.data() ?? <String, dynamic>{};

    final isRuntimeEnabled = securityConfig['teacherCodeEnabled'] == true;
    final runtimeHash = (securityConfig['teacherCodeHash'] as String? ?? '')
        .trim();

    if (isRuntimeEnabled && runtimeHash.isNotEmpty) {
      final incomingHash = sha256.convert(rawCode.trim().codeUnits).toString();
      if (incomingHash != runtimeHash) {
        throw AppException(
          message: 'Invalid teacher access code',
          code: 'invalid_teacher_code',
        );
      }
      return;
    }

    final fallbackCode = _teacherInviteCode.trim();
    if (fallbackCode.isNotEmpty) {
      if (rawCode.trim() != fallbackCode) {
        throw AppException(
          message: 'Invalid teacher access code',
          code: 'invalid_teacher_code',
        );
      }
      return;
    }

    throw AppException(
      message: 'Teacher access code flow is not configured. Contact admin.',
      code: 'teacher_code_not_configured',
    );
  }

  Future<String?> _uploadUserImage({
    required String uid,
    required PlatformFile? file,
    required String folder,
  }) async {
    if (file == null) {
      return null;
    }

    final bytes = file.bytes;
    if (bytes == null || bytes.isEmpty) {
      throw const AppException(
        message: 'Unable to read selected image. Please choose again.',
      );
    }

    final extension = _fileExtension(file.name);
    final ref = _storage
        .ref()
        .child('users')
        .child(uid)
        .child(folder)
        .child('${DateTime.now().millisecondsSinceEpoch}.$extension');

    await ref.putData(
      bytes,
      SettableMetadata(contentType: _contentType(extension)),
    );

    return ref.fullPath;
  }

  String _fileExtension(String fileName) {
    final split = fileName.split('.');
    if (split.length < 2) {
      return 'jpg';
    }
    return split.last.toLowerCase();
  }

  String _contentType(String extension) {
    switch (extension) {
      case 'png':
        return 'image/png';
      case 'webp':
        return 'image/webp';
      case 'heic':
        return 'image/heic';
      case 'jpeg':
      case 'jpg':
      default:
        return 'image/jpeg';
    }
  }
}
