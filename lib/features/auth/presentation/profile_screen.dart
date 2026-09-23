import 'dart:typed_data';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../profile/domain/profile_providers.dart';
import '../../../shared/services/storage_image_cache_service.dart';
import '../../../shared/widgets/app_back_button.dart';
import '../../../shared/widgets/loading_widget.dart';
import '../domain/auth_providers.dart';

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _bioController = TextEditingController();
  final _companyController = TextEditingController();
  final _roleController = TextEditingController();
  final _linkedinController = TextEditingController();
  final _skillsController = TextEditingController();

  bool _initialized = false;
  bool _isSaving = false;
  bool _isUploadingPhoto = false;
  bool _openToRefer = false;

  String? _photoPathOrUrl;

  @override
  void dispose() {
    _nameController.dispose();
    _bioController.dispose();
    _companyController.dispose();
    _roleController.dispose();
    _linkedinController.dispose();
    _skillsController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final profileAsync = ref.watch(currentUserProvider);

    return profileAsync.when(
      data: (user) {
        if (user == null) {
          return Scaffold(
            appBar: AppBar(
              leading: const AppBackButton(fallbackRoute: '/home'),
              title: const Text('Profile'),
            ),
            body: const Center(child: Text('Please login to view profile.')),
          );
        }

        if (!_initialized) {
          _nameController.text = user.name;
          _bioController.text = user.customBio ?? '';
          _companyController.text = user.currentCompany ?? '';
          _roleController.text = user.currentRole ?? '';
          _linkedinController.text = user.linkedinUrl ?? '';
          _skillsController.text = user.skills.join(', ');
          _openToRefer = user.openToRefer;
          _photoPathOrUrl = user.photoUrl;
          _initialized = true;
        }

        return Scaffold(
          appBar: AppBar(
            leading: const AppBackButton(fallbackRoute: '/home'),
            title: const Text('Profile'),
            actions: [
              TextButton(
                onPressed: _isSaving ? null : () => _saveProfile(user.uid),
                child: Text(_isSaving ? 'Saving...' : 'Save'),
              ),
            ],
          ),
          body: Form(
            key: _formKey,
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _ProfileImageSection(
                  name: user.name,
                  pathOrUrl: _photoPathOrUrl,
                  isUploading: _isUploadingPhoto,
                  onChangeTap: () => _pickProfileImage(user.uid),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _nameController,
                  textCapitalization: TextCapitalization.words,
                  decoration: const InputDecoration(
                    labelText: 'Full Name',
                    prefixIcon: Icon(Icons.person_outline_rounded),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Name is required';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 10),
                TextFormField(
                  initialValue: user.email,
                  readOnly: true,
                  decoration: const InputDecoration(
                    labelText: 'Email',
                    prefixIcon: Icon(Icons.mail_outline_rounded),
                  ),
                ),
                const SizedBox(height: 10),
                TextFormField(
                  initialValue: user.role,
                  readOnly: true,
                  decoration: const InputDecoration(
                    labelText: 'Role',
                    prefixIcon: Icon(Icons.badge_outlined),
                  ),
                ),
                const SizedBox(height: 10),
                TextFormField(
                  initialValue: user.collegeName.isNotEmpty
                      ? user.collegeName
                      : user.collegeId,
                  readOnly: true,
                  decoration: const InputDecoration(
                    labelText: 'College',
                    prefixIcon: Icon(Icons.school_outlined),
                  ),
                ),
                const SizedBox(height: 10),
                TextFormField(
                  controller: _bioController,
                  minLines: 2,
                  maxLines: 4,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: const InputDecoration(
                    labelText: 'Bio',
                    hintText: 'Tell others about yourself',
                    prefixIcon: Icon(Icons.edit_note_outlined),
                  ),
                ),
                const SizedBox(height: 10),
                TextFormField(
                  controller: _companyController,
                  textCapitalization: TextCapitalization.words,
                  decoration: const InputDecoration(
                    labelText: 'Current Company',
                    prefixIcon: Icon(Icons.business_center_outlined),
                  ),
                ),
                const SizedBox(height: 10),
                TextFormField(
                  controller: _roleController,
                  textCapitalization: TextCapitalization.words,
                  decoration: const InputDecoration(
                    labelText: 'Current Role',
                    prefixIcon: Icon(Icons.work_outline_rounded),
                  ),
                ),
                const SizedBox(height: 10),
                TextFormField(
                  controller: _linkedinController,
                  keyboardType: TextInputType.url,
                  decoration: const InputDecoration(
                    labelText: 'LinkedIn URL',
                    hintText: 'https://linkedin.com/in/your-handle',
                    prefixIcon: Icon(Icons.link_rounded),
                  ),
                ),
                const SizedBox(height: 10),
                TextFormField(
                  controller: _skillsController,
                  decoration: const InputDecoration(
                    labelText: 'Skills',
                    hintText: 'Comma separated, e.g. Flutter, Firebase, DSA',
                    prefixIcon: Icon(Icons.psychology_alt_outlined),
                  ),
                ),
                const SizedBox(height: 10),
                SwitchListTile.adaptive(
                  value: _openToRefer,
                  onChanged: user.role == 'alumni'
                      ? (value) => setState(() => _openToRefer = value)
                      : null,
                  title: const Text('Open To Refer'),
                  subtitle: Text(
                    user.role == 'alumni'
                        ? 'Let students know you are open to referrals.'
                        : 'Only alumni can use referral availability.',
                  ),
                  contentPadding: EdgeInsets.zero,
                ),
                const SizedBox(height: 8),
                FilledButton.icon(
                  onPressed: _isSaving ? null : () => _saveProfile(user.uid),
                  icon: _isSaving
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.save_outlined),
                  label: Text(_isSaving ? 'Saving Profile...' : 'Save Changes'),
                ),
              ],
            ),
          ),
        );
      },
      loading: () =>
          const Scaffold(body: LoadingWidget(message: 'Loading profile...')),
      error: (error, _) => Scaffold(
        appBar: AppBar(
          leading: const AppBackButton(fallbackRoute: '/home'),
          title: const Text('Profile'),
        ),
        body: Center(child: Text('Unable to load profile: $error')),
      ),
    );
  }

  Future<void> _pickProfileImage(String uid) async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('Choose from gallery'),
              onTap: () => Navigator.of(context).pop(ImageSource.gallery),
            ),
            ListTile(
              leading: const Icon(Icons.photo_camera_outlined),
              title: const Text('Take a photo'),
              onTap: () => Navigator.of(context).pop(ImageSource.camera),
            ),
          ],
        ),
      ),
    );

    if (source == null) {
      return;
    }

    try {
      setState(() => _isUploadingPhoto = true);

      final picker = ImagePicker();
      final file = await picker.pickImage(
        source: source,
        imageQuality: 82,
        maxWidth: 1080,
      );

      if (file == null) {
        return;
      }

      final bytes = await file.readAsBytes();
      await _uploadPhoto(uid, bytes, _fileExtensionFromPath(file.path));
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to upload image: $error')));
    } finally {
      if (mounted) {
        setState(() => _isUploadingPhoto = false);
      }
    }
  }

  Future<void> _uploadPhoto(
    String uid,
    Uint8List bytes,
    String extension,
  ) async {
    final repository = ref.read(profileRepositoryProvider);
    final storagePath = await repository.uploadUserImageBytes(
      uid: uid,
      bytes: bytes,
      folder: 'profile',
      extension: extension,
    );

    await repository.updateProfile(
      uid: uid,
      updates: {'photoUrl': storagePath, 'photoStoragePath': storagePath},
    );

    setState(() => _photoPathOrUrl = storagePath);
    ref.invalidate(currentUserProvider);
  }

  Future<void> _saveProfile(String uid) async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() => _isSaving = true);

    try {
      final updates = <String, dynamic>{
        'name': _nameController.text.trim(),
        'customBio': _nullable(_bioController.text),
        'currentCompany': _nullable(_companyController.text),
        'currentRole': _nullable(_roleController.text),
        'linkedinUrl': _nullable(_linkedinController.text),
        'skills': _parseSkills(_skillsController.text),
        'openToRefer': _openToRefer,
      };

      await ref
          .read(profileRepositoryProvider)
          .updateProfile(uid: uid, updates: updates);

      ref.invalidate(currentUserProvider);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Profile updated successfully.')),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to update profile: $error')),
      );
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  String? _nullable(String value) {
    final trimmed = value.trim();
    return trimmed.isEmpty ? null : trimmed;
  }

  List<String> _parseSkills(String value) {
    return value
        .split(',')
        .map((item) => item.trim())
        .where((item) => item.isNotEmpty)
        .toSet()
        .toList();
  }

  String _fileExtensionFromPath(String path) {
    final split = path.split('.');
    if (split.length < 2) {
      return 'jpg';
    }
    return split.last.toLowerCase();
  }
}

class _ProfileImageSection extends StatelessWidget {
  const _ProfileImageSection({
    required this.name,
    required this.pathOrUrl,
    required this.isUploading,
    required this.onChangeTap,
  });

  final String name;
  final String? pathOrUrl;
  final bool isUploading;
  final VoidCallback onChangeTap;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        children: [
          FutureBuilder<String?>(
            future: _resolveImage(pathOrUrl),
            builder: (context, snapshot) {
              final url = snapshot.data;
              return CircleAvatar(
                radius: 46,
                backgroundColor: Theme.of(
                  context,
                ).colorScheme.surfaceContainerHighest,
                backgroundImage: (url != null && url.isNotEmpty)
                    ? CachedNetworkImageProvider(url)
                    : null,
                child: (url == null || url.isEmpty)
                    ? Text(
                        _initials(name),
                        style: Theme.of(context).textTheme.titleLarge,
                      )
                    : null,
              );
            },
          ),
          const SizedBox(height: 10),
          FilledButton.tonalIcon(
            onPressed: isUploading ? null : onChangeTap,
            icon: isUploading
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.photo_camera_outlined),
            label: Text(isUploading ? 'Uploading...' : 'Change Photo'),
          ),
        ],
      ),
    );
  }

  Future<String?> _resolveImage(String? pathOrUrl) async {
    if (pathOrUrl == null || pathOrUrl.trim().isEmpty) {
      return null;
    }
    return StorageImageCacheService.resolveDownloadUrl(pathOrUrl);
  }

  String _initials(String fullName) {
    final words = fullName
        .trim()
        .split(RegExp(r'\s+'))
        .where((word) => word.isNotEmpty)
        .toList();
    if (words.isEmpty) {
      return 'U';
    }
    if (words.length == 1) {
      return words.first.substring(0, 1).toUpperCase();
    }
    return '${words.first.substring(0, 1)}${words.last.substring(0, 1)}'
        .toUpperCase();
  }
}
