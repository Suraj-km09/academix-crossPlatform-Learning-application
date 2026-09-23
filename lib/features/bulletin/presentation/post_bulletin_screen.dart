import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/errors/app_exception.dart';
import '../../../features/auth/domain/auth_providers.dart';
import '../../../shared/widgets/app_back_button.dart';
import '../../../shared/widgets/app_button.dart';
import '../../../shared/widgets/app_text_field.dart';
import '../../../shared/widgets/empty_state.dart';
import '../../../shared/widgets/loading_widget.dart';
import '../domain/bulletin_providers.dart';

class PostBulletinScreen extends ConsumerStatefulWidget {
  const PostBulletinScreen({super.key});

  @override
  ConsumerState<PostBulletinScreen> createState() => _PostBulletinScreenState();
}

class _PostBulletinScreenState extends ConsumerState<PostBulletinScreen> {
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  final TextEditingController _courseController = TextEditingController();

  String _category = 'notice';
  int? _targetSemester;
  DateTime? _eventDate;
  PlatformFile? _attachment;

  bool _posting = false;
  double _uploadProgress = 0;

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _courseController.dispose();
    super.dispose();
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

        final role = user.role.trim().toLowerCase();
        final canPost = role == 'teacher' || role == 'admin';
        if (!canPost) {
          return Scaffold(
            appBar: AppBar(
              leading: const AppBackButton(fallbackRoute: '/bulletin'),
              title: const Text('Post Bulletin'),
            ),
            body: const EmptyState(
              title: 'Not allowed',
              subtitle: 'Only teacher and admin can post bulletins.',
            ),
          );
        }

        return Scaffold(
          appBar: AppBar(
            leading: const AppBackButton(fallbackRoute: '/bulletin'),
            title: const Text('Post Bulletin'),
          ),
          body: SafeArea(
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                AppTextField(
                  controller: _titleController,
                  label: 'Title',
                  hint: 'Write bulletin title',
                ),
                const SizedBox(height: 10),
                AppTextField(
                  controller: _descriptionController,
                  label: 'Description',
                  hint: 'Write complete description',
                  maxLines: 6,
                ),
                const SizedBox(height: 10),
                DropdownButtonFormField<String>(
                  initialValue: _category,
                  items: _categoryItems
                      .map(
                        (item) => DropdownMenuItem<String>(
                          value: item,
                          child: Text(item.toUpperCase()),
                        ),
                      )
                      .toList(),
                  decoration: const InputDecoration(labelText: 'Category'),
                  onChanged: _posting
                      ? null
                      : (value) {
                          if (value == null || value.trim().isEmpty) {
                            return;
                          }
                          setState(() {
                            _category = value;
                            if (_category != 'event') {
                              _eventDate = null;
                            }
                          });
                        },
                ),
                if (_category == 'event') ...[
                  const SizedBox(height: 10),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.event_rounded),
                    title: const Text('Event Date'),
                    subtitle: Text(
                      _eventDate == null
                          ? 'Select date and time'
                          : DateFormat(
                              'dd MMM yyyy, hh:mm a',
                            ).format(_eventDate!),
                    ),
                    trailing: TextButton(
                      onPressed: _posting ? null : _pickEventDate,
                      child: const Text('Choose'),
                    ),
                  ),
                ],
                const SizedBox(height: 10),
                DropdownButtonFormField<int?>(
                  initialValue: _targetSemester,
                  decoration: const InputDecoration(
                    labelText: 'Target Semester',
                  ),
                  items: const [
                    DropdownMenuItem<int?>(
                      value: null,
                      child: Text('All Semesters'),
                    ),
                    DropdownMenuItem<int?>(value: 1, child: Text('Semester 1')),
                    DropdownMenuItem<int?>(value: 2, child: Text('Semester 2')),
                    DropdownMenuItem<int?>(value: 3, child: Text('Semester 3')),
                    DropdownMenuItem<int?>(value: 4, child: Text('Semester 4')),
                    DropdownMenuItem<int?>(value: 5, child: Text('Semester 5')),
                    DropdownMenuItem<int?>(value: 6, child: Text('Semester 6')),
                    DropdownMenuItem<int?>(value: 7, child: Text('Semester 7')),
                    DropdownMenuItem<int?>(value: 8, child: Text('Semester 8')),
                  ],
                  onChanged: _posting
                      ? null
                      : (value) => setState(() => _targetSemester = value),
                ),
                const SizedBox(height: 10),
                AppTextField(
                  controller: _courseController,
                  label: 'Target Course',
                  hint: 'Leave empty for all courses',
                ),
                const SizedBox(height: 12),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.attach_file_rounded),
                  title: const Text('Attachment (PDF only)'),
                  subtitle: Text(
                    _attachment == null
                        ? 'No attachment selected'
                        : _attachment!.name,
                  ),
                  trailing: TextButton(
                    onPressed: _posting ? null : _pickAttachment,
                    child: const Text('Select'),
                  ),
                ),
                if (_posting && _attachment != null) ...[
                  const SizedBox(height: 8),
                  LinearProgressIndicator(
                    value: _uploadProgress > 0 ? _uploadProgress : null,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    _uploadProgress > 0
                        ? 'Uploading ${(100 * _uploadProgress).toStringAsFixed(0)}%'
                        : 'Uploading attachment...',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
                const SizedBox(height: 16),
                AppButton(
                  label: _posting ? 'Posting...' : 'Post Bulletin',
                  isLoading: _posting,
                  onPressed: _posting
                      ? null
                      : () => _post(
                          posterUid: user.uid,
                          posterName: user.name,
                          posterRole: user.role,
                          collegeId: user.collegeId,
                        ),
                ),
              ],
            ),
          ),
        );
      },
      loading: () =>
          const Scaffold(body: LoadingWidget(message: 'Loading profile...')),
      error: (error, _) => Scaffold(
        appBar: AppBar(title: const Text('Post Bulletin')),
        body: EmptyState(title: 'Unable to load profile', subtitle: '$error'),
      ),
    );
  }

  Future<void> _pickEventDate() async {
    final now = DateTime.now();
    final date = await showDatePicker(
      context: context,
      initialDate: _eventDate ?? now,
      firstDate: now.subtract(const Duration(days: 365)),
      lastDate: now.add(const Duration(days: 3650)),
    );
    if (date == null || !mounted) {
      return;
    }

    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_eventDate ?? now),
    );
    if (time == null) {
      return;
    }

    setState(() {
      _eventDate = DateTime(
        date.year,
        date.month,
        date.day,
        time.hour,
        time.minute,
      );
    });
  }

  Future<void> _pickAttachment() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowMultiple: false,
      allowedExtensions: const ['pdf'],
      withData: false,
    );

    if (result == null || result.files.isEmpty) {
      return;
    }

    setState(() => _attachment = result.files.first);
  }

  Future<void> _post({
    required String posterUid,
    required String posterName,
    required String posterRole,
    required String collegeId,
  }) async {
    final title = _titleController.text.trim();
    final description = _descriptionController.text.trim();
    final course = _courseController.text.trim();

    if (title.isEmpty || description.isEmpty) {
      _showSnackBar('Title and description are required');
      return;
    }

    if (_category == 'event' && _eventDate == null) {
      _showSnackBar('Event date is required for event category');
      return;
    }

    setState(() {
      _posting = true;
      _uploadProgress = 0;
    });

    try {
      await ref
          .read(bulletinRepositoryProvider)
          .postBulletin(
            title,
            description,
            _category,
            collegeId,
            posterUid,
            posterName,
            posterRole,
            targetSemester: _targetSemester,
            targetCourse: course.isEmpty ? null : course,
            eventDate: _eventDate,
            attachmentFile: _attachment,
            onUploadProgress: (progress) {
              if (!mounted) {
                return;
              }
              setState(() => _uploadProgress = progress);
            },
          );

      if (!mounted) {
        return;
      }
      _showSnackBar('Bulletin posted');
      Navigator.of(context).pop(true);
    } on AppException catch (error) {
      _showSnackBar(error.message);
    } catch (error) {
      _showSnackBar('Unable to post bulletin: $error');
    } finally {
      if (mounted) {
        setState(() {
          _posting = false;
          _uploadProgress = 0;
        });
      }
    }
  }

  void _showSnackBar(String message) {
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  static const List<String> _categoryItems = <String>[
    'notice',
    'event',
    'deadline',
    'placement',
    'holiday',
  ];
}
