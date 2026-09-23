import 'package:cloud_firestore/cloud_firestore.dart';

class UserModel {
  const UserModel({
    required this.uid,
    required this.name,
    required this.email,
    required this.role,
    required this.collegeId,
    required this.collegeName,
    required this.affiliatedUniversityName,
    required this.course,
    this.branch = '',
    this.semester,
    this.collegeIdCardPhotoUrl,
    this.profileLinks = const <String, String>{},
    this.batchYear,
    this.customBio,
    this.currentCompany,
    this.currentRole,
    this.openToRefer = false,
    this.skills = const <String>[],
    this.referralsGiven = 0,
    this.questionsAnswered = 0,
    this.avgRating = 0,
    this.totalRatings = 0,
    this.linkedinUrl,
    this.fcmToken,
    this.teacherRequestStatus = 'none',
    this.requestedRole = '',
    this.isApproved = false,
    this.approvalMessageShown = false,
    this.teacherRequestMessageShown = false,
    this.isVerified = false,
    this.isBanned = false,
    this.canUploadNotesPyqs = true,
    this.isOnline = false,
    this.activeChatId,
    required this.createdAt,
    this.photoUrl,
  }) : premiumStatus = true;

  final String uid;
  final String name;
  final String email;
  final String role;
  final String collegeId;
  final String collegeName;
  final String affiliatedUniversityName;
  final String course;
  final String branch;
  final int? semester;
  final String? collegeIdCardPhotoUrl;
  final Map<String, String> profileLinks;
  final int? batchYear;
  final String? customBio;
  final String? currentCompany;
  final String? currentRole;
  final bool openToRefer;
  final List<String> skills;
  final int referralsGiven;
  final int questionsAnswered;
  final double avgRating;
  final int totalRatings;
  final String? linkedinUrl;
  final String? fcmToken;
  final String requestedRole;
  final bool isApproved;
  final bool approvalMessageShown;
  final bool teacherRequestMessageShown;
  final String teacherRequestStatus;
  final bool isVerified;
  final bool isBanned;
  final bool canUploadNotesPyqs;
  final bool premiumStatus;
  final bool? isOnline;
  final String? activeChatId;
  final DateTime createdAt;
  final String? photoUrl;

  factory UserModel.fromMap(Map<String, dynamic> map, String uid) {
    return UserModel(
      uid: uid,
      name: (map['name'] as String? ?? '').trim(),
      email: (map['email'] as String? ?? '').trim(),
      role: (map['role'] as String? ?? 'student').trim().toLowerCase(),
      collegeId: (map['collegeId'] as String? ?? '').trim(),
      collegeName: (map['collegeName'] as String? ?? '').trim(),
      affiliatedUniversityName:
          (map['affiliatedUniversityName'] as String? ?? '').trim(),
      course: (map['course'] as String? ?? '').trim(),
      branch: (map['branch'] as String? ?? map['department'] as String? ?? '')
          .trim(),
      semester: _toInt(map['semester']),
      collegeIdCardPhotoUrl:
          (map['collegeIdCardStoragePath'] ?? map['collegeIdCardPhotoUrl'])
              as String?,
      profileLinks: _toStringMap(map['profileLinks']),
      batchYear: _toInt(map['batchYear']),
      customBio: map['customBio'] as String?,
      currentCompany: map['currentCompany'] as String?,
      currentRole: map['currentRole'] as String?,
      openToRefer: map['openToRefer'] as bool? ?? false,
      skills: _toStringList(map['skills']),
      referralsGiven: _toInt(map['referralsGiven']) ?? 0,
      questionsAnswered: _toInt(map['questionsAnswered']) ?? 0,
      avgRating: _toDouble(map['avgRating']) ?? 0,
      totalRatings: _toInt(map['totalRatings']) ?? 0,
      linkedinUrl: map['linkedinUrl'] as String?,
      photoUrl: (map['photoStoragePath'] ?? map['photoUrl']) as String?,
      fcmToken: map['fcmToken'] as String?,
      teacherRequestStatus: (map['teacherRequestStatus'] as String? ?? 'none')
          .trim()
          .toLowerCase(),
      requestedRole: (map['requestedRole'] as String? ?? '')
          .trim()
          .toLowerCase(),
      isApproved: map['isApproved'] as bool? ?? false,
      approvalMessageShown: map['approvalMessageShown'] as bool? ?? false,
      teacherRequestMessageShown:
          map['teacherRequestMessageShown'] as bool? ?? false,
      isVerified: map['isVerified'] as bool? ?? false,
      isBanned: map['isBanned'] as bool? ?? false,
      canUploadNotesPyqs: map['canUploadNotesPyqs'] as bool? ?? true,
      isOnline: map['isOnline'] as bool? ?? false,
      activeChatId: (map['activeChatId'] as String?)?.toString(),
      createdAt: _toDateTime(map['createdAt']),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'uid': uid,
      'name': name,
      'email': email,
      'role': role,
      'collegeId': collegeId,
      'collegeName': collegeName,
      'affiliatedUniversityName': affiliatedUniversityName,
      'course': course,
      'branch': branch,
      'semester': semester,
      'collegeIdCardPhotoUrl': collegeIdCardPhotoUrl,
      'collegeIdCardStoragePath': collegeIdCardPhotoUrl,
      'profileLinks': profileLinks,
      'batchYear': batchYear,
      'customBio': customBio,
      'currentCompany': currentCompany,
      'currentRole': currentRole,
      'openToRefer': openToRefer,
      'skills': skills,
      'referralsGiven': referralsGiven,
      'questionsAnswered': questionsAnswered,
      'avgRating': avgRating,
      'totalRatings': totalRatings,
      'linkedinUrl': linkedinUrl,
      'isVerified': isVerified,
      'isBanned': isBanned,
      'premiumStatus': true,
      'photoUrl': photoUrl,
      'photoStoragePath': photoUrl,
      'fcmToken': fcmToken,
      'isOnline': isOnline,
      'activeChatId': activeChatId,
      'teacherRequestStatus': teacherRequestStatus,
      'requestedRole': requestedRole,
      'isApproved': isApproved,
      'approvalMessageShown': approvalMessageShown,
      'teacherRequestMessageShown': teacherRequestMessageShown,
      'createdAt': Timestamp.fromDate(createdAt),
      'canUploadNotesPyqs': canUploadNotesPyqs,
    };
  }

  UserModel copyWith({
    String? uid,
    String? name,
    String? email,
    String? role,
    String? collegeId,
    String? collegeName,
    String? affiliatedUniversityName,
    String? course,
    String? branch,
    int? semester,
    String? collegeIdCardPhotoUrl,
    Map<String, String>? profileLinks,
    int? batchYear,
    String? customBio,
    String? currentCompany,
    String? currentRole,
    bool? openToRefer,
    List<String>? skills,
    int? referralsGiven,
    int? questionsAnswered,
    double? avgRating,
    int? totalRatings,
    String? linkedinUrl,
    String? photoUrl,
    String? fcmToken,
    bool? isOnline,
    String? activeChatId,
    String? teacherRequestStatus,
    String? requestedRole,
    bool? isApproved,
    bool? approvalMessageShown,
    bool? teacherRequestMessageShown,
    bool? isVerified,
    bool? isBanned,
    bool? canUploadNotesPyqs,
    DateTime? createdAt,
  }) {
    return UserModel(
      uid: uid ?? this.uid,
      name: name ?? this.name,
      email: email ?? this.email,
      role: role ?? this.role,
      collegeId: collegeId ?? this.collegeId,
      collegeName: collegeName ?? this.collegeName,
      affiliatedUniversityName:
          affiliatedUniversityName ?? this.affiliatedUniversityName,
      course: course ?? this.course,
      branch: branch ?? this.branch,
      semester: semester ?? this.semester,
      collegeIdCardPhotoUrl:
          collegeIdCardPhotoUrl ?? this.collegeIdCardPhotoUrl,
      profileLinks: profileLinks ?? this.profileLinks,
      batchYear: batchYear ?? this.batchYear,
      customBio: customBio ?? this.customBio,
      currentCompany: currentCompany ?? this.currentCompany,
      currentRole: currentRole ?? this.currentRole,
      openToRefer: openToRefer ?? this.openToRefer,
      skills: skills ?? this.skills,
      referralsGiven: referralsGiven ?? this.referralsGiven,
      questionsAnswered: questionsAnswered ?? this.questionsAnswered,
      avgRating: avgRating ?? this.avgRating,
      totalRatings: totalRatings ?? this.totalRatings,
      linkedinUrl: linkedinUrl ?? this.linkedinUrl,
      photoUrl: photoUrl ?? this.photoUrl,
      fcmToken: fcmToken ?? this.fcmToken,
      isOnline: isOnline ?? this.isOnline,
      activeChatId: activeChatId ?? this.activeChatId,
      teacherRequestStatus: teacherRequestStatus ?? this.teacherRequestStatus,
      requestedRole: requestedRole ?? this.requestedRole,
      isApproved: isApproved ?? this.isApproved,
      approvalMessageShown: approvalMessageShown ?? this.approvalMessageShown,
      teacherRequestMessageShown:
          teacherRequestMessageShown ?? this.teacherRequestMessageShown,
      isVerified: isVerified ?? this.isVerified,
      isBanned: isBanned ?? this.isBanned,
      canUploadNotesPyqs: canUploadNotesPyqs ?? this.canUploadNotesPyqs,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  static int? _toInt(dynamic value) {
    if (value is int) {
      return value;
    }
    if (value is String) {
      return int.tryParse(value);
    }
    return null;
  }

  static DateTime _toDateTime(dynamic value) {
    if (value is Timestamp) {
      return value.toDate();
    }
    if (value is DateTime) {
      return value;
    }
    return DateTime.now();
  }

  static double? _toDouble(dynamic value) {
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

  static List<String> _toStringList(dynamic value) {
    if (value is List) {
      return value
          .map((item) => item.toString().trim())
          .where((item) => item.isNotEmpty)
          .toList();
    }
    return const <String>[];
  }

  static Map<String, String> _toStringMap(dynamic value) {
    if (value is Map) {
      return value.map(
        (key, mapValue) => MapEntry(key.toString(), mapValue.toString()),
      );
    }
    return const <String, String>{};
  }
}
