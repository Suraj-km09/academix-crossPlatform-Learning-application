import 'package:cloud_firestore/cloud_firestore.dart';

class NoteModel {
  const NoteModel({
    required this.noteId,
    required this.fileHash,
    required this.title,
    required this.subject,
    required this.course,
    required this.branch,
    required this.semester,
    required this.year,
    required this.section,
    required this.tags,
    required this.fileUrl,
    required this.fileName,
    required this.fileSize,
    required this.type,
    this.pyqYear,
    required this.collegeId,
    required this.uploadedBy,
    required this.uploaderName,
    required this.isVerified,
    this.verifiedBy,
    required this.downloadCount,
    required this.uploadedAt,
    required this.isRejected,
    this.rejectionReason,
  });

  final String noteId;
  final String fileHash;
  final String title;
  final String subject;
  final String course;
  final String branch;
  final String semester;
  final String year;
  final String section;
  final List<String> tags;
  final String fileUrl;
  final String fileName;
  final int fileSize;
  final String type;
  final int? pyqYear;
  final String collegeId;
  final String uploadedBy;
  final String uploaderName;
  final bool isVerified;
  final String? verifiedBy;
  final int downloadCount;
  final DateTime uploadedAt;
  final bool isRejected;
  final String? rejectionReason;

  factory NoteModel.fromMap(Map<String, dynamic> map, String noteId) {
    return NoteModel(
      noteId: (map['noteId'] as String? ?? noteId).trim(),
      fileHash: (map['fileHash'] as String? ?? '').trim(),
      title: (map['title'] as String? ?? '').trim(),
      subject: (map['subject'] as String? ?? '').trim(),
      course: (map['course'] as String? ?? '').trim(),
      branch: (map['branch'] as String? ?? '').trim(),
      semester: (map['semester'] as String? ?? '').trim(),
      year: (map['year'] as String? ?? '').trim(),
      section: (map['section'] as String? ?? 'notes').trim().toLowerCase(),
      tags: _toStringList(map['tags']),
      fileUrl: (map['fileUrl'] as String? ?? '').trim(),
      fileName: (map['fileName'] as String? ?? '').trim(),
      fileSize: _toInt(map['fileSize']) ?? 0,
      type: (map['type'] as String? ?? 'notes').trim().toLowerCase(),
      pyqYear: _toInt(map['pyqYear']),
      collegeId: (map['collegeId'] as String? ?? '').trim(),
      uploadedBy: (map['uploadedBy'] as String? ?? '').trim(),
      uploaderName: (map['uploaderName'] as String? ?? '').trim(),
      isVerified: map['isVerified'] as bool? ?? false,
      verifiedBy: map['verifiedBy'] as String?,
      downloadCount: _toInt(map['downloadCount']) ?? 0,
      uploadedAt: _toDateTime(map['uploadedAt']),
      isRejected: map['isRejected'] as bool? ?? false,
      rejectionReason: map['rejectionReason'] as String?,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'noteId': noteId,
      'fileHash': fileHash,
      'title': title,
      'subject': subject,
      'course': course,
      'branch': branch,
      'semester': semester,
      'year': year,
      'section': section,
      'tags': tags,
      'fileUrl': fileUrl,
      'fileName': fileName,
      'fileSize': fileSize,
      'type': type,
      'pyqYear': pyqYear,
      'collegeId': collegeId,
      'uploadedBy': uploadedBy,
      'uploaderName': uploaderName,
      'isVerified': isVerified,
      'verifiedBy': verifiedBy,
      'downloadCount': downloadCount,
      'uploadedAt': Timestamp.fromDate(uploadedAt),
      'isRejected': isRejected,
      'rejectionReason': rejectionReason,
    };
  }

  NoteModel copyWith({
    String? noteId,
    String? fileHash,
    String? title,
    String? subject,
    String? course,
    String? branch,
    String? semester,
    String? year,
    String? section,
    List<String>? tags,
    String? fileUrl,
    String? fileName,
    int? fileSize,
    String? type,
    int? pyqYear,
    String? collegeId,
    String? uploadedBy,
    String? uploaderName,
    bool? isVerified,
    String? verifiedBy,
    int? downloadCount,
    DateTime? uploadedAt,
    bool? isRejected,
    String? rejectionReason,
  }) {
    return NoteModel(
      noteId: noteId ?? this.noteId,
      fileHash: fileHash ?? this.fileHash,
      title: title ?? this.title,
      subject: subject ?? this.subject,
      course: course ?? this.course,
      branch: branch ?? this.branch,
      semester: semester ?? this.semester,
      year: year ?? this.year,
      section: section ?? this.section,
      tags: tags ?? this.tags,
      fileUrl: fileUrl ?? this.fileUrl,
      fileName: fileName ?? this.fileName,
      fileSize: fileSize ?? this.fileSize,
      type: type ?? this.type,
      pyqYear: pyqYear ?? this.pyqYear,
      collegeId: collegeId ?? this.collegeId,
      uploadedBy: uploadedBy ?? this.uploadedBy,
      uploaderName: uploaderName ?? this.uploaderName,
      isVerified: isVerified ?? this.isVerified,
      verifiedBy: verifiedBy ?? this.verifiedBy,
      downloadCount: downloadCount ?? this.downloadCount,
      uploadedAt: uploadedAt ?? this.uploadedAt,
      isRejected: isRejected ?? this.isRejected,
      rejectionReason: rejectionReason ?? this.rejectionReason,
    );
  }

  static List<String> _toStringList(dynamic value) {
    if (value is List) {
      return value
          .map((item) => item.toString().trim())
          .where((item) => item.isNotEmpty)
          .toList();
    }
    return <String>[];
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
}
