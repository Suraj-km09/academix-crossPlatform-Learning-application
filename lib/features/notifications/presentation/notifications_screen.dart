import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../features/auth/domain/auth_providers.dart';
import '../data/notification_model.dart';
import '../../../shared/widgets/app_back_button.dart';
import '../../../shared/widgets/empty_state.dart';
import '../../../shared/widgets/notification_tile.dart';
import '../../../shared/widgets/responsive_layout.dart';
import '../../../shared/widgets/skeleton_loader.dart';
import '../domain/notifications_providers.dart';

class NotificationsScreen extends ConsumerStatefulWidget {
  const NotificationsScreen({super.key});

  @override
  ConsumerState<NotificationsScreen> createState() =>
      _NotificationsScreenState();
}

class _NotificationsScreenState extends ConsumerState<NotificationsScreen> {
  final List<NotificationModel> _items = [];
  DocumentSnapshot<Map<String, dynamic>>? _lastDoc;
  bool _isLoading = false;
  bool _isLoadingMore = false;
  bool _hasMore = true;
  String? _currentUid;
  static const int _pageSize = 10;

  @override
  void initState() {
    super.initState();
  }

  Future<void> _loadInitial(String uid) async {
    setState(() {
      _isLoading = true;
      _items.clear();
      _lastDoc = null;
      _hasMore = true;
    });

    try {
      final repo = ref.read(notificationsRepositoryProvider);
      final page = await repo.fetchNotificationsPage(uid, limit: _pageSize);
      setState(() {
        _items.addAll(page.items);
        _lastDoc = page.lastDoc;
        _hasMore = page.items.length == _pageSize;
      });
    } catch (e) {
      _showSnackBar('Failed to load notifications: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _loadMore(String uid) async {
    if (!_hasMore || _isLoadingMore) return;
    setState(() => _isLoadingMore = true);
    try {
      final repo = ref.read(notificationsRepositoryProvider);
      final page = await repo.fetchNotificationsPage(
        uid,
        limit: _pageSize,
        startAfter: _lastDoc,
      );
      setState(() {
        _items.addAll(page.items);
        _lastDoc = page.lastDoc;
        _hasMore = page.items.length == _pageSize;
      });
    } catch (e) {
      _showSnackBar('Failed to load more notifications: $e');
    } finally {
      if (mounted) setState(() => _isLoadingMore = true);
    }
  }

  Future<void> _deleteNotification(String notifId) async {
    try {
      await ref
          .read(notificationsRepositoryProvider)
          .deleteNotification(notifId);
      setState(() => _items.removeWhere((i) => i.notifId == notifId));
      _showSnackBar('Notification deleted');
    } catch (e) {
      _showSnackBar('Failed to delete notification: $e');
    }
  }

  Future<void> _clearAll(String uid) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear all notifications'),
        content: const Text(
          'Are you sure you want to permanently delete all notifications?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Clear'),
          ),
        ],
      ),
    );
    if (confirm != true) return;

    try {
      await ref
          .read(notificationsRepositoryProvider)
          .clearAllNotifications(uid);
      setState(() {
        _items.clear();
        _lastDoc = null;
        _hasMore = false;
      });
      _showSnackBar('All notifications cleared');
    } catch (e) {
      _showSnackBar('Failed to clear notifications: $e');
    }
  }

  void _showSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final userAsync = ref.watch(currentUserProvider);

    return userAsync.when(
      data: (user) {
        if (user == null) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (context.mounted) context.go('/login');
          });
          return const Scaffold(body: SizedBox.shrink());
        }

        // Trigger initial load when user changes
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (_currentUid != user.uid) {
            _currentUid = user.uid;
            _loadInitial(user.uid);
          }
        });

        return Scaffold(
          appBar: AppBar(
            leading: const AppBackButton(fallbackRoute: '/home'),
            title: const Text('Notifications'),
            actions: [
              TextButton(
                onPressed: () async {
                  // Optimistic UI update
                  setState(() {
                    for (var i = 0; i < _items.length; i++) {
                      _items[i] = _items[i].copyWith(isRead: true);
                    }
                  });

                  try {
                    await ref
                        .read(notificationsRepositoryProvider)
                        .markAllAsRead(user.uid);
                    _showSnackBar('All notifications marked as read');
                  } catch (e) {
                    _showSnackBar('Error marking notifications as read: $e');
                  }
                },
                child: const Text('Mark all read'),
              ),
              TextButton(
                onPressed: () => _clearAll(user.uid),
                child: const Text('Clear all'),
              ),
            ],
          ),
          body: ResponsiveLayout(
            child: Builder(
              builder: (context) {
                if (_isLoading) {
                  return ListView.separated(
                    padding: const EdgeInsets.all(12),
                    itemCount: 8,
                    separatorBuilder: (_, _) => const SizedBox(height: 8),
                    itemBuilder: (context, index) => const NotificationSkeleton(),
                  );
                }

                if (_items.isEmpty) {
                  return const EmptyState(
                    title: 'No notifications',
                    subtitle: 'New updates will appear here.',
                    icon: Icons.notifications_none_rounded,
                  );
                }

                return ListView.separated(
                  padding: const EdgeInsets.all(12),
                  itemCount: _items.length + (_hasMore ? 1 : 0),
                  separatorBuilder: (_, _) => const SizedBox(height: 8),
                  itemBuilder: (context, index) {
                    if (index >= _items.length) {
                      return Center(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          child: _isLoadingMore
                              ? const NotificationSkeleton()
                              : TextButton(
                                  onPressed: () => _loadMore(user.uid),
                                  child: const Text('Load more'),
                                ),
                        ),
                      );
                    }

                    final item = _items[index];
                    final unread = !item.isRead;

                    return ResponsiveCard(
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12),
                          border: Border(
                            left: BorderSide(
                              color: unread
                                  ? Theme.of(context).colorScheme.primary
                                  : Colors.transparent,
                              width: 4,
                            ),
                          ),
                        ),
                        child: Card(
                          margin: EdgeInsets.zero,
                          child: NotificationTile(
                            notification: item,
                            onTap: () async {
                              // Optimistic UI update
                              setState(() {
                                final idx = _items.indexWhere(
                                  (i) => i.notifId == item.notifId,
                                );
                                if (idx != -1) {
                                  _items[idx] = _items[idx].copyWith(
                                    isRead: true,
                                  );
                                }
                              });

                              try {
                                await ref
                                    .read(notificationsRepositoryProvider)
                                    .markAsRead(item.notifId);
                              } catch (_) {}

                              final route = item.targetRoute.trim();
                              if (route.isNotEmpty && context.mounted) {
                                context.go(route);
                              }
                            },
                            onDelete: () => _deleteNotification(item.notifId),
                          ),
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        );
      },
      loading: () => const Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      ),
      error: (error, _) => Scaffold(
        appBar: AppBar(title: const Text('Notifications')),
        body: EmptyState(title: 'Unable to load profile', subtitle: '$error'),
      ),
    );
  }
}
