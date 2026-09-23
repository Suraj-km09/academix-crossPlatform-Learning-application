import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:open_file/open_file.dart';
import 'package:path_provider/path_provider.dart';
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';

import '../../../features/placement/presentation/placement_pdf_viewer_screen.dart';

import '../../../features/auth/domain/auth_providers.dart';
import '../../../shared/widgets/app_back_button.dart';
import '../../../shared/widgets/empty_state.dart';
import '../../../shared/widgets/loading_widget.dart';
import '../../../shared/widgets/responsive_layout.dart';
import '../data/bulletin_model.dart';
import '../domain/bulletin_providers.dart';

class BulletinDetailScreen extends ConsumerStatefulWidget {
  const BulletinDetailScreen({
    super.key,
    required this.bulletinId,
    this.initialBulletin,
  });

  final String bulletinId;
  final BulletinModel? initialBulletin;

  @override
  ConsumerState<BulletinDetailScreen> createState() =>
      _BulletinDetailScreenState();
}

class _BulletinDetailScreenState extends ConsumerState<BulletinDetailScreen> {
  bool _markingRead = false;
  bool _downloading = false;
  double _downloadProgress = 0;

  @override
  Widget build(BuildContext context) {
    final userAsync = ref.watch(currentUserProvider);

    return userAsync.when(
      data: (user) {
        if (user == null) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) context.go('/login');
          });
          return const Scaffold(body: SizedBox.shrink());
        }

        final bulletinAsync = ref.watch(bulletinByIdProvider(widget.bulletinId));
        final bulletin = bulletinAsync.asData?.value ?? widget.initialBulletin;

        if (bulletin == null) {
          return Scaffold(
            appBar: AppBar(
              leading: const AppBackButton(fallbackRoute: '/bulletin'),
              title: const Text('Bulletin Details'),
            ),
            body: bulletinAsync.when(
              data: (_) => const EmptyState(
                title: 'Bulletin not found',
                subtitle: 'This bulletin may have been deleted.',
              ),
              loading: () => const LoadingWidget(message: 'Loading bulletin...'),
              error: (error, _) => EmptyState(title: 'Unable to load bulletin', subtitle: '$error'),
            ),
          );
        }

        _markAsReadIfNeeded(bulletin.bulletinId, user.uid, bulletin.readBy);

        final canDelete = user.uid == bulletin.postedBy || user.role.trim().toLowerCase() == 'admin';
        final canPin = user.role.trim().toLowerCase() == 'admin';

        return Scaffold(
          appBar: AppBar(
            leading: const AppBackButton(fallbackRoute: '/bulletin'),
            title: const Text('Bulletin Details'),
            actions: [
              if (canPin && !bulletin.isPinned)
                IconButton(
                  tooltip: 'Pin bulletin',
                  onPressed: () async {
                    try {
                      await ref.read(bulletinRepositoryProvider).pinBulletin(bulletin.bulletinId);
                      _showSnackBar('Bulletin pinned');
                    } catch (error) { _showSnackBar('Unable to pin bulletin: $error'); }
                  },
                  icon: const Icon(Icons.push_pin_outlined),
                ),
              if (canDelete)
                IconButton(
                  tooltip: 'Delete bulletin',
                  onPressed: () => _confirmDelete(bulletin.bulletinId),
                  icon: const Icon(Icons.delete_outline_rounded),
                ),
            ],
          ),
          body: ResponsiveLayout(
            child: Column(
              children: [
                if (bulletin.hasAttachment)
                  Expanded(
                    flex: 3,
                    child: SfPdfViewer.network(
                      bulletin.attachmentUrl!,
                      canShowScrollHead: true,
                      canShowScrollStatus: true,
                      onDocumentLoaded: (details) {},
                      onDocumentLoadFailed: (details) {
                        _showSnackBar('Failed to load PDF: ${details.error}');
                      },
                    ),
                  ),
                Expanded(
                  flex: 2,
                  child: SingleChildScrollView(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              _CategoryBadge(
                                label: bulletin.category.toUpperCase(),
                                color: _categoryColor(bulletin.category),
                              ),
                              const SizedBox(width: 8),
                              if (bulletin.isPinned)
                                Icon(Icons.push_pin_rounded, color: Theme.of(context).colorScheme.primary),
                            ],
                          ),
                          const SizedBox(height: 16),
                          Text(bulletin.title, style: Theme.of(context).textTheme.headlineMedium),
                          const SizedBox(height: 12),
                          Text(
                            bulletin.description,
                            style: Theme.of(context).textTheme.bodyLarge?.copyWith(height: 1.5),
                          ),
                          const SizedBox(height: 24),
                          const Divider(),
                          const SizedBox(height: 16),
                          _InfoGrid(bulletin: bulletin),
                          if (bulletin.hasAttachment) ...[
                            const SizedBox(height: 24),
                            _AttachmentSection(
                              name: bulletin.attachmentName,
                              url: bulletin.attachmentUrl!,
                              downloading: _downloading,
                              progress: _downloadProgress,
                              onDownload: () => _downloadAndOpen(bulletin.attachmentUrl!, bulletin.attachmentName),
                              onFullScreen: () => _showFullScreenViewer(context, bulletin.attachmentUrl!, bulletin.title),
                            ),
                          ],
                          if (_markingRead)
                            const Padding(padding: EdgeInsets.only(top: 12), child: LinearProgressIndicator(minHeight: 2)),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
      loading: () => const Scaffold(body: LoadingWidget(message: 'Loading profile...')),
      error: (error, _) => Scaffold(
        appBar: AppBar(title: const Text('Bulletin Details')),
        body: EmptyState(title: 'Unable to load profile', subtitle: '$error'),
      ),
    );
  }

  void _showFullScreenViewer(BuildContext context, String url, String title) {
    Navigator.of(context).push(MaterialPageRoute(builder: (context) => PlacementPdfViewerScreen(title: title, pdfUrl: url)));
  }

  Future<void> _markAsReadIfNeeded(String bulletinId, String uid, List<String> readBy) async {
    if (_markingRead || readBy.contains(uid)) return;
    _markingRead = true;
    try { await ref.read(bulletinRepositoryProvider).markAsRead(bulletinId, uid); } catch (_) {}
    finally { _markingRead = false; }
  }

  Future<void> _downloadAndOpen(String url, String? name) async {
    try {
      setState(() { _downloading = true; _downloadProgress = 0; });
      final dir = await getTemporaryDirectory();
      final fn = (name ?? 'attachment.pdf').trim().isEmpty ? 'attachment.pdf' : name!.trim();
      final path = '${dir.path}${Platform.pathSeparator}$fn';
      await Dio().download(url, path, onReceiveProgress: (r, t) {
        if (!mounted || t <= 0) return;
        setState(() => _downloadProgress = (r / t).clamp(0, 1));
      });
      await OpenFile.open(path);
    } catch (e) { _showSnackBar('Download failed: $e'); }
    finally { if (mounted) setState(() { _downloading = false; _downloadProgress = 0; }); }
  }

  Future<void> _confirmDelete(String id) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete Bulletin'),
        content: const Text('Are you sure? This cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Delete')),
        ],
      ),
    );
    if (confirm == true) {
      try {
        await ref.read(bulletinRepositoryProvider).deleteBulletin(id);
        if (mounted) context.pop(id);
      } catch (e) { _showSnackBar('Delete failed: $e'); }
    }
  }

  Color _categoryColor(String c) {
    switch (c.toLowerCase()) {
      case 'deadline': return Colors.red;
      case 'placement': return Colors.green;
      case 'notice': return Colors.blue;
      case 'event': return Colors.orange.shade800;
      case 'holiday': return Colors.teal;
      default: return Colors.blueGrey;
    }
  }

  void _showSnackBar(String m) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));
}

class _InfoGrid extends StatelessWidget {
  final BulletinModel bulletin;
  const _InfoGrid({required this.bulletin});
  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, constraints) {
      final isWide = constraints.maxWidth > 600;
      final children = [
        if (bulletin.category == 'event' && bulletin.eventDate != null)
          _InfoTile(Icons.event_rounded, 'Event Date', DateFormat('dd MMM yyyy, hh:mm a').format(bulletin.eventDate!)),
        _InfoTile(Icons.person_outline, 'Posted By', '${bulletin.postedByName} (${bulletin.postedByRole.toUpperCase()})'),
        _InfoTile(Icons.schedule, 'Created At', DateFormat('dd MMM yyyy, hh:mm a').format(bulletin.createdAt)),
        if (bulletin.targetCourse?.isNotEmpty == true) _InfoTile(Icons.school_outlined, 'Target Course', bulletin.targetCourse!),
        if (bulletin.targetSemester != null) _InfoTile(Icons.filter_9_plus_outlined, 'Semester', bulletin.targetSemester.toString()),
      ];
      if (isWide) {
        return Wrap(runSpacing: 16, children: children.map((e) => SizedBox(width: constraints.maxWidth / 2, child: e)).toList());
      }
      return Column(children: children);
    });
  }
}

class _InfoTile extends StatelessWidget {
  final IconData icon; final String label; final String value;
  const _InfoTile(this.icon, this.label, this.value);
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(children: [
        Icon(icon, size: 20, color: Theme.of(context).colorScheme.primary),
        const SizedBox(width: 12),
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label, style: Theme.of(context).textTheme.labelSmall),
          Text(value, style: Theme.of(context).textTheme.bodyMedium),
        ]),
      ]),
    );
  }
}

class _AttachmentSection extends StatelessWidget {
  final String? name; final String url; final bool downloading; final double progress; final VoidCallback onDownload;
  final VoidCallback onFullScreen;
  const _AttachmentSection({this.name, required this.url, required this.downloading, required this.progress, required this.onDownload, required this.onFullScreen});
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(borderRadius: BorderRadius.circular(12), color: Theme.of(context).colorScheme.surfaceContainerHighest),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const Icon(Icons.attach_file),
          const SizedBox(width: 8),
          Expanded(child: Text(name ?? 'Attachment', style: Theme.of(context).textTheme.titleSmall)),
          IconButton(
            icon: const Icon(Icons.fullscreen),
            onPressed: onFullScreen,
            tooltip: 'Full screen',
          ),
        ]),
        if (downloading) Padding(padding: const EdgeInsets.symmetric(vertical: 8), child: LinearProgressIndicator(value: progress > 0 ? progress : null)),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: FilledButton.icon(
                onPressed: downloading ? null : onDownload,
                icon: const Icon(Icons.download),
                label: Text(downloading ? 'Downloading...' : 'Download'),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: onFullScreen,
                icon: const Icon(Icons.remove_red_eye_outlined),
                label: const Text('View Full Screen'),
              ),
            ),
          ],
        ),
      ]),
    );
  }
}

class _CategoryBadge extends StatelessWidget {
  final String label; final Color color;
  const _CategoryBadge({required this.label, required this.color});
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(borderRadius: BorderRadius.circular(20), color: color.withOpacity(0.12), border: Border.all(color: color.withOpacity(0.25))),
      child: Text(label, style: Theme.of(context).textTheme.labelSmall?.copyWith(color: color, fontWeight: FontWeight.bold)),
    );
  }
}
