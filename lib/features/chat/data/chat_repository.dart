import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:file_picker/file_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';

import '../../../core/constants/firestore_paths.dart';
import '../../../core/constants/storage_bucket_config.dart';
import '../../../core/errors/app_exception.dart';
import '../../../shared/models/user_model.dart';
import '../../../shared/services/storage_image_cache_service.dart';
import '../../../shared/services/write_rate_limiter.dart';
import 'chat_model.dart';
import 'message_model.dart';

class ChatRepository {
  ChatRepository({FirebaseFirestore? firestore, FirebaseStorage? storage})
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
  Map<String, dynamic>? _securityConfigCache;
  DateTime? _securityConfigCacheAt;

  static const int maxGroupMembers = 256;
  static const int maxFileSizeBytes =
      20 * 1024 * 1024; // Increased due to compression support
  static const int defaultRecentMessagesLimit = 50;
  static const int defaultOlderMessagesPageSize = 40;
  static const int _chatMessagesPerMinuteStudent = 30;
  static const int _chatMessagesPerMinuteAlumni = 40;
  static const int _chatMessagesPerMinuteTeacher = 70;
  static const int _chatMessagesPerMinuteAdmin = 120;
  // Keep a very small TTL so admin changes propagate quickly to message send checks.
  static const Duration _securityConfigCacheTtl = Duration(seconds: 2);

  CollectionReference<Map<String, dynamic>> get _chatsRef =>
      _firestore.collection(FirestorePaths.chats);

  CollectionReference<Map<String, dynamic>> get _usersRef =>
      _firestore.collection(FirestorePaths.users);

  DocumentReference<Map<String, dynamic>> get _securityConfigRef =>
      _firestore.collection(FirestorePaths.appConfig).doc('security');

  Future<String> getOrCreateDirectChat(
    String uid1,
    String uid2,
    String collegeId,
  ) async {
    final snapshot = await _chatsRef
        .where('participants', arrayContains: uid1)
        .get();

    for (final doc in snapshot.docs) {
      final model = ChatModel.fromMap(doc.data(), doc.id);
      final hasBoth =
          model.participants.contains(uid1) &&
          model.participants.contains(uid2);
      if (model.type == 'direct' && hasBoth) {
        return model.chatId;
      }
    }

    final now = DateTime.now();
    final chatRef = _chatsRef.doc();
    // Denormalize participant names and photo URLs to avoid N+1 reads in UI.
    final user1 = await _getUserById(uid1);
    final user2 = await _getUserById(uid2);

    final participantNames = <String, String>{};
    final participantPhotoUrls = <String, String>{};
    if (user1 != null) {
      participantNames[uid1] = user1.name;
      if (user1.photoUrl != null && user1.photoUrl!.trim().isNotEmpty) {
        final raw = user1.photoUrl!.trim();
        if (raw.startsWith('http://') || raw.startsWith('https://')) {
          participantPhotoUrls[uid1] = raw;
        } else {
          final resolved = await StorageImageCacheService.resolveDownloadUrl(
            raw,
          );
          participantPhotoUrls[uid1] = resolved ?? raw;
        }
      }
    }
    if (user2 != null) {
      participantNames[uid2] = user2.name;
      if (user2.photoUrl != null && user2.photoUrl!.trim().isNotEmpty) {
        final raw = user2.photoUrl!.trim();
        if (raw.startsWith('http://') || raw.startsWith('https://')) {
          participantPhotoUrls[uid2] = raw;
        } else {
          final resolved = await StorageImageCacheService.resolveDownloadUrl(
            raw,
          );
          participantPhotoUrls[uid2] = resolved ?? raw;
        }
      }
    }

    final chat = ChatModel(
      chatId: chatRef.id,
      type: 'direct',
      participants: [uid1, uid2],
      collegeId: collegeId,
      groupName: null,
      groupAdminUid: null,
      lastMessage: '',
      lastMessageAt: now,
      createdAt: now,
      referralId: null,
      typingUids: const <String>[],
      unreadCounts: <String, int>{uid1: 0, uid2: 0},
      participantNames: participantNames,
      participantPhotoUrls: participantPhotoUrls,
    );

    await chatRef.set(chat.toMap());
    return chat.chatId;
  }

  Stream<List<ChatModel>> getUserChats(String uid) {
    return _chatsRef
        .where('participants', arrayContains: uid)
        .orderBy('lastMessageAt', descending: true)
        .snapshots()
        .map((snapshot) {
          final chats = snapshot.docs
              .map((doc) => ChatModel.fromMap(doc.data(), doc.id))
              .toList();
          chats.sort((a, b) => b.lastMessageAt.compareTo(a.lastMessageAt));
          return chats;
        });
  }

  Future<List<ChatModel>> getUserChatsPage(
    String uid, {
    DateTime? startAfter,
    int limit = 20,
  }) async {
    Query<Map<String, dynamic>> q = _chatsRef
        .where('participants', arrayContains: uid)
        .orderBy('lastMessageAt', descending: true);
    if (startAfter != null) {
      q = q.startAfter([Timestamp.fromDate(startAfter)]);
    }

    final snapshot = await q.limit(limit).get();
    final chats = snapshot.docs
        .map((doc) => ChatModel.fromMap(doc.data(), doc.id))
        .toList();
    chats.sort((a, b) => b.lastMessageAt.compareTo(a.lastMessageAt));
    return chats;
  }

  Stream<ChatModel?> getChatById(String chatId) {
    return _chatsRef.doc(chatId).snapshots().map((snapshot) {
      if (!snapshot.exists || snapshot.data() == null) {
        return null;
      }
      return ChatModel.fromMap(snapshot.data()!, snapshot.id);
    });
  }

  Stream<List<MessageModel>> getMessages(String chatId) {
    return getRecentMessages(chatId, limit: defaultRecentMessagesLimit);
  }

  Stream<List<MessageModel>> getRecentMessages(
    String chatId, {
    int limit = defaultRecentMessagesLimit,
  }) {
    return _chatsRef
        .doc(chatId)
        .collection(FirestorePaths.messages)
        .orderBy('timestamp', descending: true)
        .limit(limit)
        .snapshots()
        .map((snapshot) {
          final messages = snapshot.docs
              .map((doc) => MessageModel.fromMap(doc.data(), doc.id))
              .toList();
          return messages.reversed.toList();
        });
  }

  Future<List<MessageModel>> getOlderMessages(
    String chatId, {
    required DateTime before,
    int limit = defaultOlderMessagesPageSize,
  }) async {
    final snapshot = await _chatsRef
        .doc(chatId)
        .collection(FirestorePaths.messages)
        .orderBy('timestamp', descending: true)
        .startAfter([Timestamp.fromDate(before)])
        .limit(limit)
        .get();

    final messages = snapshot.docs
        .map((doc) => MessageModel.fromMap(doc.data(), doc.id))
        .toList();
    return messages.reversed.toList();
  }

  Future<void> sendMessage(
    String chatId,
    String senderId,
    String senderName,
    String content,
    String type, {
    String? fileUrl,
    String? fileName,
    String? replyTo,
    String? replyToContent,
    String? messageId,
  }) async {
    final normalizedType = type.trim().toLowerCase();
    if (normalizedType != 'text' &&
        normalizedType != 'image' &&
        normalizedType != 'file') {
      throw const AppException(message: 'Invalid message type');
    }

    final chatSnapshot = await _chatsRef.doc(chatId).get();
    if (!chatSnapshot.exists || chatSnapshot.data() == null) {
      throw const AppException(message: 'Chat not found');
    }

    final chat = ChatModel.fromMap(chatSnapshot.data()!, chatSnapshot.id);

    if (chat.isGroup && (chat.onlyAdminsCanMessage || chat.broadcastOnly)) {
      final admins = _adminUids(chat);
      if (!admins.contains(senderId)) {
        throw const AppException(
          message: 'Only group admins can send messages in this group',
        );
      }
    }

    if (chat.isDirect || chat.isReferral) {
      final targetUid = chat.participants.firstWhere(
        (uid) => uid != senderId,
        orElse: () => '',
      );
      if (targetUid.isNotEmpty) {
        final blocked = await isBlockedEitherWay(senderId, targetUid);
        if (blocked) {
          throw const AppException(
            message: 'Message not sent. One of you has blocked the other.',
          );
        }
      }
    }

    final normalizedContent = content.trim();
    if (normalizedType == 'text' && normalizedContent.isEmpty) {
      throw const AppException(message: 'Message cannot be empty');
    }

    final senderRole = await _getNormalizedUserRole(senderId);
    await _assertMessagingEnabledForUser(
      uid: senderId,
      normalizedRole: senderRole,
      isGroupMessage: chat.isGroup,
    );
    final maxMessagesPerMinute = _chatMessagesPerMinuteForRole(senderRole);

    await _rateLimiter.enforce(
      uid: senderId,
      action: 'chat_message_send',
      maxRequests: maxMessagesPerMinute,
      window: const Duration(minutes: 1),
      messagePrefix: 'Message send limit reached',
    );

    final messageRef = _chatsRef
        .doc(chatId)
        .collection(FirestorePaths.messages)
        .doc(messageId);

    final now = DateTime.now();
    final message = MessageModel(
      messageId: messageRef.id,
      senderId: senderId,
      senderName: senderName.trim(),
      content: normalizedContent,
      type: normalizedType,
      fileUrl: fileUrl,
      fileName: fileName,
      timestamp: now,
      readBy: [senderId],
      replyTo: replyTo,
      replyToContent: replyToContent,
      isDeleted: false,
    );

    await _firestore.runTransaction((transaction) async {
      transaction.set(messageRef, message.toMap());
      final chatUpdates = <String, dynamic>{
        'lastMessage': _previewForMessage(message),
        'lastMessageAt': Timestamp.fromDate(now),
        'unreadCounts.$senderId': 0,
      };
      for (final participantUid in chat.participants) {
        if (participantUid == senderId) {
          continue;
        }
        chatUpdates['unreadCounts.$participantUid'] = FieldValue.increment(1);
      }
      transaction.set(
        _chatsRef.doc(chatId),
        chatUpdates,
        SetOptions(merge: true),
      );
    });
  }

  Future<void> sendFile(
    String chatId,
    String senderId,
    String senderName,
    PlatformFile file,
    String type,
  ) async {
    final normalizedType = type.trim().toLowerCase();
    if (normalizedType != 'image' && normalizedType != 'file') {
      throw const AppException(message: 'Invalid file message type');
    }

    final chatSnapshot = await _chatsRef.doc(chatId).get();
    if (!chatSnapshot.exists || chatSnapshot.data() == null) {
      throw const AppException(message: 'Chat not found');
    }
    final chat = ChatModel.fromMap(chatSnapshot.data()!, chatSnapshot.id);

    final senderRole = await _getNormalizedUserRole(senderId);
    await _assertMessagingEnabledForUser(
      uid: senderId,
      normalizedRole: senderRole,
      isGroupMessage: chat.isGroup,
    );

    if (file.size <= 0) {
      throw const AppException(message: 'Selected file is invalid');
    }
    if (file.size > maxFileSizeBytes) {
      throw const AppException(message: 'File size cannot exceed 20 MB');
    }

    final sourceBytes = await _readFileBytes(file);
    Uint8List finalBytes = sourceBytes;
    String finalFileName = file.name;

    // Compression logic
    if (normalizedType == 'image') {
      final compressed = await _compressImage(sourceBytes);
      if (compressed != null) {
        finalBytes = compressed;
      }
    } else if (normalizedType == 'file' &&
        finalFileName.toLowerCase().endsWith('.pdf')) {
      final compressed = await _compressPdf(sourceBytes);
      if (compressed != null) {
        finalBytes = compressed;
      }
    }

    final messageId = _chatsRef
        .doc(chatId)
        .collection(FirestorePaths.messages)
        .doc()
        .id;

    final extension = _extractExtension(finalFileName);
    final storageRef = _storage
        .ref()
        .child('chats')
        .child(chatId)
        .child(messageId);

    final metadata = SettableMetadata(
      contentType: _contentTypeFor(extension),
      customMetadata: {
        'originalSize': sourceBytes.length.toString(),
        'compressedSize': finalBytes.length.toString(),
        'wasCompressed': (finalBytes.length < sourceBytes.length).toString(),
      },
    );

    await storageRef.putData(finalBytes, metadata);
    final url = await storageRef.getDownloadURL();

    await sendMessage(
      chatId,
      senderId,
      senderName,
      finalFileName,
      normalizedType,
      fileUrl: url,
      fileName: finalFileName,
      messageId: messageId,
    );
  }

  Future<Uint8List?> _compressImage(Uint8List bytes) async {
    try {
      final result = await FlutterImageCompress.compressWithList(
        bytes,
        minHeight: 1920,
        minWidth: 1080,
        quality: 85,
      );
      return result.length < bytes.length ? result : null;
    } catch (_) {
      return null;
    }
  }

  Future<Uint8List?> _compressPdf(Uint8List bytes) async {
    try {
      final PdfDocument document = PdfDocument(inputBytes: bytes);
      document.compressionLevel = PdfCompressionLevel.best;
      final List<int> compressed = await document.save();
      document.dispose();
      return compressed.length < bytes.length
          ? Uint8List.fromList(compressed)
          : null;
    } catch (_) {
      return null;
    }
  }

  Future<Uint8List> _readFileBytes(PlatformFile file) async {
    if (file.bytes != null && file.bytes!.isNotEmpty) {
      return file.bytes!;
    }
    final path = file.path;
    if (path == null) throw const AppException(message: 'File path not found');
    return File(path).readAsBytes();
  }

  Future<void> markAsRead(String chatId, String messageId, String uid) async {
    await markMessagesAsRead(chatId: chatId, uid: uid, messageIds: [messageId]);
  }

  Future<void> markMessagesAsRead({
    required String chatId,
    required String uid,
    required List<String> messageIds,
  }) async {
    final sanitizedIds = messageIds
        .map((item) => item.trim())
        .where((item) => item.isNotEmpty)
        .toSet()
        .toList();

    final chatDoc = _chatsRef.doc(chatId);
    final batch = _firestore.batch();

    for (final messageId in sanitizedIds) {
      batch.set(
        chatDoc.collection(FirestorePaths.messages).doc(messageId),
        {
          'readBy': FieldValue.arrayUnion([uid]),
        },
        SetOptions(merge: true),
      );
    }

    batch.set(chatDoc, {'unreadCounts.$uid': 0}, SetOptions(merge: true));
    await batch.commit();
  }

  Future<void> deleteMessage(String chatId, String messageId) async {
    await _chatsRef
        .doc(chatId)
        .collection(FirestorePaths.messages)
        .doc(messageId)
        .set({
          'isDeleted': true,
          'content': '',
          'fileUrl': null,
          'fileName': null,
        }, SetOptions(merge: true));
  }

  Future<String> createGroupChat({
    required String name,
    required List<String> participantUids,
    required String creatorUid,
    required String collegeId,
    String? groupAdminUid,
  }) async {
    await _assertCanCreateGroup(creatorUid);

    final adminUid = (groupAdminUid ?? creatorUid).trim();
    if (adminUid.isEmpty) {
      throw const AppException(message: 'Group admin is required');
    }

    final members = participantUids
        .map((uid) => uid.trim())
        .where((uid) => uid.isNotEmpty)
        .toSet()
        .toList();
    if (!members.contains(creatorUid)) {
      members.add(creatorUid);
    }
    if (!members.contains(adminUid)) {
      members.add(adminUid);
    }

    if (members.length > maxGroupMembers) {
      throw const AppException(
        message: 'Group cannot have more than 256 members',
      );
    }

    if (name.trim().isEmpty) {
      throw const AppException(message: 'Group name is required');
    }

    final now = DateTime.now();
    final chatRef = _chatsRef.doc();

    final chat = ChatModel(
      chatId: chatRef.id,
      type: 'group',
      participants: members,
      collegeId: collegeId,
      groupName: name.trim(),
      groupAdminUid: adminUid,
      groupAdminUids: [adminUid],
      groupDescription: null,
      groupIconUrl: null,
      onlyAdminsCanMessage: false,
      onlyAdminsCanEditInfo: true,
      joinApprovalRequired: false,
      pendingJoinUids: const <String>[],
      maxMembers: maxGroupMembers,
      broadcastOnly: false,
      pinnedMessageId: null,
      pinnedMessageContent: null,
      pinnedAt: null,
      pinnedByUid: null,
      lastMessage: '',
      lastMessageAt: now,
      createdAt: now,
      referralId: null,
      inviteCode: null,
      inviteEnabled: false,
      typingUids: const <String>[],
      unreadCounts: {for (final uid in members) uid: 0},
      participantNames: await () async {
        final users = await getUsersByIds(members);
        final map = <String, String>{};
        for (final u in users) {
          map[u.uid] = u.name;
        }
        return map;
      }(),
      participantPhotoUrls: await () async {
        final users = await getUsersByIds(members);
        final map = <String, String>{};
        for (final u in users) {
          if (u.photoUrl == null || u.photoUrl!.trim().isEmpty) continue;
          final raw = u.photoUrl!.trim();
          if (raw.startsWith('http://') || raw.startsWith('https://')) {
            map[u.uid] = raw;
            continue;
          }
          final resolved = await StorageImageCacheService.resolveDownloadUrl(
            raw,
          );
          map[u.uid] = resolved ?? raw;
        }
        return map;
      }(),
    );

    await chatRef.set(chat.toMap());
    return chat.chatId;
  }

  Future<void> addGroupMember(String chatId, String uid) async {
    final user = await _getUserById(uid);
    final updates = <String, dynamic>{
      'participants': FieldValue.arrayUnion([uid]),
      'unreadCounts.$uid': 0,
    };
    if (user != null) {
      updates['participantNames.$uid'] = user.name;
      if (user.photoUrl != null && user.photoUrl!.trim().isNotEmpty) {
        final raw = user.photoUrl!.trim();
        if (raw.startsWith('http://') || raw.startsWith('https://')) {
          updates['participantPhotoUrls.$uid'] = raw;
        } else {
          final resolved = await StorageImageCacheService.resolveDownloadUrl(
            raw,
          );
          updates['participantPhotoUrls.$uid'] = resolved ?? raw;
        }
      }
    }
    await _chatsRef.doc(chatId).set(updates, SetOptions(merge: true));
  }

  Future<void> addGroupMemberByAdmin({
    required String chatId,
    required String requestedByUid,
    required String memberUid,
  }) async {
    final chat = await _requireGroupChat(chatId);
    await _assertGroupAdminPrivileges(
      chat: chat,
      requestedByUid: requestedByUid,
      errorMessage: 'Only group admin can add members',
    );

    final participantSet = chat.participants.toSet();
    if (participantSet.contains(memberUid)) {
      return;
    }

    final effectiveLimit = chat.maxMembers <= 0
        ? maxGroupMembers
        : chat.maxMembers;
    if (participantSet.length >= effectiveLimit) {
      throw const AppException(message: 'Group member limit reached (256)');
    }

    // Use addGroupMember to ensure denormalized participant info is written
    await addGroupMember(chatId, memberUid);
  }

  Future<void> removeGroupMember(String chatId, String uid) async {
    await _chatsRef.doc(chatId).set({
      'participants': FieldValue.arrayRemove([uid]),
      'typingUids': FieldValue.arrayRemove([uid]),
      'groupAdminUids': FieldValue.arrayRemove([uid]),
      'pendingJoinUids': FieldValue.arrayRemove([uid]),
      'unreadCounts.$uid': FieldValue.delete(),
    }, SetOptions(merge: true));

    final chatDoc = await _chatsRef.doc(chatId).get();
    final chatData = chatDoc.data();
    if (chatData == null) {
      return;
    }

    final chat = ChatModel.fromMap(chatData, chatDoc.id);
    final remaining = chat.participants.where((item) => item != uid).toList();

    if (chat.isGroup && remaining.isEmpty) {
      await _chatsRef.doc(chatId).delete();
      return;
    }

    if (chat.groupAdminUid == uid) {
      if (remaining.isEmpty) {
        await _chatsRef.doc(chatId).set({
          'groupAdminUid': null,
        }, SetOptions(merge: true));
        return;
      }

      final remainingAdminUids = _adminUids(chat)
          .where((item) => item != uid)
          .where((item) => remaining.contains(item))
          .toList();

      final nextAdmin = remainingAdminUids.isNotEmpty
          ? remainingAdminUids.first
          : remaining.first;

      await _chatsRef.doc(chatId).set({
        'groupAdminUid': nextAdmin,
        'groupAdminUids': FieldValue.arrayUnion([nextAdmin]),
      }, SetOptions(merge: true));
    }
  }

  Future<void> removeGroupMemberByAdmin({
    required String chatId,
    required String requestedByUid,
    required String memberUid,
  }) async {
    final chat = await _requireGroupChat(chatId);
    await _assertGroupAdminPrivileges(
      chat: chat,
      requestedByUid: requestedByUid,
      errorMessage: 'Only group admin can remove members',
    );

    if (memberUid == requestedByUid) {
      throw const AppException(message: 'Use leave group action for yourself');
    }

    await removeGroupMember(chatId, memberUid);
  }

  Future<void> leaveGroup({required String chatId, required String uid}) async {
    await removeGroupMember(chatId, uid);
  }

  Future<void> makeGroupAdmin({
    required String chatId,
    required String requestedByUid,
    required String newAdminUid,
  }) async {
    final chatDoc = await _chatsRef.doc(chatId).get();
    final chatData = chatDoc.data();
    if (chatData == null) {
      throw const AppException(message: 'Group chat not found');
    }

    final chat = ChatModel.fromMap(chatData, chatDoc.id);
    if (!chat.isGroup) {
      throw const AppException(message: 'Only group chats support admin role');
    }

    if (!chat.participants.contains(newAdminUid)) {
      throw const AppException(message: 'Selected user is not a group member');
    }

    final requester = await _getUserById(requestedByUid);
    final requesterRole = requester?.role.trim().toLowerCase() ?? 'student';
    final canManageAdmin =
        chat.groupAdminUid == requestedByUid || requesterRole == 'admin';
    if (!canManageAdmin) {
      throw const AppException(
        message: 'Only group admin can assign new admin',
      );
    }

    await _chatsRef.doc(chatId).set({
      'groupAdminUid': newAdminUid,
      'groupAdminUids': FieldValue.arrayUnion([newAdminUid]),
    }, SetOptions(merge: true));
  }

  Future<void> demoteGroupAdmin({
    required String chatId,
    required String requestedByUid,
    required String adminUid,
  }) async {
    final chat = await _requireGroupChat(chatId);
    await _assertGroupAdminPrivileges(
      chat: chat,
      requestedByUid: requestedByUid,
      errorMessage: 'Only group admin can demote admins',
    );

    final admins = _adminUids(chat);
    if (!admins.contains(adminUid)) {
      return;
    }
    if (admins.length <= 1) {
      throw const AppException(message: 'At least one admin is required');
    }

    await _chatsRef.doc(chatId).set({
      'groupAdminUids': FieldValue.arrayRemove([adminUid]),
    }, SetOptions(merge: true));

    if (chat.groupAdminUid == adminUid) {
      final replacement = admins.firstWhere((item) => item != adminUid);
      await _chatsRef.doc(chatId).set({
        'groupAdminUid': replacement,
      }, SetOptions(merge: true));
    }
  }

  Future<void> setGroupMessagingRestriction({
    required String chatId,
    required String requestedByUid,
    required bool onlyAdminsCanMessage,
    bool? broadcastOnly,
  }) async {
    final chat = await _requireGroupChat(chatId);
    await _assertGroupAdminPrivileges(
      chat: chat,
      requestedByUid: requestedByUid,
      errorMessage: 'Only group admin can update messaging settings',
    );

    await _chatsRef.doc(chatId).set({
      'onlyAdminsCanMessage': onlyAdminsCanMessage,
      'broadcastOnly': broadcastOnly ?? onlyAdminsCanMessage,
    }, SetOptions(merge: true));
  }

  Future<void> setGroupInfoEditingRestriction({
    required String chatId,
    required String requestedByUid,
    required bool onlyAdminsCanEditInfo,
  }) async {
    final chat = await _requireGroupChat(chatId);
    await _assertGroupAdminPrivileges(
      chat: chat,
      requestedByUid: requestedByUid,
      errorMessage: 'Only group admin can update info-edit restriction',
    );

    await _chatsRef.doc(chatId).set({
      'onlyAdminsCanEditInfo': onlyAdminsCanEditInfo,
    }, SetOptions(merge: true));
  }

  Future<void> setJoinApprovalRequirement({
    required String chatId,
    required String requestedByUid,
    required bool joinApprovalRequired,
  }) async {
    final chat = await _requireGroupChat(chatId);
    await _assertGroupAdminPrivileges(
      chat: chat,
      requestedByUid: requestedByUid,
      errorMessage: 'Only group admin can update join-approval settings',
    );

    await _chatsRef.doc(chatId).set({
      'joinApprovalRequired': joinApprovalRequired,
    }, SetOptions(merge: true));
  }

  Future<void> updateGroupInfo({
    required String chatId,
    required String requestedByUid,
    String? name,
    String? description,
    String? iconUrl,
  }) async {
    final chat = await _requireGroupChat(chatId);

    final admins = _adminUids(chat);
    if (chat.onlyAdminsCanEditInfo && !admins.contains(requestedByUid)) {
      final user = await _getUserById(requestedByUid);
      final role = user?.role.trim().toLowerCase() ?? 'student';
      if (role != 'admin') {
        throw const AppException(message: 'Only admins can edit group info');
      }
    }

    final updates = <String, dynamic>{};
    if (name != null) {
      final value = name.trim();
      if (value.isEmpty) {
        throw const AppException(message: 'Group name cannot be empty');
      }
      updates['groupName'] = value;
    }
    if (description != null) {
      updates['groupDescription'] = description.trim();
    }
    if (iconUrl != null) {
      updates['groupIconUrl'] = iconUrl.trim().isEmpty ? null : iconUrl.trim();
    }

    if (updates.isEmpty) {
      return;
    }

    final oldIcon = chat.groupIconUrl?.trim();

    await _chatsRef.doc(chatId).set(updates, SetOptions(merge: true));

    // If icon was updated, invalidate any cached resolved URL / image cache
    // for the old and new icon values so UI refreshes immediately.
    if (iconUrl != null) {
      final newIcon = iconUrl.trim().isEmpty ? null : iconUrl.trim();
      if (oldIcon != null && oldIcon.isNotEmpty) {
        unawaited(
          StorageImageCacheService.invalidateResolvedDownloadUrl(oldIcon),
        );
      }
      if (newIcon != null && newIcon.isNotEmpty) {
        unawaited(
          StorageImageCacheService.invalidateResolvedDownloadUrl(newIcon),
        );
      }
    }
  }

  Future<String> uploadGroupIcon({
    required String chatId,
    required String requestedByUid,
    required PlatformFile file,
  }) async {
    if (file.size <= 0) {
      throw const AppException(message: 'Selected image is invalid');
    }
    if (file.size > 5 * 1024 * 1024) {
      throw const AppException(message: 'Group icon size cannot exceed 5 MB');
    }

    final ext = _extractExtension(file.name);
    final ref = _storage
        .ref()
        .child('groups')
        .child(chatId)
        .child(
          'icon_${DateTime.now().millisecondsSinceEpoch}.${ext.isEmpty ? 'jpg' : ext}',
        );

    final metadata = SettableMetadata(contentType: _contentTypeFor(ext));
    if (file.bytes != null && file.bytes!.isNotEmpty) {
      await ref.putData(file.bytes!, metadata);
    } else {
      final path = file.path;
      if (path == null || path.trim().isEmpty) {
        throw const AppException(message: 'Unable to read selected image');
      }
      await ref.putFile(File(path), metadata);
    }

    final url = await ref.getDownloadURL();
    await updateGroupInfo(
      chatId: chatId,
      requestedByUid: requestedByUid,
      iconUrl: url,
    );
    return url;
  }

  Future<void> clearChatMessages({
    required String chatId,
    required String requestedByUid,
  }) async {
    final chatDoc = await _chatsRef.doc(chatId).get();
    final chatData = chatDoc.data();
    if (chatData == null) {
      throw const AppException(message: 'Chat not found');
    }

    final chat = ChatModel.fromMap(chatData, chatDoc.id);
    if (chat.isGroup) {
      await _assertGroupAdminPrivileges(
        chat: chat,
        requestedByUid: requestedByUid,
        errorMessage: 'Only group admin can clear chat',
      );
    } else if (!chat.participants.contains(requestedByUid)) {
      throw const AppException(message: 'Unauthorized clear chat action');
    }

    final messagesRef = _chatsRef
        .doc(chatId)
        .collection(FirestorePaths.messages);
    while (true) {
      final batchSnapshot = await messagesRef.limit(400).get();
      if (batchSnapshot.docs.isEmpty) {
        break;
      }
      final batch = _firestore.batch();
      for (final doc in batchSnapshot.docs) {
        batch.delete(doc.reference);
      }
      await batch.commit();
    }

    await _chatsRef.doc(chatId).set({
      'lastMessage': '',
      'lastMessageAt': FieldValue.serverTimestamp(),
      'pinnedMessageId': null,
      'pinnedMessageContent': null,
      'pinnedAt': null,
      'pinnedByUid': null,
      for (final participant in chat.participants)
        'unreadCounts.$participant': 0,
    }, SetOptions(merge: true));
  }

  Future<void> deleteChat({
    required String chatId,
    required String requestedByUid,
  }) async {
    final chatDoc = await _chatsRef.doc(chatId).get();
    final chatData = chatDoc.data();
    if (chatData == null) {
      throw const AppException(message: 'Chat not found');
    }

    final chat = ChatModel.fromMap(chatData, chatDoc.id);
    if (chat.isGroup) {
      throw const AppException(
        message: 'Use delete group action for group chats',
      );
    }
    if (!chat.participants.contains(requestedByUid)) {
      throw const AppException(message: 'Unauthorized delete action');
    }

    final messagesRef = _chatsRef
        .doc(chatId)
        .collection(FirestorePaths.messages);
    while (true) {
      final batchSnapshot = await messagesRef.limit(400).get();
      if (batchSnapshot.docs.isEmpty) {
        break;
      }
      final batch = _firestore.batch();
      for (final doc in batchSnapshot.docs) {
        batch.delete(doc.reference);
      }
      await batch.commit();
    }

    await _chatsRef.doc(chatId).delete();
  }

  Future<void> pinMessage({
    required String chatId,
    required String requestedByUid,
    required String messageId,
  }) async {
    final chat = await _requireGroupChat(chatId);
    await _assertGroupAdminPrivileges(
      chat: chat,
      requestedByUid: requestedByUid,
      errorMessage: 'Only group admin can pin messages',
    );

    final messageDoc = await _chatsRef
        .doc(chatId)
        .collection(FirestorePaths.messages)
        .doc(messageId)
        .get();
    final messageData = messageDoc.data();
    if (messageData == null) {
      throw const AppException(message: 'Message not found');
    }
    final message = MessageModel.fromMap(messageData, messageDoc.id);

    await _chatsRef.doc(chatId).set({
      'pinnedMessageId': messageId,
      'pinnedMessageContent': message.content,
      'pinnedAt': FieldValue.serverTimestamp(),
      'pinnedByUid': requestedByUid,
    }, SetOptions(merge: true));
  }

  Future<void> unpinMessage({
    required String chatId,
    required String requestedByUid,
  }) async {
    final chat = await _requireGroupChat(chatId);
    await _assertGroupAdminPrivileges(
      chat: chat,
      requestedByUid: requestedByUid,
      errorMessage: 'Only group admin can unpin messages',
    );

    await _chatsRef.doc(chatId).set({
      'pinnedMessageId': null,
      'pinnedMessageContent': null,
      'pinnedAt': null,
      'pinnedByUid': null,
    }, SetOptions(merge: true));
  }

  Future<void> updateGroupName({
    required String chatId,
    required String requestedByUid,
    required String newName,
  }) async {
    final chat = await _requireGroupChat(chatId);
    await _assertGroupAdminPrivileges(
      chat: chat,
      requestedByUid: requestedByUid,
      errorMessage: 'Only group admin can edit group',
    );

    if (newName.trim().isEmpty) {
      throw const AppException(message: 'Group name cannot be empty');
    }

    await _chatsRef.doc(chatId).set({
      'groupName': newName.trim(),
    }, SetOptions(merge: true));
  }

  Future<void> deleteGroup({
    required String chatId,
    required String requestedByUid,
  }) async {
    final chat = await _requireGroupChat(chatId);
    await _assertGroupAdminPrivileges(
      chat: chat,
      requestedByUid: requestedByUid,
      errorMessage: 'Only group admin can delete group',
    );

    final messagesRef = _chatsRef
        .doc(chatId)
        .collection(FirestorePaths.messages);
    while (true) {
      final batchSnapshot = await messagesRef.limit(400).get();
      if (batchSnapshot.docs.isEmpty) {
        break;
      }
      final batch = _firestore.batch();
      for (final doc in batchSnapshot.docs) {
        batch.delete(doc.reference);
      }
      await batch.commit();
    }

    await _chatsRef.doc(chatId).delete();
  }

  Future<String> generateGroupInviteCode({
    required String chatId,
    required String requestedByUid,
  }) async {
    final chat = await _requireGroupChat(chatId);
    await _assertGroupAdminPrivileges(
      chat: chat,
      requestedByUid: requestedByUid,
      errorMessage: 'Only group admin can manage invite link',
    );

    final code = _buildInviteCode();
    await _chatsRef.doc(chatId).set({
      'inviteCode': code,
      'inviteEnabled': true,
    }, SetOptions(merge: true));
    return code;
  }

  Future<void> disableGroupInviteCode({
    required String chatId,
    required String requestedByUid,
  }) async {
    final chat = await _requireGroupChat(chatId);
    await _assertGroupAdminPrivileges(
      chat: chat,
      requestedByUid: requestedByUid,
      errorMessage: 'Only group admin can manage invite link',
    );

    await _chatsRef.doc(chatId).set({
      'inviteCode': null,
      'inviteEnabled': false,
    }, SetOptions(merge: true));
  }

  Future<String> joinGroupByInviteCode({
    required String inviteCode,
    required String uid,
  }) async {
    final code = inviteCode.trim();
    if (code.isEmpty) {
      throw const AppException(message: 'Invite code is required');
    }

    final snapshot = await _chatsRef
        .where('type', isEqualTo: 'group')
        .where('inviteCode', isEqualTo: code)
        .where('inviteEnabled', isEqualTo: true)
        .limit(1)
        .get();

    if (snapshot.docs.isEmpty) {
      throw const AppException(message: 'Invite link is invalid or expired');
    }

    final chatDoc = snapshot.docs.first;
    final chat = ChatModel.fromMap(chatDoc.data(), chatDoc.id);
    final currentMembers = chat.participants.toSet();
    if (currentMembers.contains(uid)) {
      return chatDoc.id;
    }

    final effectiveLimit = chat.maxMembers <= 0
        ? maxGroupMembers
        : chat.maxMembers;
    if (currentMembers.length >= effectiveLimit) {
      throw const AppException(message: 'Group is full');
    }

    if (chat.joinApprovalRequired) {
      await _chatsRef.doc(chatDoc.id).set({
        'pendingJoinUids': FieldValue.arrayUnion([uid]),
      }, SetOptions(merge: true));
      throw const AppException(
        message: 'Join request sent. Wait for admin approval.',
      );
    }

    await _chatsRef.doc(chatDoc.id).set({
      'participants': FieldValue.arrayUnion([uid]),
      'pendingJoinUids': FieldValue.arrayRemove([uid]),
      'unreadCounts.$uid': 0,
    }, SetOptions(merge: true));

    return chatDoc.id;
  }

  Future<void> approveJoinRequest({
    required String chatId,
    required String requestedByUid,
    required String joiningUid,
  }) async {
    final chat = await _requireGroupChat(chatId);
    await _assertGroupAdminPrivileges(
      chat: chat,
      requestedByUid: requestedByUid,
      errorMessage: 'Only group admin can approve members',
    );

    final effectiveLimit = chat.maxMembers <= 0
        ? maxGroupMembers
        : chat.maxMembers;
    if (!chat.participants.contains(joiningUid) &&
        chat.participants.length >= effectiveLimit) {
      throw const AppException(message: 'Group is full');
    }

    await _chatsRef.doc(chatId).set({
      'participants': FieldValue.arrayUnion([joiningUid]),
      'pendingJoinUids': FieldValue.arrayRemove([joiningUid]),
      'unreadCounts.$joiningUid': 0,
    }, SetOptions(merge: true));
  }

  Future<void> rejectJoinRequest({
    required String chatId,
    required String requestedByUid,
    required String joiningUid,
  }) async {
    final chat = await _requireGroupChat(chatId);
    await _assertGroupAdminPrivileges(
      chat: chat,
      requestedByUid: requestedByUid,
      errorMessage: 'Only group admin can reject members',
    );

    await _chatsRef.doc(chatId).set({
      'pendingJoinUids': FieldValue.arrayRemove([joiningUid]),
    }, SetOptions(merge: true));
  }

  Future<void> blockUser({
    required String blockerUid,
    required String blockedUid,
  }) async {
    if (blockerUid.trim().isEmpty || blockedUid.trim().isEmpty) {
      throw const AppException(message: 'Invalid user for block action');
    }
    if (blockerUid == blockedUid) {
      throw const AppException(message: 'You cannot block yourself');
    }

    final ref = _usersRef
        .doc(blockerUid)
        .collection(FirestorePaths.blockedUsers)
        .doc(blockedUid);
    await ref.set({
      'blockedUid': blockedUid,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> unblockUser({
    required String blockerUid,
    required String blockedUid,
  }) async {
    final ref = _usersRef
        .doc(blockerUid)
        .collection(FirestorePaths.blockedUsers)
        .doc(blockedUid);
    await ref.delete();
  }

  Stream<Set<String>> watchBlockedUsers(String uid) {
    return _usersRef
        .doc(uid)
        .collection(FirestorePaths.blockedUsers)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map(
                (doc) => (doc.data()['blockedUid'] as String? ?? doc.id).trim(),
              )
              .where((value) => value.isNotEmpty)
              .toSet(),
        );
  }

  Future<bool> isBlockedEitherWay(String uidA, String uidB) async {
    final aBlocksB = await _usersRef
        .doc(uidA)
        .collection(FirestorePaths.blockedUsers)
        .doc(uidB)
        .get();
    if (aBlocksB.exists) {
      return true;
    }

    final bBlocksA = await _usersRef
        .doc(uidB)
        .collection(FirestorePaths.blockedUsers)
        .doc(uidA)
        .get();
    return bBlocksA.exists;
  }

  Future<void> reportChat({
    required String reporterUid,
    required String chatId,
    required String reason,
    String? targetUid,
    String? messageId,
  }) async {
    final trimmedReason = reason.trim();
    if (trimmedReason.isEmpty) {
      throw const AppException(message: 'Report reason is required');
    }

    final ref = _firestore.collection(FirestorePaths.reports).doc();
    await ref.set({
      'reportId': ref.id,
      'reporterUid': reporterUid,
      'chatId': chatId,
      'targetUid': targetUid,
      'messageId': messageId,
      'reason': trimmedReason,
      'category': 'chat',
      'status': 'open',
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  Stream<List<ChatModel>> getCollegeGroups(String collegeId) {
    return _chatsRef
        .where('type', isEqualTo: 'group')
        .where('collegeId', isEqualTo: collegeId)
        .snapshots()
        .map((snapshot) {
          final chats = snapshot.docs
              .map((doc) => ChatModel.fromMap(doc.data(), doc.id))
              .toList();
          chats.sort((a, b) => b.lastMessageAt.compareTo(a.lastMessageAt));
          return chats;
        });
  }

  Future<List<UserModel>> searchUsersInCollege({
    required String collegeId,
    required String query,
    required String currentUid,
    int limit = 50,
    String? startAfterName,
  }) async {
    final normalized = query.trim();

    try {
      Query<Map<String, dynamic>> q = _usersRef
          .where('collegeId', isEqualTo: collegeId)
          .orderBy('name');

      if (startAfterName != null && startAfterName.trim().isNotEmpty) {
        q = q.startAfter([startAfterName.trim()]);
      }

      if (normalized.isNotEmpty) {
        final start = normalized;
        final end = '$start\uf8ff';
        q = q.startAt([start]).endAt([end]);
      }

      final snapshot = await q.limit(limit).get();
      final users = snapshot.docs
          .map((doc) => UserModel.fromMap(doc.data(), doc.id))
          .where((user) => user.uid != currentUid)
          .toList();
      users.sort(
        (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
      );
      return users;
    } catch (_) {
      // Fallback to client-side filtering if server-side prefix queries fail.
      final snapshot = await _firestore
          .collection(FirestorePaths.users)
          .where('collegeId', isEqualTo: collegeId)
          .get();

      final lower = normalized.toLowerCase();
      return snapshot.docs
          .map((doc) => UserModel.fromMap(doc.data(), doc.id))
          .where((user) => user.uid != currentUid)
          .where(
            (user) => lower.isEmpty || user.name.toLowerCase().contains(lower),
          )
          .toList()
        ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    }
  }

  Future<List<UserModel>> getUsersByIds(List<String> uids) async {
    final unique = uids
        .map((item) => item.trim())
        .where((item) => item.isNotEmpty)
        .toSet()
        .toList();
    if (unique.isEmpty) {
      return const <UserModel>[];
    }

    final result = <UserModel>[];
    for (var index = 0; index < unique.length; index += 10) {
      final end = (index + 10 < unique.length) ? index + 10 : unique.length;
      final chunk = unique.sublist(index, end);
      final snapshot = await _usersRef
          .where(FieldPath.documentId, whereIn: chunk)
          .get();
      result.addAll(
        snapshot.docs.map((doc) => UserModel.fromMap(doc.data(), doc.id)),
      );
    }

    result.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    return result;
  }

  Stream<UserModel?> watchUser(String uid) {
    return _firestore.collection(FirestorePaths.users).doc(uid).snapshots().map(
      (snapshot) {
        if (!snapshot.exists || snapshot.data() == null) {
          return null;
        }
        return UserModel.fromMap(snapshot.data()!, snapshot.id);
      },
    );
  }

  Stream<bool> watchUserOnline(String uid) {
    return _firestore.collection(FirestorePaths.users).doc(uid).snapshots().map(
      (snapshot) {
        final data = snapshot.data();
        if (data == null) {
          return false;
        }
        return data['isOnline'] as bool? ?? false;
      },
    );
  }

  Future<void> setTyping({
    required String chatId,
    required String uid,
    required bool isTyping,
  }) async {
    await _chatsRef.doc(chatId).set({
      'typingUids': isTyping
          ? FieldValue.arrayUnion([uid])
          : FieldValue.arrayRemove([uid]),
    }, SetOptions(merge: true));
  }

  /// Set the active chat id for a user. When a user opens a chat screen
  /// the client should call this to indicate the user is currently viewing
  /// that chat. Passing null or empty `chatId` clears the field.
  Future<void> setActiveChat({required String uid, String? chatId}) async {
    final updates = <String, dynamic>{
      'activeSessionUpdatedAt': FieldValue.serverTimestamp(),
      'lastActiveAt': FieldValue.serverTimestamp(),
    };
    if (chatId == null || chatId.trim().isEmpty) {
      updates['activeChatId'] = FieldValue.delete();
    } else {
      updates['activeChatId'] = chatId.trim();
    }
    await _usersRef.doc(uid).set(updates, SetOptions(merge: true));
  }

  Future<String> _getNormalizedUserRole(String uid) async {
    final userDoc = await _usersRef.doc(uid).get();
    final role = (userDoc.data()?['role'] as String? ?? '')
        .trim()
        .toLowerCase();
    if (role.isEmpty) {
      return 'student';
    }
    return role;
  }

  int _chatMessagesPerMinuteForRole(String normalizedRole) {
    switch (normalizedRole) {
      case 'admin':
        return _chatMessagesPerMinuteAdmin;
      case 'teacher':
        return _chatMessagesPerMinuteTeacher;
      case 'alumni':
        return _chatMessagesPerMinuteAlumni;
      default:
        return _chatMessagesPerMinuteStudent;
    }
  }

  Future<void> _assertMessagingEnabledForUser({
    required String uid,
    required String normalizedRole,
    bool isGroupMessage = false,
  }) async {
    final config = await _getSecurityConfig();

    final disabledUsers = _toTrimmedStringSet(
      config['chatMessagingDisabledUserUids'],
    );
    if (disabledUsers.contains(uid.trim())) {
      throw const AppException(
        message:
            'Messaging access has been disabled for your account by admin.',
      );
    }

    // Role-based blocks only apply to direct messaging if requested,
    // but the prompt says "enabling and disabling only direct message is not working".
    // This implies these blocks are specifically for direct messages.
    if (!isGroupMessage) {
      final blockedRolesRaw = config['chatMessagingBlockedRoles'];
      if (blockedRolesRaw is Map) {
        final blocked = <String, bool>{};
        blockedRolesRaw.forEach((k, v) {
          final key = k.toString().trim().toLowerCase();
          if (v is bool) blocked[key] = v;
        });

        if (blocked['all'] == true) {
          throw const AppException(
            message:
                'Direct messaging is temporarily disabled for all users by admin.',
          );
        }

        if (blocked[normalizedRole] == true) {
          throw AppException(
            message:
                'Direct messaging is currently disabled for ${normalizedRole}s by admin.',
          );
        }
      }

      final mode = (config['chatMessagingRestrictionMode'] as String? ?? '')
          .trim()
          .toLowerCase();

      if (mode == 'all_users') {
        throw const AppException(
          message:
              'Direct messaging is temporarily disabled for all users by admin.',
        );
      }

      if (mode == 'only_teachers' && normalizedRole == 'teacher') {
        throw const AppException(
          message:
              'Direct messaging is currently disabled for teachers by admin.',
        );
      }

      if (mode == 'only_students' && normalizedRole == 'student') {
        throw const AppException(
          message:
              'Direct messaging is currently disabled for students by admin.',
        );
      }

      if (mode == 'only_alumni' && normalizedRole == 'alumni') {
        throw const AppException(
          message:
              'Direct messaging is currently disabled for alumni by admin.',
        );
      }
    }
  }

  Future<Map<String, dynamic>> _getSecurityConfig() async {
    final cached = _securityConfigCache;
    final cachedAt = _securityConfigCacheAt;
    if (cached != null &&
        cachedAt != null &&
        DateTime.now().difference(cachedAt) < _securityConfigCacheTtl) {
      return cached;
    }

    final snapshot = await _securityConfigRef.get();
    final data = snapshot.data() ?? <String, dynamic>{};

    _securityConfigCache = data;
    _securityConfigCacheAt = DateTime.now();

    return data;
  }

  Set<String> _toTrimmedStringSet(dynamic value) {
    if (value is! List) {
      return <String>{};
    }

    return value
        .map((item) => item.toString().trim())
        .where((item) => item.isNotEmpty)
        .toSet();
  }

  String _previewForMessage(MessageModel message) {
    if (message.isDeleted) {
      return 'Message deleted';
    }
    if (message.type == 'text') {
      return message.content;
    }
    if (message.type == 'image') {
      return 'Image';
    }
    return message.fileName?.trim().isNotEmpty == true
        ? 'File: ${message.fileName}'
        : 'File';
  }

  String _extractExtension(String name) {
    final parts = name.split('.');
    if (parts.length < 2) {
      return '';
    }
    return parts.last.toLowerCase();
  }

  String _contentTypeFor(String extension) {
    switch (extension) {
      case 'jpg':
      case 'jpeg':
        return 'image/jpeg';
      case 'png':
        return 'image/png';
      case 'webp':
        return 'image/webp';
      case 'gif':
        return 'image/gif';
      case 'pdf':
        return 'application/pdf';
      case 'doc':
        return 'application/msword';
      case 'docx':
        return 'application/vnd.openxmlformats-officedocument.wordprocessingml.document';
      default:
        return 'application/octet-stream';
    }
  }

  Future<void> _assertCanCreateGroup(String creatorUid) async {
    final creator = await _getUserById(creatorUid);
    final role = creator?.role.trim().toLowerCase() ?? 'student';
    if (role != 'teacher' && role != 'admin') {
      throw const AppException(
        message: 'Only teacher or admin can create groups',
      );
    }
  }

  Future<ChatModel> _requireGroupChat(String chatId) async {
    final chatDoc = await _chatsRef.doc(chatId).get();
    final chatData = chatDoc.data();
    if (chatData == null) {
      throw const AppException(message: 'Group chat not found');
    }
    final chat = ChatModel.fromMap(chatData, chatDoc.id);
    if (!chat.isGroup) {
      throw const AppException(message: 'Only group chats support this action');
    }
    return chat;
  }

  Future<void> _assertGroupAdminPrivileges({
    required ChatModel chat,
    required String requestedByUid,
    required String errorMessage,
  }) async {
    final requester = await _getUserById(requestedByUid);
    final role = requester?.role.trim().toLowerCase() ?? 'student';
    final admins = _adminUids(chat);
    final hasAccess = admins.contains(requestedByUid) || role == 'admin';
    if (!hasAccess) {
      throw AppException(message: errorMessage);
    }
  }

  Set<String> _adminUids(ChatModel chat) {
    final participants = chat.participants
        .map((item) => item.trim())
        .where((item) => item.isNotEmpty)
        .toSet();

    final admins = chat.groupAdminUids
        .map((item) => item.trim())
        .where((item) => item.isNotEmpty)
        .where((item) => participants.contains(item))
        .toSet();
    final legacy = (chat.groupAdminUid ?? '').trim();
    if (legacy.isNotEmpty && participants.contains(legacy)) {
      admins.add(legacy);
    }

    // Backward-compatible fallback for very old group records.
    if (admins.isEmpty && participants.isNotEmpty) {
      admins.add(participants.first);
    }

    return admins;
  }

  String _buildInviteCode() {
    const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
    final random = Random.secure();
    return List.generate(10, (_) => chars[random.nextInt(chars.length)]).join();
  }

  Future<UserModel?> _getUserById(String uid) async {
    final doc = await _usersRef.doc(uid).get();
    final data = doc.data();
    if (data == null) {
      return null;
    }
    return UserModel.fromMap(data, doc.id);
  }
}
