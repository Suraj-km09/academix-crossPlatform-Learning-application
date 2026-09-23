import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/domain/auth_providers.dart';
import '../../../shared/models/user_model.dart';
import '../../../shared/widgets/app_back_button.dart';
import '../../../shared/widgets/loading_widget.dart';
import '../domain/admin_providers.dart';

class ChatMessagingControlScreen extends ConsumerStatefulWidget {
  const ChatMessagingControlScreen({super.key});

  @override
  ConsumerState<ChatMessagingControlScreen> createState() =>
      _ChatMessagingControlScreenState();
}

class _ChatMessagingControlScreenState
    extends ConsumerState<ChatMessagingControlScreen> {
  static const int _studentsPageSize = 20;

  final List<UserModel> _students = [];
  DocumentSnapshot<Map<String, dynamic>>? _lastStudentDocument;
  bool _hasMoreStudents = true;
  bool _isLoadingStudents = false;
  bool _isLoadingMoreStudents = false;
  String? _studentLoadError;

  final Set<String> _updatingRoleFlags = <String>{};

  String _studentSearchQuery = '';
  String _studentFilter = 'all';
  final Set<String> _updatingStudentUids = <String>{};

  @override
  void initState() {
    super.initState();
    _loadStudents(reset: true);
  }

  @override
  Widget build(BuildContext context) {
    final profileAsync = ref.watch(currentUserProvider);
    final controlAsync = ref.watch(chatMessagingControlConfigProvider);

    return profileAsync.when(
      data: (profile) {
        final adminUid = profile?.uid ?? '';
        if (profile == null || profile.role != 'admin') {
          return Scaffold(
            appBar: AppBar(
              leading: const AppBackButton(fallbackRoute: '/admin'),
              title: const Text('Chat Messaging Control'),
            ),
            body: const Center(
              child: Text('Only admins can access chat messaging control.'),
            ),
          );
        }

        return Scaffold(
          appBar: AppBar(
            leading: const AppBackButton(fallbackRoute: '/admin'),
            title: const Text('Chat Messaging Control'),
          ),
          body: controlAsync.when(
            data: (config) {
              final mode = _messagingModeFromConfig(config);
              final disabledStudentUids = _disabledMessagingUidsFromConfig(
                config,
              );

              return Column(
                children: [
                  _buildGlobalModeCard(
                    adminUid: adminUid,
                    currentMode: mode,
                    disabledCount: disabledStudentUids.length,
                  ),
                  _buildRoleTogglesCard(adminUid: adminUid, config: config),
                  Expanded(
                    child: _buildStudentsSection(
                      adminUid: adminUid,
                      currentMode: mode,
                      disabledStudentUids: disabledStudentUids,
                    ),
                  ),
                ],
              );
            },
            loading: () =>
                const LoadingWidget(message: 'Loading messaging controls...'),
            error: (error, _) => Center(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Text('Failed to load messaging controls: $error'),
              ),
            ),
          ),
        );
      },
      loading: () =>
          const Scaffold(body: LoadingWidget(message: 'Loading profile...')),
      error: (error, _) => Scaffold(
        appBar: AppBar(
          leading: const AppBackButton(fallbackRoute: '/admin'),
          title: const Text('Chat Messaging Control'),
        ),
        body: Center(child: Text('Error loading profile: $error')),
      ),
    );
  }

  Widget _buildGlobalModeCard({
    required String adminUid,
    required String currentMode,
    required int disabledCount,
  }) {
    return Card(
      margin: const EdgeInsets.fromLTRB(12, 12, 12, 6),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Global Restriction Scope',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              key: ValueKey(currentMode),
              initialValue: currentMode,
              decoration: const InputDecoration(border: OutlineInputBorder()),
              items: const [
                DropdownMenuItem(value: 'none', child: Text('No global block')),
                DropdownMenuItem(
                  value: 'specific_users',
                  child: Text('Specific users'),
                ),
                DropdownMenuItem(value: 'all_users', child: Text('All users')),
                DropdownMenuItem(
                  value: 'only_teachers',
                  child: Text('Only teachers'),
                ),
                DropdownMenuItem(
                  value: 'only_students',
                  child: Text('Only students'),
                ),
                DropdownMenuItem(
                  value: 'only_alumni',
                  child: Text('Only alumni'),
                ),
              ],
              onChanged: (value) {
                if (value == null) {
                  return;
                }
                _updateMessagingMode(adminUid: adminUid, mode: value);
              },
            ),
            const SizedBox(height: 8),
            Text('Specific students blocked: $disabledCount'),
            const SizedBox(height: 4),
            Text(
              'Use "Specific users" mode and the student list below to block or unblock selected students.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStudentsSection({
    required String adminUid,
    required String currentMode,
    required Set<String> disabledStudentUids,
  }) {
    if (currentMode != 'specific_users') {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Text(
            'Switch global scope to "Specific users" to manage student-level messaging blocks.',
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    if (_isLoadingStudents && _students.isEmpty) {
      return const LoadingWidget(message: 'Loading students...');
    }

    if (_studentLoadError != null && _students.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(_studentLoadError!, textAlign: TextAlign.center),
            ),
            const SizedBox(height: 10),
            OutlinedButton.icon(
              onPressed: () => _loadStudents(reset: true),
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    final visibleStudents = _applyStudentFilters(
      _students,
      disabledStudentUids: disabledStudentUids,
    );

    return Column(
      children: [
        Card(
          margin: const EdgeInsets.fromLTRB(12, 6, 12, 6),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              children: [
                TextField(
                  decoration: const InputDecoration(
                    labelText: 'Search student by name/email',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.search),
                  ),
                  onChanged: (value) {
                    setState(() {
                      _studentSearchQuery = value;
                    });
                    // Trigger server-side search for queries of reasonable length
                    // to avoid excessive reads. Also refresh when cleared.
                    final trimmed = value.trim();
                    if (trimmed.isEmpty || trimmed.length >= 3) {
                      _loadStudents(reset: true);
                    }
                  },
                ),
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  key: ValueKey(_studentFilter),
                  initialValue: _studentFilter,
                  decoration: const InputDecoration(
                    labelText: 'Filter',
                    border: OutlineInputBorder(),
                  ),
                  items: const [
                    DropdownMenuItem(value: 'all', child: Text('All students')),
                    DropdownMenuItem(
                      value: 'blocked',
                      child: Text('Blocked students'),
                    ),
                    DropdownMenuItem(
                      value: 'allowed',
                      child: Text('Allowed students'),
                    ),
                  ],
                  onChanged: (value) {
                    if (value == null) {
                      return;
                    }
                    setState(() {
                      _studentFilter = value;
                    });
                  },
                ),
              ],
            ),
          ),
        ),
        Expanded(
          child: visibleStudents.isEmpty
              ? const Center(child: Text('No students match current filters.'))
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                  itemCount: visibleStudents.length + 1,
                  itemBuilder: (context, index) {
                    if (index == visibleStudents.length) {
                      return Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Column(
                          children: [
                            if (_studentLoadError != null)
                              Padding(
                                padding: const EdgeInsets.only(bottom: 8),
                                child: Text(_studentLoadError!),
                              ),
                            if (_hasMoreStudents)
                              OutlinedButton.icon(
                                onPressed: _isLoadingMoreStudents
                                    ? null
                                    : () => _loadStudents(reset: false),
                                icon: _isLoadingMoreStudents
                                    ? const SizedBox(
                                        width: 16,
                                        height: 16,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                        ),
                                      )
                                    : const Icon(Icons.expand_more_rounded),
                                label: Text(
                                  _isLoadingMoreStudents
                                      ? 'Loading...'
                                      : 'Load More Students',
                                ),
                              ),
                          ],
                        ),
                      );
                    }

                    final student = visibleStudents[index];
                    final isBlocked = disabledStudentUids.contains(student.uid);
                    final isUpdating = _updatingStudentUids.contains(
                      student.uid,
                    );

                    return Card(
                      margin: const EdgeInsets.only(bottom: 10),
                      child: ListTile(
                        leading: CircleAvatar(
                          child: Text(
                            student.name.isNotEmpty
                                ? student.name.substring(0, 1).toUpperCase()
                                : 'S',
                          ),
                        ),
                        title: Text(student.name),
                        subtitle: Text(
                          '${student.email}\n'
                          'Course: ${student.course.isEmpty ? 'N/A' : student.course} • '
                          'Branch: ${student.branch.isEmpty ? 'N/A' : student.branch}',
                        ),
                        isThreeLine: true,
                        trailing: isUpdating
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : OutlinedButton(
                                onPressed: () {
                                  _toggleStudentMessagingAccess(
                                    adminUid: adminUid,
                                    student: student,
                                    canMessage: isBlocked,
                                  );
                                },
                                child: Text(isBlocked ? 'Unblock' : 'Block'),
                              ),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  List<UserModel> _applyStudentFilters(
    List<UserModel> students, {
    required Set<String> disabledStudentUids,
  }) {
    final query = _studentSearchQuery.trim().toLowerCase();

    return students.where((student) {
      final isBlocked = disabledStudentUids.contains(student.uid);

      if (_studentFilter == 'blocked' && !isBlocked) {
        return false;
      }
      if (_studentFilter == 'allowed' && isBlocked) {
        return false;
      }

      if (query.isEmpty) {
        return true;
      }

      return student.name.toLowerCase().contains(query) ||
          student.email.toLowerCase().contains(query);
    }).toList();
  }

  Future<void> _loadStudents({required bool reset}) async {
    if (!reset && (!_hasMoreStudents || _isLoadingMoreStudents)) {
      return;
    }

    setState(() {
      if (reset) {
        _isLoadingStudents = true;
        _isLoadingMoreStudents = false;
        _hasMoreStudents = true;
        _lastStudentDocument = null;
      } else {
        _isLoadingMoreStudents = true;
      }
      _studentLoadError = null;
    });

    try {
      final page = await ref
          .read(adminRepositoryProvider)
          .fetchUsersPage(
            role: 'student',
            pageSize: _studentsPageSize,
            startAfter: reset ? null : _lastStudentDocument,
            search: _studentSearchQuery.trim().isNotEmpty
                ? _studentSearchQuery.trim()
                : null,
          );

      if (!mounted) {
        return;
      }

      setState(() {
        _lastStudentDocument = page.lastDocument;
        _hasMoreStudents = page.hasMore;

        if (reset) {
          _students
            ..clear()
            ..addAll(page.users);
        } else {
          final existingIds = _students.map((item) => item.uid).toSet();
          for (final student in page.users) {
            if (existingIds.add(student.uid)) {
              _students.add(student);
            }
          }
        }
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _studentLoadError = 'Failed to load students: $error';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingStudents = false;
          _isLoadingMoreStudents = false;
        });
      }
    }
  }

  Future<void> _toggleStudentMessagingAccess({
    required String adminUid,
    required UserModel student,
    required bool canMessage,
  }) async {
    setState(() {
      _updatingStudentUids.add(student.uid);
    });

    try {
      await ref
          .read(adminRepositoryProvider)
          .setStudentMessagingAccess(
            uid: student.uid,
            canMessage: canMessage,
            adminUid: adminUid,
          );

      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            canMessage
                ? 'Messaging enabled for ${student.name}.'
                : 'Messaging disabled for ${student.name}.',
          ),
        ),
      );
    } catch (error) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to update student: $error')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _updatingStudentUids.remove(student.uid);
        });
      }
    }
  }

  Future<void> _updateMessagingMode({
    required String adminUid,
    required String mode,
  }) async {
    try {
      await ref
          .read(adminRepositoryProvider)
          .setChatMessagingRestrictionMode(adminUid: adminUid, mode: mode);

      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Messaging restriction updated.')),
      );
    } catch (error) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to update mode: $error')));
    }
  }

  String _messagingModeFromConfig(Map<String, dynamic>? config) {
    final mode = (config?['chatMessagingRestrictionMode'] as String? ?? '')
        .trim()
        .toLowerCase();

    switch (mode) {
      case 'specific_users':
      case 'all_users':
      case 'only_teachers':
      case 'only_students':
      case 'only_alumni':
        return mode;
      default:
        return 'none';
    }
  }

  Set<String> _disabledMessagingUidsFromConfig(Map<String, dynamic>? config) {
    final raw = config?['chatMessagingDisabledUserUids'];

    if (raw is Set) {
      return raw
          .map((item) => item.toString().trim())
          .where((item) => item.isNotEmpty)
          .toSet();
    }

    if (raw is List) {
      return raw
          .map((item) => item.toString().trim())
          .where((item) => item.isNotEmpty)
          .toSet();
    }

    return <String>{};
  }

  bool _roleBlockedFromConfig(Map<String, dynamic>? config, String role) {
    final roleKey = role.trim().toLowerCase();

    // Prefer explicit blocked roles map if present
    final blockedRaw = config?['chatMessagingBlockedRoles'];
    if (blockedRaw is Map) {
      final value = blockedRaw[roleKey];
      if (value is bool) return value;
      // explicit 'all' overrides per-role
      final all = blockedRaw['all'];
      if (all is bool && all) return true;
    }

    // Fallback to legacy single-mode behaviour
    final mode = _messagingModeFromConfig(config);
    if (mode == 'all_users') return true;
    if (mode == 'only_students' && roleKey == 'student') return true;
    if (mode == 'only_teachers' && roleKey == 'teacher') return true;
    if (mode == 'only_alumni' && roleKey == 'alumni') return true;

    return false;
  }

  Future<void> _toggleRoleMessagingAccess({
    required String adminUid,
    required String role,
    required bool blocked,
  }) async {
    setState(() {
      _updatingRoleFlags.add(role);
    });

    try {
      await ref
          .read(adminRepositoryProvider)
          .setRoleMessagingAccess(
            adminUid: adminUid,
            role: role,
            blocked: blocked,
          );

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            blocked
                ? 'Messaging disabled for ${role}s.'
                : 'Messaging enabled for ${role}s.',
          ),
        ),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to update role: $error')));
    } finally {
      if (mounted) {
        setState(() {
          _updatingRoleFlags.remove(role);
        });
      }
    }
  }

  Widget _buildRoleTogglesCard({
    required String adminUid,
    required Map<String, dynamic>? config,
  }) {
    final studentBlocked = _roleBlockedFromConfig(config, 'student');
    final teacherBlocked = _roleBlockedFromConfig(config, 'teacher');
    final alumniBlocked = _roleBlockedFromConfig(config, 'alumni');
    final allBlocked = _roleBlockedFromConfig(config, 'all');

    return Card(
      margin: const EdgeInsets.fromLTRB(12, 6, 12, 6),
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Role-based Messaging Blocks',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            SwitchListTile(
              title: const Text('Block students from direct messaging'),
              value: studentBlocked || allBlocked,
              onChanged: _updatingRoleFlags.contains('student')
                  ? null
                  : (v) {
                      _toggleRoleMessagingAccess(
                        adminUid: adminUid,
                        role: 'student',
                        blocked: v,
                      );
                    },
            ),
            SwitchListTile(
              title: const Text('Block teachers from direct messaging'),
              value: teacherBlocked || allBlocked,
              onChanged: _updatingRoleFlags.contains('teacher')
                  ? null
                  : (v) {
                      _toggleRoleMessagingAccess(
                        adminUid: adminUid,
                        role: 'teacher',
                        blocked: v,
                      );
                    },
            ),
            SwitchListTile(
              title: const Text('Block alumni from direct messaging'),
              value: alumniBlocked || allBlocked,
              onChanged: _updatingRoleFlags.contains('alumni')
                  ? null
                  : (v) {
                      _toggleRoleMessagingAccess(
                        adminUid: adminUid,
                        role: 'alumni',
                        blocked: v,
                      );
                    },
            ),
            SwitchListTile(
              title: const Text('Block direct messaging for all users'),
              value: allBlocked,
              onChanged: _updatingRoleFlags.contains('all')
                  ? null
                  : (v) {
                      _toggleRoleMessagingAccess(
                        adminUid: adminUid,
                        role: 'all',
                        blocked: v,
                      );
                    },
            ),
          ],
        ),
      ),
    );
  }
}
