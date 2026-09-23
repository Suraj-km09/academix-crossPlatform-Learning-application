import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:open_file/open_file.dart';
import 'package:path_provider/path_provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../../auth/domain/auth_providers.dart';
import '../../../shared/models/user_model.dart';
import '../../../shared/widgets/app_back_button.dart';
import '../../../shared/widgets/empty_state.dart';
import '../../../shared/widgets/responsive_layout.dart';
import '../../../shared/widgets/skeleton_loader.dart';
import '../../../shared/services/security_config_service.dart';
import '../data/curriculum_item_model.dart';
import '../domain/curriculum_providers.dart';
import '../data/curriculum_repository.dart';
import 'upload_curriculum_screen.dart';

class CurriculumScreen extends ConsumerStatefulWidget {
  const CurriculumScreen({super.key});

  @override
  ConsumerState<CurriculumScreen> createState() => _CurriculumScreenState();
}

class _CurriculumScreenState extends ConsumerState<CurriculumScreen> {
  final TextEditingController _searchController = TextEditingController();
  final Dio _dio = Dio();
  final Set<String> _locallyDeletedCurriculumIds = <String>{};

  String _selectedCourse = 'all';
  String _selectedSemester = 'all';
  String _selectedBranch = 'all';
  String _selectedCategory = 'all';

  bool _openingDocument = false;

  final List<CurriculumItemModel> _olderItems = <CurriculumItemModel>[];
  bool _isLoadingMore = false;
  bool _hasMore = true;
  DateTime? _latestPageOldestAt;

  @override
  void dispose() {
    _searchController.dispose();
    _olderItems.clear();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final userAsync = ref.watch(currentUserStreamProvider);

    return userAsync.when(
      data: (user) {
        if (user == null) {
          return const Scaffold(
            body: EmptyState(
              title: 'Login required',
              subtitle: 'Please login to access curriculum.',
            ),
          );
        }

        final streamAsync = ref.watch(
          curriculumStreamProvider((
            collegeId: user.collegeId,
            course: _selectedCourse != 'all' ? _selectedCourse : null,
            semester: _selectedSemester != 'all' ? _selectedSemester : null,
            branch: _selectedBranch != 'all' ? _selectedBranch : null,
            category: _selectedCategory != 'all' ? _selectedCategory : null,
          )),
        );

        final normalizedRole = user.role.trim().toLowerCase();
        bool roleAllowedForCurriculum = true;
        try {
          roleAllowedForCurriculum = SecurityConfigService.instance(
            FirebaseFirestore.instance,
          ).isRoleResourceAllowed(normalizedRole, 'curriculum');
        } catch (_) {
          roleAllowedForCurriculum = true;
        }
        final canUploadCurriculum =
            normalizedRole == 'admin' ||
            (user.canUploadNotesPyqs && roleAllowedForCurriculum);

        return Scaffold(
          appBar: AppBar(
            leading: const AppBackButton(fallbackRoute: '/home'),
            title: SizedBox(
              height: 42,
              child: TextField(
                controller: _searchController,
                onChanged: (_) => setState(() {}),
                decoration: InputDecoration(
                  hintText: 'Search curriculum...',
                  prefixIcon: const Icon(Icons.search_rounded),
                  suffixIcon: _searchController.text.trim().isEmpty
                      ? null
                      : IconButton(
                          onPressed: () {
                            _searchController.clear();
                            setState(() {});
                          },
                          icon: const Icon(Icons.close_rounded),
                        ),
                ),
              ),
            ),
          ),
          body: streamAsync.when(
            data: (items) {
              final visibleLatest = items
                  .where(
                    (item) =>
                        !_locallyDeletedCurriculumIds.contains(item.curriculumId),
                  )
                  .toList();

              if (visibleLatest.isNotEmpty) {
                _latestPageOldestAt = visibleLatest.last.createdAt;
              }

              final combined = <CurriculumItemModel>[
                ...visibleLatest,
                ..._olderItems,
              ];

              final courses = _buildOptions(combined.map((e) => e.course));
              final semesters = _buildOptions(combined.map((e) => e.semester));
              final branches = _buildOptions(combined.map((e) => e.branch));
              final filtered = _applyFilters(combined, user);

              return RefreshIndicator(
                onRefresh: () async {
                  _olderItems.clear();
                  _hasMore = true;
                  ref.invalidate(
                    curriculumStreamProvider((
                      collegeId: user.collegeId,
                      course: _selectedCourse != 'all' ? _selectedCourse : null,
                      semester: _selectedSemester != 'all'
                          ? _selectedSemester
                          : null,
                      branch: _selectedBranch != 'all' ? _selectedBranch : null,
                      category: _selectedCategory != 'all'
                          ? _selectedCategory
                          : null,
                    )),
                  );
                  await Future<void>.delayed(const Duration(milliseconds: 250));
                },
                child: ResponsiveLayout(
                  maxWidthDesktop: 1100,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  child: ListView(
                    padding: EdgeInsets.zero,
                  children: [
                    LayoutBuilder(
                      builder: (context, constraints) {
                        final compact = constraints.maxWidth < 720;

                        final courseField = DropdownButtonFormField<String>(
                          initialValue: _selectedCourse,
                          decoration: const InputDecoration(
                            labelText: 'Course',
                          ),
                          items: courses
                              .map(
                                (item) => DropdownMenuItem<String>(
                                  value: item,
                                  child: Text(item == 'all' ? 'All' : item),
                                ),
                              )
                              .toList(),
                          onChanged: (value) {
                            if (value == null) return;
                            setState(() => _selectedCourse = value);
                          },
                        );

                        final semesterField = DropdownButtonFormField<String>(
                          initialValue: _selectedSemester,
                          decoration: const InputDecoration(
                            labelText: 'Semester',
                          ),
                          items: semesters
                              .map(
                                (item) => DropdownMenuItem<String>(
                                  value: item,
                                  child: Text(item == 'all' ? 'All' : item),
                                ),
                              )
                              .toList(),
                          onChanged: (value) {
                            if (value == null) return;
                            setState(() => _selectedSemester = value);
                          },
                        );

                        final branchField = DropdownButtonFormField<String>(
                          initialValue: _selectedBranch,
                          decoration: const InputDecoration(
                            labelText: 'Branch',
                          ),
                          items: branches
                              .map(
                                (item) => DropdownMenuItem<String>(
                                  value: item,
                                  child: Text(item == 'all' ? 'All' : item),
                                ),
                              )
                              .toList(),
                          onChanged: (value) {
                            if (value == null) return;
                            setState(() => _selectedBranch = value);
                          },
                        );

                        final categoryField = DropdownButtonFormField<String>(
                          initialValue: _selectedCategory,
                          decoration: const InputDecoration(
                            labelText: 'Category',
                          ),
                          items: const [
                            DropdownMenuItem(value: 'all', child: Text('All')),
                            DropdownMenuItem(
                              value: 'syllabus',
                              child: Text('Syllabus'),
                            ),
                            DropdownMenuItem(
                              value: 'subject_info',
                              child: Text('Subject Information'),
                            ),
                            DropdownMenuItem(
                              value: 'exam_guideline',
                              child: Text('Exam Guideline'),
                            ),
                            DropdownMenuItem(
                              value: 'useful_info',
                              child: Text('Useful Information'),
                            ),
                          ],
                          onChanged: (value) {
                            if (value == null) return;
                            setState(() => _selectedCategory = value);
                          },
                        );

                        if (compact) {
                          return Column(
                            children: [
                              courseField,
                              const SizedBox(height: 10),
                              semesterField,
                              const SizedBox(height: 10),
                              branchField,
                              const SizedBox(height: 10),
                              categoryField,
                            ],
                          );
                        }

                        return Column(
                          children: [
                            Row(
                              children: [
                                Expanded(child: courseField),
                                const SizedBox(width: 10),
                                Expanded(child: semesterField),
                              ],
                            ),
                            const SizedBox(height: 10),
                            Row(
                              children: [
                                Expanded(child: branchField),
                                const SizedBox(width: 10),
                                Expanded(child: categoryField),
                              ],
                            ),
                          ],
                        );
                      },
                    ),
                    const SizedBox(height: 12),
                    if (filtered.isEmpty)
                      const Padding(
                        padding: EdgeInsets.only(top: 48),
                        child: EmptyState(
                          title: 'No curriculum items found',
                          subtitle: 'Try changing filters.',
                          icon: Icons.menu_book_outlined,
                        ),
                      )
                    else
                      ...filtered.map(
                        (item) => _CurriculumCard(
                          item: item,
                          onOpenDocument: item.documentUrl.trim().isEmpty
                              ? null
                              : () => _openDocument(item),
                          canDelete:
                              user.role.trim().toLowerCase() == 'admin' ||
                              item.uploadedBy == user.uid,
                          onDelete: () => _deleteCurriculumItem(user, item),
                        ),
                      ),

                    if (_hasMore)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        child: Center(
                          child: _isLoadingMore
                              ? const CurriculumCardSkeleton()
                              : FilledButton(
                                  onPressed: () => _loadMore(user),
                                  child: const Text('Load more'),
                                ),
                        ),
                      ),
                  ],
                ),
              ),
            );
            },
            loading: () => ListView.builder(
              padding: const EdgeInsets.all(12),
              itemCount: 6,
              itemBuilder: (context, index) => const CurriculumCardSkeleton(),
            ),
            error: (error, _) => EmptyState(
              title: 'Unable to load curriculum',
              subtitle: '$error',
            ),
          ),
          floatingActionButton: canUploadCurriculum
              ? FloatingActionButton.extended(
                  onPressed: () async {
                    final normRole = user.role.trim().toLowerCase();
                    final allowed =
                        normRole == 'admin' ||
                        (user.canUploadNotesPyqs &&
                            SecurityConfigService.instance(
                              FirebaseFirestore.instance,
                            ).isRoleResourceAllowed(
                              normRole,
                              'curriculum',
                            ));
                    if (!allowed) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text(
                            'Your upload access is disabled by admin.',
                          ),
                        ),
                      );
                      return;
                    }

                    final uploaded = await Navigator.of(context).push<bool>(
                      MaterialPageRoute(
                        builder: (_) => UploadCurriculumScreen(
                          collegeId: user.collegeId,
                          uploaderUid: user.uid,
                          uploaderName: user.name,
                          uploaderRole: user.role,
                          defaultCourse: user.course,
                          defaultBranch: user.branch,
                          defaultSemester: user.semester,
                        ),
                      ),
                    );

                    if (uploaded == true && mounted) {
                      _olderItems.clear();
                      _hasMore = true;
                      ref.invalidate(
                        curriculumStreamProvider((
                          collegeId: user.collegeId,
                          course: _selectedCourse != 'all'
                              ? _selectedCourse
                              : null,
                          semester: _selectedSemester != 'all'
                              ? _selectedSemester
                              : null,
                          branch: _selectedBranch != 'all'
                              ? _selectedBranch
                              : null,
                          category: _selectedCategory != 'all'
                              ? _selectedCategory
                              : null,
                        )),
                      );
                    }
                  },
                  icon: const Icon(Icons.upload_file_rounded),
                  label: const Text('Upload Curriculum'),
                )
              : null,
        );
      },
      loading: () => Scaffold(
        appBar: AppBar(
          leading: const AppBackButton(fallbackRoute: '/home'),
          title: const Text('Curriculum'),
        ),
        body: ListView.builder(
          padding: const EdgeInsets.all(12),
          itemCount: 6,
          itemBuilder: (context, index) => const CurriculumCardSkeleton(),
        ),
      ),
      error: (error, _) => Scaffold(
        appBar: AppBar(
          leading: const AppBackButton(fallbackRoute: '/home'),
          title: const Text('Curriculum'),
        ),
        body: EmptyState(title: 'Unable to load profile', subtitle: '$error'),
      ),
    );
  }

  List<String> _buildOptions(Iterable<String> raw) {
    final values =
        raw.map((e) => e.trim()).where((e) => e.isNotEmpty).toSet().toList()
          ..sort();
    return <String>['all', ...values];
  }

  List<CurriculumItemModel> _applyFilters(
    List<CurriculumItemModel> items,
    UserModel user,
  ) {
    final query = _searchController.text.trim().toLowerCase();

    return items.where((item) {
      if (_selectedCourse != 'all' && item.course != _selectedCourse) {
        return false;
      }
      if (_selectedSemester != 'all' && item.semester != _selectedSemester) {
        return false;
      }

      if (_selectedBranch != 'all') {
        if (_selectedBranch.isEmpty) {
          if (item.branch.trim().isNotEmpty) {
            return false;
          }
        } else if (item.branch != _selectedBranch) {
          return false;
        }
      }

      if (_selectedCategory != 'all' && item.category != _selectedCategory) {
        return false;
      }

      if (query.isEmpty) {
        return true;
      }

      final haystack = <String>[
        item.title,
        item.subject,
        item.description,
        item.course,
        item.branch,
        item.semester,
        item.category,
        item.uploaderName,
      ].join(' ').toLowerCase();

      return haystack.contains(query);
    }).toList();
  }

  Future<void> _openDocument(CurriculumItemModel item) async {
    if (_openingDocument) return;

    setState(() => _openingDocument = true);
    try {
      final docs = await getApplicationDocumentsDirectory();
      final folder = Directory(
        '${docs.path}${Platform.pathSeparator}curriculum_docs',
      );
      if (!folder.existsSync()) folder.createSync(recursive: true);

      final safeName = _sanitizeFileName(
        item.documentName.isEmpty
            ? '${item.curriculumId}.pdf'
            : item.documentName,
      );
      final targetPath = '${folder.path}${Platform.pathSeparator}$safeName';

      await _dio.download(item.documentUrl, targetPath);
      await _decompressIfGzip(targetPath);
      final opened = await OpenFile.open(targetPath);
      if (!mounted) return;

      if (opened.type != ResultType.done) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Unable to open file: ${opened.message}')),
        );
      }
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to open document: $error')),
      );
    } finally {
      if (mounted) setState(() => _openingDocument = false);
    }
  }

  Future<void> _deleteCurriculumItem(
    UserModel user,
    CurriculumItemModel item,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Resource'),
        content: const Text(
          'This will permanently delete this curriculum resource. Continue?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed != true) {
      return;
    }

    if (mounted) {
      setState(() => _locallyDeletedCurriculumIds.add(item.curriculumId));
    }

    try {
      await ref
          .read(curriculumRepositoryProvider)
          .deleteCurriculumItem(
            curriculumId: item.curriculumId,
            actorUid: user.uid,
            actorRole: user.role,
          );

      if (!mounted) {
        return;
      }

      ref.invalidate(
        curriculumStreamProvider((
          collegeId: user.collegeId,
          course: _selectedCourse != 'all' ? _selectedCourse : null,
          semester: _selectedSemester != 'all' ? _selectedSemester : null,
          branch: _selectedBranch != 'all' ? _selectedBranch : null,
          category: _selectedCategory != 'all' ? _selectedCategory : null,
        )),
      );

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Resource deleted successfully.')),
      );
    } catch (error) {
      if (mounted) {
        setState(() => _locallyDeletedCurriculumIds.remove(item.curriculumId));
      }
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Unable to delete resource: $error')),
      );
    }
  }

  Future<void> _loadMore(UserModel user) async {
    if (_isLoadingMore || !_hasMore) return;
    setState(() => _isLoadingMore = true);
    try {
      final before = _olderItems.isNotEmpty
          ? _olderItems.last.createdAt
          : (_latestPageOldestAt ?? DateTime.now());

      final page = await ref
          .read(curriculumRepositoryProvider)
          .getOlderCurriculumPage(
            user.collegeId,
            before: before,
            limit: CurriculumRepository.defaultOlderCurriculumPageSize,
            course: _selectedCourse != 'all' ? _selectedCourse : null,
            semester: _selectedSemester != 'all' ? _selectedSemester : null,
            branch: _selectedBranch != 'all' ? _selectedBranch : null,
            category: _selectedCategory != 'all' ? _selectedCategory : null,
          );

      final existingIds = _olderItems.map((e) => e.curriculumId).toSet();
      final newItems = page
          .where((i) => !existingIds.contains(i.curriculumId))
          .toList();

      if (newItems.isNotEmpty) {
        _olderItems.addAll(newItems);
      }

      if (page.length < CurriculumRepository.defaultOlderCurriculumPageSize) {
        _hasMore = false;
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Unable to load more: $error')));
      }
    } finally {
      if (mounted) setState(() => _isLoadingMore = false);
    }
  }

  String _sanitizeFileName(String name) {
    final sanitized = name.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_').trim();
    if (sanitized.isEmpty) return 'curriculum_document';
    return sanitized;
  }

  Future<void> _decompressIfGzip(String path) async {
    final file = File(path);
    if (!await file.exists()) return;

    final bytes = await file.readAsBytes();
    if (bytes.length < 2) return;

    if (bytes[0] != 0x1f || bytes[1] != 0x8b) return;

    final decoded = gzip.decode(bytes);
    await file.writeAsBytes(decoded, flush: true);
  }
}

class _CurriculumCard extends StatelessWidget {
  const _CurriculumCard({
    required this.item,
    this.onOpenDocument,
    required this.canDelete,
    this.onDelete,
  });

  final CurriculumItemModel item;
  final VoidCallback? onOpenDocument;
  final bool canDelete;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    item.title,
                    style: Theme.of(context).textTheme.titleMedium,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (canDelete)
                  IconButton(
                    tooltip: 'Delete Resource',
                    onPressed: onDelete,
                    icon: const Icon(Icons.delete_outline_rounded),
                  ),
                if (item.isPinned)
                  Icon(
                    Icons.push_pin_rounded,
                    color: Theme.of(context).colorScheme.primary,
                  ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              '${item.subject} • Sem ${item.semester} • ${item.course}${item.branch.isEmpty ? '' : ' • ${item.branch}'}',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 6),
            Text(
              item.description,
              maxLines: 4,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: [
                _chip(context, _categoryLabel(item.category)),
                if (item.documentUrl.trim().isNotEmpty)
                  _chip(context, 'Has Document'),
                if (item.isPinned) _chip(context, 'Important'),
              ],
            ),
            const SizedBox(height: 8),
            LayoutBuilder(
              builder: (context, constraints) {
                final compact = constraints.maxWidth < 430;
                final uploaderText = Text(
                  'By ${item.uploaderName.isEmpty ? 'Unknown' : item.uploaderName}',
                  style: Theme.of(context).textTheme.bodySmall,
                );

                if (onOpenDocument == null) return uploaderText;

                if (compact) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      uploaderText,
                      const SizedBox(height: 8),
                      OutlinedButton.icon(
                        onPressed: onOpenDocument,
                        icon: const Icon(Icons.open_in_new_rounded, size: 16),
                        label: const Text('Open Doc'),
                      ),
                    ],
                  );
                }

                return Row(
                  children: [
                    Expanded(child: uploaderText),
                    OutlinedButton.icon(
                      onPressed: onOpenDocument,
                      icon: const Icon(Icons.open_in_new_rounded, size: 16),
                      label: const Text('Open Doc'),
                    ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _chip(BuildContext context, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(label, style: Theme.of(context).textTheme.labelSmall),
    );
  }

  String _categoryLabel(String value) {
    switch (value) {
      case 'syllabus':
        return 'Syllabus';
      case 'subject_info':
        return 'Subject Information';
      case 'exam_guideline':
        return 'Exam Guideline';
      case 'useful_info':
      default:
        return 'Useful Information';
    }
  }
}
