import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/errors/app_exception.dart';
import '../../../core/utils/validators.dart';
import '../../../features/auth/domain/auth_providers.dart';
import '../../../shared/domain/academic_options_providers.dart';
import '../../../shared/models/academic_options_model.dart';
import '../../../shared/models/user_model.dart';
import '../../../shared/widgets/app_back_button.dart';
import '../../../shared/widgets/app_button.dart';
import '../../../shared/widgets/app_text_field.dart';
import '../domain/profile_providers.dart';

class EditProfileScreen extends ConsumerWidget {
  const EditProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userAsync = ref.watch(currentUserProvider);

    return userAsync.when(
      data: (user) {
        if (user == null) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (context.mounted) {
              context.go('/login');
            }
          });
          return const Scaffold(body: SizedBox.shrink());
        }

        return _EditProfileForm(user: user);
      },
      loading: () =>
          const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (error, stackTrace) => Scaffold(
        appBar: AppBar(
          leading: const AppBackButton(fallbackRoute: '/profile'),
          title: const Text('Edit Profile'),
        ),
        body: Center(child: Text('Unable to load profile: $error')),
      ),
    );
  }
}

class _EditProfileForm extends ConsumerStatefulWidget {
  const _EditProfileForm({required this.user});

  final UserModel user;

  @override
  ConsumerState<_EditProfileForm> createState() => _EditProfileFormState();
}

class _EditProfileFormState extends ConsumerState<_EditProfileForm> {
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _universityController;
  late final TextEditingController _batchYearController;
  late final TextEditingController _companyController;
  late final TextEditingController _jobRoleController;
  late final TextEditingController _bioController;
  late final List<TextEditingController> _socialNameControllers;
  late final List<TextEditingController> _socialUrlControllers;
  late final TextEditingController _githubController;
  late final TextEditingController _leetcodeController;
  late final TextEditingController _gfgController;

  String? _selectedCourse;
  String? _selectedBranch;
  int? _selectedSemester;
  bool _isSaving = false;

  PlatformFile? _profileImage;
  PlatformFile? _idCardImage;

  @override
  void initState() {
    super.initState();
    final user = widget.user;

    _universityController = TextEditingController(
      text: user.affiliatedUniversityName,
    );
    _selectedCourse = user.course.isNotEmpty ? user.course : null;
    _selectedBranch = user.branch.isNotEmpty ? user.branch : null;
    _batchYearController = TextEditingController(
      text: user.batchYear?.toString() ?? '',
    );
    _companyController = TextEditingController(text: user.currentCompany ?? '');
    _jobRoleController = TextEditingController(text: user.currentRole ?? '');
    _bioController = TextEditingController(text: user.customBio ?? '');
    _selectedSemester = user.semester;

    final entries = user.profileLinks.entries.toList()
      ..sort((a, b) => a.key.compareTo(b.key));

    _socialNameControllers = List.generate(
      5,
      (index) => TextEditingController(
        text: index < entries.length
            ? _displaySocialName(entries[index].key)
            : '',
      ),
    );
    _socialUrlControllers = List.generate(
      5,
      (index) => TextEditingController(
        text: index < entries.length ? entries[index].value : '',
      ),
    );
    _githubController = TextEditingController(
      text: user.profileLinks['github'] ?? user.profileLinks['GitHub'] ?? '',
    );
    _leetcodeController = TextEditingController(
      text:
          user.profileLinks['leetcode'] ?? user.profileLinks['LeetCode'] ?? '',
    );
    _gfgController = TextEditingController(
      text:
          user.profileLinks['geeksforgeeks'] ?? user.profileLinks['gfg'] ?? '',
    );
  }

  @override
  void dispose() {
    _universityController.dispose();
    _batchYearController.dispose();
    _companyController.dispose();
    _jobRoleController.dispose();
    _bioController.dispose();
    for (final controller in _socialNameControllers) {
      controller.dispose();
    }
    for (final controller in _socialUrlControllers) {
      controller.dispose();
    }
    _githubController.dispose();
    _leetcodeController.dispose();
    _gfgController.dispose();
    super.dispose();
  }

  String? _validateUrl(String? value) {
    final input = (value ?? '')
        .replaceAll(RegExp(r'[\u200B\u200C\u200D\uFEFF\u00A0]'), '')
        .trim();
    if (input.isEmpty) return null;
    final uri = Uri.tryParse(input);
    if (uri == null ||
        !uri.hasScheme ||
        !uri.hasAuthority ||
        (uri.scheme != 'http' && uri.scheme != 'https')) {
      return 'Enter a valid URL (http/https)';
    }
    return null;
  }

  String _cleanUrl(String value) {
    return value
        .replaceAll(RegExp(r'[\u200B\u200C\u200D\uFEFF\u00A0]'), '')
        .trim();
  }

  @override
  Widget build(BuildContext context) {
    final user = widget.user;
    final role = user.role.toLowerCase();
    final isStudentOrTeacher = role == 'student' || role == 'teacher';
    final isAlumni = role == 'alumni';

    final academicOptions = ref.watch(academicOptionsProvider).valueOrNull ??
        const AcademicOptionsModel.defaults();

    return Scaffold(
      appBar: AppBar(
        leading: const AppBackButton(fallbackRoute: '/profile'),
        title: const Text('Edit Profile'),
      ),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _ReadOnlyCard(user: user),
              const SizedBox(height: 12),
              _UploadTile(
                title: 'Profile Picture',
                subtitle:
                    _profileImage?.name ?? _displayExisting(user.photoUrl),
                buttonLabel: _profileImage == null ? 'Choose' : 'Replace',
                onTap: _pickProfileImage,
              ),
              const SizedBox(height: 10),
              _UploadTile(
                title: 'ID Card Picture',
                subtitle:
                    _idCardImage?.name ??
                    _displayExisting(user.collegeIdCardPhotoUrl),
                buttonLabel: _idCardImage == null ? 'Choose' : 'Replace',
                onTap: _pickIdCardImage,
              ),
              const SizedBox(height: 12),
              AppTextField(
                controller: _universityController,
                label: 'University',
                hint: 'Enter university name',
              ),
              const SizedBox(height: 12),
              if (isStudentOrTeacher) ...[
                DropdownButtonFormField<String>(
                  isExpanded: true,
                  value: academicOptions.courses.contains(_selectedCourse) ? _selectedCourse : null,
                  decoration: const InputDecoration(labelText: 'Course'),
                  items: academicOptions.courses
                      .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                      .toList(),
                  onChanged: (val) => setState(() => _selectedCourse = val),
                  validator: (value) =>
                      value == null ? 'Please select course' : null,
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  isExpanded: true,
                  value: academicOptions.branches.contains(_selectedBranch) ? _selectedBranch : null,
                  decoration: const InputDecoration(labelText: 'Branch'),
                  items: academicOptions.branches
                      .map((b) => DropdownMenuItem(value: b, child: Text(b)))
                      .toList(),
                  onChanged: (val) => setState(() => _selectedBranch = val),
                  validator: (value) =>
                      value == null ? 'Please select branch' : null,
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<int>(
                  isExpanded: true,
                  value: (_selectedSemester != null && _selectedSemester! >= 1 && _selectedSemester! <= 8) ? _selectedSemester : null,
                  decoration: const InputDecoration(labelText: 'Semester'),
                  items: List.generate(
                    8,
                    (index) => DropdownMenuItem<int>(
                      value: index + 1,
                      child: Text('${index + 1}'),
                    ),
                  ),
                  onChanged: (value) =>
                      setState(() => _selectedSemester = value),
                  validator: (value) =>
                      value == null ? 'Please select semester' : null,
                ),
                const SizedBox(height: 12),
              ],
              if (isAlumni) ...[
                AppTextField(
                  controller: _batchYearController,
                  label: 'Batch Year',
                  hint: 'e.g., 2020',
                  keyboardType: TextInputType.number,
                  validator: (value) {
                    if (!isAlumni) return null;
                    final input = value?.trim() ?? '';
                    if (input.isEmpty) return 'Batch year is required';
                    final year = int.tryParse(input);
                    return year == null ? 'Enter a valid batch year' : null;
                  },
                ),
                const SizedBox(height: 12),
                AppTextField(
                  controller: _companyController,
                  label: 'Current Company',
                  hint: 'e.g., Microsoft',
                  validator: (value) {
                    if (!isAlumni) return null;
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
                    if (!isAlumni) return null;
                    return Validators.requiredField(
                      value,
                      field: 'Current job role',
                    );
                  },
                ),
                const SizedBox(height: 12),
              ],
              AppTextField(
                controller: _bioController,
                label: 'Bio',
                hint: 'Write short bio',
                maxLines: 4,
              ),
              const SizedBox(height: 12),
              AppTextField(
                controller: _githubController,
                label: 'GitHub URL',
                hint: 'https://github.com/your-handle',
                keyboardType: TextInputType.url,
                validator: _validateUrl,
              ),
              const SizedBox(height: 12),
              AppTextField(
                controller: _leetcodeController,
                label: 'LeetCode URL',
                hint: 'https://leetcode.com/your-handle',
                keyboardType: TextInputType.url,
                validator: _validateUrl,
              ),
              const SizedBox(height: 12),
              AppTextField(
                controller: _gfgController,
                label: 'GeeksforGeeks URL',
                hint: 'https://auth.geeksforgeeks.org/user/your-handle',
                keyboardType: TextInputType.url,
                validator: _validateUrl,
              ),
              const SizedBox(height: 12),
              Text(
                'Social Links (name + URL, up to 5)',
                style: Theme.of(context).textTheme.titleSmall,
              ),
              const SizedBox(height: 8),
              for (
                var index = 0;
                index < _socialUrlControllers.length;
                index++
              ) ...[
                AppTextField(
                  controller: _socialNameControllers[index],
                  label: 'Link Name ${index + 1}',
                  hint: 'e.g., LinkedIn, GitHub, Portfolio',
                  textInputAction: TextInputAction.next,
                  enableInteractiveSelection: true,
                  validator: (value) {
                    final name = value?.trim() ?? '';
                    final url = _socialUrlControllers[index].text.trim();
                    if (name.isEmpty && url.isEmpty) return null;
                    if (name.isEmpty) return 'Add link name';
                    return null;
                  },
                ),
                const SizedBox(height: 8),
                AppTextField(
                  controller: _socialUrlControllers[index],
                  label: 'Link URL ${index + 1}',
                  hint: 'https://...',
                  keyboardType: TextInputType.url,
                  textInputAction: TextInputAction.next,
                  enableInteractiveSelection: true,
                  validator: (value) {
                    final input = _cleanUrl(value ?? '');
                    final name = _socialNameControllers[index].text.trim();
                    if (input.isEmpty && name.isEmpty) return null;
                    if (input.isEmpty) return 'Add link URL';
                    return _validateUrl(input);
                  },
                ),
                const SizedBox(height: 10),
              ],
              AppButton(
                label: 'Save Profile',
                isLoading: _isSaving,
                onPressed: _isSaving ? null : _saveProfile,
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _displayExisting(String? value) {
    if (value == null || value.trim().isEmpty) return 'No file uploaded';
    return 'Existing file uploaded';
  }

  Future<void> _pickProfileImage() async {
    final file = await _pickImage();
    if (file == null) return;
    setState(() => _profileImage = file);
  }

  Future<void> _pickIdCardImage() async {
    final file = await _pickImage();
    if (file == null) return;
    setState(() => _idCardImage = file);
  }

  Future<PlatformFile?> _pickImage() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.image,
      allowMultiple: false,
      withData: true,
    );
    if (result == null || result.files.isEmpty) return null;
    return result.files.first;
  }

  Future<void> _saveProfile() async {
    final valid = _formKey.currentState?.validate() ?? false;
    if (!valid) return;

    setState(() => _isSaving = true);

    try {
      final user = widget.user;
      final role = user.role.toLowerCase();
      final isStudentOrTeacher = role == 'student' || role == 'teacher';
      final isAlumni = role == 'alumni';

      final repository = ref.read(profileRepositoryProvider);
      final updates = <String, dynamic>{
        'affiliatedUniversityName': _universityController.text.trim(),
        'customBio': _bioController.text.trim().isEmpty
            ? null
            : _bioController.text.trim(),
      };

      if (isStudentOrTeacher) {
        updates['course'] = _selectedCourse;
        updates['branch'] = _selectedBranch;
        updates['semester'] = _selectedSemester;
        updates['batchYear'] = null;
        updates['currentCompany'] = null;
        updates['currentRole'] = null;
      }

      if (isAlumni) {
        updates['batchYear'] = int.tryParse(_batchYearController.text.trim());
        updates['currentCompany'] = _companyController.text.trim();
        updates['currentRole'] = _jobRoleController.text.trim();
        updates['course'] = '';
        updates['branch'] = '';
        updates['semester'] = null;
      }

      final socialLinks = <String, String>{};

      final github = _cleanUrl(_githubController.text);
      final leetcode = _cleanUrl(_leetcodeController.text);
      final gfg = _cleanUrl(_gfgController.text);

      if (github.isNotEmpty) socialLinks['github'] = github;
      if (leetcode.isNotEmpty) socialLinks['leetcode'] = leetcode;
      if (gfg.isNotEmpty) socialLinks['geeksforgeeks'] = gfg;

      for (var i = 0; i < _socialUrlControllers.length; i++) {
        final name = _socialNameControllers[i].text.trim();
        final url = _cleanUrl(_socialUrlControllers[i].text);
        if (name.isEmpty || url.isEmpty) continue;

        final key = name.toLowerCase();
        if (key == 'github' || key == 'github.com' || key.contains('github')) {
          if (!socialLinks.containsKey('github')) {
            socialLinks['github'] = url;
          }
          continue;
        }
        if (key == 'leetcode' || key.contains('leetcode')) {
          if (!socialLinks.containsKey('leetcode')) {
            socialLinks['leetcode'] = url;
          }
          continue;
        }
        if (key == 'geeksforgeeks' || key == 'gfg' || key.contains('geeks')) {
          if (!socialLinks.containsKey('geeksforgeeks')) {
            socialLinks['geeksforgeeks'] = url;
          }
          continue;
        }

        socialLinks[name] = url;
      }

      updates['profileLinks'] = socialLinks;

      if (_profileImage != null) {
        final path = await repository.uploadUserImage(
          uid: user.uid,
          file: _profileImage!,
          folder: 'profile',
        );
        updates['photoUrl'] = path;
        updates['photoStoragePath'] = path;
      }

      if (_idCardImage != null) {
        final path = await repository.uploadUserImage(
          uid: user.uid,
          file: _idCardImage!,
          folder: 'id_card',
        );
        updates['collegeIdCardPhotoUrl'] = path;
        updates['collegeIdCardStoragePath'] = path;
      }

      await repository.updateProfile(uid: user.uid, updates: updates);
      ref.invalidate(currentUserProvider);

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Profile updated successfully.')),
      );
      context.pop();
    } on AppException catch (error) {
      _showSnackBar(error.message);
    } catch (error) {
      _showSnackBar('Failed to update profile: $error');
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  String _displaySocialName(String rawKey) {
    final normalized = rawKey.trim();
    if (normalized.toLowerCase().startsWith('link_')) {
      final suffix = normalized.substring(5);
      return 'Link $suffix';
    }
    return normalized;
  }
}

class _ReadOnlyCard extends StatelessWidget {
  const _ReadOnlyCard({required this.user});

  final UserModel user;

  @override
  Widget build(BuildContext context) {
    final textStyle = Theme.of(context).textTheme.bodyMedium;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Non-Editable Information',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 10),
            _line('Name', user.name, textStyle),
            _line('Email', user.email, textStyle),
            _line('Role', user.role.toUpperCase(), textStyle),
            _line(
              'College',
              user.collegeName.isEmpty ? user.collegeId : user.collegeName,
              textStyle,
            ),
          ],
        ),
      ),
    );
  }

  Widget _line(String label, String value, TextStyle? style) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: RichText(
        text: TextSpan(
          style: style,
          children: [
            TextSpan(
              text: '$label: ',
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            TextSpan(text: value.trim().isEmpty ? '-' : value.trim()),
          ],
        ),
      ),
    );
  }
}

class _UploadTile extends StatelessWidget {
  const _UploadTile({
    required this.title,
    required this.subtitle,
    required this.buttonLabel,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final String buttonLabel;
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
            TextButton(onPressed: onTap, child: Text(buttonLabel)),
          ],
        ),
      ),
    );
  }
}
