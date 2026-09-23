import 'dart:async';

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
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../shared/services/security_config_service.dart';
import '../domain/notes_providers.dart';

class UploadNoteScreen extends ConsumerStatefulWidget {
  const UploadNoteScreen({
    super.key,
    required this.collegeId,
    required this.uploaderUid,
    required this.uploaderName,
    required this.uploaderRole,
    required this.uploaderCourse,
    required this.uploaderBranch,
  });

  final String collegeId;
  final String uploaderUid;
  final String uploaderName;
  final String uploaderRole;
  final String uploaderCourse;
  final String uploaderBranch;

  @override
  ConsumerState<UploadNoteScreen> createState() => _UploadNoteScreenState();
}

class _UploadNoteScreenState extends ConsumerState<UploadNoteScreen> {
  final _formKey = GlobalKey<FormState>();

  final _titleController = TextEditingController();
  final _subjectController = TextEditingController();
  final _tagsController = TextEditingController();
  final _pyqYearController = TextEditingController();

  final StreamController<double> _progressController =
      StreamController<double>.broadcast();

  PlatformFile? _selectedFile;
  String _selectedSection = 'notes';
  String? _selectedCourse;
  String? _selectedBranch;
  int _selectedYear = 1;
  int _selectedSemester = 1;

  bool _isUploading = false;
  double _progress = 0;

  @override
  void initState() {
    super.initState();
    _selectedCourse = widget.uploaderCourse;
    _selectedBranch = widget.uploaderBranch;
    _progressController.stream.listen((value) {
      if (!mounted) {
        return;
      }
      setState(() => _progress = value);
    });
  }

  @override
  void dispose() {
    _titleController.dispose();
    _subjectController.dispose();
    _tagsController.dispose();
    _pyqYearController.dispose();
    _progressController.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isPyq = _selectedSection == 'pyq';
    final academicOptions =
        ref.watch(academicOptionsProvider).valueOrNull ??
        const AcademicOptionsModel.defaults();
    final courseOptions = academicOptions.courses;
    final branchOptions = academicOptions.branches;
    final selectedCourse = _normalizeSelection(
      _selectedCourse ?? '',
      courseOptions,
    );
    final selectedBranch = _normalizeSelection(
      _selectedBranch ?? '',
      branchOptions,
      fallbackToFirst: false,
    );

    final normalizedRole = widget.uploaderRole.trim().toLowerCase();
    bool roleAllowedForNotes = true;
    try {
      roleAllowedForNotes = SecurityConfigService.instance(
        FirebaseFirestore.instance,
      ).isRoleResourceAllowed(normalizedRole, 'notes');
    } catch (_) {
      roleAllowedForNotes = true;
    }

    if (!(normalizedRole == 'admin' || roleAllowedForNotes)) {
      return Scaffold(
        appBar: AppBar(
          leading: const AppBackButton(fallbackRoute: '/notes'),
          title: const Text('Upload Note/PYQ'),
        ),
        body: const Center(
          child: Text('Uploads are currently disabled for your role.'),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        leading: const AppBackButton(fallbackRoute: '/notes'),
        title: const Text('Upload Note/PYQ'),
      ),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              InkWell(
                onTap: _isUploading ? null : _pickPdf,
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
                      final fileText = Text(
                        _selectedFile == null
                            ? 'Pick PDF file'
                            : _selectedFile!.name,
                        style: Theme.of(context).textTheme.bodyMedium,
                        maxLines: compact ? 3 : 2,
                        overflow: TextOverflow.ellipsis,
                      );

                      final chooseButton = TextButton(
                        onPressed: _isUploading ? null : _pickPdf,
                        child: const Text('Choose'),
                      );

                      if (compact) {
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(
                                  Icons.picture_as_pdf_rounded,
                                  color: Theme.of(context).colorScheme.primary,
                                ),
                                const SizedBox(width: 12),
                                Expanded(child: fileText),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Align(
                              alignment: Alignment.centerRight,
                              child: chooseButton,
                            ),
                          ],
                        );
                      }

                      return Row(
                        children: [
                          Icon(
                            Icons.picture_as_pdf_rounded,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                          const SizedBox(width: 12),
                          Expanded(child: fileText),
                          chooseButton,
                        ],
                      );
                    },
                  ),
                ),
              ),
              const SizedBox(height: 12),
              AppTextField(
                controller: _titleController,
                label: 'Title',
                hint: 'Enter note title',
                validator: (value) =>
                    Validators.requiredField(value, field: 'Title'),
              ),
              const SizedBox(height: 12),
              AppTextField(
                controller: _subjectController,
                label: 'Subject',
                hint: 'e.g., DBMS',
                validator: (value) =>
                    Validators.requiredField(value, field: 'Subject'),
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
                onChanged: _isUploading
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
                onChanged: _isUploading
                    ? null
                    : (value) {
                        setState(() => _selectedBranch = value);
                      },
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<int>(
                initialValue: _selectedYear,
                isExpanded: true,
                decoration: const InputDecoration(labelText: 'Year'),
                items: List.generate(
                  5,
                  (index) => DropdownMenuItem<int>(
                    value: index + 1,
                    child: Text('Year ${index + 1}'),
                  ),
                ),
                onChanged: _isUploading
                    ? null
                    : (value) {
                        if (value == null) {
                          return;
                        }
                        setState(() => _selectedYear = value);
                      },
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<int>(
                initialValue: _selectedSemester,
                isExpanded: true,
                decoration: const InputDecoration(labelText: 'Semester'),
                items: List.generate(
                  8,
                  (index) => DropdownMenuItem<int>(
                    value: index + 1,
                    child: Text('${index + 1}'),
                  ),
                ),
                onChanged: _isUploading
                    ? null
                    : (value) {
                        if (value == null) {
                          return;
                        }
                        setState(() => _selectedSemester = value);
                      },
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: _selectedSection,
                isExpanded: true,
                decoration: const InputDecoration(labelText: 'Section'),
                items: const [
                  DropdownMenuItem(value: 'notes', child: Text('Notes')),
                  DropdownMenuItem(value: 'pyq', child: Text('PYQ')),
                  DropdownMenuItem(
                    value: 'sessional',
                    child: Text('Sessional'),
                  ),
                  DropdownMenuItem(value: 'put', child: Text('PUT')),
                ],
                onChanged: _isUploading
                    ? null
                    : (value) {
                        if (value == null) {
                          return;
                        }
                        setState(() => _selectedSection = value);
                      },
              ),
              if (isPyq) ...[
                const SizedBox(height: 12),
                AppTextField(
                  controller: _pyqYearController,
                  label: 'PYQ Year',
                  hint: 'e.g., 2023',
                  keyboardType: TextInputType.number,
                  validator: (value) {
                    if (!isPyq) {
                      return null;
                    }
                    if (value == null || value.trim().isEmpty) {
                      return 'PYQ year is required';
                    }
                    final parsed = int.tryParse(value.trim());
                    if (parsed == null) {
                      return 'Enter a valid year';
                    }
                    return null;
                  },
                ),
              ],
              const SizedBox(height: 12),
              AppTextField(
                controller: _tagsController,
                label: 'Tags',
                hint: 'Comma separated: unit-1, sessionals, PUTs',
                maxLines: 2,
              ),
              const SizedBox(height: 8),
              Text(
                'Section tags are added automatically for easier filtering.',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              if (_isUploading) ...[
                const SizedBox(height: 16),
                LinearProgressIndicator(value: _progress),
                const SizedBox(height: 6),
                Text(
                  'Uploading ${(100 * _progress).toStringAsFixed(0)}%',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
              const SizedBox(height: 22),
              AppButton(
                label: _isUploading ? 'Uploading...' : 'Upload',
                isLoading: _isUploading,
                onPressed: _isUploading ? null : _upload,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _pickPdf() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      withData: true,
      allowMultiple: false,
      allowedExtensions: const ['pdf'],
    );

    if (result == null || result.files.isEmpty) {
      return;
    }

    final file = result.files.first;
    final extension = (file.extension ?? '').toLowerCase();
    if (extension != 'pdf' && !file.name.toLowerCase().endsWith('.pdf')) {
      _showSnackBar('Only PDF files are allowed');
      return;
    }

    setState(() => _selectedFile = file);
  }

  Future<void> _upload() async {
    final formOk = _formKey.currentState?.validate() ?? false;
    if (!formOk) {
      return;
    }

    if (_selectedFile == null) {
      _showSnackBar('Please select a PDF file');
      return;
    }

    setState(() {
      _isUploading = true;
      _progress = 0;
    });

    try {
      final repository = ref.read(notesRepositoryProvider);
      final academicOptions = _currentAcademicOptions();
      final selectedCourse = _normalizeSelection(
        _selectedCourse ?? '',
        academicOptions.courses,
      );
      final selectedBranch = _normalizeSelection(
        _selectedBranch ?? '',
        academicOptions.branches,
        fallbackToFirst: false,
      );

      if (selectedCourse == null) {
        _showSnackBar('Please select a valid course');
        return;
      }

      final tags = _extractTags(_tagsController.text);
      final sectionTag = _selectedSection == 'sessional'
          ? 'sessionals'
          : (_selectedSection == 'put' ? 'puts' : _selectedSection);
      if (!tags.contains(sectionTag)) {
        tags.add(sectionTag);
      }

      if (widget.uploaderRole.trim().toLowerCase() != 'student') {
        if (!tags.contains('faculty')) {
          tags.add('faculty');
        }
      }

      if (widget.uploaderRole.trim().toLowerCase() == 'student') {
        if (!tags.any((tag) => tag.toLowerCase() == 'community')) {
          tags.add('community');
        }
      }

      final pyqYear = _selectedSection == 'pyq'
          ? int.tryParse(_pyqYearController.text.trim())
          : null;

      final typeForStorage = _selectedSection == 'pyq' ? 'pyq' : 'notes';

      await repository.uploadNote(
        _selectedFile!,
        _titleController.text,
        _subjectController.text,
        selectedCourse,
        (selectedBranch ?? '').trim(),
        _selectedSemester.toString(),
        _selectedYear.toString(),
        tags,
        typeForStorage,
        _selectedSection,
        pyqYear,
        widget.collegeId,
        widget.uploaderUid,
        widget.uploaderName,
        onProgress: (progress) => _progressController.add(progress),
      );

      if (!mounted) {
        return;
      }

      _showSnackBar('Note uploaded successfully');
      Navigator.of(context).pop(true);
    } on AppException catch (error) {
      _showSnackBar(error.message);
    } catch (error) {
      _showSnackBar('Upload failed: $error');
    } finally {
      if (mounted) {
        setState(() => _isUploading = false);
      }
    }
  }

  List<String> _extractTags(String raw) {
    return raw
        .split(',')
        .map((tag) => tag.trim())
        .where((tag) => tag.isNotEmpty)
        .toSet()
        .toList();
  }

  String? _normalizeSelection(
    String value,
    List<String> options, {
    bool fallbackToFirst = true,
  }) {
    final normalized = value.trim().toLowerCase();
    for (final item in options) {
      if (item.toLowerCase() == normalized) {
        return item;
      }
    }
    if (!fallbackToFirst) {
      return '';
    }
    return options.isEmpty ? null : options.first;
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
