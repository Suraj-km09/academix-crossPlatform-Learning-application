import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/errors/app_exception.dart';
import '../../../shared/services/cache_policy.dart';
import '../../../shared/widgets/app_back_button.dart';
import '../../../shared/widgets/locker_file_card.dart';
import '../../../shared/widgets/responsive_layout.dart';
import '../../../shared/widgets/skeleton_loader.dart';
import '../../auth/domain/auth_providers.dart';
import '../data/locker_file_model.dart';
import '../data/locker_repository.dart';
import '../domain/locker_providers.dart';

class LockerScreen extends ConsumerStatefulWidget {
  const LockerScreen({super.key});

  @override
  ConsumerState<LockerScreen> createState() => _LockerScreenState();
}

class _LockerScreenState extends ConsumerState<LockerScreen> {
  bool _gridView = false;
  String _sortBy = 'latest';
  String _selectedTag = 'all';
  DateTime? _lastManualRefreshAt;
  final Set<String> _locallyDeletedFileIds = <String>{};

  String? _cachingFileId;
  double _cachingProgress = 0;

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
        final totalBytesAsync = ref.watch(
          lockerTotalUsedBytesProvider(user.uid),
        );

        return Scaffold(
          appBar: AppBar(
            leading: const AppBackButton(fallbackRoute: '/home'),
            title: const Text('Digital Locker'),
            actions: [
              IconButton(
                tooltip: _gridView ? 'List View' : 'Grid View',
                onPressed: () => setState(() => _gridView = !_gridView),
                icon: Icon(
                  _gridView ? Icons.view_list_rounded : Icons.grid_view_rounded,
                ),
              ),
            ],
          ),
          floatingActionButton: FloatingActionButton.extended(
            onPressed: () async {
              final uploaded = await context.push('/upload-locker');
              if (uploaded == true) {
                ref.invalidate(lockerTotalUsedBytesProvider(user.uid));
              }
            },
            icon: const Icon(Icons.upload_file_rounded),
            label: const Text('Upload'),
          ),
          body: SafeArea(
            child: filesAsync.when(
              data: (files) {
                final visibleFiles = files
                    .where(
                      (file) => !_locallyDeletedFileIds.contains(file.fileId),
                    )
                    .toList();
                final filtered = _applyFiltersAndSort(visibleFiles);
                final tags = _availableTags(visibleFiles);

                return RefreshIndicator(
                  onRefresh: () async {
                    final now = DateTime.now();
                    final last = _lastManualRefreshAt;
                    if (last != null &&
                        now.difference(last) <
                            CachePolicy.manualRefreshMinInterval) {
                      return;
                    }
                    _lastManualRefreshAt = now;

                    ref.invalidate(lockerFilesProvider(user.uid));
                    await Future<void>.delayed(
                      const Duration(milliseconds: 250),
                    );
                  },
                  child: ResponsiveLayout(
                    maxWidthDesktop: 1000,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    child: ListView(
                      padding: EdgeInsets.zero,
                    children: [
                      _UsageHeader(
                        usedBytesAsync: totalBytesAsync,
                        maxBytes: LockerRepository.maxUserStorageBytes,
                      ),
                      const SizedBox(height: 14),
                      _SortAndTagBar(
                        sortBy: _sortBy,
                        onSortChanged: (value) {
                          if (value == null) {
                            return;
                          }
                          setState(() => _sortBy = value);
                        },
                        selectedTag: _selectedTag,
                        tags: tags,
                        onTagSelected: (value) {
                          setState(() => _selectedTag = value);
                        },
                      ),
                      const SizedBox(height: 12),
                      if (_cachingFileId != null)
                        Container(
                          margin: const EdgeInsets.only(bottom: 10),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(12),
                            color: Theme.of(
                              context,
                            ).colorScheme.primary.withValues(alpha: 0.08),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Caching for offline use...',
                                style: Theme.of(context).textTheme.titleSmall,
                              ),
                              const SizedBox(height: 8),
                              LinearProgressIndicator(value: _cachingProgress),
                              const SizedBox(height: 4),
                              Text(
                                '${(_cachingProgress * 100).toStringAsFixed(0)}%',
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                            ],
                          ),
                        ),
                      if (filtered.isEmpty)
                        _EmptyLockerView(hasFiles: files.isNotEmpty)
                      else if (_gridView)
                        GridView.builder(
                          itemCount: filtered.length,
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          gridDelegate:
                              const SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: 2,
                                crossAxisSpacing: 10,
                                mainAxisSpacing: 10,
                                childAspectRatio: 0.95,
                              ),
                          itemBuilder: (_, index) {
                            final item = filtered[index];
                            return LockerFileCard(
                              file: item,
                              gridMode: true,
                              onOpen: () => _openDetails(item),
                              onRename: () => _renameFile(user.uid, item),
                              onAddTags: () => _addTags(user.uid, item),
                              onCacheOffline: () =>
                                  _cacheOffline(user.uid, item),
                              onDelete: () => _deleteFile(user.uid, item),
                            );
                          },
                        )
                      else
                        ListView.separated(
                          itemCount: filtered.length,
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          separatorBuilder: (context, index) =>
                              const SizedBox(height: 8),
                          itemBuilder: (_, index) {
                            final item = filtered[index];
                            return LockerFileCard(
                              file: item,
                              onOpen: () => _openDetails(item),
                              onRename: () => _renameFile(user.uid, item),
                              onAddTags: () => _addTags(user.uid, item),
                              onCacheOffline: () =>
                                  _cacheOffline(user.uid, item),
                              onDelete: () => _deleteFile(user.uid, item),
                            );
                          },
                        ),
                    ],
                  ),
                ),
              );
              },
              loading: () => ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  const SkeletonLoader(
                    child: Card(
                      child: SizedBox(height: 120, width: double.infinity),
                    ),
                  ),
                  const SizedBox(height: 24),
                  if (_gridView)
                    GridView.builder(
                      itemCount: 6,
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 2,
                            crossAxisSpacing: 10,
                            mainAxisSpacing: 10,
                            childAspectRatio: 0.95,
                          ),
                      itemBuilder: (context, index) =>
                          const LockerFileSkeleton(gridMode: true),
                    )
                  else
                    ...List.generate(6, (index) => const LockerFileSkeleton()),
                ],
              ),
              error: (error, _) => Center(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.error_outline_rounded, size: 44),
                      const SizedBox(height: 8),
                      const Text('Failed to load locker files'),
                      const SizedBox(height: 8),
                      Text('$error', textAlign: TextAlign.center),
                      const SizedBox(height: 10),
                      ElevatedButton(
                        onPressed: () {
                          ref.invalidate(lockerFilesProvider(user.uid));
                        },
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
      loading: () =>
          const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (error, _) => Scaffold(
        appBar: AppBar(title: const Text('Digital Locker')),
        body: Center(child: Text('Unable to load user: $error')),
      ),
    );
  }

  Future<void> _openDetails(LockerFileModel file) async {
    final updated = await context.push(
      '/locker-file/${file.fileId}',
      extra: file,
    );
    if (updated is String && updated.trim().isNotEmpty) {
      if (mounted) {
        setState(() {
          _locallyDeletedFileIds.add(updated);
        });
      }
      final user = await ref.read(currentUserProvider.future);
      if (user == null) {
        return;
      }
      ref.invalidate(lockerTotalUsedBytesProvider(user.uid));
      ref.invalidate(lockerFilesProvider(user.uid));
      return;
    }

    if (updated == true) {
      final user = await ref.read(currentUserProvider.future);
      if (user == null) {
        return;
      }
      ref.invalidate(lockerFilesProvider(user.uid));
      ref.invalidate(lockerTotalUsedBytesProvider(user.uid));
    }
  }

  Future<void> _renameFile(String uid, LockerFileModel file) async {
    final controller = TextEditingController(text: file.fileName);
    final value = await showDialog<String>(
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

    if (value == null || value.trim().isEmpty) {
      return;
    }

    try {
      await ref
          .read(lockerRepositoryProvider)
          .renameFile(uid, file.fileId, value);
      _showSnackBar('File renamed');
    } on AppException catch (error) {
      _showSnackBar(error.message);
    } catch (error) {
      _showSnackBar('Rename failed: $error');
    }
  }

  Future<void> _addTags(String uid, LockerFileModel file) async {
    final controller = TextEditingController(text: file.tags.join(', '));

    final value = await showDialog<String>(
      context: context,
      builder: (_) {
        return AlertDialog(
          title: const Text('Update Tags'),
          content: TextField(
            controller: controller,
            decoration: const InputDecoration(hintText: 'Comma separated tags'),
            autofocus: true,
            maxLines: 2,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(controller.text),
              child: const Text('Save'),
            ),
          ],
        );
      },
    );

    if (value == null) {
      return;
    }

    final tags = value
        .split(',')
        .map((item) => item.trim())
        .where((item) => item.isNotEmpty)
        .toSet()
        .toList();

    try {
      await ref
          .read(lockerRepositoryProvider)
          .updateTags(uid, file.fileId, tags);
      _showSnackBar('Tags updated');
      if (_selectedTag != 'all' &&
          !_availableTags([file]).contains(_selectedTag)) {
        setState(() => _selectedTag = 'all');
      }
    } on AppException catch (error) {
      _showSnackBar(error.message);
    } catch (error) {
      _showSnackBar('Tag update failed: $error');
    }
  }

  Future<void> _cacheOffline(String uid, LockerFileModel file) async {
    try {
      setState(() {
        _cachingFileId = file.fileId;
        _cachingProgress = 0;
      });

      await ref
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
              setState(() => _cachingProgress = progress);
            },
          );

      _showSnackBar('File cached for offline use');
    } on AppException catch (error) {
      _showSnackBar(error.message);
    } catch (error) {
      _showSnackBar('Caching failed: $error');
    } finally {
      if (mounted) {
        setState(() {
          _cachingFileId = null;
          _cachingProgress = 0;
        });
      }
    }
  }

  Future<void> _deleteFile(String uid, LockerFileModel file) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) {
        return AlertDialog(
          title: const Text('Delete File'),
          content: Text(
            'Delete "${file.fileName}" from your locker? This cannot be undone.',
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

    if (mounted) {
      setState(() {
        _locallyDeletedFileIds.add(file.fileId);
      });
    }

    try {
      await ref
          .read(lockerRepositoryProvider)
          .deleteFile(uid, file.fileId, file.fileUrl);
      ref.invalidate(lockerFilesProvider(uid));
      ref.invalidate(lockerTotalUsedBytesProvider(uid));
      _showSnackBar('File deleted');
    } on AppException catch (error) {
      if (mounted) {
        setState(() {
          _locallyDeletedFileIds.remove(file.fileId);
        });
      }
      _showSnackBar(error.message);
    } catch (error) {
      if (mounted) {
        setState(() {
          _locallyDeletedFileIds.remove(file.fileId);
        });
      }
      _showSnackBar('Delete failed: $error');
    }
  }

  List<LockerFileModel> _applyFiltersAndSort(List<LockerFileModel> files) {
    var filtered = files;

    if (_selectedTag != 'all') {
      filtered = filtered
          .where((file) => file.tags.any((tag) => tag == _selectedTag))
          .toList();
    }

    final sorted = [...filtered];
    switch (_sortBy) {
      case 'name':
        sorted.sort(
          (a, b) =>
              a.fileName.toLowerCase().compareTo(b.fileName.toLowerCase()),
        );
      case 'size_desc':
        sorted.sort((a, b) => b.fileSize.compareTo(a.fileSize));
      case 'size_asc':
        sorted.sort((a, b) => a.fileSize.compareTo(b.fileSize));
      case 'latest':
      default:
        sorted.sort((a, b) => b.uploadedAt.compareTo(a.uploadedAt));
    }

    return sorted;
  }

  List<String> _availableTags(List<LockerFileModel> files) {
    final tags = files.expand((item) => item.tags).toSet().toList()..sort();
    return ['all', ...tags];
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }
}

class _UsageHeader extends StatelessWidget {
  const _UsageHeader({required this.usedBytesAsync, required this.maxBytes});

  final AsyncValue<int> usedBytesAsync;
  final int maxBytes;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.10),
        border: Border.all(
          color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.24),
        ),
      ),
      child: usedBytesAsync.when(
        data: (used) {
          final remaining = maxBytes - used;
          final progress = (used / maxBytes).clamp(0.0, 1.0);
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Locker Usage',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 6),
              Text(
                '${_formatBytes(used)} used of ${_formatBytes(maxBytes)}',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 8),
              LinearProgressIndicator(value: progress),
              const SizedBox(height: 6),
              Text(
                '${_formatBytes(remaining.clamp(0, maxBytes))} remaining',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          );
        },
        loading: () => const LinearProgressIndicator(),
        error: (error, _) => const Text('Failed to calculate storage usage'),
      ),
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
    return '${value.toStringAsFixed(unitIndex == 0 ? 0 : 2)} ${units[unitIndex]}';
  }
}

class _SortAndTagBar extends StatelessWidget {
  const _SortAndTagBar({
    required this.sortBy,
    required this.onSortChanged,
    required this.selectedTag,
    required this.tags,
    required this.onTagSelected,
  });

  final String sortBy;
  final ValueChanged<String?> onSortChanged;
  final String selectedTag;
  final List<String> tags;
  final ValueChanged<String> onTagSelected;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        DropdownButtonFormField<String>(
          initialValue: sortBy,
          decoration: const InputDecoration(
            labelText: 'Sort by',
            isDense: true,
          ),
          items: const [
            DropdownMenuItem(value: 'latest', child: Text('Latest Uploads')),
            DropdownMenuItem(value: 'name', child: Text('File Name')),
            DropdownMenuItem(value: 'size_desc', child: Text('Largest Size')),
            DropdownMenuItem(value: 'size_asc', child: Text('Smallest Size')),
          ],
          onChanged: onSortChanged,
        ),
        const SizedBox(height: 10),
        SizedBox(
          height: 38,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: tags.length,
            separatorBuilder: (context, index) => const SizedBox(width: 8),
            itemBuilder: (_, index) {
              final tag = tags[index];
              final selected = tag == selectedTag;
              return ChoiceChip(
                label: Text(tag == 'all' ? 'All' : tag),
                selected: selected,
                onSelected: (_) => onTagSelected(tag),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _EmptyLockerView extends StatelessWidget {
  const _EmptyLockerView({required this.hasFiles});

  final bool hasFiles;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 26),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Theme.of(context).dividerColor),
      ),
      child: Column(
        children: [
          const Icon(Icons.folder_copy_outlined, size: 46),
          const SizedBox(height: 8),
          Text(
            hasFiles
                ? 'No files for selected tag filter'
                : 'Your digital locker is empty',
            style: Theme.of(context).textTheme.titleMedium,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 6),
          Text(
            hasFiles
                ? 'Change tag filter or upload a new PDF.'
                : 'Upload class notes, docs and references (PDF only).',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}
