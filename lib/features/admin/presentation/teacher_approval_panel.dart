import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';

import '../domain/admin_providers.dart';
import '../../auth/domain/auth_providers.dart';
import '../../../shared/models/user_model.dart';
import '../../../shared/services/storage_image_cache_service.dart';

class TeacherApprovalPanel extends ConsumerWidget {
  const TeacherApprovalPanel({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pending = ref.watch(adminPendingTeacherRequestsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Teacher Approval Panel'),
        actions: [
          IconButton(
            onPressed: () =>
                ref.invalidate(adminPendingTeacherRequestsProvider),
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(adminPendingTeacherRequestsProvider);
          await Future<void>.delayed(const Duration(milliseconds: 500));
        },
        child: pending.when(
          data: (users) {
            if (users.isEmpty) {
              return const Center(child: Text('No pending teacher requests.'));
            }
            return ListView.separated(
              padding: const EdgeInsets.all(12),
              itemCount: users.length,
              separatorBuilder: (context, index) => const SizedBox(height: 10),
              itemBuilder: (context, index) {
                final user = users[index];
                return _UserCard(user: user);
              },
            );
          },
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (err, st) => Center(child: Text('Failed to load: $err')),
        ),
      ),
    );
  }
}

class _UserCard extends ConsumerWidget {
  const _UserCard({required this.user});

  final UserModel user;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final adminRepo = ref.read(adminRepositoryProvider);
    final currentUserAsync = ref.watch(currentUserStreamProvider);
    final currentAdmin = currentUserAsync.value;

    Future<void> approve() async {
      final adminUid = currentAdmin?.uid ?? '';
      if (adminUid.isEmpty) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Admin session not ready')),
          );
        }
        return;
      }
      try {
        await adminRepo.approveTeacherRequest(user.uid, adminUid: adminUid);
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Approved teacher request')),
          );
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('Approve failed: $e')));
        }
      }
    }

    Future<void> reject() async {
      final adminUid = currentAdmin?.uid ?? '';
      if (adminUid.isEmpty) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Admin session not ready')),
          );
        }
        return;
      }

      final controller = TextEditingController();
      final reason = await showDialog<String>(
        context: context,
        builder: (dialogContext) {
          return AlertDialog(
            title: const Text('Reject Teacher Request'),
            content: TextField(
              controller: controller,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'Reason for Rejection',
                hintText: 'Enter reason (optional)',
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () =>
                    Navigator.of(dialogContext).pop(controller.text.trim()),
                child: const Text('Reject'),
              ),
            ],
          );
        },
      );

      if (reason == null) return; // User cancelled

      try {
        await adminRepo.rejectTeacherRequest(
          user.uid,
          adminUid: adminUid,
          reason: reason.isEmpty ? null : reason,
        );
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Rejected teacher request')),
          );
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('Reject failed: $e')));
        }
      }
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _UserAvatar(pathOrUrl: user.photoUrl, name: user.name),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        user.name,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      Text(
                        user.email,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${user.course} • ${user.branch}',
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                      Text(
                        user.collegeName,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            if (user.collegeIdCardPhotoUrl != null &&
                user.collegeIdCardPhotoUrl!.isNotEmpty) ...[
              const SizedBox(height: 12),
              const Text(
                'College ID Card:',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
              ),
              const SizedBox(height: 4),
              _StorageImagePreview(
                storagePathOrUrl: user.collegeIdCardPhotoUrl!,
              ),
            ],
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: FilledButton.icon(
                    onPressed: approve,
                    icon: const Icon(Icons.check_circle_outline),
                    label: const Text('Approve'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: reject,
                    icon: const Icon(Icons.cancel_outlined),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.red,
                    ),
                    label: const Text('Reject'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _UserAvatar extends StatelessWidget {
  const _UserAvatar({required this.pathOrUrl, required this.name});
  final String? pathOrUrl;
  final String name;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<String?>(
      future: StorageImageCacheService.resolveDownloadUrl(pathOrUrl ?? ''),
      builder: (context, snapshot) {
        final url = snapshot.data;
        if (url == null || url.isEmpty) {
          return CircleAvatar(
            radius: 24,
            child: Text(name.isNotEmpty ? name[0].toUpperCase() : 'U'),
          );
        }
        return CircleAvatar(
          radius: 24,
          backgroundImage: CachedNetworkImageProvider(url),
        );
      },
    );
  }
}

class _StorageImagePreview extends StatelessWidget {
  const _StorageImagePreview({required this.storagePathOrUrl});
  final String storagePathOrUrl;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<String?>(
      future: StorageImageCacheService.resolveDownloadUrl(storagePathOrUrl),
      builder: (context, snapshot) {
        final url = snapshot.data;
        if (url == null || url.isEmpty) {
          return const SizedBox(
            height: 40,
            child: Center(child: Text('Loading image...')),
          );
        }
        return InkWell(
          onTap: () {
            showDialog(
              context: context,
              builder: (_) => Dialog(
                child: InteractiveViewer(
                  child: CachedNetworkImage(imageUrl: url),
                ),
              ),
            );
          },
          child: ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: CachedNetworkImage(
              imageUrl: url,
              height: 120,
              width: double.infinity,
              fit: BoxFit.cover,
              placeholder: (context, url) => Container(color: Colors.grey[200]),
              errorWidget: (context, url, error) => const Icon(Icons.error),
            ),
          ),
        );
      },
    );
  }
}
