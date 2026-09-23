import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:open_file/open_file.dart';
import 'package:path_provider/path_provider.dart';

import '../../../core/errors/app_exception.dart';
import '../../../shared/widgets/app_back_button.dart';
import '../../auth/domain/auth_providers.dart';
import '../data/locker_file_model.dart';
import '../domain/locker_providers.dart';

class LockerFileDetailScreen extends ConsumerStatefulWidget {
  const LockerFileDetailScreen({
    super.key,
    required this.fileId,
    this.initialFile,
  });

  final String fileId;
  final LockerFileModel? initialFile;

  @override
  ConsumerState<LockerFileDetailScreen> createState() =>
      _LockerFileDetailScreenState();
}

class _LockerFileDetailScreenState
    extends ConsumerState<LockerFileDetailScreen> {
  String? _cachedPath;
  bool _checkingCache = true;

  bool _isActionBusy = false;
  double _cacheProgress = 0;

  @override
  void initState() {
    super.initState();
    _initFileStatus();
  }

  Future<void> _initFileStatus() async {
    final user = ref.read(currentUserProvider).value;
    if (user == null || widget.initialFile == null) {
      setState(() => _checkingCache = false);
      return;
    }

    final path = await _getExistingLocalPath(user.uid, widget.initialFile!);
    if (mounted) {
      setState(() {
        _cachedPath = path;
        _checkingCache = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final userAsync = ref.watch(currentUserProvider);

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

        final filesAsync = ref.watch(lockerFilesProvider(user.uid));

        return filesAsync.when(
          data: (files) {
            final liveFile = files.where(
              (item) => item.fileId == widget.fileId,
            );
            final file = liveFile.isNotEmpty
                ? liveFile.first
                : widget.initialFile;

            if (file == null) {
              return Scaffold(
                appBar: AppBar(
                  leading: const AppBackButton(fallbackRoute: '/locker'),
                  title: const Text('Locker File'),
                ),
                body: const Center(child: Text('File not found')),
              );
            }

            return Scaffold(
              appBar: AppBar(
                leading: const AppBackButton(fallbackRoute: '/locker'),
                title: Text(file.fileName),
              ),
              body: Column(
                children: [
                  if (_isActionBusy)
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      child: Column(
                        children: [
                          LinearProgressIndicator(
                            value: _cacheProgress > 0 ? _cacheProgress : null,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _cacheProgress > 0
                                ? 'Caching ${(100 * _cacheProgress).toStringAsFixed(0)}%'
                                : 'Working...',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ],
                      ),
                    ),
                  Expanded(
                    child: _checkingCache
                        ? const Center(child: CircularProgressIndicator())
                        : _cachedPath != null
                        ? SfPdfViewer.file(
                            File(_cachedPath!),
                            canShowScrollHead: true,
                            canShowScrollStatus: true,
                          )
                        : SfPdfViewer.network(
                            file.fileUrl,
                            canShowScrollHead: true,
                            canShowScrollStatus: true,
                          ),
                  ),
                  const Divider(height: 1),
                  Padding(
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                file.fileName,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: Theme.of(context).textTheme.titleMedium,
                              ),
                            ),
                            if (file.isOfflineCached || _cachedPath != null)
                              Chip(
                                label: const Text('Offline'),
                                backgroundColor: Colors.green.withValues(
                                  alpha: 0.12,
                                ),
                                visualDensity: VisualDensity.compact,
                              ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${_formatBytes(file.fileSize)} • Uploaded ${_formatDate(file.uploadedAt)}',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                        const SizedBox(height: 8),
                        if (file.tags.isNotEmpty)
                          Wrap(
                            spacing: 6,
                            runSpacing: 6,
                            children: file.tags
                                .map(
                                  (tag) => Chip(
                                    label: Text(tag),
                                    visualDensity: VisualDensity.compact,
                                  ),
                                )
                                .toList(),
                          ),
                        const SizedBox(height: 10),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            OutlinedButton.icon(
                              onPressed: _isActionBusy
                                  ? null
                                  : () => _downloadAndOpen(user.uid, file),
                              icon: const Icon(Icons.download_rounded),
                              label: const Text('Download'),
                            ),
                            if (_cachedPath == null)
                              OutlinedButton.icon(
                                onPressed: _isActionBusy
                                    ? null
                                    : () => _cacheOffline(user.uid, file),
                                icon: const Icon(
                                  Icons.download_for_offline_outlined,
                                ),
                                label: const Text('Cache Offline'),
                              ),
                            OutlinedButton.icon(
                              onPressed: _isActionBusy
                                  ? null
                                  : () => _rename(user.uid, file),
                              icon: const Icon(
                                Icons.drive_file_rename_outline_rounded,
                              ),
                              label: const Text('Rename'),
                            ),
                            TextButton.icon(
                              onPressed: _isActionBusy
                                  ? null
                                  : () => _delete(user.uid, file),
                              icon: Icon(
                                Icons.delete_outline_rounded,
                                color: Theme.of(context).colorScheme.error,
                              ),
                              label: Text(
                                'Delete',
                                style: TextStyle(
                                  color: Theme.of(context).colorScheme.error,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
          loading: () =>
              const Scaffold(body: Center(child: CircularProgressIndicator())),
          error: (error, _) => Scaffold(
            appBar: AppBar(
              leading: const AppBackButton(fallbackRoute: '/locker'),
              title: const Text('Locker File'),
            ),
            body: Center(child: Text('Failed to load file: $error')),
          ),
        );
      },
      loading: () =>
          const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (error, _) => Scaffold(
        appBar: AppBar(title: const Text('Locker File')),
        body: Center(child: Text('Unable to load user: $error')),
      ),
    );
  }

  Future<String?> _getExistingLocalPath(
    String uid,
    LockerFileModel file,
  ) async {
    final localPath = file.localPath;
    if (localPath != null && localPath.trim().isNotEmpty) {
      if (await File(localPath).exists()) {
        return localPath;
      }
    }

    final cachedPath = await ref
        .read(lockerRepositoryProvider)
        .getCachedLocalPath(uid, file.fileId);
    if (cachedPath != null && cachedPath.trim().isNotEmpty) {
      if (await File(cachedPath).exists()) {
        return cachedPath;
      }
    }
    return null;
  }

  Future<void> _downloadAndOpen(String uid, LockerFileModel file) async {
    try {
      setState(() => _isActionBusy = true);

      final existingPath = await _getExistingLocalPath(uid, file);
      if (existingPath != null) {
        await OpenFile.open(existingPath);
        return;
      }

      final tempDir = await getTemporaryDirectory();
      final tempPath =
          '${tempDir.path}${Platform.pathSeparator}locker_preview_${file.fileId}.pdf';

      await Dio().download(
        file.fileUrl,
        tempPath,
        options: Options(responseType: ResponseType.bytes),
      );

      await OpenFile.open(tempPath);
    } catch (error) {
      _showSnackBar('Open failed: $error');
    } finally {
      if (mounted) {
        setState(() {
          _isActionBusy = false;
          _cacheProgress = 0;
        });
      }
    }
  }

  Future<void> _cacheOffline(String uid, LockerFileModel file) async {
    try {
      setState(() {
        _isActionBusy = true;
        _cacheProgress = 0;
      });

      final localPath = await ref
          .read(lockerRepositoryProvider)
          .cacheOffline(
            uid,
            file.fileId,
            file.fileUrl,
            file.fileName,
            onProgress: (progress) {
              if (!mounted) {
                return;
              }
              setState(() => _cacheProgress = progress);
            },
          );

      setState(() {
        _cachedPath = localPath;
      });

      ref.invalidate(lockerFilesProvider(uid));
      _showSnackBar('Cached for offline use');
    } on AppException catch (error) {
      _showSnackBar(error.message);
    } catch (error) {
      _showSnackBar('Caching failed: $error');
    } finally {
      if (mounted) {
        setState(() {
          _isActionBusy = false;
          _cacheProgress = 0;
        });
      }
    }
  }

  Future<void> _rename(String uid, LockerFileModel file) async {
    final controller = TextEditingController(text: file.fileName);
    final newName = await showDialog<String>(
      context: context,
      builder: (_) {
        return AlertDialog(
          title: const Text('Rename File'),
          content: TextField(
            controller: controller,
            decoration: const InputDecoration(hintText: 'Enter file name'),
            autofocus: true,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () =>
                  Navigator.of(context).pop(controller.text.trim()),
              child: const Text('Save'),
            ),
          ],
        );
      },
    );

    if (newName == null || newName.trim().isEmpty) {
      return;
    }

    try {
      setState(() => _isActionBusy = true);
      await ref
          .read(lockerRepositoryProvider)
          .renameFile(uid, file.fileId, newName.trim());
      ref.invalidate(lockerFilesProvider(uid));
      _showSnackBar('File renamed');
    } on AppException catch (error) {
      _showSnackBar(error.message);
    } catch (error) {
      _showSnackBar('Rename failed: $error');
    } finally {
      if (mounted) {
        setState(() => _isActionBusy = false);
      }
    }
  }

  Future<void> _delete(String uid, LockerFileModel file) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) {
        return AlertDialog(
          title: const Text('Delete File'),
          content: Text(
            'Delete "${file.fileName}" from locker? This action cannot be undone.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );

    if (confirm != true) {
      return;
    }

    try {
      setState(() => _isActionBusy = true);
      await ref
          .read(lockerRepositoryProvider)
          .deleteFile(uid, file.fileId, file.fileUrl);
      ref.invalidate(lockerFilesProvider(uid));
      ref.invalidate(lockerTotalUsedBytesProvider(uid));
      if (!mounted) {
        return;
      }
      Navigator.of(context).pop(file.fileId);
    } on AppException catch (error) {
      _showSnackBar(error.message);
    } catch (error) {
      _showSnackBar('Delete failed: $error');
    } finally {
      if (mounted) {
        setState(() => _isActionBusy = false);
      }
    }
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
    return '${value.toStringAsFixed(unitIndex == 0 ? 0 : 2)} ${units[unitIndex]}';
  }

  static String _formatDate(DateTime value) {
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return '${value.day} ${months[value.month - 1]} ${value.year}';
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }
}
