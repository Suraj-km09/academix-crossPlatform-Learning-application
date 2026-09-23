import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/app_exception.dart';
import '../../../features/auth/domain/auth_providers.dart';
import '../../../shared/models/user_model.dart';
import '../../../shared/services/storage_image_cache_service.dart';
import '../../../shared/widgets/app_back_button.dart';
import '../../../shared/widgets/app_button.dart';
import '../../../shared/widgets/app_text_field.dart';
import '../../../shared/widgets/empty_state.dart';
import '../../../shared/widgets/loading_widget.dart';
import '../domain/chat_providers.dart';

class CreateGroupChatScreen extends ConsumerStatefulWidget {
  const CreateGroupChatScreen({super.key});

  @override
  ConsumerState<CreateGroupChatScreen> createState() =>
      _CreateGroupChatScreenState();
}

class _CreateGroupChatScreenState extends ConsumerState<CreateGroupChatScreen> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _searchController = TextEditingController();

  Timer? _debounce;
  String _query = '';
  Future<List<UserModel>>? _usersFuture;

  final Set<String> _selectedMemberUids = <String>{};
  String? _groupAdminUid;
  bool _creating = false;

  @override
  void dispose() {
    _debounce?.cancel();
    _nameController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final currentUserAsync = ref.watch(currentUserStreamProvider);

    return currentUserAsync.when(
      data: (currentUser) {
        if (currentUser == null) {
          return const Scaffold(
            body: EmptyState(
              title: 'Login required',
              subtitle: 'Please login to create group chats.',
            ),
          );
        }

        final role = currentUser.role.trim().toLowerCase();
        final canCreate = role == 'teacher' || role == 'admin';
        if (!canCreate) {
          return Scaffold(
            appBar: AppBar(
              leading: const AppBackButton(fallbackRoute: '/chats'),
              title: const Text('Create Group'),
            ),
            body: const EmptyState(
              title: 'Not allowed',
              subtitle: 'Only teacher or admin can create group chats.',
            ),
          );
        }

        _selectedMemberUids.add(currentUser.uid);
        _groupAdminUid ??= currentUser.uid;
        _usersFuture ??= _searchUsers(currentUser);

        return Scaffold(
          appBar: AppBar(
            leading: const AppBackButton(fallbackRoute: '/chats'),
            title: const Text('Create Group'),
          ),
          body: SafeArea(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 10, 12, 8),
                  child: AppTextField(
                    controller: _nameController,
                    label: 'Group Name',
                    hint: 'e.g. Placement Community',
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
                  child: AppTextField(
                    controller: _searchController,
                    label: 'Search Members',
                    hint: 'Search users in your college',
                    onChanged: _onSearchChanged,
                    prefixIcon: Icons.search_rounded,
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
                  child: Row(
                    children: [
                      const Text('Group Admin:'),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _AdminDropdown(
                          selectedUid: _groupAdminUid,
                          selectedUids: _selectedMemberUids.toList(),
                          onChanged: (value) {
                            if (value == null || value.trim().isEmpty) {
                              return;
                            }
                            setState(() => _groupAdminUid = value);
                          },
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: FutureBuilder<List<UserModel>>(
                    future: _usersFuture,
                    builder: (_, snapshot) {
                      if (snapshot.connectionState != ConnectionState.done) {
                        return const LoadingWidget(
                          message: 'Loading college users...',
                        );
                      }

                      if (snapshot.hasError) {
                        return EmptyState(
                          title: 'Unable to load users',
                          subtitle: '${snapshot.error}',
                        );
                      }

                      final users = snapshot.data ?? const <UserModel>[];
                      if (users.isEmpty) {
                        return const EmptyState(
                          title: 'No users found',
                          subtitle: 'Try a different search query.',
                          icon: Icons.person_search_rounded,
                        );
                      }

                      return ListView.separated(
                        padding: const EdgeInsets.all(12),
                        itemCount: users.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 6),
                        itemBuilder: (_, index) {
                          final user = users[index];
                          final selected = _selectedMemberUids.contains(
                            user.uid,
                          );

                          return Card(
                            child: CheckboxListTile(
                              value: selected,
                              onChanged: (value) {
                                if (value == null) {
                                  return;
                                }
                                setState(() {
                                  if (value) {
                                    _selectedMemberUids.add(user.uid);
                                  } else {
                                    _selectedMemberUids.remove(user.uid);
                                    if (_groupAdminUid == user.uid) {
                                      _groupAdminUid = currentUser.uid;
                                    }
                                  }
                                });
                              },
                              title: Text(user.name),
                              subtitle: Text(
                                '${user.role} • ${user.course.isEmpty ? user.collegeName : user.course}',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              secondary: _Avatar(
                                pathOrUrl: user.photoUrl,
                                name: user.name,
                              ),
                            ),
                          );
                        },
                      );
                    },
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
                  child: AppButton(
                    label: _creating ? 'Creating...' : 'Create Group',
                    isLoading: _creating,
                    onPressed: _creating
                        ? null
                        : () => _createGroup(
                            currentUser.uid,
                            currentUser.collegeId,
                          ),
                  ),
                ),
              ],
            ),
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

  void _onSearchChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), () async {
      final currentUser = await ref.read(currentUserStreamProvider.future);
      if (!mounted || currentUser == null) {
        return;
      }
      setState(() {
        _query = value.trim();
        _usersFuture = _searchUsers(currentUser);
      });
    });
  }

  Future<List<UserModel>> _searchUsers(UserModel currentUser) {
    return ref
        .read(chatRepositoryProvider)
        .searchUsersInCollege(
          collegeId: currentUser.collegeId,
          query: _query,
          currentUid: '',
        );
  }

  Future<void> _createGroup(String creatorUid, String collegeId) async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      _showSnack('Group name is required');
      return;
    }

    if (_selectedMemberUids.length < 2) {
      _showSnack('Select at least 2 members for a group');
      return;
    }

    final groupAdminUid = _groupAdminUid;
    if (groupAdminUid == null || !_selectedMemberUids.contains(groupAdminUid)) {
      _showSnack('Please select a valid group admin');
      return;
    }

    setState(() => _creating = true);
    try {
      await ref
          .read(chatRepositoryProvider)
          .createGroupChat(
            name: name,
            participantUids: _selectedMemberUids.toList(),
            creatorUid: creatorUid,
            collegeId: collegeId,
            groupAdminUid: groupAdminUid,
          );

      if (!mounted) {
        return;
      }
      _showSnack('Group created');
      Navigator.of(context).pop(true);
    } on AppException catch (error) {
      _showSnack(error.message);
    } catch (error) {
      _showSnack('Failed to create group: $error');
    } finally {
      if (mounted) {
        setState(() => _creating = false);
      }
    }
  }

  void _showSnack(String message) {
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }
}

class _AdminDropdown extends ConsumerWidget {
  const _AdminDropdown({
    required this.selectedUid,
    required this.selectedUids,
    required this.onChanged,
  });

  final String? selectedUid;
  final List<String> selectedUids;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final items = selectedUids.toSet().toList();
    if (items.isEmpty) {
      return const SizedBox.shrink();
    }

    return DropdownButtonFormField<String>(
      initialValue: (selectedUid != null && items.contains(selectedUid))
          ? selectedUid
          : items.first,
      isExpanded: true,
      items: items
          .map(
            (uid) => DropdownMenuItem<String>(
              value: uid,
              child: _MemberName(uid: uid),
            ),
          )
          .toList(),
      onChanged: onChanged,
    );
  }
}

class _MemberName extends ConsumerWidget {
  const _MemberName({required this.uid});

  final String uid;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncUser = ref.watch(chatUserProvider(uid));
    return asyncUser.when(
      data: (user) => Text(user?.name ?? uid, overflow: TextOverflow.ellipsis),
      loading: () => Text(uid, overflow: TextOverflow.ellipsis),
      error: (_, _) => Text(uid, overflow: TextOverflow.ellipsis),
    );
  }
}

class _Avatar extends StatelessWidget {
  const _Avatar({required this.pathOrUrl, required this.name});

  final String? pathOrUrl;
  final String name;

  @override
  Widget build(BuildContext context) {
    final value = (pathOrUrl ?? '').trim();
    if (value.isEmpty) {
      return CircleAvatar(child: Text(_initial(name)));
    }

    return FutureBuilder<String?>(
      future: StorageImageCacheService.resolveDownloadUrl(value),
      builder: (_, snapshot) {
        final url = snapshot.data;
        if (url != null && url.trim().isNotEmpty) {
          return CircleAvatar(backgroundImage: NetworkImage(url));
        }
        return CircleAvatar(child: Text(_initial(name)));
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
