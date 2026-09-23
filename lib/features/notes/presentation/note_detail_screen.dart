import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:dio/dio.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:intl/intl.dart';
import 'package:open_file/open_file.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../../core/errors/app_exception.dart';
import '../../../core/constants/firestore_paths.dart';
import '../../../shared/services/ad_service.dart';
import '../../../shared/widgets/app_back_button.dart';
import '../../../shared/widgets/empty_state.dart';
import '../../../shared/widgets/skeleton_loader.dart';
import '../data/note_model.dart';
import '../data/notes_repository.dart';

class NoteDetailScreen extends StatefulWidget {
  const NoteDetailScreen({super.key, required this.noteId, this.initialNote});

  final String noteId;
  final NoteModel? initialNote;

  @override
  State<NoteDetailScreen> createState() => _NoteDetailScreenState();
}

class _NoteDetailScreenState extends State<NoteDetailScreen> {
  final NotesRepository _repository = NotesRepository();
  final Dio _dio = Dio();

  NoteModel? _note;
  Box<dynamic>? _downloadedBox;

  bool _loading = true;
  bool _downloading = false;
  bool _bookmarkLoading = false;
  bool _isBookmarked = false;
  bool _canDelete = false;
  String _currentUserRole = '';

  String? _pdfPath;
  bool _isOfflineAvailable = false;
  bool _isFullScreen = false;

  @override
  void initState() {
    super.initState();
    AdService.loadInterstitialAd(null, () {});
    _bootstrap();
  }

  @override
  void dispose() {
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    super.dispose();
  }

  void _toggleFullScreen() {
    setState(() {
      _isFullScreen = !_isFullScreen;
      if (_isFullScreen) {
        SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
      } else {
        SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final note = _note;

    return Scaffold(
      appBar: _isFullScreen
          ? null
          : AppBar(
              leading: const AppBackButton(fallbackRoute: '/notes'),
              title: Text(note?.title ?? 'Note Detail'),
              actions: [
                if (note != null)
                  IconButton(
                    onPressed: _share,
                    icon: const Icon(Icons.share_rounded),
                    tooltip: 'Share',
                  ),
                if (note != null && _canDelete)
                  IconButton(
                    onPressed: _confirmDelete,
                    icon: const Icon(Icons.delete_outline_rounded),
                    tooltip: 'Delete note',
                  ),
              ],
            ),
      body: _loading
          ? const NoteDetailSkeleton()
          : note == null
              ? const EmptyState(
                  title: 'Note unavailable',
                  subtitle: 'This note does not exist or was removed.',
                )
              : Column(
                  children: [
                    Expanded(
                      child: Stack(
                        children: [
                          _isOfflineAvailable && _pdfPath != null
                              ? SfPdfViewer.file(
                                  File(_pdfPath!),
                                  canShowScrollHead: true,
                                  canShowScrollStatus: true,
                                )
                              : SfPdfViewer.network(
                                  note.fileUrl,
                                  canShowScrollHead: true,
                                  canShowScrollStatus: true,
                                ),
                          Positioned(
                            right: 16,
                            bottom: 16,
                            child: FloatingActionButton.small(
                              heroTag: 'fullscreen_toggle',
                              onPressed: _toggleFullScreen,
                              child: Icon(_isFullScreen
                                  ? Icons.fullscreen_exit_rounded
                                  : Icons.fullscreen_rounded),
                            ),
                          ),
                          if (_isFullScreen)
                            Positioned(
                              left: 16,
                              top: 16,
                              child: SafeArea(
                                child: CircleAvatar(
                                  backgroundColor: Colors.black54,
                                  child: IconButton(
                                    icon: const Icon(Icons.arrow_back,
                                        color: Colors.white),
                                    onPressed: _toggleFullScreen,
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                    if (!_isFullScreen)
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.surface,
                          border: Border(
                            top: BorderSide(
                                color: Theme.of(context).dividerColor),
                          ),
                        ),
                        child: SingleChildScrollView(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                note.title,
                                style:
                                    Theme.of(context).textTheme.titleMedium,
                              ),
                              const SizedBox(height: 8),
                              Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: [
                                  _chip('Subject: ${note.subject}'),
                                  _chip('Semester: ${note.semester}'),
                                  _chip('Type: ${note.type.toUpperCase()}'),
                                  if (note.pyqYear != null)
                                    _chip('PYQ Year: ${note.pyqYear}'),
                                  if (note.isVerified) _chip('Verified'),
                                  if (_isOfflineAvailable)
                                    _chip('Available Offline'),
                                ],
                              ),
                              const SizedBox(height: 10),
                              Text(
                                'Uploaded by ${note.uploaderName} on ${DateFormat('dd MMM yyyy, hh:mm a').format(note.uploadedAt)}',
                                style:
                                    Theme.of(context).textTheme.bodySmall,
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Downloads: ${note.downloadCount} • File: ${note.fileName}',
                                style:
                                    Theme.of(context).textTheme.bodySmall,
                              ),
                              if (note.tags.isNotEmpty) ...[
                                const SizedBox(height: 10),
                                Wrap(
                                  spacing: 8,
                                  runSpacing: 8,
                                  children: note.tags
                                      .map((tag) => _chip('#$tag'))
                                      .toList(),
                                ),
                              ],
                              const SizedBox(height: 12),
                              Row(
                                children: [
                                  Expanded(
                                    child: ElevatedButton.icon(
                                      onPressed: _downloading
                                          ? null
                                          : _downloadAndOpen,
                                      icon: _downloading
                                          ? const SizedBox(
                                              width: 16,
                                              height: 16,
                                              child:
                                                  CircularProgressIndicator(
                                                strokeWidth: 2,
                                              ),
                                            )
                                          : const Icon(
                                              Icons.download_rounded),
                                      label: Text(
                                        _downloading
                                            ? 'Downloading...'
                                            : 'Download',
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  IconButton.filledTonal(
                                    onPressed: _bookmarkLoading
                                        ? null
                                        : _toggleBookmark,
                                    icon: Icon(
                                      _isBookmarked
                                          ? Icons.bookmark
                                          : Icons.bookmark_border,
                                    ),
                                    tooltip: _isBookmarked
                                        ? 'Remove bookmark'
                                        : 'Bookmark',
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
    );
  }

  Future<void> _bootstrap() async {
    try {
      _downloadedBox = await Hive.openBox<dynamic>('downloaded_notes');

      NoteModel? fetchedNote;
      try {
        fetchedNote = await _repository.getNoteById(widget.noteId);
      } catch (_) {
        fetchedNote = widget.initialNote;
      }

      if (fetchedNote == null) {
        setState(() {
          _note = null;
          _loading = false;
        });
        return;
      }

      _note = fetchedNote;

      final savedPath = _downloadedBox?.get(fetchedNote.noteId) as String?;
      if (savedPath != null && File(savedPath).existsSync()) {
        _pdfPath = savedPath;
        _isOfflineAvailable = true;
      }

      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid != null) {
        _isBookmarked = await _repository.isBookmarked(uid, fetchedNote.noteId);

        final userDoc = await FirebaseFirestore.instance
            .collection(FirestorePaths.users)
            .doc(uid)
            .get();
        final role = (userDoc.data()?['role'] as String? ?? '')
            .trim()
            .toLowerCase();
        _currentUserRole = role;
        _canDelete = fetchedNote.uploadedBy == uid || role == 'admin';
      }
    } catch (error) {
      if (mounted) {
        _showSnackBar('Failed to load note: $error');
      }
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _downloadAndOpen() async {
    final note = _note;
    if (note == null) {
      return;
    }

    if (_isOfflineAvailable &&
        _pdfPath != null &&
        File(_pdfPath!).existsSync()) {
      final existingResult = await OpenFile.open(_pdfPath!);
      if (existingResult.type != ResultType.done) {
        _showSnackBar('Unable to open local file: ${existingResult.message}');
      }
      return;
    }

    setState(() => _downloading = true);

    try {
      final docs = await getApplicationDocumentsDirectory();
      final folder = Directory(
        '${docs.path}${Platform.pathSeparator}notes_downloads',
      );
      if (!folder.existsSync()) {
        folder.createSync(recursive: true);
      }

      final safeName = _sanitizeFileName(
        note.fileName.isEmpty ? '${note.noteId}.pdf' : note.fileName,
      );
      final targetPath = '${folder.path}${Platform.pathSeparator}$safeName';

      await _dio.download(note.fileUrl, targetPath);
      await _decompressIfGzip(targetPath);

      await _downloadedBox?.put(note.noteId, targetPath);

      var incremented = false;
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid != null && uid.trim().isNotEmpty) {
        incremented = await _repository.registerUniqueDownload(
          note.noteId,
          uid,
        );
      }

      final result = await OpenFile.open(targetPath);
      if (result.type != ResultType.done) {
        throw AppException(message: result.message);
      }

      await AdService.showInterstitialIfReady();
      await AdService.loadInterstitialAd(null, () {});

      setState(() {
        _isOfflineAvailable = true;
        _pdfPath = targetPath;
        _note = note.copyWith(
          downloadCount: incremented
              ? note.downloadCount + 1
              : note.downloadCount,
        );
      });
    } catch (error) {
      _showSnackBar('Download failed: $error');
    } finally {
      if (mounted) {
        setState(() => _downloading = false);
      }
    }
  }

  Future<void> _toggleBookmark() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      _showSnackBar('Please login to bookmark notes');
      return;
    }

    final note = _note;
    if (note == null) {
      return;
    }

    setState(() => _bookmarkLoading = true);

    try {
      if (_isBookmarked) {
        await _repository.removeBookmark(uid, note.noteId);
      } else {
        await _repository.bookmarkNote(uid, note.noteId);
      }
      if (mounted) {
        setState(() => _isBookmarked = !_isBookmarked);
      }
    } catch (error) {
      _showSnackBar('Unable to update bookmark: $error');
    } finally {
      if (mounted) {
        setState(() => _bookmarkLoading = false);
      }
    }
  }

  Future<void> _share() async {
    final note = _note;
    if (note == null) {
      return;
    }

    await Share.share(note.fileUrl, subject: note.title);
  }

  Future<void> _confirmDelete() async {
    final note = _note;
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (note == null || uid == null || !_canDelete) {
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Note'),
        content: const Text(
          'This will permanently remove the note for everyone. Continue?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed != true) {
      return;
    }

    try {
      await _repository.deleteNote(
        noteId: note.noteId,
        actorUid: uid,
        actorRole: _currentUserRole,
      );
      if (!mounted) {
        return;
      }
      _showSnackBar('Note deleted successfully');
      
      // Fix black screen issue: use GoRouter.of(context).pop() or Navigator.pop
      // If we can pop, we pop. If not, we go to /notes.
      if (context.canPop()) {
        context.pop(note.noteId);
      } else {
        context.go('/notes');
      }
    } catch (error) {
      if (!mounted) {
        return;
      }
      _showSnackBar('Unable to delete note: $error');
    }
  }

  String _sanitizeFileName(String fileName) {
    final fallback = '${widget.noteId}.pdf';
    final sanitized = fileName.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_').trim();
    if (sanitized.isEmpty) {
      return fallback;
    }
    if (!sanitized.toLowerCase().endsWith('.pdf')) {
      return '$sanitized.pdf';
    }
    return sanitized;
  }

  Future<void> _decompressIfGzip(String path) async {
    final file = File(path);
    if (!await file.exists()) {
      return;
    }

    final bytes = await file.readAsBytes();
    if (bytes.length < 2) {
      return;
    }

    if (bytes[0] != 0x1f || bytes[1] != 0x8b) {
      return;
    }

    final decoded = gzip.decode(bytes);
    await file.writeAsBytes(decoded, flush: true);
  }

  Widget _chip(String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.blueGrey.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(label),
    );
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }
}
