import 'package:flutter/material.dart';

import '../../features/bulletin/data/bulletin_model.dart';

class BulletinCard extends StatelessWidget {
  const BulletinCard({
    super.key,
    required this.bulletin,
    required this.currentUid,
    required this.onTap,
  });

  final BulletinModel bulletin;
  final String currentUid;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isUnread = !bulletin.readBy.contains(currentUid);
    final categoryStyle = _categoryStyle(bulletin.category);

    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  _CategoryBadge(
                    label: bulletin.category.toUpperCase(),
                    color: categoryStyle,
                  ),
                  const SizedBox(width: 8),
                  if (bulletin.isPinned)
                    Icon(
                      Icons.push_pin_rounded,
                      size: 18,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  const Spacer(),
                  if (isUnread)
                    Container(
                      width: 9,
                      height: 9,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                bulletin.title,
                style: Theme.of(context).textTheme.titleMedium,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 6),
              Text(
                bulletin.description,
                style: Theme.of(context).textTheme.bodyMedium,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      '${bulletin.postedByName} • ${bulletin.postedByRole.toUpperCase()}',
                      style: Theme.of(context).textTheme.bodySmall,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    _timeAgo(bulletin.createdAt),
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
              if (bulletin.hasAttachment) ...[
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Icon(Icons.attach_file_rounded, size: 17),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        (bulletin.attachmentName ?? 'Attachment').trim(),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Color _categoryStyle(String category) {
    switch (category.trim().toLowerCase()) {
      case 'deadline':
        return Colors.red;
      case 'placement':
        return Colors.green;
      case 'notice':
        return Colors.blue;
      case 'event':
        return Colors.amber.shade800;
      case 'holiday':
        return Colors.teal;
      default:
        return Colors.blueGrey;
    }
  }

  String _timeAgo(DateTime dateTime) {
    final now = DateTime.now();
    final diff = now.difference(dateTime);

    if (diff.inMinutes < 1) {
      return 'Just now';
    }
    if (diff.inMinutes < 60) {
      return '${diff.inMinutes}m ago';
    }
    if (diff.inHours < 24) {
      return '${diff.inHours}h ago';
    }
    if (diff.inDays < 7) {
      return '${diff.inDays}d ago';
    }
    final weeks = (diff.inDays / 7).floor();
    if (weeks < 5) {
      return '${weeks}w ago';
    }
    final months = (diff.inDays / 30).floor();
    if (months < 12) {
      return '${months}mo ago';
    }
    final years = (diff.inDays / 365).floor();
    return '${years}y ago';
  }
}

class _CategoryBadge extends StatelessWidget {
  const _CategoryBadge({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        color: color.withValues(alpha: 0.12),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: color,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
