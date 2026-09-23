import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../models/user_model.dart';
import '../services/storage_image_cache_service.dart';

class AlumniCard extends StatelessWidget {
  const AlumniCard({super.key, required this.alumni, required this.onTap});

  final UserModel alumni;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  _AlumniAvatar(pathOrUrl: alumni.photoUrl, name: alumni.name),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          alumni.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${_safe(alumni.currentCompany)} • ${_safe(alumni.currentRole)}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Batch ${alumni.batchYear?.toString() ?? '-'}',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                  if (alumni.openToRefer)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.green.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        'Open',
                        style: TextStyle(
                          color: Colors.green.shade800,
                          fontWeight: FontWeight.w600,
                          fontSize: 12,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  _StatChip(
                    icon: Icons.volunteer_activism_outlined,
                    label: '${alumni.referralsGiven} referrals',
                  ),
                  const SizedBox(width: 8),
                  _StatChip(
                    icon: Icons.star_rounded,
                    label: alumni.avgRating.toStringAsFixed(1),
                  ),
                  const SizedBox(width: 8),
                  _StatChip(
                    icon: Icons.question_answer_outlined,
                    label: '${alumni.questionsAnswered} answers',
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _safe(String? value) {
    if (value == null || value.trim().isEmpty) {
      return '-';
    }
    return value.trim();
  }
}

class _StatChip extends StatelessWidget {
  const _StatChip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10),
          color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.08),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 14),
            const SizedBox(width: 4),
            Flexible(
              child: Text(
                label,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AlumniAvatar extends StatelessWidget {
  const _AlumniAvatar({required this.pathOrUrl, required this.name});

  final String? pathOrUrl;
  final String name;

  @override
  Widget build(BuildContext context) {
    if (pathOrUrl == null || pathOrUrl!.trim().isEmpty) {
      return CircleAvatar(radius: 24, child: Text(_initials(name)));
    }

    return FutureBuilder<String?>(
      future: _resolveDownloadUrl(pathOrUrl!),
      builder: (context, snapshot) {
        final url = snapshot.data;
        if (url == null || url.isEmpty) {
          return CircleAvatar(radius: 24, child: Text(_initials(name)));
        }
        return CircleAvatar(
          radius: 24,
          backgroundImage: CachedNetworkImageProvider(url),
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
      return 'A';
    }
    if (parts.length == 1) {
      return parts.first.substring(0, 1).toUpperCase();
    }
    return '${parts.first.substring(0, 1)}${parts.last.substring(0, 1)}'
        .toUpperCase();
  }
}

Future<String?> _resolveDownloadUrl(String pathOrUrl) async {
  return StorageImageCacheService.resolveDownloadUrl(pathOrUrl);
}
