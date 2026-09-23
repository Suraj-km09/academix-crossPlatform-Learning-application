import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../auth/domain/auth_providers.dart';
import '../../../shared/widgets/app_back_button.dart';
import '../../../shared/widgets/loading_widget.dart';
import '../domain/admin_providers.dart';

class AdminDashboardScreen extends ConsumerWidget {
  const AdminDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profileAsync = ref.watch(currentUserProvider);
    final statsAsync = ref.watch(adminDashboardStatsProvider);
    final pendingReportsAsync = ref.watch(adminPendingReportsCountProvider);
    final pendingAlumniAsync = ref.watch(adminPendingAlumniCountProvider);
    final pendingTeacherAsync = ref.watch(
      adminPendingTeacherRequestsCountProvider,
    );
    final pendingNotesAsync = ref.watch(adminPendingNotesCountProvider);

    return profileAsync.when(
      data: (profile) {
        if (profile == null || profile.role != 'admin') {
          return Scaffold(
            appBar: AppBar(
              leading: const AppBackButton(fallbackRoute: '/home'),
              title: const Text('Admin Dashboard'),
            ),
            body: const Center(
              child: Text('Admin access is required for this screen.'),
            ),
          );
        }

        return Scaffold(
          appBar: AppBar(
            leading: const AppBackButton(fallbackRoute: '/home'),
            title: const Text('Admin Dashboard'),
          ),
          body: RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(adminDashboardStatsProvider);
              ref.invalidate(adminPendingReportsCountProvider);
              ref.invalidate(adminPendingAlumniCountProvider);
              ref.invalidate(adminPendingTeacherRequestsCountProvider);
              ref.invalidate(adminPendingNotesCountProvider);
              await Future<void>.delayed(const Duration(milliseconds: 250));
            },
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                statsAsync.when(
                  data: (stats) {
                    final screenWidth = MediaQuery.of(context).size.width;
                    final crossAxisCount = (screenWidth > 700) ? 4 : 2;
                    return GridView.count(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      crossAxisCount: crossAxisCount,
                      crossAxisSpacing: 12,
                      mainAxisSpacing: 12,
                      childAspectRatio: 1.4,
                      children: [
                        _StatCard(
                          label: 'Users',
                          value: '${stats['users'] ?? 0}',
                          icon: Icons.groups_rounded,
                        ),
                        _StatCard(
                          label: 'Colleges',
                          value: '${stats['colleges'] ?? 0}',
                          icon: Icons.school_rounded,
                        ),
                        _StatCard(
                          label: 'Notes Today',
                          value: '${stats['notesToday'] ?? 0}',
                          icon: Icons.description_outlined,
                        ),
                        _StatCard(
                          label: 'Referrals Today',
                          value: '${stats['referralsToday'] ?? 0}',
                          icon: Icons.work_outline_rounded,
                        ),
                      ],
                    );
                  },
                  loading: () => const SizedBox(
                    height: 160,
                    child: LoadingWidget(message: 'Loading dashboard stats...'),
                  ),
                  error: (error, _) => _ErrorCard(
                    message: 'Failed to load dashboard stats: $error',
                  ),
                ),
                const SizedBox(height: 16),
                _ModerationSummaryRow(
                  pendingReportsAsync: pendingReportsAsync,
                  pendingAlumniAsync: pendingAlumniAsync,
                  pendingTeacherAsync: pendingTeacherAsync,
                  pendingNotesAsync: pendingNotesAsync,
                ),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    _QuickActionButton(
                      icon: Icons.manage_accounts_rounded,
                      label: 'User Management',
                      onTap: () => context.push('/admin/users'),
                    ),
                    _QuickActionButton(
                      icon: Icons.report_gmailerrorred_rounded,
                      label: 'Reports Queue',
                      onTap: () => context.push('/admin/reports'),
                    ),
                    _QuickActionButton(
                      icon: Icons.account_balance_rounded,
                      label: 'College Management',
                      onTap: () => context.push('/admin/colleges'),
                    ),
                    _QuickActionButton(
                      icon: Icons.assignment_turned_in_rounded,
                      label: 'Pending Notes Review',
                      onTap: () => context.push('/admin/pending-notes'),
                    ),
                    _QuickActionButton(
                      icon: Icons.lock_reset_rounded,
                      label: 'Teacher Access Code',
                      onTap: () => context.push('/admin/teacher-code'),
                    ),
                    _QuickActionButton(
                      icon: Icons.how_to_reg_rounded,
                      label:
                          'Teacher Approvals (${pendingTeacherAsync.valueOrNull ?? 0})',
                      onTap: () => context.push('/admin/teacher-approvals'),
                    ),
                    _QuickActionButton(
                      icon: Icons.chat_bubble_outline_rounded,
                      label: 'Chat Messaging Control',
                      onTap: () => context.push('/admin/chat-messaging'),
                    ),
                    _QuickActionButton(
                      icon: Icons.menu_book_rounded,
                      label: 'Courses & Branches',
                      onTap: () => context.push('/admin/academic-options'),
                    ),
                    _QuickActionButton(
                      icon: Icons.business_center_rounded,
                      label: 'Placement Management',
                      onTap: () => context.push('/admin/placement'),
                    ),
                    _QuickActionButton(
                      icon: Icons.history_rounded,
                      label: 'Admin Logs',
                      onTap: () => context.push('/admin/logs'),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                // Upload control toggles for roles
                Consumer(
                  builder: (context, refLocal, _) {
                    final uploadConfigAsync = refLocal.watch(
                      adminUploadAccessConfigProvider,
                    );
                    return uploadConfigAsync.when(
                      data: (cfg) {
                        final studentCfg =
                            cfg['student'] as Map<String, dynamic>? ??
                            {'notes': true, 'curriculum': true};
                        final teacherCfg =
                            cfg['teacher'] as Map<String, dynamic>? ??
                            {'notes': true, 'curriculum': true};
                        final alumniCfg =
                            cfg['alumni'] as Map<String, dynamic>? ??
                            {'notes': true, 'curriculum': true};
                        final adminUid = profile.uid;
                        return Card(
                          child: Padding(
                            padding: const EdgeInsets.all(12),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Upload Controls',
                                  style: Theme.of(
                                    context,
                                  ).textTheme.titleMedium,
                                ),
                                const SizedBox(height: 8),
                                Text('Students'),
                                SwitchListTile(
                                  title: const Text(
                                    'Allow Students to upload Notes',
                                  ),
                                  value: studentCfg['notes'] as bool? ?? true,
                                  onChanged: (v) async {
                                    final messenger = ScaffoldMessenger.of(
                                      context,
                                    );
                                    try {
                                      await refLocal
                                          .read(adminRepositoryProvider)
                                          .setRoleUploadAccess(
                                            adminUid: adminUid,
                                            role: 'student',
                                            resource: 'notes',
                                            canUpload: v,
                                          );
                                    } catch (e) {
                                      messenger.showSnackBar(
                                        SnackBar(
                                          content: Text('Failed to update: $e'),
                                        ),
                                      );
                                    }
                                  },
                                ),
                                SwitchListTile(
                                  title: const Text(
                                    'Allow Students to upload Curriculum',
                                  ),
                                  value:
                                      studentCfg['curriculum'] as bool? ?? true,
                                  onChanged: (v) async {
                                    final messenger = ScaffoldMessenger.of(
                                      context,
                                    );
                                    try {
                                      await refLocal
                                          .read(adminRepositoryProvider)
                                          .setRoleUploadAccess(
                                            adminUid: adminUid,
                                            role: 'student',
                                            resource: 'curriculum',
                                            canUpload: v,
                                          );
                                    } catch (e) {
                                      messenger.showSnackBar(
                                        SnackBar(
                                          content: Text('Failed to update: $e'),
                                        ),
                                      );
                                    }
                                  },
                                ),

                                const SizedBox(height: 6),
                                Text('Teachers'),
                                SwitchListTile(
                                  title: const Text(
                                    'Allow Teachers to upload Notes',
                                  ),
                                  value: teacherCfg['notes'] as bool? ?? true,
                                  onChanged: (v) async {
                                    final messenger = ScaffoldMessenger.of(
                                      context,
                                    );
                                    try {
                                      await refLocal
                                          .read(adminRepositoryProvider)
                                          .setRoleUploadAccess(
                                            adminUid: adminUid,
                                            role: 'teacher',
                                            resource: 'notes',
                                            canUpload: v,
                                          );
                                    } catch (e) {
                                      messenger.showSnackBar(
                                        SnackBar(
                                          content: Text('Failed to update: $e'),
                                        ),
                                      );
                                    }
                                  },
                                ),
                                SwitchListTile(
                                  title: const Text(
                                    'Allow Teachers to upload Curriculum',
                                  ),
                                  value:
                                      teacherCfg['curriculum'] as bool? ?? true,
                                  onChanged: (v) async {
                                    final messenger = ScaffoldMessenger.of(
                                      context,
                                    );
                                    try {
                                      await refLocal
                                          .read(adminRepositoryProvider)
                                          .setRoleUploadAccess(
                                            adminUid: adminUid,
                                            role: 'teacher',
                                            resource: 'curriculum',
                                            canUpload: v,
                                          );
                                    } catch (e) {
                                      messenger.showSnackBar(
                                        SnackBar(
                                          content: Text('Failed to update: $e'),
                                        ),
                                      );
                                    }
                                  },
                                ),

                                const SizedBox(height: 6),
                                Text('Alumni'),
                                SwitchListTile(
                                  title: const Text(
                                    'Allow Alumni to upload Notes',
                                  ),
                                  value: alumniCfg['notes'] as bool? ?? true,
                                  onChanged: (v) async {
                                    final messenger = ScaffoldMessenger.of(
                                      context,
                                    );
                                    try {
                                      await refLocal
                                          .read(adminRepositoryProvider)
                                          .setRoleUploadAccess(
                                            adminUid: adminUid,
                                            role: 'alumni',
                                            resource: 'notes',
                                            canUpload: v,
                                          );
                                    } catch (e) {
                                      messenger.showSnackBar(
                                        SnackBar(
                                          content: Text('Failed to update: $e'),
                                        ),
                                      );
                                    }
                                  },
                                ),
                                SwitchListTile(
                                  title: const Text(
                                    'Allow Alumni to upload Curriculum',
                                  ),
                                  value:
                                      alumniCfg['curriculum'] as bool? ?? true,
                                  onChanged: (v) async {
                                    final messenger = ScaffoldMessenger.of(
                                      context,
                                    );
                                    try {
                                      await refLocal
                                          .read(adminRepositoryProvider)
                                          .setRoleUploadAccess(
                                            adminUid: adminUid,
                                            role: 'alumni',
                                            resource: 'curriculum',
                                            canUpload: v,
                                          );
                                    } catch (e) {
                                      messenger.showSnackBar(
                                        SnackBar(
                                          content: Text('Failed to update: $e'),
                                        ),
                                      );
                                    }
                                  },
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                      loading: () => const Card(
                        child: ListTile(
                          title: Text('Upload Controls'),
                          subtitle: Text('Loading...'),
                        ),
                      ),
                      error: (e, _) => Card(
                        child: ListTile(
                          title: const Text('Upload Controls'),
                          subtitle: Text('Error: $e'),
                        ),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        );
      },
      loading: () =>
          const Scaffold(body: LoadingWidget(message: 'Loading profile...')),
      error: (error, _) => Scaffold(
        appBar: AppBar(
          leading: const AppBackButton(fallbackRoute: '/home'),
          title: const Text('Admin Dashboard'),
        ),
        body: Center(child: Text('Error loading profile: $error')),
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.label,
    required this.value,
    required this.icon,
  });

  final String label;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Theme.of(context).dividerColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon),
          const Spacer(),
          Text(
            value,
            style: Theme.of(
              context,
            ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700),
          ),
          Text(label, style: Theme.of(context).textTheme.bodyMedium),
        ],
      ),
    );
  }
}

class _ModerationSummaryRow extends StatelessWidget {
  const _ModerationSummaryRow({
    required this.pendingReportsAsync,
    required this.pendingAlumniAsync,
    required this.pendingTeacherAsync,
    required this.pendingNotesAsync,
  });

  final AsyncValue<int> pendingReportsAsync;
  final AsyncValue<int> pendingAlumniAsync;
  final AsyncValue<int> pendingTeacherAsync;
  final AsyncValue<int> pendingNotesAsync;

  @override
  Widget build(BuildContext context) {
    final pendingReports = pendingReportsAsync.valueOrNull ?? 0;
    final pendingAlumni = pendingAlumniAsync.valueOrNull ?? 0;
    final pendingTeacher = pendingTeacherAsync.valueOrNull ?? 0;
    final pendingNotes = pendingNotesAsync.valueOrNull ?? 0;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            Expanded(
              child: _SummaryItem(
                label: 'Reports',
                value: '$pendingReports',
                color: Colors.redAccent,
              ),
            ),
            Expanded(
              child: _SummaryItem(
                label: 'Alumni Verify',
                value: '$pendingAlumni',
                color: Colors.orange,
              ),
            ),
            Expanded(
              child: _SummaryItem(
                label: 'Teacher Req',
                value: '$pendingTeacher',
                color: Colors.deepPurple,
              ),
            ),
            Expanded(
              child: _SummaryItem(
                label: 'Notes Pending',
                value: '$pendingNotes',
                color: Colors.blue,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SummaryItem extends StatelessWidget {
  const _SummaryItem({
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          value,
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
            color: color,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ],
    );
  }
}

class _QuickActionButton extends StatelessWidget {
  const _QuickActionButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: onTap,
      icon: Icon(icon),
      label: Text(label),
    );
  }
}

class _ErrorCard extends StatelessWidget {
  const _ErrorCard({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Card(
      color: Theme.of(context).colorScheme.errorContainer,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Text(
          message,
          style: TextStyle(
            color: Theme.of(context).colorScheme.onErrorContainer,
          ),
        ),
      ),
    );
  }
}
