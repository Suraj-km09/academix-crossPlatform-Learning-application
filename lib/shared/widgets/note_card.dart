import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../features/notes/data/note_model.dart';

class NoteCard extends StatelessWidget {
  const NoteCard({
    super.key,
    required this.note,
    required this.onTap,
    this.isBookmarked = false,
  });

  final NoteModel note;
  final VoidCallback onTap;
  final bool isBookmarked;

  @override
  Widget build(BuildContext context) {
    final date = DateFormat('dd MMM yyyy').format(note.uploadedAt);
    final isCommunity =
        note.tags.any((tag) => tag.toLowerCase() == 'community') ||
        note.tags.any((tag) => tag.toLowerCase() == 'student');

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
                  Expanded(
                    child: Text(
                      note.title,
                      style: Theme.of(context).textTheme.titleMedium,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (isBookmarked)
                    Icon(
                      Icons.bookmark_rounded,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                note.year.trim().isNotEmpty
                    ? '${note.subject} • Year ${note.year} • Semester ${note.semester}'
                    : '${note.subject} • Semester ${note.semester}',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              if (note.course.trim().isNotEmpty ||
                  note.branch.trim().isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    [
                      note.course.trim(),
                      note.branch.trim(),
                    ].where((value) => value.isNotEmpty).join(' • '),
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 6,
                children: [
                  if (note.isVerified)
                    _badge(context, 'Verified', Colors.green),
                  if (isCommunity) _badge(context, 'Community', Colors.blue),
                  if (note.section == 'sessional')
                    _badge(context, 'Sessional', Colors.teal),
                  if (note.section == 'put')
                    _badge(context, 'PUT', Colors.indigo),
                  if (note.type == 'pyq')
                    _badge(
                      context,
                      note.pyqYear == null ? 'PYQ' : 'PYQ ${note.pyqYear}',
                      Colors.deepPurple,
                    ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'By ${note.uploaderName.isEmpty ? 'Unknown' : note.uploaderName}',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ),
                  Text(date, style: Theme.of(context).textTheme.bodySmall),
                ],
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  const Icon(Icons.download_rounded, size: 16),
                  const SizedBox(width: 4),
                  Text(
                    '${note.downloadCount}',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  const SizedBox(width: 12),
                  const Icon(Icons.picture_as_pdf_rounded, size: 16),
                  const SizedBox(width: 4),
                  Text(
                    _readableSize(note.fileSize),
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _badge(BuildContext context, String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Text(
        text,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: color,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  String _readableSize(int size) {
    if (size <= 0) {
      return '0 B';
    }
    const units = ['B', 'KB', 'MB', 'GB'];
    var value = size.toDouble();
    var idx = 0;

    while (value >= 1024 && idx < units.length - 1) {
      value = value / 1024;
      idx++;
    }

    final fixed = value >= 100
        ? value.toStringAsFixed(0)
        : value.toStringAsFixed(1);
    return '$fixed ${units[idx]}';
  }
}
