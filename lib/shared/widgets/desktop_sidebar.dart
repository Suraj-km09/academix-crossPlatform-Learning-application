import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'academix_logo.dart';

class DashboardItem {
  const DashboardItem({
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

const List<DashboardItem> dashboardItems = [
  DashboardItem(
    title: 'Academix AI',
    subtitle: 'Copilot & Roadmap',
    icon: Icons.auto_awesome_rounded,
    route: '/ai',
    allowedRoles: {'student', 'teacher', 'alumni', 'admin'},
  ),
  DashboardItem(
    title: 'Notes & PYQs',
    subtitle: 'All free content',
    icon: Icons.menu_book_rounded,
    route: '/notes',
    allowedRoles: {'student', 'teacher', 'alumni', 'admin'},
  ),
  DashboardItem(
    title: 'Curriculum',
    subtitle: 'Syllabus and subject info',
    icon: Icons.library_books_outlined,
    route: '/curriculum',
    allowedRoles: {'student', 'teacher', 'alumni', 'admin'},
  ),
  DashboardItem(
    title: 'Bulletin',
    subtitle: 'Latest updates',
    icon: Icons.campaign_rounded,
    route: '/bulletin',
    allowedRoles: {'student', 'teacher', 'alumni', 'admin'},
  ),
  DashboardItem(
    title: 'Locker',
    subtitle: 'Your saved files',
    icon: Icons.lock_outline_rounded,
    route: '/locker',
    allowedRoles: {'student', 'teacher', 'alumni', 'admin'},
  ),
  DashboardItem(
    title: 'Chat',
    subtitle: 'Community discussions',
    icon: Icons.chat_bubble_outline_rounded,
    route: '/chats',
    allowedRoles: {'student', 'teacher', 'alumni', 'admin'},
  ),
  DashboardItem(
    title: 'Profile',
    subtitle: 'Manage account',
    icon: Icons.person_outline_rounded,
    route: '/profile',
    allowedRoles: {'student', 'teacher', 'alumni', 'admin'},
  ),
  DashboardItem(
    title: 'Settings',
    subtitle: 'Preferences',
    icon: Icons.settings_outlined,
    route: '/settings',
    allowedRoles: {'student', 'teacher', 'alumni', 'admin'},
  ),
  DashboardItem(
    title: 'Admin',
    subtitle: 'Moderation panel',
    icon: Icons.admin_panel_settings_outlined,
    route: '/admin',
    allowedRoles: {'admin'},
  ),
];

class DesktopSideNav extends StatelessWidget {
  const DesktopSideNav({
    super.key,
    required this.user,
    this.unreadCount = 0,
    required this.onLogout,
    this.currentRoute = '',
  });

  final dynamic user;
  final int unreadCount;
  final VoidCallback onLogout;
  final String currentRoute;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final userRole = user.role.toString().toLowerCase();

    return Container(
      width: 260,
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        border: Border(
          right: BorderSide(
            color: theme.dividerColor.withValues(alpha: 0.15),
            width: 1,
          ),
        ),
      ),
      child: Column(
        children: [
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 24, horizontal: 16),
            child: AcademixLogo(size: 32, showAppName: true),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              children: [
                _NavTile(
                  icon: Icons.dashboard_outlined,
                  label: 'Dashboard',
                  onTap: () => context.go('/home'),
                  isSelected: currentRoute == '/home',
                ),
                _NavTile(
                  icon: Icons.notifications_none_rounded,
                  label: 'Notifications',
                  onTap: () => context.push('/notifications'),
                  isSelected: currentRoute == '/notifications',
                  trailing: unreadCount > 0 ? _CountBadge(count: unreadCount) : null,
                ),
                const Divider(height: 32),
                ...dashboardItems
                    .where((item) => item.allowedRoles.contains(userRole))
                    .map(
                      (item) => _NavTile(
                        icon: item.icon,
                        label: item.title,
                        onTap: () {
                          if (currentRoute != item.route) {
                            context.push(item.route);
                          }
                        },
                        isSelected: currentRoute == item.route,
                      ),
                    ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: _NavTile(
              icon: Icons.logout_rounded,
              label: 'Logout',
              onTap: onLogout,
              color: theme.colorScheme.error,
            ),
          ),
        ],
      ),
    );
  }
}

class _NavTile extends StatelessWidget {
  const _NavTile({
    required this.icon,
    required this.label,
    required this.onTap,
    this.isSelected = false,
    this.trailing,
    this.color,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool isSelected;
  final Widget? trailing;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListTile(
      onTap: onTap,
      leading: Icon(
        icon,
        color: color ?? (isSelected ? theme.colorScheme.primary : null),
      ),
      title: Text(
        label,
        style: TextStyle(
          color: color ?? (isSelected ? theme.colorScheme.primary : null),
          fontWeight: isSelected ? FontWeight.bold : null,
        ),
      ),
      trailing: trailing,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      selected: isSelected,
      selectedTileColor: theme.colorScheme.primary.withOpacity(0.08),
    );
  }
}

class _CountBadge extends StatelessWidget {
  const _CountBadge({required this.count});
  final int count;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.error,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        count > 99 ? '99+' : '$count',
        style: const TextStyle(
          color: Colors.white,
          fontSize: 10,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}
