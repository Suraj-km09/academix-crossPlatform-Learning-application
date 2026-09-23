import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../features/auth/domain/auth_providers.dart';
import '../../../shared/models/user_model.dart';
import '../../../shared/services/storage_image_cache_service.dart';
import '../../../shared/widgets/app_back_button.dart';
import '../../../shared/widgets/responsive_layout.dart';
import '../../../shared/widgets/skeleton_loader.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userAsync = ref.watch(currentUserProvider);

    return userAsync.when(
      data: (user) {
        if (user == null) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (context.mounted) {
              context.go('/login');
            }
          });
          return const Scaffold(body: SizedBox.shrink());
        }

        return Scaffold(
          appBar: AppBar(
            leading: const AppBackButton(fallbackRoute: '/home'),
            title: const Text('Profile'),
            actions: [
              IconButton(
                tooltip: 'Edit Profile',
                onPressed: () => context.push('/profile/edit'),
                icon: const Icon(Icons.edit_outlined),
              ),
              IconButton(
                tooltip: 'Refresh',
                onPressed: () => ref.invalidate(currentUserProvider),
                icon: const Icon(Icons.refresh_rounded),
              ),
            ],
          ),
          body: RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(currentUserProvider);
              await Future<void>.delayed(const Duration(milliseconds: 250));
            },
            child: ResponsiveLayout(
              maxWidthDesktop: 760,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: ListView(
                padding: EdgeInsets.zero,
              children: [
                _ProfileHeader(user: user),
                const SizedBox(height: 14),
                _SectionCard(
                  title: 'Basic Information',
                  children: [
                    _InfoTile(label: 'Name', value: user.name),
                    _InfoTile(label: 'Email', value: user.email),
                    _InfoTile(label: 'Role', value: user.role.toUpperCase()),
                    _InfoTile(
                      label: 'College',
                      value: user.collegeName.isEmpty
                          ? user.collegeId
                          : user.collegeName,
                    ),
                    _InfoTile(
                      label: 'University',
                      value: user.affiliatedUniversityName,
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                _SectionCard(
                  title: 'Role Details',
                  children: _roleDetails(user),
                ),
                const SizedBox(height: 12),
                _SectionCard(
                  title: 'Bio',
                  children: [_InfoTile(label: 'About', value: user.customBio)],
                ),
                const SizedBox(height: 12),
                _SectionCard(
                  title: 'Social Links',
                  children: _socialLinks(user),
                ),
                const SizedBox(height: 12),
                _SectionCard(
                  title: 'Account Status',
                  children: [
                    _StatusChips(user: user),
                    const SizedBox(height: 8),
                    _InfoTile(
                      label: 'Joined On',
                      value: DateFormat('dd MMM yyyy').format(user.createdAt),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                if (_hasImage(user.photoUrl) ||
                    _hasImage(user.collegeIdCardPhotoUrl))
                  _SectionCard(
                    title: 'Uploaded Documents',
                    children: [
                      if (_hasImage(user.photoUrl))
                        _StorageImageTile(
                          title: 'Profile Picture',
                          storagePathOrUrl: user.photoUrl!,
                        ),
                      if (_hasImage(user.collegeIdCardPhotoUrl))
                        _StorageImageTile(
                          title: 'College ID Card',
                          storagePathOrUrl: user.collegeIdCardPhotoUrl!,
                        ),
                    ],
                  ),
              ],
            ),
          ),
        ),
      );
      },
      loading: () => Scaffold(
        appBar: AppBar(
          leading: const AppBackButton(fallbackRoute: '/home'),
          title: const Text('Profile'),
        ),
        body: const ProfileSkeleton(),
      ),
      error: (error, stackTrace) => Scaffold(
        appBar: AppBar(
          leading: const AppBackButton(fallbackRoute: '/home'),
          title: const Text('Profile'),
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.error_outline_rounded, size: 48),
                const SizedBox(height: 10),
                const Text('Unable to load profile'),
                const SizedBox(height: 8),
                Text('$error', textAlign: TextAlign.center),
              ],
            ),
          ),
        ),
      ),
    );
  }

  List<Widget> _roleDetails(UserModel user) {
    final role = user.role.toLowerCase();

    if (role == 'alumni') {
      return [
        _InfoTile(label: 'Branch', value: user.branch),
        _InfoTile(label: 'Batch Year', value: _stringOrDash(user.batchYear)),
        _InfoTile(label: 'Current Company', value: user.currentCompany),
        _InfoTile(label: 'Current Job Role', value: user.currentRole),
      ];
    }

    if (role == 'student' || role == 'teacher') {
      return [
        _InfoTile(label: 'Course', value: user.course),
        _InfoTile(label: 'Branch', value: user.branch),
        _InfoTile(label: 'Semester', value: _stringOrDash(user.semester)),
      ];
    }

    if (role == 'admin') {
      return [
        const _InfoTile(label: 'Access', value: 'Administrative account'),
        _InfoTile(label: 'Branch', value: user.branch),
      ];
    }

    return const [
      _InfoTile(label: 'Details', value: 'No role-specific details available'),
    ];
  }

  String _stringOrDash(Object? value) {
    if (value == null) {
      return '-';
    }
    final str = value.toString().trim();
    return str.isEmpty ? '-' : str;
  }

  bool _hasImage(String? value) {
    return value != null && value.trim().isNotEmpty;
  }

  List<Widget> _socialLinks(UserModel user) {
    if (user.profileLinks.isEmpty) {
      return const [_InfoTile(label: 'Links', value: 'No social links added')];
    }

    final entries = user.profileLinks.entries.toList()
      ..sort((a, b) => a.key.compareTo(b.key));

    return entries
        .map(
          (entry) =>
              _InfoTile(label: _labelForLinkKey(entry.key), value: entry.value),
        )
        .toList();
  }

  String _labelForLinkKey(String key) {
    final normalized = key.trim().toLowerCase();
    if (normalized.startsWith('link_')) {
      return 'Link ${normalized.replaceFirst('link_', '')}';
    }
    if (normalized == 'github') {
      return 'GitHub';
    }
    if (normalized == 'leetcode') {
      return 'LeetCode';
    }
    if (normalized == 'geeksforgeeks' || normalized == 'gfg') {
      return 'GeeksforGeeks';
    }
    return key[0].toUpperCase() + key.substring(1);
  }
}

class _ProfileHeader extends StatelessWidget {
  const _ProfileHeader({required this.user});

  final UserModel user;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.08),
        border: Border.all(
          color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.2),
        ),
      ),
      child: Row(
        children: [
          _Avatar(pathOrUrl: user.photoUrl, name: user.name),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  user.name.isEmpty ? 'User' : user.name,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 4),
                Text(user.email, style: Theme.of(context).textTheme.bodyMedium),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Avatar extends StatelessWidget {
  const _Avatar({required this.pathOrUrl, required this.name});

  final String? pathOrUrl;
  final String name;

  @override
  Widget build(BuildContext context) {
    if (pathOrUrl == null || pathOrUrl!.trim().isEmpty) {
      return CircleAvatar(radius: 28, child: Text(_initials(name)));
    }

    return FutureBuilder<String?>(
      future: _resolveDownloadUrl(pathOrUrl!),
      builder: (context, snapshot) {
        final url = snapshot.data;
        if (url == null || url.isEmpty) {
          return CircleAvatar(radius: 28, child: Text(_initials(name)));
        }

        return CircleAvatar(
          radius: 28,
          backgroundImage: CachedNetworkImageProvider(url),
          backgroundColor: Theme.of(
            context,
          ).colorScheme.surfaceContainerHighest,
        );
      },
    );
  }

  String _initials(String fullName) {
    final parts = fullName
        .trim()
        .split(RegExp(r'\s+'))
        .where((part) => part.isNotEmpty)
        .toList();
    if (parts.isEmpty) {
      return 'U';
    }
    if (parts.length == 1) {
      return parts.first.substring(0, 1).toUpperCase();
    }
    return '${parts.first.substring(0, 1)}${parts.last.substring(0, 1)}'
        .toUpperCase();
  }
}

class _StorageImageTile extends StatelessWidget {
  const _StorageImageTile({
    required this.title,
    required this.storagePathOrUrl,
  });

  final String title;
  final String storagePathOrUrl;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<String?>(
      future: _resolveDownloadUrl(storagePathOrUrl),
      builder: (context, snapshot) {
        final url = snapshot.data;
        return ListTile(
          contentPadding: EdgeInsets.zero,
          title: Text(title),
          subtitle: Text(
            url == null ? 'Unable to load preview' : 'Tap to open image',
          ),
          leading: ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: SizedBox(
              width: 52,
              height: 52,
              child: url == null
                  ? const ColoredBox(
                      color: Color(0x11000000),
                      child: Icon(Icons.broken_image_outlined),
                    )
                  : CachedNetworkImage(
                      imageUrl: url,
                      fit: BoxFit.cover,
                      errorWidget: (context, imageUrl, error) =>
                          const ColoredBox(
                            color: Color(0x11000000),
                            child: Icon(Icons.broken_image_outlined),
                          ),
                    ),
            ),
          ),
          onTap: url == null
              ? null
              : () {
                  showDialog<void>(
                    context: context,
                    builder: (_) => Dialog(
                      child: InteractiveViewer(
                        child: CachedNetworkImage(
                          imageUrl: url,
                          fit: BoxFit.contain,
                          errorWidget: (context, imageUrl, error) =>
                              const Center(
                                child: Icon(Icons.broken_image_outlined),
                              ),
                        ),
                      ),
                    ),
                  );
                },
        );
      },
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 10),
            ...children,
          ],
        ),
      ),
    );
  }
}

class _InfoTile extends StatelessWidget {
  const _InfoTile({required this.label, required this.value});

  final String label;
  final String? value;

  @override
  Widget build(BuildContext context) {
    final displayValue = (value == null || value!.trim().isEmpty)
        ? '-'
        : value!.trim();

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              displayValue,
              style: Theme.of(context).textTheme.bodyLarge,
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusChips extends StatelessWidget {
  const _StatusChips({required this.user});

  final UserModel user;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        _chip(
          context,
          label: user.isVerified ? 'Verified' : 'Not Verified',
          good: user.isVerified,
        ),
        _chip(
          context,
          label: user.isBanned ? 'Restricted' : 'Active',
          good: !user.isBanned,
        ),
        if (user.teacherRequestStatus != 'none')
          _chip(
            context,
            label: 'Teacher: ${user.teacherRequestStatus.toUpperCase()}',
            good: user.teacherRequestStatus == 'approved',
            isWarning: user.teacherRequestStatus == 'pending',
          ),
      ],
    );
  }

  Widget _chip(
    BuildContext context, {
    required String label,
    required bool good,
    bool isWarning = false,
  }) {
    final scheme = Theme.of(context).colorScheme;
    Color bg;
    Color fg;

    if (good) {
      bg = Colors.green.withValues(alpha: 0.12);
      fg = Colors.green.shade800;
    } else if (isWarning) {
      bg = Colors.orange.withValues(alpha: 0.12);
      fg = Colors.orange.shade800;
    } else {
      bg = scheme.errorContainer;
      fg = scheme.onErrorContainer;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(30),
      ),
      child: Text(
        label,
        style: TextStyle(fontWeight: FontWeight.w600, color: fg),
      ),
    );
  }
}

Future<String?> _resolveDownloadUrl(String pathOrUrl) async {
  return StorageImageCacheService.resolveDownloadUrl(pathOrUrl);
}
