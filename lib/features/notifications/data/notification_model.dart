import 'package:cloud_firestore/cloud_firestore.dart';

class NotificationModel {
  const NotificationModel({
    required this.notifId,
    required this.recipientUid,
    required this.title,
    required this.body,
    required this.type,
    required this.targetRoute,
    required this.isRead,
    required this.createdAt,
    required this.data,
  });

  final String notifId;
  final String recipientUid;
  final String title;
  final String body;
  final String type;
  final String targetRoute;
  final bool isRead;
  final DateTime createdAt;
  final Map<String, dynamic> data;

  factory NotificationModel.fromMap(Map<String, dynamic> map, String id) {
    final payloadMap = _toMap(map['data'] ?? map['payload']);
    final routeFromData =
        (payloadMap['targetRoute'] ?? payloadMap['route'] ?? '')
            .toString()
            .trim();

    return NotificationModel(
      notifId:
          (map['notifId'] as String? ?? map['notificationId'] as String? ?? id)
              .trim(),
      recipientUid:
          (map['recipientUid'] as String? ?? map['targetUid'] as String? ?? '')
              .trim(),
      title: (map['title'] as String? ?? '').trim(),
      body: (map['body'] as String? ?? '').trim(),
      type: _normalizedType(
        (map['type'] as String? ?? '').trim().toLowerCase(),
      ),
      targetRoute: (map['targetRoute'] as String? ?? routeFromData).trim(),
      isRead: map['isRead'] == true,
      createdAt: _toDateTime(map['createdAt']),
      data: payloadMap,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'notifId': notifId,
      'recipientUid': recipientUid,
      'title': title,
      'body': body,
      'type': type,
      'targetRoute': targetRoute,
      'isRead': isRead,
      'createdAt': Timestamp.fromDate(createdAt),
      'data': data,
    };
  }

  NotificationModel copyWith({
    String? notifId,
    String? recipientUid,
    String? title,
    String? body,
    String? type,
    String? targetRoute,
    bool? isRead,
    DateTime? createdAt,
    Map<String, dynamic>? data,
  }) {
    return NotificationModel(
      notifId: notifId ?? this.notifId,
      recipientUid: recipientUid ?? this.recipientUid,
      title: title ?? this.title,
      body: body ?? this.body,
      type: type ?? this.type,
      targetRoute: targetRoute ?? this.targetRoute,
      isRead: isRead ?? this.isRead,
      createdAt: createdAt ?? this.createdAt,
      data: data ?? this.data,
    );
  }

  static String _normalizedType(String value) {
    switch (value) {
      case 'chat_message':
        return 'new_message';
      case 'bulletin_post':
      case 'bulletin_created':
        return 'new_bulletin';
      case 'alumni_answer':
        return 'new_qa_answer';
      default:
        return value.isEmpty ? 'new_message' : value;
    }
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

  static Map<String, dynamic> _toMap(dynamic value) {
    if (value is Map<String, dynamic>) {
      return value;
    }
    if (value is Map) {
      return value.map((key, mapValue) => MapEntry(key.toString(), mapValue));
    }
    return const <String, dynamic>{};
  }
}
