import 'package:cloud_firestore/cloud_firestore.dart';

class LockerFileModel {
  const LockerFileModel({
    required this.fileId,
    required this.fileName,
    required this.fileUrl,
    required this.fileSize,
    required this.tags,
    required this.uploadedAt,
    required this.isOfflineCached,
    this.localPath,
  });

  final String fileId;
  final String fileName;
  final String fileUrl;
  final int fileSize;
  final List<String> tags;
  final DateTime uploadedAt;
  final bool isOfflineCached;
  final String? localPath;

  factory LockerFileModel.fromMap(Map<String, dynamic> map, String id) {
    return LockerFileModel(
      fileId: (map['fileId'] as String? ?? id).trim(),
      fileName: (map['fileName'] as String? ?? '').trim(),
      fileUrl: (map['fileUrl'] as String? ?? '').trim(),
      fileSize: _toInt(map['fileSize']) ?? 0,
      tags: _toStringList(map['tags']),
      uploadedAt: _toDateTime(map['uploadedAt']),
      isOfflineCached: map['isOfflineCached'] as bool? ?? false,
      localPath: (map['localPath'] as String?)?.trim(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'fileId': fileId,
      'fileName': fileName,
      'fileUrl': fileUrl,
      'fileSize': fileSize,
      'tags': tags,
      'uploadedAt': Timestamp.fromDate(uploadedAt),
      'isOfflineCached': isOfflineCached,
      'localPath': localPath,
    };
  }

  LockerFileModel copyWith({
    String? fileId,
    String? fileName,
    String? fileUrl,
    int? fileSize,
    List<String>? tags,
    DateTime? uploadedAt,
    bool? isOfflineCached,
    String? localPath,
  }) {
    return LockerFileModel(
      fileId: fileId ?? this.fileId,
      fileName: fileName ?? this.fileName,
      fileUrl: fileUrl ?? this.fileUrl,
      fileSize: fileSize ?? this.fileSize,
      tags: tags ?? this.tags,
      uploadedAt: uploadedAt ?? this.uploadedAt,
      isOfflineCached: isOfflineCached ?? this.isOfflineCached,
      localPath: localPath ?? this.localPath,
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

  static List<String> _toStringList(dynamic value) {
    if (value is List) {
      return value
          .map((item) => item.toString().trim())
          .where((item) => item.isNotEmpty)
          .toList();
    }
    return <String>[];
  }
}
