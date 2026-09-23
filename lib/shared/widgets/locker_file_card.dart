import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../features/locker/data/locker_file_model.dart';

class LockerFileCard extends StatelessWidget {
  const LockerFileCard({
    super.key,
    required this.file,
    required this.onOpen,
    required this.onRename,
    required this.onAddTags,
    required this.onCacheOffline,
    required this.onDelete,
    this.gridMode = false,
  });

  final LockerFileModel file;
  final VoidCallback onOpen;
  final Future<void> Function() onRename;
  final Future<void> Function() onAddTags;
  final Future<void> Function() onCacheOffline;
  final Future<void> Function() onDelete;
  final bool gridMode;

  @override
  Widget build(BuildContext context) {
    final child = InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: onOpen,
      onLongPress: () => _showActionSheet(context),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: gridMode ? _gridBody(context) : _listBody(context),
      ),
    );

    return Card(child: child);
  }

  Widget _listBody(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _pdfBadge(context),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                file.fileName,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.titleSmall,
              ),
              const SizedBox(height: 4),
              Text(
                '${_formatBytes(file.fileSize)} • ${DateFormat('dd MMM yyyy').format(file.uploadedAt)}',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 6),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  ...file.tags
                      .take(4)
                      .map(
                        (tag) => Chip(
                          label: Text(tag),
                          visualDensity: VisualDensity.compact,
                        ),
                      ),
                  if (file.isOfflineCached)
                    Chip(
                      label: const Text('Offline'),
                      backgroundColor: Colors.green.withValues(alpha: 0.12),
                      visualDensity: VisualDensity.compact,
                    ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _gridBody(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            _pdfBadge(context),
            const Spacer(),
            if (file.isOfflineCached)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.green.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Text(
                  'Offline',
                  style: TextStyle(
                    color: Colors.green.shade800,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          file.fileName,
          maxLines: 3,
          overflow: TextOverflow.ellipsis,
          style: Theme.of(context).textTheme.titleSmall,
        ),
        const Spacer(),
        Text(
          _formatBytes(file.fileSize),
          style: Theme.of(context).textTheme.bodySmall,
        ),
        Text(
          DateFormat('dd MMM').format(file.uploadedAt),
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ],
    );
  }

  Widget _pdfBadge(BuildContext context) {
    return Container(
      width: 42,
      height: 42,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.12),
      ),
      alignment: Alignment.center,
      child: Icon(
        Icons.picture_as_pdf_rounded,
        color: Theme.of(context).colorScheme.primary,
      ),
    );
  }

  Future<void> _showActionSheet(BuildContext context) async {
    await showModalBottomSheet<void>(
      context: context,
      builder: (sheetContext) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.drive_file_rename_outline_rounded),
                title: const Text('Rename'),
                onTap: () async {
                  Navigator.of(sheetContext).pop();
                  await onRename();
                },
              ),
              ListTile(
                leading: const Icon(Icons.sell_outlined),
                title: const Text('Add Tags'),
                onTap: () async {
                  Navigator.of(sheetContext).pop();
                  await onAddTags();
                },
              ),
              ListTile(
                leading: const Icon(Icons.download_for_offline_outlined),
                title: const Text('Cache Offline'),
                onTap: () async {
                  Navigator.of(sheetContext).pop();
                  await onCacheOffline();
                },
              ),
              ListTile(
                leading: Icon(
                  Icons.delete_outline_rounded,
                  color: Theme.of(context).colorScheme.error,
                ),
                title: Text(
                  'Delete',
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
                onTap: () async {
                  Navigator.of(sheetContext).pop();
                  await onDelete();
                },
              ),
            ],
          ),
        );
      },
    );
  }

  static String _formatBytes(int bytes) {
    if (bytes <= 0) {
      return '0 B';
    }
    const units = ['B', 'KB', 'MB', 'GB'];
    var value = bytes.toDouble();
    var unitIndex = 0;
    while (value >= 1024 && unitIndex < units.length - 1) {
      value /= 1024;
      unitIndex++;
    }
    final fraction = unitIndex == 0 ? 0 : 2;
    return '${value.toStringAsFixed(fraction)} ${units[unitIndex]}';
  }
}
