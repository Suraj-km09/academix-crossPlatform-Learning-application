import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/domain/auth_providers.dart';
import '../../notes/data/note_model.dart';
import '../../notes/domain/notes_providers.dart';
import '../../../shared/widgets/app_back_button.dart';
import '../../../shared/widgets/empty_state.dart';
import '../../../shared/widgets/loading_widget.dart';
import '../domain/admin_providers.dart';

class PendingNotesReviewScreen extends ConsumerStatefulWidget {
  const PendingNotesReviewScreen({super.key});

  @override
  ConsumerState<PendingNotesReviewScreen> createState() =>
      _PendingNotesReviewScreenState();
}

class _PendingNotesReviewScreenState
    extends ConsumerState<PendingNotesReviewScreen> {
  final TextEditingController _searchController = TextEditingController();

  String _selectedYear = 'all';
  String _selectedSemester = 'all';
  String _selectedCourse = 'all';
  String _selectedBranch = 'all';
  String _selectedSection = 'all';
  String _selectedSubject = 'all';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final currentUserAsync = ref.watch(currentUserProvider);

    return currentUserAsync.when(
      data: (user) {
        if (user == null || user.role != 'admin') {
          return Scaffold(
            appBar: AppBar(
              leading: const AppBackButton(fallbackRoute: '/admin'),
              title: const Text('Pending Notes Review'),
            ),
            body: const Center(
              child: Text('Admin access is required for this screen.'),
            ),
          );
        }

        final pendingAsync = ref.watch(pendingNotesProvider(user.collegeId));

        return pendingAsync.when(
          data: (notes) {
            final years = _buildYears(notes);
            final semesters = _buildSemesters(notes);
            final courses = _buildCourses(notes);
            final branches = _buildBranches(notes);
            final subjects = _buildSubjects(notes);
            final filtered = _applyFilters(notes);

            return Scaffold(
              appBar: AppBar(
                leading: const AppBackButton(fallbackRoute: '/admin'),
                title: const Text('Pending Notes Review'),
              ),
              body: RefreshIndicator(
                onRefresh: () => _refresh(user.collegeId),
                child: ListView(
                  padding: const EdgeInsets.all(12),
                  children: [
                    TextField(
                      controller: _searchController,
                      onChanged: (_) => setState(() {}),
                      decoration: InputDecoration(
                        hintText: 'Search by title, subject, tags, uploader',
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
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            initialValue: _selectedYear,
                            decoration: const InputDecoration(
                              labelText: 'Year',
                            ),
                            items: years
                                .map(
                                  (item) => DropdownMenuItem<String>(
                                    value: item,
                                    child: Text(item == 'all' ? 'All' : item),
                                  ),
                                )
                                .toList(),
                            onChanged: (value) {
                              if (value == null) {
                                return;
                              }
                              setState(() => _selectedYear = value);
                            },
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: DropdownButtonFormField<String>(
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
                              if (value == null) {
                                return;
                              }
                              setState(() => _selectedSemester = value);
                            },
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: DropdownButtonFormField<String>(
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
                              if (value == null) {
                                return;
                              }
                              setState(() => _selectedCourse = value);
                            },
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: DropdownButtonFormField<String>(
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
                              if (value == null) {
                                return;
                              }
                              setState(() => _selectedBranch = value);
                            },
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    DropdownButtonFormField<String>(
                      initialValue: _selectedSection,
                      decoration: const InputDecoration(labelText: 'Section'),
                      items: const [
                        DropdownMenuItem(value: 'all', child: Text('All')),
                        DropdownMenuItem(value: 'notes', child: Text('Notes')),
                        DropdownMenuItem(value: 'pyq', child: Text('PYQ')),
                        DropdownMenuItem(
                          value: 'sessional',
                          child: Text('Sessional'),
                        ),
                        DropdownMenuItem(value: 'put', child: Text('PUT')),
                      ],
                      onChanged: (value) {
                        if (value == null) {
                          return;
                        }
                        setState(() => _selectedSection = value);
                      },
                    ),
                    const SizedBox(height: 10),
                    SizedBox(
                      height: 40,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        itemBuilder: (context, index) {
                          final subject = subjects[index];
                          return ChoiceChip(
                            selected: subject == _selectedSubject,
                            label: Text(subject == 'all' ? 'All' : subject),
                            onSelected: (_) {
                              setState(() => _selectedSubject = subject);
                            },
                          );
                        },
                        separatorBuilder: (_, _) => const SizedBox(width: 8),
                        itemCount: subjects.length,
                      ),
                    ),
                    const SizedBox(height: 12),
                    if (filtered.isEmpty)
                      const Padding(
                        padding: EdgeInsets.only(top: 48),
                        child: EmptyState(
                          title: 'No pending notes found',
                          subtitle: 'Try changing filters.',
                          icon: Icons.filter_alt_off_rounded,
                        ),
                      )
                    else
                      ...filtered.map(
                        (note) => _PendingNoteCard(
                          note: note,
                          onApprove: () =>
                              _approve(note.noteId, user.uid, user.collegeId),
                          onReject: () =>
                              _askRejectReason(note.noteId, user.collegeId),
                        ),
                      ),
                  ],
                ),
              ),
            );
          },
          loading: () => const Scaffold(
            body: LoadingWidget(message: 'Loading pending notes...'),
          ),
          error: (error, _) => Scaffold(
            appBar: AppBar(
              leading: const AppBackButton(fallbackRoute: '/admin'),
              title: const Text('Pending Notes Review'),
            ),
            body: EmptyState(
              title: 'Unable to load pending notes',
              subtitle: '$error',
            ),
          ),
        );
      },
      loading: () =>
          const Scaffold(body: LoadingWidget(message: 'Loading profile...')),
      error: (error, _) => Scaffold(
        appBar: AppBar(
          leading: const AppBackButton(fallbackRoute: '/admin'),
          title: const Text('Pending Notes Review'),
        ),
        body: Center(child: Text('Error loading profile: $error')),
      ),
    );
  }

  List<String> _buildYears(List<NoteModel> notes) {
    final years =
        notes
            .map((note) => note.year.trim())
            .where((year) => year.isNotEmpty)
            .toSet()
            .toList()
          ..sort(
            (a, b) =>
                int.tryParse(a)?.compareTo(int.tryParse(b) ?? 0) ??
                a.compareTo(b),
          );

    return <String>['all', ...years];
  }

  List<String> _buildSemesters(List<NoteModel> notes) {
    final semesters =
        notes
            .map((note) => note.semester.trim())
            .where((semester) => semester.isNotEmpty)
            .toSet()
            .toList()
          ..sort(
            (a, b) =>
                int.tryParse(a)?.compareTo(int.tryParse(b) ?? 0) ??
                a.compareTo(b),
          );

    return <String>['all', ...semesters];
  }

  List<String> _buildCourses(List<NoteModel> notes) {
    final courses =
        notes
            .map((note) => note.course.trim())
            .where((course) => course.isNotEmpty)
            .toSet()
            .toList()
          ..sort();

    return <String>['all', ...courses];
  }

  List<String> _buildBranches(List<NoteModel> notes) {
    final branches =
        notes
            .map((note) => note.branch.trim())
            .where((branch) => branch.isNotEmpty)
            .toSet()
            .toList()
          ..sort();

    return <String>['all', ...branches];
  }

  List<String> _buildSubjects(List<NoteModel> notes) {
    final subjects =
        notes
            .map((note) => note.subject.trim())
            .where((subject) => subject.isNotEmpty)
            .toSet()
            .toList()
          ..sort();

    return <String>['all', ...subjects];
  }

  List<NoteModel> _applyFilters(List<NoteModel> notes) {
    final query = _searchController.text.trim().toLowerCase();

    return notes.where((note) {
      if (_selectedYear != 'all' && note.year != _selectedYear) {
        return false;
      }

      if (_selectedSemester != 'all' && note.semester != _selectedSemester) {
        return false;
      }

      if (_selectedCourse != 'all' && note.course != _selectedCourse) {
        return false;
      }

      if (_selectedBranch != 'all' && note.branch != _selectedBranch) {
        return false;
      }

      if (_selectedSubject != 'all' && note.subject != _selectedSubject) {
        return false;
      }

      if (_selectedSection != 'all' && note.section != _selectedSection) {
        return false;
      }

      if (query.isEmpty) {
        return true;
      }

      final haystack = <String>[
        note.title,
        note.subject,
        note.course,
        note.branch,
        note.year,
        note.semester,
        note.section,
        note.uploaderName,
        note.tags.join(' '),
      ].join(' ').toLowerCase();

      return haystack.contains(query);
    }).toList();
  }

  Future<void> _approve(
    String noteId,
    String adminUid,
    String collegeId,
  ) async {
    try {
      await ref.read(notesRepositoryProvider).verifyNote(noteId, adminUid);
      await _refresh(collegeId);
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Note approved successfully.')),
      );
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Approval failed: $error')));
    }
  }

  Future<void> _askRejectReason(String noteId, String collegeId) async {
    final controller = TextEditingController();
    final reason = await showDialog<String>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Reject Note'),
          content: TextField(
            controller: controller,
            maxLines: 3,
            decoration: const InputDecoration(
              labelText: 'Reason',
              hintText: 'Mention why this note is rejected',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                Navigator.of(dialogContext).pop(controller.text.trim());
              },
              child: const Text('Reject'),
            ),
          ],
        );
      },
    );

    if (reason == null || reason.trim().isEmpty) {
      return;
    }

    try {
      await ref.read(notesRepositoryProvider).rejectNote(noteId, reason);
      await _refresh(collegeId);
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Note rejected.')));
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Rejection failed: $error')));
    }
  }

  Future<void> _refresh(String collegeId) async {
    ref.invalidate(pendingNotesProvider(collegeId));
    ref.invalidate(adminPendingNotesCountProvider);
    await Future<void>.delayed(const Duration(milliseconds: 250));
  }
}

class _PendingNoteCard extends StatelessWidget {
  const _PendingNoteCard({
    required this.note,
    required this.onApprove,
    required this.onReject,
  });

  final NoteModel note;
  final VoidCallback onApprove;
  final VoidCallback onReject;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              note.title,
              style: Theme.of(context).textTheme.titleMedium,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 6),
            Text(
              '${note.subject} • Year ${note.year} • Semester ${note.semester}',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 4),
            Text(
              '${note.course}${note.branch.trim().isEmpty ? '' : ' • ${note.branch}'}',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 4),
            Text(
              'Section: ${note.section.toUpperCase()} • By ${note.uploaderName}',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: FilledButton.icon(
                    onPressed: onApprove,
                    icon: const Icon(Icons.check_circle_outline_rounded),
                    label: const Text('Approve'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: onReject,
                    icon: const Icon(Icons.cancel_outlined),
                    label: const Text('Reject'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
