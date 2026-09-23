import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/domain/auth_providers.dart';
import '../../../shared/models/user_model.dart';
import '../../../shared/widgets/app_back_button.dart';
import '../../../shared/widgets/loading_widget.dart';
import '../domain/admin_providers.dart';

class UserManagementScreen extends ConsumerStatefulWidget {
  const UserManagementScreen({super.key});

  @override
  ConsumerState<UserManagementScreen> createState() =>
      _UserManagementScreenState();
}

class _UserManagementScreenState extends ConsumerState<UserManagementScreen> {
  static const int _usersPageSize = 30;

  String? _roleFilter;
  String _statusFilter = 'all'; // 'all', 'active', 'banned'
  String? _searchQuery;
  final TextEditingController _searchController = TextEditingController();

  final List<UserModel> _users = [];
  DocumentSnapshot<Map<String, dynamic>>? _lastUserDocument;
  bool _hasMoreUsers = true;
  bool _isLoadingUsers = false;
  bool _isLoadingMoreUsers = false;
  String? _userLoadError;

  @override
  void initState() {
    super.initState();
    _loadUsers(reset: true);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _clearSearch() {
    if (_searchQuery != null || _searchController.text.isNotEmpty) {
      setState(() {
        _searchQuery = null;
        _searchController.clear();
      });
      _loadUsers(reset: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final profileAsync = ref.watch(currentUserProvider);

    return profileAsync.when(
      data: (profile) {
        final adminUid = profile?.uid ?? '';

        if (profile == null || profile.role != 'admin') {
          return Scaffold(
            appBar: AppBar(
              leading: const AppBackButton(fallbackRoute: '/admin'),
              title: const Text('User Management'),
            ),
            body: const Center(
              child: Text('Only admins can access user management.'),
            ),
          );
        }

        return Scaffold(
          appBar: AppBar(
            leading: const AppBackButton(fallbackRoute: '/admin'),
            title: const Text('User Management'),
            actions: [
              IconButton(
                icon: const Icon(Icons.refresh),
                onPressed: () => _loadUsers(reset: true),
                tooltip: 'Refresh',
              ),
            ],
          ),
          body: Column(
            children: [
              // Search and Filter Bar
              Container(
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
                color: Theme.of(context).colorScheme.surface,
                child: Column(
                  children: [
                    TextField(
                      controller: _searchController,
                      decoration: InputDecoration(
                        hintText: 'Search by Name or Email...',
                        prefixIcon: const Icon(Icons.search),
                        suffixIcon: _searchController.text.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.clear),
                                onPressed: _clearSearch,
                              )
                            : null,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                      ),
                      textInputAction: TextInputAction.search,
                      onSubmitted: (value) {
                        setState(() {
                          _searchQuery = value.trim().isNotEmpty
                              ? value.trim()
                              : null;
                        });
                        _loadUsers(reset: true);
                      },
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            value: _statusFilter,
                            decoration: InputDecoration(
                              labelText: 'Status',
                              isDense: true,
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            items: const [
                              DropdownMenuItem(
                                value: 'all',
                                child: Text('All Status'),
                              ),
                              DropdownMenuItem(
                                value: 'active',
                                child: Text('Active Only'),
                              ),
                              DropdownMenuItem(
                                value: 'banned',
                                child: Text('Banned Only'),
                              ),
                            ],
                            onChanged: (value) {
                              if (value != null) {
                                setState(() => _statusFilter = value);
                                _loadUsers(reset: true);
                              }
                            },
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            value: _roleFilter ?? 'all',
                            decoration: InputDecoration(
                              labelText: 'Role',
                              isDense: true,
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            items: const [
                              DropdownMenuItem(
                                value: 'all',
                                child: Text('All Roles'),
                              ),
                              DropdownMenuItem(
                                value: 'student',
                                child: Text('Student'),
                              ),
                              DropdownMenuItem(
                                value: 'teacher',
                                child: Text('Teacher'),
                              ),
                              DropdownMenuItem(
                                value: 'alumni',
                                child: Text('Alumni'),
                              ),
                              DropdownMenuItem(
                                value: 'admin',
                                child: Text('Admin'),
                              ),
                            ],
                            onChanged: (value) {
                              setState(() {
                                _roleFilter = (value == 'all' || value == null)
                                    ? null
                                    : value;
                              });
                              _loadUsers(reset: true);
                            },
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                  ],
                ),
              ),
              const Divider(height: 1),
              // User List
              Expanded(child: _buildUsersSection(adminUid)),
            ],
          ),
        );
      },
      loading: () =>
          const Scaffold(body: LoadingWidget(message: 'Loading profile...')),
      error: (error, _) => Scaffold(
        appBar: AppBar(
          leading: const AppBackButton(fallbackRoute: '/admin'),
          title: const Text('User Management'),
        ),
        body: Center(child: Text('Error loading profile: $error')),
      ),
    );
  }

  Future<void> _handleUserAction({
    required String adminUid,
    required UserModel user,
    required String action,
  }) async {
    final repo = ref.read(adminRepositoryProvider);

    try {
      if (action == 'ban') {
        await repo.banUser(user.uid, adminUid: adminUid);
      } else if (action == 'unban') {
        await repo.unbanUser(user.uid, adminUid: adminUid);
      } else if (action == 'delete') {
        final confirmed = await _confirmDeleteUser(user);
        if (confirmed == true) {
          await repo.deleteUser(user.uid, adminUid: adminUid);
        } else {
          return;
        }
      } else if (action == 'verify_alumni') {
        await repo.verifyAlumni(user.uid, adminUid: adminUid);
      } else if (action == 'toggle_notes_upload_access') {
        await repo.setNotesUploadAccess(
          user.uid,
          canUpload: !user.canUploadNotesPyqs,
          adminUid: adminUid,
        );
      } else if (action == 'change_role') {
        final selectedRole = await _showRoleSelector(user.role);
        if (selectedRole != null && selectedRole != user.role) {
          await repo.changeUserRole(user.uid, selectedRole, adminUid: adminUid);
        }
      } else if (action == 'approve_teacher') {
        await repo.approveTeacherRequest(user.uid, adminUid: adminUid);
      } else if (action == 'reject_teacher') {
        await repo.rejectTeacherRequest(user.uid, adminUid: adminUid);
      } else if (action == 'delete_uploads') {
        final confirmed = await _confirmDeleteUploads(user);
        if (confirmed != true) return;

        final result = await repo.deleteAllResourcesByUploader(
          adminUid: adminUid,
          uploaderUid: user.uid,
        );

        if (!mounted) return;

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Deleted uploads - Notes: ${result['notes']}, Curriculum: ${result['curriculum']}, Bulletins: ${result['bulletins']}',
            ),
          ),
        );
        return;
      }

      await _loadUsers(reset: true);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Action completed successfully.')),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Action failed: $error')));
    }
  }

  Future<bool?> _confirmDeleteUser(UserModel user) {
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete User'),
        content: Text(
          'Are you sure you want to permanently delete ${user.name}? This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  Future<void> _loadUsers({required bool reset}) async {
    if (!reset && (!_hasMoreUsers || _isLoadingMoreUsers)) {
      return;
    }

    setState(() {
      if (reset) {
        _isLoadingUsers = true;
        _hasMoreUsers = true;
        _lastUserDocument = null;
      } else {
        _isLoadingMoreUsers = true;
      }
      _userLoadError = null;
    });

    try {
      final page = await ref
          .read(adminRepositoryProvider)
          .fetchUsersPage(
            role: _roleFilter,
            collegeId: null,
            search: _searchQuery,
            pageSize: _usersPageSize,
            startAfter: reset ? null : _lastUserDocument,
            isBanned: _statusFilter == 'all'
                ? null
                : (_statusFilter == 'banned'),
          );

      if (!mounted) return;

      setState(() {
        _lastUserDocument = page.lastDocument;
        _hasMoreUsers = page.hasMore;
        if (reset) {
          _users.clear();
          _users.addAll(page.users);
        } else {
          final existingIds = _users.map((item) => item.uid).toSet();
          for (final user in page.users) {
            if (existingIds.add(user.uid)) {
              _users.add(user);
            }
          }
          _users.sort(
            (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
          );
        }
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _userLoadError =
            'Failed to load users. You may need to create a Firestore index for this filter combination.\n\nError: $error';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingUsers = false;
          _isLoadingMoreUsers = false;
        });
      }
    }
  }

  Widget _buildUsersSection(String adminUid) {
    if (_isLoadingUsers && _users.isEmpty) {
      return const LoadingWidget(message: 'Loading users...');
    }

    if (_userLoadError != null && _users.isEmpty) {
      return Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, color: Colors.red, size: 48),
              const SizedBox(height: 16),
              Text(
                _userLoadError!,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 14),
              ),
              const SizedBox(height: 20),
              FilledButton.icon(
                onPressed: () => _loadUsers(reset: true),
                icon: const Icon(Icons.refresh),
                label: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    if (_users.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.person_search, size: 64, color: Colors.grey),
            const SizedBox(height: 16),
            const Text(
              'No users found matching your filters.',
              style: TextStyle(color: Colors.grey, fontSize: 16),
            ),
            if (_searchQuery != null ||
                _roleFilter != null ||
                _statusFilter != 'all')
              TextButton(
                onPressed: () {
                  setState(() {
                    _searchQuery = null;
                    _searchController.clear();
                    _roleFilter = null;
                    _statusFilter = 'all';
                  });
                  _loadUsers(reset: true);
                },
                child: const Text('Clear All Filters'),
              ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: _users.length + 1,
      itemBuilder: (context, index) {
        if (index == _users.length) {
          return _buildLoadMoreButton();
        }

        final user = _users[index];
        return Card(
          margin: const EdgeInsets.only(bottom: 10),
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: user.isBanned ? Colors.red.shade100 : null,
              child: Text(
                user.name.isNotEmpty
                    ? user.name.substring(0, 1).toUpperCase()
                    : 'U',
                style: TextStyle(color: user.isBanned ? Colors.red : null),
              ),
            ),
            title: Row(
              children: [
                Expanded(child: Text(user.name)),
                if (user.isBanned)
                  const ContainerBadge(text: 'BANNED', color: Colors.red),
              ],
            ),
            subtitle: Text(
              '${user.email}\n'
              'Role: ${user.role} • Verified: ${user.isVerified ? 'Yes' : 'No'}\n'
              'Teacher Req: ${user.teacherRequestStatus}',
            ),
            isThreeLine: true,
            trailing: PopupMenuButton<String>(
              onSelected: (value) async {
                await _handleUserAction(
                  adminUid: adminUid,
                  user: user,
                  action: value,
                );
              },
              itemBuilder: (_) => [
                PopupMenuItem(
                  value: user.isBanned ? 'unban' : 'ban',
                  child: Text(user.isBanned ? 'Unban User' : 'Ban User'),
                ),
                const PopupMenuItem(
                  value: 'change_role',
                  child: Text('Change Role'),
                ),
                const PopupMenuItem(
                  value: 'verify_alumni',
                  child: Text('Verify Alumni'),
                ),
                if (user.role != 'admin')
                  PopupMenuItem(
                    value: 'toggle_notes_upload_access',
                    child: Text(
                      user.canUploadNotesPyqs
                          ? 'Disable Upload Access'
                          : 'Enable Upload Access',
                    ),
                  ),
                const PopupMenuDivider(),
                const PopupMenuItem(
                  value: 'delete',
                  child: Text(
                    'Delete User',
                    style: TextStyle(color: Colors.red),
                  ),
                ),
                if (user.role == 'student' || user.role == 'teacher')
                  const PopupMenuItem(
                    value: 'delete_uploads',
                    child: Text('Delete All Uploads'),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildLoadMoreButton() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Center(
        child: _hasMoreUsers
            ? OutlinedButton.icon(
                onPressed: _isLoadingMoreUsers
                    ? null
                    : () => _loadUsers(reset: false),
                icon: _isLoadingMoreUsers
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.expand_more_rounded),
                label: Text(
                  _isLoadingMoreUsers ? 'Loading...' : 'Load More Users',
                ),
              )
            : const Text(
                'All users loaded',
                style: TextStyle(color: Colors.grey),
              ),
      ),
    );
  }

  Future<bool?> _confirmDeleteUploads(UserModel user) {
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete All Uploads'),
        content: Text(
          'This will permanently remove all notes, curriculum items, and bulletins uploaded by ${user.name}. Continue?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  Future<String?> _showRoleSelector(String currentRole) async {
    String selected = currentRole;

    return showDialog<String>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Change User Role'),
          content: StatefulBuilder(
            builder: (context, setStateDialog) =>
                DropdownButtonFormField<String>(
                  value: selected,
                  decoration: const InputDecoration(labelText: 'Role'),
                  items: ['student', 'teacher', 'alumni', 'admin']
                      .map(
                        (role) => DropdownMenuItem<String>(
                          value: role,
                          child: Text(
                            role[0].toUpperCase() + role.substring(1),
                          ),
                        ),
                      )
                      .toList(),
                  onChanged: (value) {
                    if (value != null) setStateDialog(() => selected = value);
                  },
                ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(selected),
              child: const Text('Save'),
            ),
          ],
        );
      },
    );
  }
}

class ContainerBadge extends StatelessWidget {
  final String text;
  final Color color;

  const ContainerBadge({super.key, required this.text, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        border: Border.all(color: color.withOpacity(0.5)),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}
