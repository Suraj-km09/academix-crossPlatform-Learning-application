import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/app_exception.dart';
import '../../../core/utils/validators.dart';
import '../../../shared/domain/academic_options_providers.dart';
import '../../../shared/models/academic_options_model.dart';
import '../../../shared/widgets/app_back_button.dart';
import '../../../shared/widgets/app_button.dart';
import '../../../shared/widgets/app_text_field.dart';
import '../data/curriculum_repository.dart';
import '../domain/curriculum_providers.dart';

class UploadCurriculumScreen extends ConsumerStatefulWidget {
  const UploadCurriculumScreen({
    super.key,
    required this.collegeId,
    required this.uploaderUid,
    required this.uploaderName,
    required this.uploaderRole,
    required this.defaultCourse,
    required this.defaultBranch,
    required this.defaultSemester,
  });

  final String collegeId;
  final String uploaderUid;
  final String uploaderName;
  final String uploaderRole;
  final String defaultCourse;
  final String defaultBranch;
  final int? defaultSemester;

  @override
  ConsumerState<UploadCurriculumScreen> createState() =>
      _UploadCurriculumScreenState();
}

class _UploadCurriculumScreenState
    extends ConsumerState<UploadCurriculumScreen> {
  final _formKey = GlobalKey<FormState>();

  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _subjectController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();

  String? _selectedCourse;
  String _selectedBranch = '';
  int _selectedSemester = 1;
  String _selectedYear = '1';
  String _selectedCategory = 'syllabus';
  bool _isPinned = false;
  bool _isSubmitting = false;

  PlatformFile? _selectedDocument;

  @override
  void initState() {
    super.initState();
    _selectedCourse = widget.defaultCourse;
    _selectedBranch = widget.defaultBranch;
    _selectedSemester = _normalizeSemester(widget.defaultSemester);
    _selectedYear = _calculateYear(_selectedSemester);
  }

  String _calculateYear(int semester) {
    if (semester <= 2) return '1';
    if (semester <= 4) return '2';
    if (semester <= 6) return '3';
    return '4';
  }

  @override
  void dispose() {
    _titleController.dispose();
    _subjectController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final maxChars = CurriculumRepository.descriptionLimit;
    final academicOptions =
        ref.watch(academicOptionsProvider).valueOrNull ??
        const AcademicOptionsModel.defaults();
    final courseOptions = academicOptions.courses;
    final branchOptions = academicOptions.branches;
    final selectedCourse = _normalizeCourse(
      _selectedCourse ?? '',
      courseOptions,
    );
    final selectedBranch = _normalizeBranch(_selectedBranch, branchOptions);

    return Scaffold(
      appBar: AppBar(
        leading: const AppBackButton(fallbackRoute: '/curriculum'),
        title: const Text('Upload Curriculum Item'),
      ),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              AppTextField(
                controller: _titleController,
                label: 'Title',
                hint: 'e.g., B.Tech CSE 3rd Sem Syllabus',
                validator: (value) =>
                    Validators.requiredField(value, field: 'Title'),
              ),
              const SizedBox(height: 12),
              AppTextField(
                controller: _subjectController,
                label: 'Subject (Optional)',
                hint: 'e.g., Data Structures',
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: selectedCourse,
                isExpanded: true,
                decoration: const InputDecoration(labelText: 'Course'),
                items: courseOptions
                    .map(
                      (course) => DropdownMenuItem<String>(
                        value: course,
                        child: Text(course),
                      ),
                    )
                    .toList(),
                onChanged: _isSubmitting
                    ? null
                    : (value) {
                        setState(() => _selectedCourse = value);
                      },
                validator: (value) => value == null || value.trim().isEmpty
                    ? 'Please select course'
                    : null,
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: selectedBranch,
                isExpanded: true,
                decoration: const InputDecoration(
                  labelText: 'Branch (Optional)',
                ),
                items: [
                  const DropdownMenuItem<String>(
                    value: '',
                    child: Text('All Branches'),
                  ),
                  ...branchOptions.map(
                    (branch) => DropdownMenuItem<String>(
                      value: branch,
                      child: Text(branch),
                    ),
                  ),
                ],
                onChanged: _isSubmitting
                    ? null
                    : (value) {
                        setState(() => _selectedBranch = value ?? '');
                      },
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<int>(
                      initialValue: _selectedSemester,
                      isExpanded: true,
                      decoration: const InputDecoration(labelText: 'Semester'),
                      items: List.generate(
                        8,
                        (index) => DropdownMenuItem<int>(
                          value: index + 1,
                          child: Text('Sem ${index + 1}'),
                        ),
                      ),
                      onChanged: _isSubmitting
                          ? null
                          : (value) {
                              if (value == null) return;
                              setState(() {
                                _selectedSemester = value;
                                _selectedYear = _calculateYear(value);
                              });
                            },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      initialValue: _selectedYear,
                      decoration: const InputDecoration(labelText: 'Year'),
                      items: ['1', '2', '3', '4']
                          .map(
                            (y) => DropdownMenuItem(
                              value: y,
                              child: Text('Year $y'),
                            ),
                          )
                          .toList(),
                      onChanged: _isSubmitting
                          ? null
                          : (value) {
                              if (value == null) return;
                              setState(() => _selectedYear = value);
                            },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: _selectedCategory,
                isExpanded: true,
                decoration: const InputDecoration(labelText: 'Category'),
                items: const [
                  DropdownMenuItem(value: 'syllabus', child: Text('Syllabus')),
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
                onChanged: _isSubmitting
                    ? null
                    : (value) {
                        if (value == null) {
                          return;
                        }
                        setState(() => _selectedCategory = value);
                      },
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _descriptionController,
                maxLines: 7,
                maxLength: maxChars,
                enabled: !_isSubmitting,
                decoration: const InputDecoration(
                  labelText: 'Text Information (Optional)',
                  hintText:
                      'Add syllabus summary, unit breakdown, subject tips, or important notices.',
                  alignLabelWithHint: true,
                ),
                validator: (value) {
                  if ((value ?? '').trim().length > maxChars) {
                    return 'Text must be within $maxChars characters';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 10),
              InkWell(
                onTap: _isSubmitting ? null : _pickDocument,
                borderRadius: BorderRadius.circular(12),
                child: Ink(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Theme.of(context).dividerColor),
                  ),
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final compact = constraints.maxWidth < 420;
                      final helperText = Text(
                        _selectedDocument == null
                            ? 'Attach optional document (PDF/TXT/DOC/DOCX)'
                            : _selectedDocument!.name,
                      );

                      final trailing = _selectedDocument != null
                          ? IconButton(
                              onPressed: _isSubmitting
                                  ? null
                                  : () => setState(
                                      () => _selectedDocument = null,
                                    ),
                              icon: const Icon(Icons.close_rounded),
                            )
                          : TextButton(
                              onPressed: _isSubmitting ? null : _pickDocument,
                              child: const Text('Choose'),
                            );

                      if (compact) {
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(
                                  Icons.attach_file_rounded,
                                  color: Theme.of(context).colorScheme.primary,
                                ),
                                const SizedBox(width: 10),
                                Expanded(child: helperText),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Align(
                              alignment: Alignment.centerRight,
                              child: trailing,
                            ),
                          ],
                        );
                      }

                      return Row(
                        children: [
                          Icon(
                            Icons.attach_file_rounded,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                          const SizedBox(width: 10),
                          Expanded(child: helperText),
                          trailing,
                        ],
                      );
                    },
                  ),
                ),
              ),
              const SizedBox(height: 10),
              Text(
                'Document and Text information are optional. Use at least one for clarity.',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              if (_canPin) ...[
                const SizedBox(height: 8),
                SwitchListTile.adaptive(
                  contentPadding: EdgeInsets.zero,
                  value: _isPinned,
                  onChanged: _isSubmitting
                      ? null
                      : (value) => setState(() => _isPinned = value),
                  title: const Text('Mark as Important'),
                  subtitle: const Text('Important items are shown at the top.'),
                ),
              ],
              const SizedBox(height: 22),
              AppButton(
                label: _isSubmitting
                    ? 'Publishing...'
                    : 'Publish Curriculum Item',
                isLoading: _isSubmitting,
                onPressed: _isSubmitting ? null : _submit,
              ),
            ],
          ),
        ),
      ),
    );
  }

  bool get _canPin {
    final role = widget.uploaderRole.trim().toLowerCase();
    return role == 'admin' || role == 'teacher';
  }

  Future<void> _pickDocument() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowMultiple: false,
      withData: true,
      allowedExtensions: const ['pdf', 'txt', 'doc', 'docx'],
    );

    if (result == null || result.files.isEmpty) {
      return;
    }

    setState(() => _selectedDocument = result.files.first);
  }

  Future<void> _submit() async {
    final isValid = _formKey.currentState?.validate() ?? false;
    if (!isValid) {
      return;
    }

    if (_descriptionController.text.trim().isEmpty &&
        _selectedDocument == null) {
      _showSnackBar('Please provide either text information or a document');
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final academicOptions = _currentAcademicOptions();
      final resolvedCourse = _normalizeCourse(
        _selectedCourse ?? '',
        academicOptions.courses,
      );
      final resolvedBranch = _normalizeBranch(
        _selectedBranch,
        academicOptions.branches,
      );

      if (resolvedCourse == null) {
        _showSnackBar('Please select a valid course');
        return;
      }

      await ref
          .read(curriculumRepositoryProvider)
          .createCurriculumItem(
            title: _titleController.text,
            subject: _subjectController.text,
            description: _descriptionController.text,
            course: resolvedCourse,
            semester: _selectedSemester.toString(),
            branch: resolvedBranch,
            category: _selectedCategory,
            collegeId: widget.collegeId,
            uploadedBy: widget.uploaderUid,
            uploaderName: widget.uploaderName,
            uploaderRole: widget.uploaderRole,
            isPinned: _canPin ? _isPinned : false,
            documentFile: _selectedDocument,
          );

      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Curriculum item published successfully.'),
        ),
      );
      Navigator.of(context).pop(true);
    } on AppException catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.message)));
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Publish failed: $error')));
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  String? _normalizeCourse(String value, List<String> courses) {
    final normalized = value.trim().toLowerCase();
    for (final option in courses) {
      if (option.toLowerCase() == normalized) {
        return option;
      }
    }
    if (courses.isEmpty) {
      return null;
    }
    return courses.first;
  }

  String _normalizeBranch(String value, List<String> branches) {
    final normalized = value.trim().toLowerCase();
    for (final option in branches) {
      if (option.toLowerCase() == normalized) {
        return option;
      }
    }
    return '';
  }

  int _normalizeSemester(int? semester) {
    if (semester == null) {
      return 1;
    }
    if (semester < 1) {
      return 1;
    }
    if (semester > 8) {
      return 8;
    }
    return semester;
  }

  AcademicOptionsModel _currentAcademicOptions() {
    return ref.read(academicOptionsProvider).valueOrNull ??
        const AcademicOptionsModel.defaults();
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }
}
