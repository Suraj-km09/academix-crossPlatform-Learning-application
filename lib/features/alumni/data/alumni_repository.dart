import 'dart:io';
import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:file_picker/file_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';

import '../../../core/constants/firestore_paths.dart';
import '../../../core/constants/storage_bucket_config.dart';
import '../../../core/errors/app_exception.dart';
import '../../../shared/models/user_model.dart';
import '../../../shared/services/write_rate_limiter.dart';
import 'alumni_qa_model.dart';
import 'referral_request_model.dart';

class AlumniRepository {
  AlumniRepository({FirebaseFirestore? firestore, FirebaseStorage? storage})
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

  static const int _minCompressionSizeBytes = 128 * 1024;
  static const double _compressionSavingsThreshold = 0.98;
  static const int _referralRequestsPerHourStudent = 5;
  static const int _referralRequestsPerHourAlumni = 8;
  static const int _referralRequestsPerHourTeacher = 12;
  static const int _referralRequestsPerHourAdmin = 20;

  Stream<List<UserModel>> getAlumni(String collegeId) {
    return _firestore
        .collection(FirestorePaths.users)
        .where('role', isEqualTo: 'alumni')
        .where('collegeId', isEqualTo: collegeId)
        .snapshots()
        .map(
          (snapshot) =>
              snapshot.docs
                  .map((doc) => UserModel.fromMap(doc.data(), doc.id))
                  .toList()
                ..sort(
                  (a, b) =>
                      a.name.toLowerCase().compareTo(b.name.toLowerCase()),
                ),
        );
  }

  Future<List<UserModel>> searchAlumni(
    String collegeId, {
    String? company,
    String? role,
    int? batchYear,
    bool? openToRefer,
  }) async {
    final alumni = await getAlumni(collegeId).first;

    return alumni.where((item) {
      if (company != null && company.trim().isNotEmpty) {
        final ok =
            item.currentCompany?.toLowerCase().contains(
              company.trim().toLowerCase(),
            ) ??
            false;
        if (!ok) {
          return false;
        }
      }

      if (role != null && role.trim().isNotEmpty) {
        final ok =
            item.currentRole?.toLowerCase().contains(
              role.trim().toLowerCase(),
            ) ??
            false;
        if (!ok) {
          return false;
        }
      }

      if (batchYear != null && item.batchYear != batchYear) {
        return false;
      }

      if (openToRefer != null && item.openToRefer != openToRefer) {
        return false;
      }

      return true;
    }).toList();
  }

  Future<void> sendReferralRequest(
    String studentUid,
    String alumniUid,
    String targetCompany,
    String targetRole,
    String message,
    PlatformFile resumeFile, {
    void Function(double progress)? onProgress,
  }) async {
    if (!_isPdf(resumeFile)) {
      throw const AppException(message: 'Resume must be a PDF file');
    }

    final studentDoc = await _firestore
        .collection(FirestorePaths.users)
        .doc(studentUid)
        .get();

    final studentData = studentDoc.data();
    if (studentData == null) {
      throw const AppException(message: 'Unable to load user profiles');
    }

    final requesterRole = (studentData['role'] as String? ?? '')
        .trim()
        .toLowerCase();

    await _rateLimiter.enforce(
      uid: studentUid,
      action: 'alumni_referral_request',
      maxRequests: _referralRequestsPerHourForRole(requesterRole),
      window: const Duration(hours: 1),
      messagePrefix: 'Referral request limit reached',
    );

    final requestRef = _firestore.collection(FirestorePaths.referrals).doc();
    final requestId = requestRef.id;
    final alumniDoc = await _firestore
        .collection(FirestorePaths.users)
        .doc(alumniUid)
        .get();

    final alumniData = alumniDoc.data();

    if (alumniData == null) {
      throw const AppException(message: 'Unable to load user profiles');
    }

    final resumeRef = _storage
        .ref()
        .child('referrals')
        .child(requestId)
        .child('resume.pdf');

    final resumeBytes = await _readFileBytes(resumeFile);
    final uploadPayload = _preparePdfUploadPayload(resumeBytes);

    final uploadTask = _uploadPdf(resumeRef, uploadPayload);
    final subscription = uploadTask.snapshotEvents.listen((snapshot) {
      final total = snapshot.totalBytes;
      if (total <= 0) {
        return;
      }
      final progress = snapshot.bytesTransferred / total;
      onProgress?.call(progress.clamp(0, 1));
    });

    try {
      await uploadTask;
      await subscription.cancel();

      final resumeUrl = await resumeRef.getDownloadURL();
      final now = DateTime.now();

      final referral = ReferralRequestModel(
        requestId: requestId,
        studentUid: studentUid,
        studentName: (studentData['name'] as String? ?? '').trim(),
        alumniUid: alumniUid,
        alumniName: (alumniData['name'] as String? ?? '').trim(),
        targetCompany: targetCompany.trim(),
        targetRole: targetRole.trim(),
        message: message.trim(),
        resumeUrl: resumeUrl,
        status: 'pending',
        createdAt: now,
        updatedAt: now,
        chatId: null,
      );

      await requestRef.set(referral.toMap());
    } catch (error) {
      await subscription.cancel();
      rethrow;
    }
  }

  Future<void> acceptReferral(String requestId, String alumniUid) async {
    final referralRef = _firestore
        .collection(FirestorePaths.referrals)
        .doc(requestId);
    final referralDoc = await referralRef.get();
    final data = referralDoc.data();

    if (!referralDoc.exists || data == null) {
      throw const AppException(message: 'Referral request not found');
    }

    final referral = ReferralRequestModel.fromMap(data, referralDoc.id);
    if (referral.alumniUid != alumniUid) {
      throw const AppException(message: 'Unauthorized referral action');
    }

    final studentDoc = await _firestore
        .collection(FirestorePaths.users)
        .doc(referral.studentUid)
        .get();
    final studentData = studentDoc.data() ?? <String, dynamic>{};
    final collegeId = (studentData['collegeId'] as String? ?? '').trim();

    final now = DateTime.now();
    final chatRef = _firestore.collection(FirestorePaths.chats).doc();

    await _firestore.runTransaction((transaction) async {
      transaction.set(chatRef, {
        'chatId': chatRef.id,
        'type': 'referral',
        'participants': [referral.studentUid, referral.alumniUid],
        'collegeId': collegeId,
        'groupName': null,
        'groupAdminUid': null,
        'lastMessage': '',
        'lastMessageAt': Timestamp.fromDate(now),
        'createdAt': Timestamp.fromDate(now),
        'referralId': requestId,
        'typingUids': <String>[],
      });

      transaction.set(referralRef, {
        'status': 'accepted',
        'chatId': chatRef.id,
        'updatedAt': Timestamp.fromDate(now),
      }, SetOptions(merge: true));
    });
  }

  Future<void> rejectReferral(String requestId, String reason) async {
    final referralRef = _firestore
        .collection(FirestorePaths.referrals)
        .doc(requestId);
    final referralDoc = await referralRef.get();
    final data = referralDoc.data();

    if (!referralDoc.exists || data == null) {
      throw const AppException(message: 'Referral request not found');
    }

    await referralRef.set({
      'status': 'rejected',
      'rejectionReason': reason.trim(),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Stream<List<ReferralRequestModel>> getReferralRequests(String alumniUid) {
    return _firestore
        .collection(FirestorePaths.referrals)
        .where('alumniUid', isEqualTo: alumniUid)
        .where('status', isEqualTo: 'pending')
        .snapshots()
        .map(
          (snapshot) =>
              snapshot.docs
                  .map(
                    (doc) => ReferralRequestModel.fromMap(doc.data(), doc.id),
                  )
                  .toList()
                ..sort((a, b) => b.createdAt.compareTo(a.createdAt)),
        );
  }

  Stream<List<ReferralRequestModel>> getStudentReferrals(String studentUid) {
    return _firestore
        .collection(FirestorePaths.referrals)
        .where('studentUid', isEqualTo: studentUid)
        .snapshots()
        .map(
          (snapshot) =>
              snapshot.docs
                  .map(
                    (doc) => ReferralRequestModel.fromMap(doc.data(), doc.id),
                  )
                  .toList()
                ..sort((a, b) => b.createdAt.compareTo(a.createdAt)),
        );
  }

  Stream<List<ReferralRequestModel>> getAlumniReferrals(String alumniUid) {
    return _firestore
        .collection(FirestorePaths.referrals)
        .where('alumniUid', isEqualTo: alumniUid)
        .snapshots()
        .map(
          (snapshot) =>
              snapshot.docs
                  .map(
                    (doc) => ReferralRequestModel.fromMap(doc.data(), doc.id),
                  )
                  .toList()
                ..sort((a, b) => b.createdAt.compareTo(a.createdAt)),
        );
  }

  Future<void> askAlumni(
    String studentUid,
    String alumniUid,
    String question,
    String collegeId,
  ) async {
    final threadRef = _firestore.collection(FirestorePaths.alumniQa).doc();
    final now = DateTime.now();

    await threadRef.set({
      'threadId': threadRef.id,
      'studentUid': studentUid,
      'alumniUid': alumniUid,
      'question': question.trim(),
      'answer': '',
      'isPublic': false,
      'createdAt': Timestamp.fromDate(now),
      'answeredAt': null,
      'collegeId': collegeId,
    });
  }

  Future<void> answerQuestion(
    String threadId,
    String answer,
    bool isPublic,
  ) async {
    final threadRef = _firestore
        .collection(FirestorePaths.alumniQa)
        .doc(threadId);
    final threadDoc = await threadRef.get();
    final data = threadDoc.data();

    if (!threadDoc.exists || data == null) {
      throw const AppException(message: 'Question thread not found');
    }

    final thread = AlumniQAModel.fromMap(data, threadDoc.id);

    await _firestore.runTransaction((transaction) async {
      transaction.set(threadRef, {
        'answer': answer.trim(),
        'isPublic': isPublic,
        'answeredAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      final alumniRef = _firestore
          .collection(FirestorePaths.users)
          .doc(thread.alumniUid);
      transaction.set(alumniRef, {
        'questionsAnswered': FieldValue.increment(1),
      }, SetOptions(merge: true));
    });
  }

  Stream<List<AlumniQAModel>> getPublicQA(String collegeId) {
    return _firestore
        .collection(FirestorePaths.alumniQa)
        .where('collegeId', isEqualTo: collegeId)
        .where('isPublic', isEqualTo: true)
        .snapshots()
        .map(
          (snapshot) =>
              snapshot.docs
                  .map((doc) => AlumniQAModel.fromMap(doc.data(), doc.id))
                  .where((item) => item.answer.trim().isNotEmpty)
                  .toList()
                ..sort((a, b) => b.createdAt.compareTo(a.createdAt)),
        );
  }

  Stream<List<AlumniQAModel>> getAlumniUnansweredQuestions(String alumniUid) {
    return _firestore
        .collection(FirestorePaths.alumniQa)
        .where('alumniUid', isEqualTo: alumniUid)
        .snapshots()
        .map(
          (snapshot) =>
              snapshot.docs
                  .map((doc) => AlumniQAModel.fromMap(doc.data(), doc.id))
                  .where((item) => item.answer.trim().isEmpty)
                  .toList()
                ..sort((a, b) => b.createdAt.compareTo(a.createdAt)),
        );
  }

  Future<void> rateAlumni(
    String raterUid,
    String alumniUid,
    String referralId,
    int rating,
    String comment,
  ) async {
    if (rating < 1 || rating > 5) {
      throw const AppException(message: 'Rating should be between 1 and 5');
    }

    final ratingRef = _firestore.collection(FirestorePaths.alumniRatings).doc();

    await _firestore.runTransaction((transaction) async {
      final alumniRef = _firestore
          .collection(FirestorePaths.users)
          .doc(alumniUid);
      final alumniDoc = await transaction.get(alumniRef);
      final alumniData = alumniDoc.data() ?? <String, dynamic>{};

      final currentTotal = _toInt(alumniData['totalRatings']) ?? 0;
      final currentAvg = _toDouble(alumniData['avgRating']) ?? 0;

      final totalScore = currentAvg * currentTotal;
      final updatedTotal = currentTotal + 1;
      final updatedAvg = (totalScore + rating) / updatedTotal;

      transaction.set(ratingRef, {
        'raterUid': raterUid,
        'alumniUid': alumniUid,
        'referralId': referralId,
        'rating': rating,
        'comment': comment.trim(),
        'createdAt': FieldValue.serverTimestamp(),
      });

      transaction.set(alumniRef, {
        'avgRating': updatedAvg,
        'totalRatings': updatedTotal,
      }, SetOptions(merge: true));
    });
  }

  Stream<List<ReferralRequestModel>> getCompletedReferralsBetween(
    String studentUid,
    String alumniUid,
  ) {
    return _firestore
        .collection(FirestorePaths.referrals)
        .where('studentUid', isEqualTo: studentUid)
        .where('alumniUid', isEqualTo: alumniUid)
        .where('status', isEqualTo: 'completed')
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => ReferralRequestModel.fromMap(doc.data(), doc.id))
              .toList(),
        );
  }

  int _referralRequestsPerHourForRole(String normalizedRole) {
    switch (normalizedRole) {
      case 'admin':
        return _referralRequestsPerHourAdmin;
      case 'teacher':
        return _referralRequestsPerHourTeacher;
      case 'alumni':
        return _referralRequestsPerHourAlumni;
      default:
        return _referralRequestsPerHourStudent;
    }
  }

  Future<UserModel?> getUserById(String uid) async {
    final doc = await _firestore
        .collection(FirestorePaths.users)
        .doc(uid)
        .get();
    final data = doc.data();
    if (!doc.exists || data == null) {
      return null;
    }
    return UserModel.fromMap(data, doc.id);
  }

  UploadTask _uploadPdf(Reference ref, _PreparedPdfUpload payload) {
    final metadata = SettableMetadata(
      contentType: 'application/pdf',
      contentEncoding: payload.isCompressed ? 'gzip' : null,
      customMetadata: {
        'storageCompression': payload.isCompressed ? 'gzip' : 'none',
        'originalBytes': payload.originalSize.toString(),
        'storedBytes': payload.bytes.length.toString(),
      },
    );

    return ref.putData(payload.bytes, metadata);
  }

  bool _isPdf(PlatformFile file) {
    final ext = (file.extension ?? '').toLowerCase();
    if (ext == 'pdf') {
      return true;
    }
    return file.name.toLowerCase().endsWith('.pdf');
  }

  Future<Uint8List> _readFileBytes(PlatformFile file) async {
    if (file.bytes != null && file.bytes!.isNotEmpty) {
      return file.bytes!;
    }

    final path = file.path;
    if (path == null || path.trim().isEmpty) {
      throw const AppException(message: 'Selected file is invalid');
    }

    final localFile = File(path);
    if (!await localFile.exists()) {
      throw const AppException(message: 'Selected file does not exist');
    }

    return localFile.readAsBytes();
  }

  _PreparedPdfUpload _preparePdfUploadPayload(Uint8List sourceBytes) {
    if (sourceBytes.length < _minCompressionSizeBytes) {
      return _PreparedPdfUpload(
        bytes: sourceBytes,
        isCompressed: false,
        originalSize: sourceBytes.length,
      );
    }

    final compressedBytes = Uint8List.fromList(gzip.encode(sourceBytes));
    final shouldUseCompressed =
        compressedBytes.length <
        (sourceBytes.length * _compressionSavingsThreshold).round();

    if (!shouldUseCompressed) {
      return _PreparedPdfUpload(
        bytes: sourceBytes,
        isCompressed: false,
        originalSize: sourceBytes.length,
      );
    }

    return _PreparedPdfUpload(
      bytes: compressedBytes,
      isCompressed: true,
      originalSize: sourceBytes.length,
    );
  }

  int? _toInt(dynamic value) {
    if (value is int) {
      return value;
    }
    if (value is String) {
      return int.tryParse(value);
    }
    return null;
  }

  double? _toDouble(dynamic value) {
    if (value is double) {
      return value;
    }
    if (value is int) {
      return value.toDouble();
    }
    if (value is String) {
      return double.tryParse(value);
    }
    return null;
  }
}

class _PreparedPdfUpload {
  const _PreparedPdfUpload({
    required this.bytes,
    required this.isCompressed,
    required this.originalSize,
  });

  final Uint8List bytes;
  final bool isCompressed;
  final int originalSize;
}
