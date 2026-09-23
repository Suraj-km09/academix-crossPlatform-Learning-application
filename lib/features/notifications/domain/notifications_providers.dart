import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/notification_model.dart';
import '../data/notifications_repository.dart';

final notificationsRepositoryProvider = Provider<NotificationsRepository>((
  ref,
) {
  return NotificationsRepository();
});

final notificationsStreamProvider =
    StreamProvider.family<List<NotificationModel>, String>((ref, uid) {
      final repository = ref.watch(notificationsRepositoryProvider);
      return repository.getNotifications(uid);
    });

final unreadCountProvider = Provider.family<AsyncValue<int>, String>((
  ref,
  uid,
) {
  final notificationsAsync = ref.watch(notificationsStreamProvider(uid));
  return notificationsAsync.whenData(
    (items) => items.where((item) => !item.isRead).length,
  );
});
