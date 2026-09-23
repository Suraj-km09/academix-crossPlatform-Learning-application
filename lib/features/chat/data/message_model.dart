import 'package:cloud_firestore/cloud_firestore.dart';

class MessageModel {
  const MessageModel({
    required this.messageId,
    required this.senderId,
    required this.senderName,
    required this.content,
    required this.type,
    required this.timestamp,
    required this.readBy,
    required this.isDeleted,
    this.fileUrl,
    this.fileName,
    this.replyTo,
    this.replyToContent,
  });

  final String messageId;
  final String senderId;
  final String senderName;
  final String content;
  final String type;
  final String? fileUrl;
  final String? fileName;
  final DateTime timestamp;
  final List<String> readBy;
  final String? replyTo;
  final String? replyToContent;
  final bool isDeleted;

  bool get isText => type == 'text';
  bool get isImage => type == 'image';
  bool get isFile => type == 'file';

  factory MessageModel.fromMap(Map<String, dynamic> map, String id) {
    return MessageModel(
      messageId: (map['messageId'] as String? ?? id).trim(),
      senderId: (map['senderId'] as String? ?? '').trim(),
      senderName: (map['senderName'] as String? ?? '').trim(),
      content: (map['content'] as String? ?? '').trim(),
      type: (map['type'] as String? ?? 'text').trim().toLowerCase(),
      fileUrl: (map['fileUrl'] as String?)?.trim(),
      fileName: (map['fileName'] as String?)?.trim(),
      timestamp: _toDateTime(map['timestamp']),
      readBy: _toStringList(map['readBy']),
      replyTo: (map['replyTo'] as String?)?.trim(),
      replyToContent: (map['replyToContent'] as String?)?.trim(),
      isDeleted: map['isDeleted'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'messageId': messageId,
      'senderId': senderId,
      'senderName': senderName,
      'content': content,
      'type': type,
      'fileUrl': fileUrl,
      'fileName': fileName,
      'timestamp': Timestamp.fromDate(timestamp),
      'readBy': readBy,
      'replyTo': replyTo,
      'replyToContent': replyToContent,
      'isDeleted': isDeleted,
    };
  }

  MessageModel copyWith({
    String? messageId,
    String? senderId,
    String? senderName,
    String? content,
    String? type,
    String? fileUrl,
    String? fileName,
    DateTime? timestamp,
    List<String>? readBy,
    String? replyTo,
    String? replyToContent,
    bool? isDeleted,
  }) {
    return MessageModel(
      messageId: messageId ?? this.messageId,
      senderId: senderId ?? this.senderId,
      senderName: senderName ?? this.senderName,
      content: content ?? this.content,
      type: type ?? this.type,
      fileUrl: fileUrl ?? this.fileUrl,
      fileName: fileName ?? this.fileName,
      timestamp: timestamp ?? this.timestamp,
      readBy: readBy ?? this.readBy,
      replyTo: replyTo ?? this.replyTo,
      replyToContent: replyToContent ?? this.replyToContent,
      isDeleted: isDeleted ?? this.isDeleted,
    );
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
    return const <String>[];
  }
}
