import 'package:cloud_firestore/cloud_firestore.dart';

class ChatModel {
  const ChatModel({
    required this.chatId,
    required this.type,
    required this.participants,
    required this.collegeId,
    required this.lastMessage,
    required this.lastMessageAt,
    required this.createdAt,
    this.groupName,
    this.groupAdminUid,
    this.groupAdminUids = const <String>[],
    this.groupDescription,
    this.groupIconUrl,
    this.onlyAdminsCanMessage = false,
    this.onlyAdminsCanEditInfo = false,
    this.joinApprovalRequired = false,
    this.pendingJoinUids = const <String>[],
    this.maxMembers = 256,
    this.broadcastOnly = false,
    this.pinnedMessageId,
    this.pinnedMessageContent,
    this.pinnedAt,
    this.pinnedByUid,
    this.referralId,
    this.inviteCode,
    this.inviteEnabled = false,
    this.typingUids = const <String>[],
    this.unreadCounts = const <String, int>{},
    this.participantNames = const <String, String>{},
    this.participantPhotoUrls = const <String, String>{},
  });

  final String chatId;
  final String type;
  final List<String> participants;
  final String collegeId;

  final String? groupName;
  final String? groupAdminUid;
  final List<String> groupAdminUids;
  final String? groupDescription;
  final String? groupIconUrl;

  final bool onlyAdminsCanMessage;
  final bool onlyAdminsCanEditInfo;
  final bool joinApprovalRequired;
  final List<String> pendingJoinUids;
  final int maxMembers;
  final bool broadcastOnly;

  final String? pinnedMessageId;
  final String? pinnedMessageContent;
  final DateTime? pinnedAt;
  final String? pinnedByUid;

  final String lastMessage;
  final DateTime lastMessageAt;
  final DateTime createdAt;

  final String? referralId;
  final String? inviteCode;
  final bool inviteEnabled;
  final List<String> typingUids;
  final Map<String, int> unreadCounts;
  final Map<String, String> participantNames;
  final Map<String, String> participantPhotoUrls;

  bool get isGroup => type == 'group';
  bool get isDirect => type == 'direct';
  bool get isReferral => type == 'referral';

  int unreadCountFor(String uid) {
    final key = uid.trim();
    if (key.isEmpty) {
      return 0;
    }
    return unreadCounts[key] ?? 0;
  }

  factory ChatModel.fromMap(Map<String, dynamic> map, String id) {
    final normalizedType = _normalizeType(map['type'] as String?);
    final participants = _toStringList(
      map['participants'] ?? map['participantUids'],
    );

    final adminUids = _toStringList(map['groupAdminUids']);
    final primaryAdminUid = (map['groupAdminUid'] as String?)?.trim();
    final mergedAdmins = <String>{...adminUids};
    if (primaryAdminUid != null && primaryAdminUid.isNotEmpty) {
      mergedAdmins.add(primaryAdminUid);
    }

    String? resolvedPrimaryAdmin = primaryAdminUid;
    if (normalizedType == 'group' &&
        mergedAdmins.isEmpty &&
        participants.isNotEmpty) {
      final fallback = participants.first;
      mergedAdmins.add(fallback);
      resolvedPrimaryAdmin = fallback;
    }

    return ChatModel(
      chatId: (map['chatId'] as String? ?? id).trim(),
      type: normalizedType,
      participants: participants,
      collegeId: (map['collegeId'] as String? ?? '').trim(),
      groupName: (map['groupName'] as String?)?.trim(),
      groupAdminUid: resolvedPrimaryAdmin,
      groupAdminUids: mergedAdmins.toList(),
      groupDescription: (map['groupDescription'] as String?)?.trim(),
      groupIconUrl: (map['groupIconUrl'] as String?)?.trim(),
      onlyAdminsCanMessage: map['onlyAdminsCanMessage'] as bool? ?? false,
      onlyAdminsCanEditInfo: map['onlyAdminsCanEditInfo'] as bool? ?? false,
      joinApprovalRequired: map['joinApprovalRequired'] as bool? ?? false,
      pendingJoinUids: _toStringList(map['pendingJoinUids']),
      maxMembers: _toInt(map['maxMembers']) ?? 256,
      broadcastOnly: map['broadcastOnly'] as bool? ?? false,
      pinnedMessageId: (map['pinnedMessageId'] as String?)?.trim(),
      pinnedMessageContent: (map['pinnedMessageContent'] as String?)?.trim(),
      pinnedAt: _toNullableDateTime(map['pinnedAt']),
      pinnedByUid: (map['pinnedByUid'] as String?)?.trim(),
      lastMessage: (map['lastMessage'] as String? ?? '').trim(),
      lastMessageAt: _toDateTime(map['lastMessageAt']),
      createdAt: _toDateTime(map['createdAt']),
      referralId: (map['referralId'] as String?)?.trim(),
      inviteCode: (map['inviteCode'] as String?)?.trim(),
      inviteEnabled: map['inviteEnabled'] as bool? ?? false,
      typingUids: _toStringList(map['typingUids']),
      unreadCounts: _toIntMap(map['unreadCounts']),
      participantNames: _toStringMap(map['participantNames']),
      participantPhotoUrls: _toStringMap(map['participantPhotoUrls']),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'chatId': chatId,
      'type': type,
      'participants': participants,
      'collegeId': collegeId,
      'groupName': groupName,
      'groupAdminUid': groupAdminUid,
      'groupAdminUids': groupAdminUids,
      'groupDescription': groupDescription,
      'groupIconUrl': groupIconUrl,
      'onlyAdminsCanMessage': onlyAdminsCanMessage,
      'onlyAdminsCanEditInfo': onlyAdminsCanEditInfo,
      'joinApprovalRequired': joinApprovalRequired,
      'pendingJoinUids': pendingJoinUids,
      'maxMembers': maxMembers,
      'broadcastOnly': broadcastOnly,
      'pinnedMessageId': pinnedMessageId,
      'pinnedMessageContent': pinnedMessageContent,
      'pinnedAt': pinnedAt == null ? null : Timestamp.fromDate(pinnedAt!),
      'pinnedByUid': pinnedByUid,
      'lastMessage': lastMessage,
      'lastMessageAt': Timestamp.fromDate(lastMessageAt),
      'createdAt': Timestamp.fromDate(createdAt),
      'referralId': referralId,
      'inviteCode': inviteCode,
      'inviteEnabled': inviteEnabled,
      'typingUids': typingUids,
      'unreadCounts': unreadCounts,
      'participantNames': participantNames,
      'participantPhotoUrls': participantPhotoUrls,
    };
  }

  ChatModel copyWith({
    String? chatId,
    String? type,
    List<String>? participants,
    String? collegeId,
    String? groupName,
    String? groupAdminUid,
    List<String>? groupAdminUids,
    String? groupDescription,
    String? groupIconUrl,
    bool? onlyAdminsCanMessage,
    bool? onlyAdminsCanEditInfo,
    bool? joinApprovalRequired,
    List<String>? pendingJoinUids,
    int? maxMembers,
    bool? broadcastOnly,
    String? pinnedMessageId,
    String? pinnedMessageContent,
    DateTime? pinnedAt,
    String? pinnedByUid,
    String? lastMessage,
    DateTime? lastMessageAt,
    DateTime? createdAt,
    String? referralId,
    String? inviteCode,
    bool? inviteEnabled,
    List<String>? typingUids,
    Map<String, int>? unreadCounts,
    Map<String, String>? participantNames,
    Map<String, String>? participantPhotoUrls,
  }) {
    return ChatModel(
      chatId: chatId ?? this.chatId,
      type: type ?? this.type,
      participants: participants ?? this.participants,
      collegeId: collegeId ?? this.collegeId,
      groupName: groupName ?? this.groupName,
      groupAdminUid: groupAdminUid ?? this.groupAdminUid,
      groupAdminUids: groupAdminUids ?? this.groupAdminUids,
      groupDescription: groupDescription ?? this.groupDescription,
      groupIconUrl: groupIconUrl ?? this.groupIconUrl,
      onlyAdminsCanMessage: onlyAdminsCanMessage ?? this.onlyAdminsCanMessage,
      onlyAdminsCanEditInfo:
          onlyAdminsCanEditInfo ?? this.onlyAdminsCanEditInfo,
      joinApprovalRequired: joinApprovalRequired ?? this.joinApprovalRequired,
      pendingJoinUids: pendingJoinUids ?? this.pendingJoinUids,
      maxMembers: maxMembers ?? this.maxMembers,
      broadcastOnly: broadcastOnly ?? this.broadcastOnly,
      pinnedMessageId: pinnedMessageId ?? this.pinnedMessageId,
      pinnedMessageContent: pinnedMessageContent ?? this.pinnedMessageContent,
      pinnedAt: pinnedAt ?? this.pinnedAt,
      pinnedByUid: pinnedByUid ?? this.pinnedByUid,
      lastMessage: lastMessage ?? this.lastMessage,
      lastMessageAt: lastMessageAt ?? this.lastMessageAt,
      createdAt: createdAt ?? this.createdAt,
      referralId: referralId ?? this.referralId,
      inviteCode: inviteCode ?? this.inviteCode,
      inviteEnabled: inviteEnabled ?? this.inviteEnabled,
      typingUids: typingUids ?? this.typingUids,
      unreadCounts: unreadCounts ?? this.unreadCounts,
      participantNames: participantNames ?? this.participantNames,
      participantPhotoUrls: participantPhotoUrls ?? this.participantPhotoUrls,
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

  static DateTime? _toNullableDateTime(dynamic value) {
    if (value == null) {
      return null;
    }
    if (value is Timestamp) {
      return value.toDate();
    }
    if (value is DateTime) {
      return value;
    }
    return null;
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

  static List<String> _toStringList(dynamic value) {
    if (value is List) {
      return value
          .map((item) => item.toString().trim())
          .where((item) => item.isNotEmpty)
          .toList();
    }
    return const <String>[];
  }

  static Map<String, int> _toIntMap(dynamic value) {
    if (value is! Map) {
      return const <String, int>{};
    }

    final result = <String, int>{};
    for (final entry in value.entries) {
      final key = entry.key.toString().trim();
      if (key.isEmpty) {
        continue;
      }

      final raw = entry.value;
      if (raw is int) {
        result[key] = raw;
      } else if (raw is num) {
        result[key] = raw.toInt();
      } else if (raw is String) {
        final parsed = int.tryParse(raw);
        if (parsed != null) {
          result[key] = parsed;
        }
      }
    }

    return result;
  }

  static Map<String, String> _toStringMap(dynamic value) {
    if (value is! Map) {
      return <String, String>{};
    }

    final result = <String, String>{};
    for (final entry in value.entries) {
      final key = entry.key.toString().trim();
      if (key.isEmpty) continue;
      final raw = entry.value;
      if (raw == null) continue;
      final str = raw.toString().trim();
      if (str.isNotEmpty) result[key] = str;
    }
    return result;
  }

  static String _normalizeType(String? rawType) {
    final value = (rawType ?? 'direct').trim().toLowerCase();
    if (value == 'group' || value == 'groupchat' || value == 'group_chat') {
      return 'group';
    }
    if (value == 'referral' ||
        value == 'referralchat' ||
        value == 'referral_chat') {
      return 'referral';
    }
    return 'direct';
  }
}
