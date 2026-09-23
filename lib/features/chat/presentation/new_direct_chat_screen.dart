import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../features/auth/domain/auth_providers.dart';
import '../../admin/domain/admin_providers.dart';
import '../../../shared/providers/storage_image_providers.dart';
import '../../../shared/widgets/app_back_button.dart';
import '../../../shared/widgets/empty_state.dart';
import '../../../shared/widgets/loading_widget.dart';
import '../../../shared/models/user_model.dart';
import '../domain/chat_providers.dart';

class NewDirectChatScreen extends ConsumerStatefulWidget {
  const NewDirectChatScreen({super.key});

  @override
  ConsumerState<NewDirectChatScreen> createState() =>
      _NewDirectChatScreenState();
}

class _NewDirectChatScreenState extends ConsumerState<NewDirectChatScreen> {
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  Timer? _scrollDebounce;
  bool _searchInitialized = false;
  String? _openingUid;

  @override
  void dispose() {
    _scrollDebounce?.cancel();
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    final pos = _scrollController.position;
    if (pos.pixels < pos.maxScrollExtent - 120) return;

    if (_scrollDebounce?.isActive == true) return;
    _scrollDebounce = Timer(const Duration(milliseconds: 200), () async {
      final currentUser = ref.read(currentUserStreamProvider).asData?.value;
      if (currentUser == null) return;
      final key = (
        collegeId: currentUser.collegeId,
        currentUid: currentUser.uid,
      );
      ref.read(directUserSearchProvider(key).notifier).loadMore();
    });
  }

  @override
  Widget build(BuildContext context) {
    final currentUserAsync = ref.watch(currentUserStreamProvider);
    final controlAsync = ref.watch(chatMessagingControlConfigProvider);

    return currentUserAsync.when(
      data: (currentUser) {
        if (currentUser == null) {
          return const Scaffold(
            body: EmptyState(
              title: 'Login required',
              subtitle: 'Please login to start chats.',
            ),
          );
        }

        final searchKey = (
          collegeId: currentUser.collegeId,
          currentUid: currentUser.uid,
        );
        final searchState = ref.watch(directUserSearchProvider(searchKey));
        final searchNotifier = ref.read(
          directUserSearchProvider(searchKey).notifier,
        );
        if (!_searchInitialized) {
          _searchInitialized = true;
          // kick off initial empty search
          searchNotifier.setQuery('');
        }

        return Scaffold(
          appBar: AppBar(
            leading: const AppBackButton(fallbackRoute: '/chats'),
            title: const Text('New Direct Message'),
          ),
          body: controlAsync.when(
            data: (control) {
              final roleKey = currentUser.role.trim().toLowerCase();
              final disabledUsers = _toTrimmedStringSet(
                control['chatMessagingDisabledUserUids'],
              );
              final blockedRolesRaw = control['chatMessagingBlockedRoles'];
              var directBlocked = false;
              if (disabledUsers.contains(currentUser.uid)) directBlocked = true;
              if (blockedRolesRaw is Map) {
                if (blockedRolesRaw['all'] == true) directBlocked = true;
                if (blockedRolesRaw[roleKey] == true) directBlocked = true;
              } else {
                final mode =
                    (control['chatMessagingRestrictionMode'] as String? ?? '')
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
                return const EmptyState(
                  title: 'Messaging Disabled',
                  subtitle:
                      'Admin has disabled direct messaging for your account or role. You can still message in groups.',
                  icon: Icons.block_flipped,
                );
              }

              return SafeArea(
                child: Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(12, 10, 12, 8),
                      child: TextField(
                        controller: _searchController,
                        decoration: const InputDecoration(
                          hintText: 'Search by name in your college...',
                          prefixIcon: Icon(Icons.search_rounded),
                        ),
                        onChanged: _onQueryChanged,
                      ),
                    ),
                    Expanded(
                      child: searchState.when(
                        data: (users) {
                          if (users.isEmpty) {
                            return const EmptyState(
                              title: 'No users found',
                              subtitle: 'Try another name.',
                              icon: Icons.person_search_rounded,
                            );
                          }

                          return RefreshIndicator(
                            onRefresh: () async {
                              await searchNotifier.refresh();
                            },
                            child: ListView.separated(
                              controller: _scrollController
                                ..addListener(() {
                                  if (_scrollController.position.pixels >=
                                      _scrollController
                                              .position
                                              .maxScrollExtent -
                                          120) {
                                    searchNotifier.loadMore();
                                  }
                                }),
                              physics: const AlwaysScrollableScrollPhysics(),
                              padding: const EdgeInsets.all(12),
                              itemCount: users.length,
                              separatorBuilder: (_, _) =>
                                  const SizedBox(height: 8),
                              itemBuilder: (_, index) {
                                final user = users[index];
                                final opening = _openingUid == user.uid;
                                return Card(
                                  child: ListTile(
                                    leading: _UserAvatar(
                                      pathOrUrl: user.photoUrl,
                                      name: user.name,
                                    ),
                                    title: Text(user.name),
                                    subtitle: Text(
                                      '${user.role} • ${user.course.isEmpty ? user.collegeName : user.course}',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    trailing: opening
                                        ? const SizedBox(
                                            width: 18,
                                            height: 18,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2,
                                            ),
                                          )
                                        : const Icon(
                                            Icons.chevron_right_rounded,
                                          ),
                                    onTap: opening
                                        ? null
                                        : () => _openDirectChat(
                                            currentUser,
                                            user,
                                          ),
                                  ),
                                );
                              },
                            ),
                          );
                        },
                        loading: () =>
                            const LoadingWidget(message: 'Searching users...'),
                        error: (e, _) =>
                            EmptyState(title: 'Search failed', subtitle: '$e'),
                      ),
                    ),
                  ],
                ),
              );
            },
            loading: () => const LoadingWidget(
              message: 'Checking messaging permissions...',
            ),
            error: (e, _) =>
                EmptyState(title: 'Unable to load permissions', subtitle: '$e'),
          ),
        );
      },
      loading: () =>
          const Scaffold(body: LoadingWidget(message: 'Loading profile...')),
      error: (error, _) => Scaffold(
        body: EmptyState(title: 'Unable to load profile', subtitle: '$error'),
      ),
    );
  }

  void _onQueryChanged(String value) {
    final currentUser = ref.read(currentUserStreamProvider).asData?.value;
    if (currentUser == null) return;
    final key = (collegeId: currentUser.collegeId, currentUid: currentUser.uid);
    ref.read(directUserSearchProvider(key).notifier).setQuery(value);
  }

  Future<void> _openDirectChat(UserModel currentUser, UserModel target) async {
    setState(() => _openingUid = target.uid);
    try {
      final chatId = await ref
          .read(chatRepositoryProvider)
          .getOrCreateDirectChat(
            currentUser.uid,
            target.uid,
            currentUser.collegeId,
          );

      if (!mounted) {
        return;
      }
      context.pushReplacement('/chat/$chatId');
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Unable to start chat: $error')));
    } finally {
      if (mounted) {
        setState(() => _openingUid = null);
      }
    }
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

class _UserAvatar extends ConsumerWidget {
  const _UserAvatar({required this.pathOrUrl, required this.name});

  final String? pathOrUrl;
  final String name;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final value = (pathOrUrl ?? '').trim();
    if (value.isEmpty) {
      return CircleAvatar(child: Text(_initial(name)));
    }

    final urlAsync = ref.watch(resolvedStorageUrlProvider(value));
    return urlAsync.when(
      data: (url) {
        if (url != null && url.trim().isNotEmpty) {
          return CircleAvatar(backgroundImage: NetworkImage(url));
        }
        return CircleAvatar(child: Text(_initial(name)));
      },
      loading: () => CircleAvatar(child: Text(_initial(name))),
      error: (e, st) => CircleAvatar(child: Text(_initial(name))),
    );
  }

  static String _initial(String text) {
    if (text.trim().isEmpty) {
      return '?';
    }
    return text.trim().substring(0, 1).toUpperCase();
  }
}
