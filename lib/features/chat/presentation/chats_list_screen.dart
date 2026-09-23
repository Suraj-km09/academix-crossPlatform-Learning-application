import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../features/auth/domain/auth_providers.dart';
import '../../admin/domain/admin_providers.dart';
import '../../../shared/providers/storage_image_providers.dart';
import '../../../shared/widgets/app_back_button.dart';
import '../../../shared/widgets/empty_state.dart';
import '../../../shared/widgets/skeleton_loader.dart';
import '../data/chat_model.dart';
import '../domain/chat_providers.dart';

class ChatsListScreen extends ConsumerStatefulWidget {
  const ChatsListScreen({super.key});

  @override
  ConsumerState<ChatsListScreen> createState() => _ChatsListScreenState();
}

class _ChatsListScreenState extends ConsumerState<ChatsListScreen> {
  @override
  Widget build(BuildContext context) {
    final userAsync = ref.watch(currentUserStreamProvider);
    final controlAsync = ref.watch(chatMessagingControlConfigProvider);

    return userAsync.when(
      data: (user) {
        if (user == null) {
          return const Scaffold(
            body: EmptyState(
              title: 'Login required',
              subtitle: 'Please login to access chats.',
            ),
          );
        }

        final chatsAsync = ref.watch(userChatsProvider(user.uid));

        return DefaultTabController(
          length: 2,
          child: Scaffold(
            appBar: AppBar(
              leading: const AppBackButton(fallbackRoute: '/home'),
              title: const Text('Chats'),
              bottom: const TabBar(
                tabs: [
                  Tab(text: 'Direct'),
                  Tab(text: 'Groups'),
                ],
              ),
            ),
            floatingActionButton: FloatingActionButton(
              onPressed: () async {
                final role = user.role.trim().toLowerCase();
                final canCreateGroup = role == 'teacher' || role == 'admin';

                final action = await showModalBottomSheet<String>(
                  context: context,
                  builder: (sheetContext) {
                    return SafeArea(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          ListTile(
                            leading: const Icon(Icons.person_add_alt_rounded),
                            title: const Text('New Direct Message'),
                            onTap: () =>
                                Navigator.of(sheetContext).pop('direct'),
                          ),
                          ListTile(
                            leading: const Icon(Icons.link_rounded),
                            title: const Text('Join Group via Link'),
                            onTap: () =>
                                Navigator.of(sheetContext).pop('join_link'),
                          ),
                          if (canCreateGroup)
                            ListTile(
                              leading: const Icon(Icons.groups_rounded),
                              title: const Text('Create Group'),
                              onTap: () =>
                                  Navigator.of(sheetContext).pop('group'),
                            ),
                        ],
                      ),
                    );
                  },
                );

                if (action == null) {
                  return;
                }

                if (!context.mounted) {
                  return;
                }

                if (action == 'direct') {
                  final control = controlAsync.maybeWhen(
                    data: (c) => c,
                    orElse: () => null,
                  );
                  final roleKey = user.role.trim().toLowerCase();
                  final disabledUsers = _toTrimmedStringSet(
                    control?['chatMessagingDisabledUserUids'],
                  );
                  final blockedRolesRaw = control?['chatMessagingBlockedRoles'];
                  var directBlocked = false;
                  if (disabledUsers.contains(user.uid)) directBlocked = true;
                  if (blockedRolesRaw is Map) {
                    if (blockedRolesRaw['all'] == true) directBlocked = true;
                    if (blockedRolesRaw[roleKey] == true) directBlocked = true;
                  } else {
                    final mode =
                        (control?['chatMessagingRestrictionMode'] as String? ??
                                '')
                            .toString()
                            .trim()
                            .toLowerCase();
                    if (mode == 'all_users') directBlocked = true;
                    if (mode == 'only_students' && roleKey == 'student')
                      directBlocked = true;
                    if (mode == 'only_teachers' && roleKey == 'teacher')
                      directBlocked = true;
                    if (mode == 'only_alumni' && roleKey == 'alumni')
                      directBlocked = true;
                  }

                  if (directBlocked) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Direct messaging is disabled by admin.'),
                      ),
                    );
                    return;
                  }
                }

                final created = await context.push(switch (action) {
                  'group' => '/chat/create-group',
                  'join_link' => '/chat/join-group',
                  _ => '/chat/new-direct',
                });
                if (created == true) {
                  await ref
                      .read(userChatsProvider(user.uid).notifier)
                      .refresh();
                }
              },
              child: const Icon(Icons.edit_square),
            ),
            body: chatsAsync.when(
              data: (chats) {
                final direct = chats.where((chat) => !chat.isGroup).toList();
                final groups = chats.where((chat) => chat.isGroup).toList();

                return controlAsync.when(
                  data: (control) {
                    final roleKey = user.role.trim().toLowerCase();
                    final disabledUsers = _toTrimmedStringSet(
                      control['chatMessagingDisabledUserUids'],
                    );
                    final blockedRolesRaw =
                        control['chatMessagingBlockedRoles'];
                    var directBlocked = false;
                    if (disabledUsers.contains(user.uid)) directBlocked = true;
                    if (blockedRolesRaw is Map) {
                      if (blockedRolesRaw['all'] == true) directBlocked = true;
                      if (blockedRolesRaw[roleKey] == true)
                        directBlocked = true;
                    } else {
                      final mode =
                          (control['chatMessagingRestrictionMode'] as String? ??
                                  '')
                              .toString()
                              .trim()
                              .toLowerCase();
                      if (mode == 'all_users') directBlocked = true;
                      if (mode == 'only_students' && roleKey == 'student')
                        directBlocked = true;
                      if (mode == 'only_teachers' && roleKey == 'teacher')
                        directBlocked = true;
                      if (mode == 'only_alumni' && roleKey == 'alumni')
                        directBlocked = true;
                    }

                    return RefreshIndicator(
                      onRefresh: () async {
                        await ref
                            .read(userChatsProvider(user.uid).notifier)
                            .refresh();
                      },
                      child: TabBarView(
                        children: [
                          _ChatsTab(
                            currentUid: user.uid,
                            chats: direct,
                            isDirectBlocked: directBlocked,
                            showBlockedBanner: true,
                          ),
                          _ChatsTab(currentUid: user.uid, chats: groups),
                        ],
                      ),
                    );
                  },
                  loading: () => ListView.separated(
                    padding: const EdgeInsets.all(12),
                    itemCount: 8,
                    separatorBuilder: (_, _) => const SizedBox(height: 8),
                    itemBuilder: (context, index) => const ChatTileSkeleton(),
                  ),
                  error: (error, _) => EmptyState(
                    title: 'Unable to load messaging controls',
                    subtitle: '$error',
                  ),
                );
              },
              loading: () => ListView.separated(
                padding: const EdgeInsets.all(12),
                itemCount: 8,
                separatorBuilder: (_, _) => const SizedBox(height: 8),
                itemBuilder: (context, index) => const ChatTileSkeleton(),
              ),
              error: (error, _) =>
                  EmptyState(title: 'Unable to load chats', subtitle: '$error'),
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
        body: EmptyState(title: 'Unable to load profile', subtitle: '$error'),
      ),
    );
  }

  Set<String> _toTrimmedStringSet(dynamic value) {
    if (value is Set) {
      return value
          .map((item) => item.toString().trim())
          .where((item) => item.isNotEmpty)
          .toSet();
    }
    if (value is List) {
      return value
          .map((item) => item.toString().trim())
          .where((item) => item.isNotEmpty)
          .toSet();
    }
    return <String>{};
  }
}

class _ChatsTab extends ConsumerStatefulWidget {
  const _ChatsTab({
    required this.currentUid,
    required this.chats,
    this.isDirectBlocked = false,
    this.showBlockedBanner = false,
  });

  final String currentUid;
  final List<ChatModel> chats;
  final bool isDirectBlocked;
  final bool showBlockedBanner;

  @override
  ConsumerState<_ChatsTab> createState() => _ChatsTabState();
}

class _ChatsTabState extends ConsumerState<_ChatsTab> {
  late final ScrollController _scrollController;
  bool _isLoadingMore = false;
  Timer? _scrollDebounce;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController()..addListener(_onScroll);
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    final pos = _scrollController.position;
    if (pos.pixels < pos.maxScrollExtent - 120) return;

    if (_scrollDebounce?.isActive == true) return;
    _scrollDebounce = Timer(const Duration(milliseconds: 200), () {
      _tryLoadMore();
    });
  }

  Future<void> _tryLoadMore() async {
    if (_isLoadingMore) return;
    final notifier = ref.read(userChatsProvider(widget.currentUid).notifier);
    setState(() => _isLoadingMore = true);
    try {
      await notifier.loadMore();
    } finally {
      if (mounted) setState(() => _isLoadingMore = false);
    }
  }

  @override
  void dispose() {
    _scrollDebounce?.cancel();
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final chats = widget.chats;

    return Column(
      children: [
        if (widget.showBlockedBanner && widget.isDirectBlocked)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            color: Theme.of(context).colorScheme.errorContainer,
            child: Row(
              children: [
                Icon(
                  Icons.info_outline,
                  color: Theme.of(context).colorScheme.onErrorContainer,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Admin has disabled direct messaging. You can still send messages in groups.',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onErrorContainer,
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),
        Expanded(
          child: chats.isEmpty
              ? const EmptyState(
                  title: 'No chats yet',
                  subtitle: 'Start a direct conversation or join a group chat.',
                  icon: Icons.forum_outlined,
                )
              : ListView.separated(
                  controller: _scrollController,
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.all(12),
                  itemCount: chats.length + (_isLoadingMore ? 1 : 0),
                  separatorBuilder: (_, _) => const SizedBox(height: 8),
                  itemBuilder: (_, index) {
                    if (index < chats.length) {
                      final chat = chats[index];
                      return _ChatTile(
                        chat: chat,
                        currentUid: widget.currentUid,
                        isDirectBlocked: widget.isDirectBlocked,
                      );
                    }
                    return const ChatTileSkeleton();
                  },
                ),
        ),
      ],
    );
  }
}

class _ChatTile extends ConsumerWidget {
  const _ChatTile({
    required this.chat,
    required this.currentUid,
    this.isDirectBlocked = false,
  });

  final ChatModel chat;
  final String currentUid;
  final bool isDirectBlocked;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final unreadCount = chat.unreadCountFor(currentUid);

    final otherUid = chat.participants.firstWhere(
      (uid) => uid != currentUid,
      orElse: () => '',
    );
    final title = chat.isGroup
        ? (chat.groupName?.trim().isNotEmpty == true
              ? chat.groupName!
              : 'Group Chat')
        : (chat.participantNames[otherUid]?.trim().isNotEmpty == true
              ? chat.participantNames[otherUid]!
              : 'Direct Chat');

    final avatarPath = chat.participantPhotoUrls[otherUid];

    return Card(
      child: ListTile(
        onTap: () {
          if (!chat.isGroup && isDirectBlocked) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Direct messaging is disabled by admin.'),
              ),
            );
            return;
          }
          context.push('/chat/${chat.chatId}', extra: chat);
        },
        leading: _Avatar(
          pathOrUrl: chat.isGroup ? chat.groupIconUrl : avatarPath,
          fallbackName: title,
        ),
        title: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis),
        subtitle: Text(
          chat.lastMessage.trim().isEmpty
              ? 'No messages yet'
              : chat.lastMessage,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              _formatTime(chat.lastMessageAt),
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 4),
            if (unreadCount <= 0)
              const SizedBox(height: 16)
            else
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primary,
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Text(
                  '$unreadCount',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  static String _formatTime(DateTime value) {
    final now = DateTime.now();
    final sameDay =
        value.year == now.year &&
        value.month == now.month &&
        value.day == now.day;
    if (sameDay) {
      return DateFormat('hh:mm a').format(value);
    }
    return DateFormat('dd MMM').format(value);
  }
}

class _Avatar extends StatelessWidget {
  const _Avatar({required this.pathOrUrl, required this.fallbackName});

  final String? pathOrUrl;
  final String fallbackName;

  @override
  Widget build(BuildContext context) {
    final value = (pathOrUrl ?? '').trim();
    if (value.isEmpty) {
      return CircleAvatar(child: Text(_initial(fallbackName)));
    }

    return Consumer(
      builder: (context, ref, _) {
        final urlAsync = ref.watch(resolvedStorageUrlProvider(value));
        return urlAsync.when(
          data: (url) {
            if (url != null && url.trim().isNotEmpty) {
              return CircleAvatar(backgroundImage: NetworkImage(url));
            }
            return CircleAvatar(child: Text(_initial(fallbackName)));
          },
          loading: () => CircleAvatar(child: Text(_initial(fallbackName))),
          error: (e, st) => CircleAvatar(child: Text(_initial(fallbackName))),
        );
      },
    );
  }

  static String _initial(String text) {
    if (text.trim().isEmpty) {
      return '?';
    }
    return text.trim().substring(0, 1).toUpperCase();
  }
}
