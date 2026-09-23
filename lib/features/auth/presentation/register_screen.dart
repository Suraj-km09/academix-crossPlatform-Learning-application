import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/errors/app_exception.dart';
import '../../../core/utils/validators.dart';
import '../../../shared/domain/academic_options_providers.dart';
import '../../../shared/models/academic_options_model.dart';
import '../../../shared/models/college_model.dart';
import '../../../shared/widgets/app_button.dart';
import '../../../shared/widgets/app_text_field.dart';
import '../domain/auth_providers.dart';

class RegisterScreen extends ConsumerStatefulWidget {
  const RegisterScreen({super.key});

  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();

  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmPasswordController =
      TextEditingController();
  final TextEditingController _collegeSearchController =
      TextEditingController();
  final FocusNode _collegeFocusNode = FocusNode();
  final ScrollController _collegeListController = ScrollController();
  final TextEditingController _teacherCodeController = TextEditingController();
  final TextEditingController _batchYearController = TextEditingController();
  final TextEditingController _companyController = TextEditingController();
  final TextEditingController _jobRoleController = TextEditingController();
  Timer? _collegeSearchDebounce;

  String _selectedRole = 'student';
  String? _selectedCourse;
  String? _selectedBranch;
  int? _selectedSemester = 1;

  bool _isSubmitting = false;
  String? _teacherCodeError;
  bool _isLoadingColleges = true;
  bool _isLoadingMoreColleges = false;
  bool _isSeedingColleges = false;
  bool _showCollegePanel = true;
  bool _hasMoreColleges = true;
  String? _collegeLoadError;
  String _currentCollegeSearch = '';

  List<CollegeModel> _collegeResults = <CollegeModel>[];
  DocumentSnapshot<Map<String, dynamic>>? _lastCollegeDocument;
  String? _selectedCollegeId;
  String? _selectedCollegeName;
  PlatformFile? _profileImageFile;
  PlatformFile? _idCardImageFile;

  @override
  void initState() {
    super.initState();
    _collegeFocusNode.addListener(_onCollegeFocusChanged);
    _collegeListController.addListener(_onCollegeListScroll);
    _loadColleges(reset: true);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _collegeSearchController.dispose();
    _collegeFocusNode.dispose();
    _collegeListController.dispose();
    _teacherCodeController.dispose();
    _batchYearController.dispose();
    _companyController.dispose();
    _jobRoleController.dispose();
    _collegeSearchDebounce?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isAlumni = _selectedRole == 'alumni';
    final isTeacherRequest = _selectedRole == 'teacher';
    final isStudentOrTeacher =
        _selectedRole == 'student' || _selectedRole == 'teacher';
    final academicOptions =
        ref.watch(academicOptionsProvider).valueOrNull ??
        const AcademicOptionsModel.defaults();
    final courseOptions = academicOptions.courses;
    final branchOptions = academicOptions.branches;
    final selectedCourse = _resolveOption(
      _selectedCourse,
      courseOptions,
      fallbackToFirst: true,
    );
    final selectedBranch = _resolveOption(
      _selectedBranch,
      branchOptions,
      fallbackToFirst: true,
    );

    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: const Text('Create Account'),
      ),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: LayoutBuilder(
            builder: (context, constraints) {
              final isWide = constraints.maxWidth >= 720;

              return SingleChildScrollView(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 24,
                ),
                keyboardDismissBehavior:
                    ScrollViewKeyboardDismissBehavior.onDrag,
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 720),
                    child: Material(
                      color: isWide
                          ? Theme.of(context).colorScheme.surface
                          : Colors.transparent,
                      elevation: isWide ? 1 : 0,
                      shadowColor: Colors.black.withValues(alpha: 0.08),
                      shape: isWide
                          ? RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(20),
                              side: BorderSide(
                                color: Theme.of(
                                  context,
                                ).dividerColor.withValues(alpha: 0.2),
                                width: 1.2,
                              ),
                            )
                          : null,
                      child: Padding(
                        padding: isWide
                            ? const EdgeInsets.all(32)
                            : EdgeInsets.zero,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            AppTextField(
                              controller: _nameController,
                              label: 'Name',
                              hint: 'Enter full name',
                              textCapitalization: TextCapitalization.words,
                              validator: (value) => Validators.requiredField(
                                value,
                                field: 'Name',
                              ),
                            ),
                            const SizedBox(height: 12),
                            AppTextField(
                              controller: _emailController,
                              label: 'Email',
                              hint: 'you@college.edu',
                              keyboardType: TextInputType.emailAddress,
                              validator: Validators.email,
                            ),
                            const SizedBox(height: 12),
                            if (isWide) ...[
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Expanded(
                                    child: AppTextField(
                                      controller: _passwordController,
                                      label: 'Password',
                                      hint: 'Create a password',
                                      obscureText: true,
                                      validator: Validators.password,
                                    ),
                                  ),
                                  const SizedBox(width: 14),
                                  Expanded(
                                    child: AppTextField(
                                      controller: _confirmPasswordController,
                                      label: 'Confirm Password',
                                      hint: 'Re-enter password',
                                      obscureText: true,
                                      validator: (value) {
                                        final message =
                                            Validators.requiredField(
                                              value,
                                              field: 'Confirm password',
                                            );
                                        if (message != null) {
                                          return message;
                                        }
                                        if (value != _passwordController.text) {
                                          return 'Passwords do not match';
                                        }
                                        return null;
                                      },
                                    ),
                                  ),
                                ],
                              ),
                            ] else ...[
                              AppTextField(
                                controller: _passwordController,
                                label: 'Password',
                                hint: 'Create a password',
                                obscureText: true,
                                validator: Validators.password,
                              ),
                              const SizedBox(height: 12),
                              AppTextField(
                                controller: _confirmPasswordController,
                                label: 'Confirm Password',
                                hint: 'Re-enter password',
                                obscureText: true,
                                validator: (value) {
                                  final message = Validators.requiredField(
                                    value,
                                    field: 'Confirm password',
                                  );
                                  if (message != null) {
                                    return message;
                                  }
                                  if (value != _passwordController.text) {
                                    return 'Passwords do not match';
                                  }
                                  return null;
                                },
                              ),
                            ],
                            const SizedBox(height: 12),
                            DropdownButtonFormField<String>(
                              initialValue: _selectedRole,
                              decoration: const InputDecoration(
                                labelText: 'Role',
                              ),
                              items: const [
                                DropdownMenuItem(
                                  value: 'student',
                                  child: Text('Student'),
                                ),
                                DropdownMenuItem(
                                  value: 'teacher',
                                  child: Text(
                                    'Teacher (Code + Admin Approval)',
                                  ),
                                ),
                                DropdownMenuItem(
                                  value: 'alumni',
                                  child: Text('Alumni'),
                                ),
                              ],
                              onChanged: (value) {
                                if (value == null) {
                                  return;
                                }
                                setState(() {
                                  _selectedRole = value;
                                  if (_selectedRole == 'alumni') {
                                    _selectedCourse = null;
                                    _selectedBranch = null;
                                    _teacherCodeController.clear();
                                    _selectedSemester = null;
                                  } else {
                                    _batchYearController.clear();
                                    _companyController.clear();
                                    _jobRoleController.clear();
                                    _selectedSemester ??= 1;
                                  }
                                });
                              },
                            ),
                            const SizedBox(height: 6),
                            Text(
                              isTeacherRequest
                                  ? 'Teacher signup needs access code and admin approval.'
                                  : 'Teacher role is assigned after code validation + admin approval.',
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                            if (isTeacherRequest) ...[
                              const SizedBox(height: 12),
                              AppTextField(
                                controller: _teacherCodeController,
                                label: 'Teacher Access Code',
                                hint:
                                    'Enter teacher code provided by institute',
                                obscureText: true,
                                onChanged: (value) {
                                  if (_teacherCodeError != null) {
                                    setState(() => _teacherCodeError = null);
                                  }
                                },
                                validator: (value) {
                                  if (!isTeacherRequest) {
                                    return null;
                                  }
                                  if (value == null || value.trim().isEmpty) {
                                    return 'Teacher access code is required';
                                  }
                                  if (_teacherCodeError != null) {
                                    return _teacherCodeError;
                                  }
                                  return null;
                                },
                              ),
                            ],
                            const SizedBox(height: 12),
                            AppTextField(
                              controller: _collegeSearchController,
                              focusNode: _collegeFocusNode,
                              label: 'College Search',
                              hint: 'Type college name or college code',
                              onTap: _handleCollegeFieldTap,
                              onChanged: _onCollegeSearchChanged,
                              suffixIcon: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  if (_selectedCollegeId != null ||
                                      _collegeSearchController.text.isNotEmpty)
                                    IconButton(
                                      tooltip: 'Clear',
                                      icon: const Icon(
                                        Icons.close_rounded,
                                        size: 18,
                                      ),
                                      onPressed: _clearCollegeSelection,
                                    ),
                                  IconButton(
                                    tooltip: 'Refresh list',
                                    onPressed: _isLoadingColleges
                                        ? null
                                        : () => _loadColleges(reset: true),
                                    icon: const Icon(Icons.refresh_rounded),
                                  ),
                                ],
                              ),
                              validator: (_) {
                                if (_selectedCollegeId == null ||
                                    _selectedCollegeId!.isEmpty) {
                                  return 'Please select a college';
                                }
                                return null;
                              },
                            ),
                            if (_isLoadingColleges) ...[
                              const SizedBox(height: 8),
                              const LinearProgressIndicator(),
                            ] else if (_showCollegeSuggestions) ...[
                              const SizedBox(height: 8),
                              Container(
                                constraints: const BoxConstraints(
                                  maxHeight: 220,
                                ),
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: Theme.of(context).dividerColor,
                                  ),
                                ),
                                child: ListView.separated(
                                  controller: _collegeListController,
                                  shrinkWrap: true,
                                  itemCount:
                                      _collegeResults.length +
                                      (_isLoadingMoreColleges ? 1 : 0),
                                  separatorBuilder: (context, index) =>
                                      const Divider(height: 1),
                                  itemBuilder: (context, index) {
                                    if (index >= _collegeResults.length) {
                                      return const ListTile(
                                        dense: true,
                                        title: Center(
                                          child: SizedBox(
                                            width: 18,
                                            height: 18,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2,
                                            ),
                                          ),
                                        ),
                                      );
                                    }

                                    final college = _collegeResults[index];
                                    return ListTile(
                                      title: Text(college.name),
                                      subtitle: Text(
                                        '${college.city}, ${college.state}',
                                      ),
                                      onTap: () => _selectCollege(college),
                                    );
                                  },
                                ),
                              ),
                            ] else if (_showNoCollegeResult) ...[
                              const SizedBox(height: 8),
                              Text(
                                'No college matched your search. Try a different keyword.',
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                            ] else if (_showNoCollegeData) ...[
                              const SizedBox(height: 8),
                              Text(
                                'No colleges found on server. Tap Upload Colleges to seed Firestore.',
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                              const SizedBox(height: 6),
                              TextButton.icon(
                                onPressed: _isSeedingColleges
                                    ? null
                                    : _seedCollegesToServer,
                                icon: _isSeedingColleges
                                    ? const SizedBox(
                                        width: 14,
                                        height: 14,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                        ),
                                      )
                                    : const Icon(Icons.cloud_upload_outlined),
                                label: Text(
                                  _isSeedingColleges
                                      ? 'Uploading colleges...'
                                      : 'Upload Colleges To Firestore',
                                ),
                              ),
                            ],
                            if (_collegeLoadError != null) ...[
                              const SizedBox(height: 6),
                              Text(
                                _collegeLoadError!,
                                style: TextStyle(
                                  color: Theme.of(context).colorScheme.error,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                            if (_selectedCollegeName != null &&
                                _selectedCollegeName!.isNotEmpty) ...[
                              const SizedBox(height: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 8,
                                ),
                                decoration: BoxDecoration(
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.primary.withValues(alpha: 0.08),
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(
                                    color: Theme.of(context).colorScheme.primary
                                        .withValues(alpha: 0.25),
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    Icon(
                                      Icons.check_circle_rounded,
                                      size: 18,
                                      color: Theme.of(
                                        context,
                                      ).colorScheme.primary,
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        _selectedCollegeName!,
                                        style: Theme.of(context)
                                            .textTheme
                                            .bodyMedium
                                            ?.copyWith(
                                              fontWeight: FontWeight.bold,
                                            ),
                                      ),
                                    ),
                                    TextButton(
                                      onPressed: () {
                                        setState(() {
                                          _showCollegePanel = true;
                                        });
                                        _collegeFocusNode.requestFocus();
                                      },
                                      child: const Text('Change'),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                            const SizedBox(height: 12),
                            if (isWide) ...[
                              Row(
                                children: [
                                  Expanded(
                                    child: _ImagePickerTile(
                                      title: 'Profile Picture (Optional)',
                                      subtitle:
                                          _profileImageFile?.name ??
                                          'Select profile image (optional)',
                                      onTap: _pickProfileImage,
                                    ),
                                  ),
                                  const SizedBox(width: 14),
                                  Expanded(
                                    child: _ImagePickerTile(
                                      title:
                                          'College ID Card Picture (Optional)',
                                      subtitle:
                                          _idCardImageFile?.name ??
                                          'Select ID card image (optional)',
                                      onTap: _pickIdCardImage,
                                    ),
                                  ),
                                ],
                              ),
                            ] else ...[
                              _ImagePickerTile(
                                title: 'Profile Picture (Optional)',
                                subtitle:
                                    _profileImageFile?.name ??
                                    'Select profile image (optional)',
                                onTap: _pickProfileImage,
                              ),
                              const SizedBox(height: 12),
                              _ImagePickerTile(
                                title: 'College ID Card Picture (Optional)',
                                subtitle:
                                    _idCardImageFile?.name ??
                                    'Select ID card image (optional)',
                                onTap: _pickIdCardImage,
                              ),
                            ],
                            const SizedBox(height: 12),
                            if (isStudentOrTeacher) ...[
                              if (isWide) ...[
                                Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Expanded(
                                      flex: 4,
                                      child: DropdownButtonFormField<String>(
                                        isExpanded: true,
                                        initialValue: selectedCourse,
                                        decoration: const InputDecoration(
                                          labelText: 'Course',
                                        ),
                                        items: courseOptions
                                            .map(
                                              (course) =>
                                                  DropdownMenuItem<String>(
                                                    value: course,
                                                    child: Text(course),
                                                  ),
                                            )
                                            .toList(),
                                        onChanged: (value) => setState(
                                          () => _selectedCourse = value,
                                        ),
                                        validator: (value) =>
                                            value == null ||
                                                value.trim().isEmpty
                                            ? 'Please select course'
                                            : null,
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      flex: 4,
                                      child: DropdownButtonFormField<String>(
                                        isExpanded: true,
                                        initialValue: selectedBranch,
                                        decoration: const InputDecoration(
                                          labelText: 'Branch',
                                        ),
                                        items: branchOptions
                                            .map(
                                              (branch) =>
                                                  DropdownMenuItem<String>(
                                                    value: branch,
                                                    child: Text(branch),
                                                  ),
                                            )
                                            .toList(),
                                        onChanged: (value) => setState(
                                          () => _selectedBranch = value,
                                        ),
                                        validator: (value) =>
                                            value == null ||
                                                value.trim().isEmpty
                                            ? 'Please select branch'
                                            : null,
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      flex: 3,
                                      child: DropdownButtonFormField<int>(
                                        isExpanded: true,
                                        initialValue: _selectedSemester,
                                        decoration: const InputDecoration(
                                          labelText: 'Semester',
                                        ),
                                        items: List.generate(
                                          8,
                                          (index) => DropdownMenuItem<int>(
                                            value: index + 1,
                                            child: Text('${index + 1}'),
                                          ),
                                        ),
                                        onChanged: (value) => setState(
                                          () => _selectedSemester = value,
                                        ),
                                        validator: (value) => value == null
                                            ? 'Please select semester'
                                            : null,
                                      ),
                                    ),
                                  ],
                                ),
                              ] else ...[
                                DropdownButtonFormField<String>(
                                  isExpanded: true,
                                  initialValue: selectedCourse,
                                  decoration: const InputDecoration(
                                    labelText: 'Course',
                                  ),
                                  items: courseOptions
                                      .map(
                                        (course) => DropdownMenuItem<String>(
                                          value: course,
                                          child: Text(course),
                                        ),
                                      )
                                      .toList(),
                                  onChanged: (value) =>
                                      setState(() => _selectedCourse = value),
                                  validator: (value) =>
                                      value == null || value.trim().isEmpty
                                      ? 'Please select course'
                                      : null,
                                ),
                                const SizedBox(height: 12),
                                DropdownButtonFormField<String>(
                                  isExpanded: true,
                                  initialValue: selectedBranch,
                                  decoration: const InputDecoration(
                                    labelText: 'Branch',
                                  ),
                                  items: branchOptions
                                      .map(
                                        (branch) => DropdownMenuItem<String>(
                                          value: branch,
                                          child: Text(branch),
                                        ),
                                      )
                                      .toList(),
                                  onChanged: (value) =>
                                      setState(() => _selectedBranch = value),
                                  validator: (value) =>
                                      value == null || value.trim().isEmpty
                                      ? 'Please select branch'
                                      : null,
                                ),
                                const SizedBox(height: 12),
                                DropdownButtonFormField<int>(
                                  isExpanded: true,
                                  initialValue: _selectedSemester,
                                  decoration: const InputDecoration(
                                    labelText: 'Semester',
                                  ),
                                  items: List.generate(
                                    8,
                                    (index) => DropdownMenuItem<int>(
                                      value: index + 1,
                                      child: Text('${index + 1}'),
                                    ),
                                  ),
                                  onChanged: (value) =>
                                      setState(() => _selectedSemester = value),
                                  validator: (value) => value == null
                                      ? 'Please select semester'
                                      : null,
                                ),
                              ],
                            ],
                            if (isAlumni) ...[
                              if (isWide) ...[
                                Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Expanded(
                                      flex: 2,
                                      child: AppTextField(
                                        controller: _batchYearController,
                                        label: 'Batch Year',
                                        hint: 'e.g., 2020',
                                        keyboardType: TextInputType.number,
                                        validator: (value) {
                                          if (_selectedRole != 'alumni') {
                                            return null;
                                          }
                                          if (value == null ||
                                              value.trim().isEmpty) {
                                            return 'Batch year is required';
                                          }
                                          final parsed = int.tryParse(
                                            value.trim(),
                                          );
                                          if (parsed == null) {
                                            return 'Enter a valid batch year';
                                          }
                                          return null;
                                        },
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      flex: 3,
                                      child: AppTextField(
                                        controller: _companyController,
                                        label: 'Current Company',
                                        hint: 'e.g., Microsoft',
                                        validator: (value) {
                                          if (_selectedRole != 'alumni') {
                                            return null;
                                          }
                                          return Validators.requiredField(
                                            value,
                                            field: 'Current company',
                                          );
                                        },
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      flex: 3,
                                      child: AppTextField(
                                        controller: _jobRoleController,
                                        label: 'Current Job Role',
                                        hint: 'e.g., Software Engineer',
                                        validator: (value) {
                                          if (_selectedRole != 'alumni') {
                                            return null;
                                          }
                                          return Validators.requiredField(
                                            value,
                                            field: 'Current job role',
                                          );
                                        },
                                      ),
                                    ),
                                  ],
                                ),
                              ] else ...[
                                AppTextField(
                                  controller: _batchYearController,
                                  label: 'Batch Year',
                                  hint: 'e.g., 2020',
                                  keyboardType: TextInputType.number,
                                  validator: (value) {
                                    if (_selectedRole != 'alumni') {
                                      return null;
                                    }
                                    if (value == null || value.trim().isEmpty) {
                                      return 'Batch year is required';
                                    }
                                    final parsed = int.tryParse(value.trim());
                                    if (parsed == null) {
                                      return 'Enter a valid batch year';
                                    }
                                    return null;
                                  },
                                ),
                                const SizedBox(height: 12),
                                AppTextField(
                                  controller: _companyController,
                                  label: 'Current Company',
                                  hint: 'e.g., Microsoft',
                                  validator: (value) {
                                    if (_selectedRole != 'alumni') {
                                      return null;
                                    }
                                    return Validators.requiredField(
                                      value,
                                      field: 'Current company',
                                    );
                                  },
                                ),
                                const SizedBox(height: 12),
                                AppTextField(
                                  controller: _jobRoleController,
                                  label: 'Current Job Role',
                                  hint: 'e.g., Software Engineer',
                                  validator: (value) {
                                    if (_selectedRole != 'alumni') {
                                      return null;
                                    }
                                    return Validators.requiredField(
                                      value,
                                      field: 'Current job role',
                                    );
                                  },
                                ),
                              ],
                            ],
                            const SizedBox(height: 24),
                            AppButton(
                              label: 'Register',
                              isLoading: _isSubmitting,
                              onPressed: _isSubmitting ? null : _register,
                            ),
                            const SizedBox(height: 8),
                            Align(
                              alignment: Alignment.center,
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  TextButton(
                                    onPressed: () => context.go('/login'),
                                    child: const Text(
                                      'Already have an account? Login',
                                    ),
                                  ),
                                  TextButton(
                                    onPressed: () => context.push(
                                      '/forgot-password?email=${Uri.encodeComponent(_emailController.text.trim())}',
                                    ),
                                    child: const Text(
                                      'Forgot password? Send reset link',
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  bool get _showCollegeSuggestions {
    return _showCollegePanel &&
        !_isLoadingColleges &&
        _collegeResults.isNotEmpty;
  }

  bool get _showNoCollegeResult {
    return _showCollegePanel &&
        !_isLoadingColleges &&
        _collegeResults.isEmpty &&
        _collegeSearchController.text.trim().isNotEmpty;
  }

  bool get _showNoCollegeData {
    return !_isLoadingColleges &&
        _collegeResults.isEmpty &&
        _currentCollegeSearch.isEmpty &&
        _collegeLoadError == null;
  }

  Future<void> _loadColleges({required bool reset}) async {
    if (!reset && (!_hasMoreColleges || _isLoadingMoreColleges)) {
      return;
    }

    if (reset) {
      setState(() {
        _isLoadingColleges = true;
        _collegeLoadError = null;
        _hasMoreColleges = true;
        _lastCollegeDocument = null;
      });
    } else {
      setState(() {
        _isLoadingMoreColleges = true;
        _collegeLoadError = null;
      });
    }

    try {
      final repository = ref.read(collegesRepositoryProvider);
      final offset = reset ? 0 : _collegeResults.length;
      var page = await repository.fetchColleges(
        searchQuery: _currentCollegeSearch,
        pageSize: 30,
        startAfter: reset ? null : _lastCollegeDocument,
        offset: offset,
      );

      if (!mounted) {
        return;
      }

      if (reset && page.colleges.isEmpty && _currentCollegeSearch.isEmpty) {
        final uploaded = await _attemptAutoSeedIfNeeded();
        if (uploaded > 0) {
          page = await repository.fetchColleges(
            searchQuery: _currentCollegeSearch,
            pageSize: 30,
          );
        }
      }

      if (!mounted) {
        return;
      }

      setState(() {
        _lastCollegeDocument = page.lastDocument;
        _hasMoreColleges = page.hasMore;
        if (reset) {
          _collegeResults = page.colleges;
        } else {
          final merged = <CollegeModel>[..._collegeResults, ...page.colleges];
          final seen = <String>{};
          _collegeResults = merged.where((college) {
            if (seen.contains(college.collegeId)) {
              return false;
            }
            seen.add(college.collegeId);
            return true;
          }).toList();
        }
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _collegeLoadError = 'Failed to load colleges: $error';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingColleges = false;
          _isLoadingMoreColleges = false;
        });
      }
    }
  }

  void _onCollegeSearchChanged(String query) {
    setState(() {
      _showCollegePanel = true;
      if (_selectedCollegeName != query) {
        _selectedCollegeId = null;
        _selectedCollegeName = null;
      }
    });

    _scheduleCollegeSearch(query);
  }

  void _selectCollege(CollegeModel college) {
    setState(() {
      _selectedCollegeId = college.collegeId;
      _selectedCollegeName = _collegeDisplayName(college);
      _collegeSearchController.text = _collegeDisplayName(college);
      _showCollegePanel = false;
    });
    _collegeFocusNode.unfocus();
  }

  Future<void> _register() async {
    _resolveTypedCollegeMatch();
    final isAlumni = _selectedRole == 'alumni';
    final isTeacherRequest = _selectedRole == 'teacher';

    final isValidForm = _formKey.currentState?.validate() ?? false;
    if (!isValidForm) {
      return;
    }

    if (_selectedCollegeId == null || _selectedCollegeId!.isEmpty) {
      _showSnackBar('Please select a college from the list');
      return;
    }

    final academicOptions = _currentAcademicOptions();
    final resolvedCourse = _resolveOption(
      _selectedCourse,
      academicOptions.courses,
      fallbackToFirst: true,
    );
    final resolvedBranch = _resolveOption(
      _selectedBranch,
      academicOptions.branches,
      fallbackToFirst: true,
    );

    if (!isAlumni && (resolvedCourse == null || resolvedBranch == null)) {
      _showSnackBar('Please select course and branch');
      return;
    }

    final batchYear = isAlumni
        ? int.tryParse(_batchYearController.text.trim())
        : null;

    if (_selectedRole == 'alumni' && batchYear == null) {
      _showSnackBar('Enter a valid batch year');
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final repository = ref.read(authRepositoryProvider);
      final createdUser = await repository.signUp(
        _nameController.text,
        _emailController.text,
        _passwordController.text,
        _selectedRole,
        _selectedCollegeId!,
        isAlumni ? null : resolvedCourse,
        isAlumni ? null : resolvedBranch,
        isAlumni ? null : _selectedSemester,
        batchYear,
        isAlumni ? _companyController.text : null,
        isAlumni ? _jobRoleController.text : null,
        _profileImageFile,
        _idCardImageFile,
        isTeacherRequest ? _teacherCodeController.text.trim() : null,
      );

      var verificationSent = false;
      try {
        await repository.sendEmailVerificationToCurrentUser();
        verificationSent = true;
      } on AppException {
        verificationSent = false;
      }

      if (!mounted) {
        return;
      }

      if (verificationSent) {
        if (isTeacherRequest) {
          _showSnackBar(
            'Your teacher request has been submitted. After admin approval, you will become a teacher.',
          );
        } else {
          _showSnackBar(
            'Verification email sent. Check inbox and spam/junk folder.',
          );
        }
      } else {
        _showSnackBar(
          'Account created. Open Verify Email screen and resend if needed.',
        );
      }

      final destination = dashboardRouteForRole(createdUser.role);
      context.go(destination);
    } on AppException catch (error) {
      final msg = error.message.toLowerCase();
      final code = (error.code ?? '').toLowerCase();

      // Prefer checking `code` where available, fallback to message matching.
      final isInvalidTeacherCode =
          code == 'invalid_teacher_code' ||
          code == 'missing_teacher_code' ||
          msg.contains('teacher access code') ||
          msg.contains('invalid teacher');

      if (isInvalidTeacherCode) {
        // Show inline error near the teacher code field instead of a generic snackbar.
        setState(() {
          _teacherCodeError = code == 'missing_teacher_code'
              ? 'Teacher access code is required'
              : 'Security code is invalid. Please try again.';
          _isSubmitting = false;
        });
        // Re-run validators so the inline message displays.
        _formKey.currentState?.validate();
        return;
      }

      _showSnackBar(error.message);
    } catch (error) {
      _showSnackBar('Registration failed: $error');
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  Future<void> _pickProfileImage() async {
    final file = await _pickImage();
    if (file == null) {
      return;
    }
    setState(() => _profileImageFile = file);
  }

  Future<void> _pickIdCardImage() async {
    final file = await _pickImage();
    if (file == null) {
      return;
    }
    setState(() => _idCardImageFile = file);
  }

  Future<PlatformFile?> _pickImage() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.image,
      allowMultiple: false,
      withData: true,
    );
    if (result == null || result.files.isEmpty) {
      return null;
    }
    return result.files.first;
  }

  void _onCollegeFocusChanged() {
    if (_collegeFocusNode.hasFocus) {
      setState(() => _showCollegePanel = true);
    }
  }

  void _handleCollegeFieldTap() {
    setState(() => _showCollegePanel = true);
  }

  void _clearCollegeSelection() {
    setState(() {
      _selectedCollegeId = null;
      _selectedCollegeName = null;
      _collegeSearchController.clear();
      _currentCollegeSearch = '';
      _showCollegePanel = true;
    });
    _loadColleges(reset: true);
  }

  void _resolveTypedCollegeMatch() {
    if (_selectedCollegeId != null && _selectedCollegeId!.isNotEmpty) {
      return;
    }

    final typed = _collegeSearchController.text.trim().toLowerCase();
    if (typed.isEmpty) {
      return;
    }

    final exactMatches = _collegeResults.where((college) {
      final display = _collegeDisplayName(college).toLowerCase();
      return display == typed || college.collegeId.toLowerCase() == typed;
    }).toList();

    if (exactMatches.length == 1) {
      _selectCollege(exactMatches.first);
    }
  }

  String _collegeDisplayName(CollegeModel college) {
    return college.name.trim().isEmpty ? college.collegeId : college.name;
  }

  void _scheduleCollegeSearch(String query) {
    _collegeSearchDebounce?.cancel();
    _collegeSearchDebounce = Timer(const Duration(milliseconds: 350), () {
      if (!mounted) {
        return;
      }

      _currentCollegeSearch = query.trim().toLowerCase();
      _loadColleges(reset: true);
    });
  }

  void _onCollegeListScroll() {
    if (!_showCollegePanel || _isLoadingColleges || _isLoadingMoreColleges) {
      return;
    }

    if (!_collegeListController.hasClients) {
      return;
    }

    final position = _collegeListController.position;
    if (position.pixels >= position.maxScrollExtent - 80) {
      _loadColleges(reset: false);
    }
  }

  Future<int> _attemptAutoSeedIfNeeded() async {
    if (_isSeedingColleges) {
      return 0;
    }

    setState(() => _isSeedingColleges = true);
    try {
      final repository = ref.read(collegesRepositoryProvider);
      final uploaded = await repository.seedCollegesFromAsset();
      if (!mounted) {
        return uploaded;
      }

      if (uploaded > 0) {
        _showSnackBar('Uploaded $uploaded colleges to Firestore.');
      }
      return uploaded;
    } catch (_) {
      // Ignore auto-seed failures; manual upload action remains available.
      return 0;
    } finally {
      if (mounted) {
        setState(() => _isSeedingColleges = false);
      }
    }
  }

  Future<void> _seedCollegesToServer() async {
    if (_isSeedingColleges) {
      return;
    }

    setState(() => _isSeedingColleges = true);
    try {
      final repository = ref.read(collegesRepositoryProvider);
      final uploaded = await repository.seedCollegesFromAsset();
      if (!mounted) {
        return;
      }

      if (uploaded == 0) {
        _showSnackBar('No colleges were uploaded. Check source asset data.');
        return;
      }

      _showSnackBar('Uploaded $uploaded colleges to Firestore.');
      _currentCollegeSearch = _collegeSearchController.text
          .trim()
          .toLowerCase();
      await _loadColleges(reset: true);
    } catch (error) {
      _showSnackBar('Upload failed: $error');
    } finally {
      if (mounted) {
        setState(() => _isSeedingColleges = false);
      }
    }
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  AcademicOptionsModel _currentAcademicOptions() {
    return ref.read(academicOptionsProvider).valueOrNull ??
        const AcademicOptionsModel.defaults();
  }

  String? _resolveOption(
    String? selected,
    List<String> options, {
    required bool fallbackToFirst,
  }) {
    final normalized = (selected ?? '').trim().toLowerCase();
    for (final option in options) {
      if (option.toLowerCase() == normalized) {
        return option;
      }
    }

    if (!fallbackToFirst || options.isEmpty) {
      return null;
    }
    return options.first;
  }
}

class _ImagePickerTile extends StatelessWidget {
  const _ImagePickerTile({
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Ink(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Theme.of(context).dividerColor),
        ),
        child: Row(
          children: [
            Icon(
              Icons.image_outlined,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: Theme.of(context).textTheme.labelLarge),
                  const SizedBox(height: 2),
                  Text(subtitle, style: Theme.of(context).textTheme.bodySmall),
                ],
              ),
            ),
            const SizedBox(width: 8),
            TextButton(onPressed: onTap, child: const Text('Choose')),
          ],
        ),
      ),
    );
  }
}
