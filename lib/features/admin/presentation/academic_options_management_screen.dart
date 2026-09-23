import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/domain/auth_providers.dart';
import '../../../shared/domain/academic_options_providers.dart';
import '../../../shared/widgets/app_back_button.dart';
import '../../../shared/widgets/loading_widget.dart';
import '../domain/admin_providers.dart';

class AcademicOptionsManagementScreen extends ConsumerStatefulWidget {
  const AcademicOptionsManagementScreen({super.key});

  @override
  ConsumerState<AcademicOptionsManagementScreen> createState() =>
      _AcademicOptionsManagementScreenState();
}

class _AcademicOptionsManagementScreenState
    extends ConsumerState<AcademicOptionsManagementScreen> {
  static const int _pageSize = 10;

  final TextEditingController _courseController = TextEditingController();
  final TextEditingController _branchController = TextEditingController();

  final List<String> _courses = [];
  final List<String> _branches = [];

  bool _seeded = false;
  bool _isSaving = false;
  int _visibleCourses = _pageSize;
  int _visibleBranches = _pageSize;

  @override
  void dispose() {
    _courseController.dispose();
    _branchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final profileAsync = ref.watch(currentUserProvider);
    final optionsAsync = ref.watch(academicOptionsProvider);

    return profileAsync.when(
      data: (profile) {
        if (profile == null || profile.role != 'admin') {
          return Scaffold(
            appBar: AppBar(
              leading: const AppBackButton(fallbackRoute: '/admin'),
              title: const Text('Courses & Branches'),
            ),
            body: const Center(
              child: Text('Only admins can access courses and branches.'),
            ),
          );
        }

        return Scaffold(
          appBar: AppBar(
            leading: const AppBackButton(fallbackRoute: '/admin'),
            title: const Text('Courses & Branches'),
            actions: [
              TextButton.icon(
                onPressed: _isSaving ? null : () => _saveOptions(profile.uid),
                icon: _isSaving
                    ? const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.save),
                label: const Text('Save'),
              ),
              const SizedBox(width: 8),
            ],
          ),
          body: optionsAsync.when(
            data: (options) {
              _seedFromOptionsIfNeeded(options.courses, options.branches);
              return ListView(
                padding: const EdgeInsets.all(12),
                children: [
                  _buildOptionSection(
                    title: 'Courses',
                    hint: 'Add course',
                    controller: _courseController,
                    values: _courses,
                    visibleCount: _visibleCourses,
                    onAdd: _addCourse,
                    onRemove: _removeCourse,
                    onLoadMore: () {
                      setState(() {
                        _visibleCourses = min(
                          _visibleCourses + _pageSize,
                          _courses.length,
                        );
                      });
                    },
                  ),
                  const SizedBox(height: 12),
                  _buildOptionSection(
                    title: 'Branches',
                    hint: 'Add branch',
                    controller: _branchController,
                    values: _branches,
                    visibleCount: _visibleBranches,
                    onAdd: _addBranch,
                    onRemove: _removeBranch,
                    onLoadMore: () {
                      setState(() {
                        _visibleBranches = min(
                          _visibleBranches + _pageSize,
                          _branches.length,
                        );
                      });
                    },
                  ),
                ],
              );
            },
            loading: () => const LoadingWidget(
              message: 'Loading course/branch options...',
            ),
            error: (error, _) => Center(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Text('Failed to load options: $error'),
              ),
            ),
          ),
        );
      },
      loading: () =>
          const Scaffold(body: LoadingWidget(message: 'Loading profile...')),
      error: (error, _) => Scaffold(
        appBar: AppBar(
          leading: const AppBackButton(fallbackRoute: '/admin'),
          title: const Text('Courses & Branches'),
        ),
        body: Center(child: Text('Error loading profile: $error')),
      ),
    );
  }

  Widget _buildOptionSection({
    required String title,
    required String hint,
    required TextEditingController controller,
    required List<String> values,
    required int visibleCount,
    required VoidCallback onAdd,
    required void Function(String value) onRemove,
    required VoidCallback onLoadMore,
  }) {
    final visibleItems = values.take(visibleCount).toList();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: controller,
                    decoration: InputDecoration(
                      hintText: hint,
                      border: const OutlineInputBorder(),
                    ),
                    onSubmitted: (_) => onAdd(),
                  ),
                ),
                const SizedBox(width: 8),
                FilledButton.icon(
                  onPressed: onAdd,
                  icon: const Icon(Icons.add),
                  label: const Text('Add'),
                ),
              ],
            ),
            const SizedBox(height: 8),
            if (values.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 8),
                child: Text('No items yet.'),
              )
            else
              Column(
                children: visibleItems
                    .map(
                      (value) => ListTile(
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 6,
                        ),
                        title: Text(value),
                        trailing: IconButton(
                          icon: const Icon(Icons.delete_outline),
                          onPressed: () => onRemove(value),
                        ),
                      ),
                    )
                    .toList(),
              ),
            if (values.length > visibleItems.length)
              Align(
                alignment: Alignment.centerLeft,
                child: OutlinedButton.icon(
                  onPressed: onLoadMore,
                  icon: const Icon(Icons.expand_more_rounded),
                  label: Text('Load More $title'),
                ),
              ),
          ],
        ),
      ),
    );
  }

  void _seedFromOptionsIfNeeded(List<String> courses, List<String> branches) {
    if (_seeded) {
      return;
    }
    _courses
      ..clear()
      ..addAll(courses);
    _branches
      ..clear()
      ..addAll(branches);
    _visibleCourses = min(_pageSize, _courses.length);
    _visibleBranches = min(_pageSize, _branches.length);
    _seeded = true;
  }

  void _addCourse() {
    final value = _courseController.text.trim();
    if (value.isEmpty) {
      return;
    }

    final exists = _courses.any(
      (item) => item.toLowerCase() == value.toLowerCase(),
    );
    if (exists) {
      _showSnackBar('Course already exists');
      return;
    }

    setState(() {
      _courses.add(value);
      _visibleCourses = min(_visibleCourses + 1, _courses.length);
      _courseController.clear();
    });
  }

  void _addBranch() {
    final value = _branchController.text.trim();
    if (value.isEmpty) {
      return;
    }

    final exists = _branches.any(
      (item) => item.toLowerCase() == value.toLowerCase(),
    );
    if (exists) {
      _showSnackBar('Branch already exists');
      return;
    }

    setState(() {
      _branches.add(value);
      _visibleBranches = min(_visibleBranches + 1, _branches.length);
      _branchController.clear();
    });
  }

  void _removeCourse(String value) {
    setState(() {
      _courses.remove(value);
      _visibleCourses = min(_visibleCourses, _courses.length);
    });
  }

  void _removeBranch(String value) {
    setState(() {
      _branches.remove(value);
      _visibleBranches = min(_visibleBranches, _branches.length);
    });
  }

  Future<void> _saveOptions(String adminUid) async {
    setState(() {
      _isSaving = true;
    });

    try {
      await ref
          .read(adminRepositoryProvider)
          .saveAcademicOptions(
            courses: _courses,
            branches: _branches,
            adminUid: adminUid,
          );

      if (!mounted) {
        return;
      }
      _showSnackBar('Courses and branches updated.');
    } catch (error) {
      if (!mounted) {
        return;
      }
      _showSnackBar('Failed to save options: $error');
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }
}
