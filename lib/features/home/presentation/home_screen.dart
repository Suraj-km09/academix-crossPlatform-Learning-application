import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../shared/widgets/academix_logo.dart';
import '../../../shared/widgets/skeleton_loader.dart';
import '../../auth/domain/auth_providers.dart';
import '../../notifications/domain/notifications_providers.dart';
import '../../../shared/widgets/desktop_sidebar.dart';
import '../../../shared/widgets/responsive_layout.dart';
import '../../ai/presentation/widgets/academix_ai_entry_card.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  bool _loggingOut = false;

  @override
  Widget build(BuildContext context) {
    final userAsync = ref.watch(currentUserStreamProvider);

    return userAsync.when(
      data: (user) {
        if (user == null) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) {
              context.go('/login');
            }
          });
          return const Scaffold(body: SizedBox.shrink());
        }

        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          try {
            if ((user.requestedRole == 'teacher' ||
                    user.teacherRequestStatus == 'pending') &&
                !user.teacherRequestMessageShown) {
              showDialog<void>(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text('Teacher Request Submitted'),
                  content: const Text(
                    'Your role has been set to Teacher. Pending admin approval.',
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text('OK'),
                    ),
                  ],
                ),
                useRootNavigator: true,
              );
              ref
                  .read(authRepositoryProvider)
                  .markTeacherRequestMessageShown(user.uid)
                  .catchError((_) {});
              return;
            }

            if (user.role == 'teacher' &&
                user.isApproved &&
                !user.approvalMessageShown) {
              showDialog<void>(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text('You are now a Teacher'),
                  content: const Text(
                    'You have been approved as Teacher. Welcome!',
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text('OK'),
                    ),
                  ],
                ),
                useRootNavigator: true,
              );
              ref
                  .read(authRepositoryProvider)
                  .markApprovalMessageShown(user.uid)
                  .catchError((_) {});
            }
          } catch (_) {}
        });

        final items = _dashboardItems
            .where(
              (item) =>
                  item.allowedRoles.contains(user.role.toLowerCase()) &&
                  item.route != '/alumni',
            )
            .toList();
        final unreadCountAsync = ref.watch(unreadCountProvider(user.uid));

        final isDesktop = MediaQuery.of(context).size.width >= 960;
        final unreadCount = unreadCountAsync.maybeWhen(
          data: (count) => count,
          orElse: () => 0,
        );

        final dashboardContent = RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(currentUserStreamProvider);
            await Future<void>.delayed(const Duration(milliseconds: 250));
          },
          child: ResponsiveLayout(
            maxWidthDesktop: 1100,
            padding: EdgeInsets.symmetric(
              horizontal: isDesktop ? 28 : 16,
              vertical: isDesktop ? 24 : 16,
            ),
            child: ListView(
              padding: EdgeInsets.zero,
              children: [
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(18),
                    color: Theme.of(
                      context,
                    ).colorScheme.primary.withValues(alpha: 0.08),
                    border: Border.all(
                      color: Theme.of(
                        context,
                      ).colorScheme.primary.withValues(alpha: 0.2),
                    ),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Welcome, ${user.name.isEmpty ? 'User' : user.name}',
                              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                    fontWeight: FontWeight.bold,
                                  ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              'Role: ${user.role.toUpperCase()} • College: ${user.collegeName.isEmpty ? user.collegeId : user.collegeName}',
                              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                    color: Theme.of(context)
                                        .textTheme
                                        .bodySmall
                                        ?.color,
                                  ),
                            ),
                          ],
                        ),
                      ),
                      if (isDesktop)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: Theme.of(context)
                                .colorScheme
                                .primary
                                .withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            'PORTAL ACTIVE',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                              color: Theme.of(context).colorScheme.primary,
                              letterSpacing: 0.8,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                LayoutBuilder(
                  builder: (context, constraints) {
                    final w = constraints.maxWidth;
                    if (w >= 760) {
                      return Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: _AlumniEntryCard(
                              onOpenAlumni: () => context.push('/alumni'),
                              onOpenReferrals: () =>
                                  context.push('/my-referrals'),
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: AcademixAiEntryCard(
                              onOpenCopilot: () => context.push('/ai/copilot'),
                              onOpenSkillGap: () =>
                                  context.push('/ai/skill-gap'),
                              onOpenRoadmap: () => context.push('/ai/roadmap'),
                              onOpenAiHub: () => context.push('/ai'),
                            ),
                          ),
                        ],
                      );
                    }
                    return Column(
                      children: [
                        _AlumniEntryCard(
                          onOpenAlumni: () => context.push('/alumni'),
                          onOpenReferrals: () => context.push('/my-referrals'),
                        ),
                        const SizedBox(height: 14),
                        AcademixAiEntryCard(
                          onOpenCopilot: () => context.push('/ai/copilot'),
                          onOpenSkillGap: () => context.push('/ai/skill-gap'),
                          onOpenRoadmap: () => context.push('/ai/roadmap'),
                          onOpenAiHub: () => context.push('/ai'),
                        ),
                      ],
                    );
                  },
                ),
                const SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Quick Access & Modules',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                    Text(
                      '${items.length} Modules',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                LayoutBuilder(
                  builder: (context, constraints) {
                    final w = constraints.maxWidth;
                    final crossAxisCount = w >= 1100 ? 4 : (w >= 750 ? 3 : 2);
                    final aspectRatio =
                        w >= 1100 ? 1.35 : (w >= 750 ? 1.15 : 0.95);
                    return GridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: items.length,
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: crossAxisCount,
                        crossAxisSpacing: 12,
                        mainAxisSpacing: 12,
                        childAspectRatio: aspectRatio,
                      ),
                      itemBuilder: (context, index) {
                        final item = items[index];
                        return _FeatureCard(
                          item: item,
                          onTap: () => context.push(item.route),
                        );
                      },
                    );
                  },
                ),
                const SizedBox(height: 24),
              ],
            ),
          ),
        );

        if (isDesktop) {
          return Scaffold(
            body: Row(
              children: [
                DesktopSideNav(
                  user: user,
                  unreadCount: unreadCount,
                  onLogout: () => _confirmAndLogout(),
                  currentRoute: '/home',
                ),
                Expanded(child: dashboardContent),
              ],
            ),
          );
        }

        return Scaffold(
          appBar: AppBar(
            title: const AcademixLogo(size: 30, showAppName: true),
            actions: [
              IconButton(
                tooltip: 'Notifications',
                onPressed: () => context.push('/notifications'),
                icon: unreadCountAsync.when(
                  data: (count) => _BellBadge(count: count),
                  loading: () => const Icon(Icons.notifications_none_rounded),
                  error: (_, _) => const Icon(Icons.notifications_none_rounded),
                ),
              ),
              IconButton(
                tooltip: 'Logout',
                onPressed: _loggingOut ? null : () => _confirmAndLogout(),
                icon: _loggingOut
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.logout_rounded),
              ),
            ],
          ),
          body: dashboardContent,
        );
      },
      loading: () => Scaffold(
        appBar: AppBar(title: const AcademixLogo(size: 30, showAppName: true)),
        body: const HomeSkeleton(),
      ),
      error: (error, stackTrace) => Scaffold(
        appBar: AppBar(title: const AcademixLogo(size: 28, showAppName: true)),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.error_outline_rounded, size: 48),
                const SizedBox(height: 10),
                Text(
                  'Unable to load dashboard',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 8),
                Text('$error', textAlign: TextAlign.center),
                const SizedBox(height: 12),
                ElevatedButton(
                  onPressed: () => ref.invalidate(currentUserStreamProvider),
                  child: const Text('Retry'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _logout() async {
    setState(() => _loggingOut = true);
    try {
      final repository = ref.read(authRepositoryProvider);
      await repository.logout();
      if (!mounted) {
        return;
      }
      context.go('/login');
    } finally {
      if (mounted) {
        setState(() => _loggingOut = false);
      }
    }
  }

  Future<void> _confirmAndLogout() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Logout'),
        content: const Text('Are you sure you want to logout?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Logout'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await _logout();
    }
  }
}

class _FeatureCard extends StatelessWidget {
  const _FeatureCard({required this.item, required this.onTap});

  final _DashboardItem item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(
          color: Theme.of(context).dividerColor.withValues(alpha: 0.14),
        ),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        mouseCursor: SystemMouseCursors.click,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Theme.of(
                    context,
                  ).colorScheme.primary.withValues(alpha: 0.12),
                ),
                alignment: Alignment.center,
                child: Icon(
                  item.icon,
                  size: 24,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
              const Spacer(),
              Text(
                item.title,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 4),
              Text(
                item.subtitle,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  fontSize: 11,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BellBadge extends StatelessWidget {
  const _BellBadge({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    if (count <= 0) {
      return const Icon(Icons.notifications_none_rounded);
    }

    return Stack(
      clipBehavior: Clip.none,
      children: [
        const Icon(Icons.notifications_none_rounded),
        Positioned(
          right: -7,
          top: -5,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
            constraints: const BoxConstraints(minWidth: 16, minHeight: 14),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.error,
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              count > 99 ? '99+' : '$count',
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 9,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _AlumniEntryCard extends StatelessWidget {
  const _AlumniEntryCard({
    required this.onOpenAlumni,
    required this.onOpenReferrals,
  });

  final VoidCallback onOpenAlumni;
  final VoidCallback onOpenReferrals;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: Theme.of(context).colorScheme.secondary.withValues(alpha: 0.10),
        border: Border.all(
          color: Theme.of(
            context,
          ).colorScheme.secondary.withValues(alpha: 0.25),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 44, 
                height: 44, 
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Theme.of(
                    context,
                  ).colorScheme.secondary.withValues(alpha: 0.18),
                ),
                child: Icon(
                  Icons.groups_rounded,
                  size: 26,
                  color: Theme.of(context).colorScheme.secondary,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Alumni Network',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Mentorship, referral requests and Q&A',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: onOpenAlumni,
                  icon: const Icon(Icons.open_in_new_rounded, size: 18),
                  label: const Text('Open Alumni'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: onOpenReferrals,
                  icon: const Icon(Icons.receipt_long_outlined, size: 18),
                  label: const Text('My Referrals'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _DashboardItem {
  const _DashboardItem({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.route,
    required this.allowedRoles,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final String route;
  final Set<String> allowedRoles;
}

const List<_DashboardItem> _dashboardItems = [
  _DashboardItem(
    title: 'Academix AI',
    subtitle: 'Copilot & Roadmap',
    icon: Icons.auto_awesome_rounded,
    route: '/ai',
    allowedRoles: {'student', 'teacher', 'alumni', 'admin'},
  ),
  _DashboardItem(
    title: 'Placement',
    subtitle: 'Career & Prep',
    icon: Icons.rocket_launch_rounded,
    route: '/placement',
    allowedRoles: {'student', 'teacher', 'alumni', 'admin'},
  ),
  _DashboardItem(
    title: 'Notes/PYQs',
    subtitle: 'All free content',
    icon: Icons.menu_book_rounded,
    route: '/notes',
    allowedRoles: {'student', 'teacher', 'alumni', 'admin'},
  ),
  _DashboardItem(
    title: 'Curriculum',
    subtitle: 'Syllabus and subject info',
    icon: Icons.library_books_outlined,
    route: '/curriculum',
    allowedRoles: {'student', 'teacher', 'alumni', 'admin'},
  ),
  _DashboardItem(
    title: 'Bulletin',
    subtitle: 'Latest updates',
    icon: Icons.campaign_rounded,
    route: '/bulletin',
    allowedRoles: {'student', 'teacher', 'alumni', 'admin'},
  ),
  _DashboardItem(
    title: 'Chat',
    subtitle: 'Community discussions',
    icon: Icons.chat_bubble_outline_rounded,
    route: '/chats',
    allowedRoles: {'student', 'teacher', 'alumni', 'admin'},
  ),
  _DashboardItem(
    title: 'Resume Builder',
    subtitle: 'Free Templates',
    icon: Icons.description_outlined,
    route: '/resume/templates',
    allowedRoles: {'student', 'teacher', 'alumni', 'admin'},
  ),
  _DashboardItem(
    title: 'Locker',
    subtitle: 'Your saved files',
    icon: Icons.lock_outline_rounded,
    route: '/locker',
    allowedRoles: {'student', 'teacher', 'alumni', 'admin'},
  ),
  _DashboardItem(
    title: 'Profile',
    subtitle: 'Manage account',
    icon: Icons.person_outline_rounded,
    route: '/profile',
    allowedRoles: {'student', 'teacher', 'alumni', 'admin'},
  ),
  _DashboardItem(
    title: 'Settings',
    subtitle: 'Preferences',
    icon: Icons.settings_outlined,
    route: '/settings',
    allowedRoles: {'student', 'teacher', 'alumni', 'admin'},
  ),
  _DashboardItem(
    title: 'Admin Panel',
    subtitle: 'Moderation panel',
    icon: Icons.admin_panel_settings_outlined,
    route: '/admin',
    allowedRoles: {'admin'},
  ),
];
