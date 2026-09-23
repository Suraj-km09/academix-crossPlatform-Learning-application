import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../core/constants/firestore_paths.dart';
import '../../../shared/services/cache_policy.dart';
import '../../../shared/services/local_json_cache_service.dart';
import 'notification_model.dart';

class NotificationsRepository {
  NotificationsRepository({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;
  static const String _cachePrefix = 'notifications::';

  CollectionReference<Map<String, dynamic>> get _notificationsRef =>
      _firestore.collection(FirestorePaths.notifications);

  Stream<List<NotificationModel>> getNotifications(String uid) async* {
    final cachedItems = await _readCachedNotifications(uid);
    if (cachedItems.isNotEmpty) {
      yield cachedItems;
    }

    final stream = _notificationsRef
        .where('recipientUid', isEqualTo: uid)
        .snapshots();

    await for (final snapshot in stream) {
      final items = snapshot.docs
          .map((doc) => NotificationModel.fromMap(doc.data(), doc.id))
          .toList();

      items.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      final limited = items.length <= 50 ? items : items.take(50).toList();
      unawaited(_writeCachedNotifications(uid, limited));
      yield limited;
    }
  }

  Future<int> getUnreadCount(String uid) async {
    // We fetch and filter because 'isRead' might be missing in some docs.
    final snapshot = await _notificationsRef
        .where('recipientUid', isEqualTo: uid)
        .get();
    
    return snapshot.docs.where((doc) {
      final data = doc.data();
      return data['isRead'] != true;
    }).length;
  }

  Future<void> markAsRead(String notifId) async {
    await _notificationsRef.doc(notifId).set({
      'isRead': true,
    }, SetOptions(merge: true));
    await LocalJsonCacheService.instance.clearPrefix(_cachePrefix);
  }

  Future<void> markAllAsRead(String uid) async {
    // To handle cases where 'isRead' might be missing (null) in Firestore,
    // we fetch all notifications for the user and filter client-side for the update.
    final snapshot = await _notificationsRef
        .where('recipientUid', isEqualTo: uid)
        .get();

    final unreadDocs = snapshot.docs.where((doc) {
      final data = doc.data();
      return data['isRead'] != true;
    }).toList();

    if (unreadDocs.isEmpty) return;

    const batchSize = 400;
    for (var i = 0; i < unreadDocs.length; i += batchSize) {
      final batch = _firestore.batch();
      final chunk = unreadDocs.skip(i).take(batchSize);
      for (final doc in chunk) {
        batch.update(doc.reference, {'isRead': true});
      }
      await batch.commit();
    }

    await LocalJsonCacheService.instance.remove(_cacheKey(uid));
    await LocalJsonCacheService.instance.clearPrefix(_cachePrefix);
  }

  String _cacheKey(String uid) => '$_cachePrefix$uid';

  Future<List<NotificationModel>> _readCachedNotifications(String uid) async {
    final entry = await LocalJsonCacheService.instance.read(_cacheKey(uid));
    if (entry == null || !entry.isFresh(CachePolicy.notificationsMaxAge)) {
      return const <NotificationModel>[];
    }
    final payload = entry.payload;
    if (payload is! List) {
      return const <NotificationModel>[];
    }

    final items = <NotificationModel>[];
    for (final item in payload) {
      if (item is! Map) {
        continue;
      }

      final map = item.map((k, v) => MapEntry(k.toString(), v));
      final createdAtMs = map['createdAtMs'];
      if (createdAtMs is int) {
        map['createdAt'] = DateTime.fromMillisecondsSinceEpoch(createdAtMs);
      }

      items.add(NotificationModel.fromMap(Map<String, dynamic>.from(map), ''));
    }

    items.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return items;
  }

  Future<void> _writeCachedNotifications(
    String uid,
    List<NotificationModel> items,
  ) {
    final payload = items
        .map(
          (item) => {
            'notifId': item.notifId,
            'recipientUid': item.recipientUid,
            'title': item.title,
            'body': item.body,
            'type': item.type,
            'targetRoute': item.targetRoute,
            'isRead': item.isRead,
            'createdAtMs': item.createdAt.millisecondsSinceEpoch,
            'data': item.data,
          },
        )
        .toList();

    return LocalJsonCacheService.instance.write(_cacheKey(uid), payload);
  }

  Future<NotificationPage> fetchNotificationsPage(
    String uid, {
    int limit = 10,
    DocumentSnapshot<Map<String, dynamic>>? startAfter,
  }) async {
    Query<Map<String, dynamic>> query = _notificationsRef
        .where('recipientUid', isEqualTo: uid)
        .orderBy('createdAt', descending: true)
        .limit(limit);

    if (startAfter != null) {
      query = query.startAfterDocument(startAfter);
    }

    final snapshot = await query.get();
    final items = snapshot.docs
        .map((doc) => NotificationModel.fromMap(doc.data(), doc.id))
        .toList();
    final lastDoc = snapshot.docs.isNotEmpty
        ? snapshot.docs.last as DocumentSnapshot<Map<String, dynamic>>
        : null;
    return NotificationPage(items, lastDoc);
  }

  Future<void> deleteNotification(String notifId) async {
    await _notificationsRef.doc(notifId).delete();
    await LocalJsonCacheService.instance.clearPrefix(_cachePrefix);
  }

  Future<void> clearAllNotifications(String uid) async {
    while (true) {
      final snapshot = await _notificationsRef
          .where('recipientUid', isEqualTo: uid)
          .limit(400)
          .get();
      if (snapshot.docs.isEmpty) break;
      final batch = _firestore.batch();
      for (final doc in snapshot.docs) {
        batch.delete(doc.reference);
      }
      await batch.commit();
    }
    await LocalJsonCacheService.instance.remove(_cacheKey(uid));
  }
}

class NotificationPage {
  final List<NotificationModel> items;
  final DocumentSnapshot<Map<String, dynamic>>? lastDoc;
  NotificationPage(this.items, this.lastDoc);
}
