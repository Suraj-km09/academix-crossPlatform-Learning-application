import 'dart:async';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/app_exception.dart';
import '../../../core/utils/validators.dart';
import '../../../shared/widgets/app_back_button.dart';
import '../../../shared/widgets/app_button.dart';
import '../../../shared/widgets/app_text_field.dart';
import '../../auth/domain/auth_providers.dart';
import '../data/locker_repository.dart';
import '../domain/locker_providers.dart';

class UploadToLockerScreen extends ConsumerStatefulWidget {
  const UploadToLockerScreen({super.key});

  @override
  ConsumerState<UploadToLockerScreen> createState() =>
      _UploadToLockerScreenState();
}

class _UploadToLockerScreenState extends ConsumerState<UploadToLockerScreen> {
  final _formKey = GlobalKey<FormState>();

  final _fileNameController = TextEditingController();
  final _tagController = TextEditingController();
  final StreamController<double> _progressController =
      StreamController<double>.broadcast();

  final List<String> _tags = [];

  PlatformFile? _selectedFile;
  bool _isUploading = false;
  double _progress = 0;

  @override
  void initState() {
    super.initState();
    _progressController.stream.listen((value) {
      if (!mounted) {
        return;
      }
      setState(() => _progress = value);
    });
  }

  @override
  void dispose() {
    _fileNameController.dispose();
    _tagController.dispose();
    _progressController.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final userAsync = ref.watch(currentUserProvider);

    return userAsync.when(
      data: (user) {
        if (user == null) {
          return Scaffold(
            appBar: AppBar(
              leading: const AppBackButton(fallbackRoute: '/locker'),
              title: const Text('Upload to Locker'),
            ),
            body: const Center(child: Text('Please login to upload files.')),
          );
        }

        final totalAsync = ref.watch(lockerTotalUsedBytesProvider(user.uid));

        return Scaffold(
          appBar: AppBar(
            leading: const AppBackButton(fallbackRoute: '/locker'),
            title: const Text('Upload to Locker'),
          ),
          body: SafeArea(
            child: Form(
              key: _formKey,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  totalAsync.when(
                    data: (used) => _StorageInfoCard(used: used),
                    loading: () => const LinearProgressIndicator(),
                    error: (_, _) => const SizedBox.shrink(),
                  ),
                  const SizedBox(height: 12),
                  InkWell(
                    onTap: _isUploading ? null : _pickPdf,
                    borderRadius: BorderRadius.circular(12),
                    child: Ink(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: Theme.of(context).dividerColor,
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.picture_as_pdf_rounded,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              _selectedFile == null
                                  ? 'Pick PDF file'
                                  : _selectedFile!.name,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          TextButton(
                            onPressed: _isUploading ? null : _pickPdf,
                            child: const Text('Choose'),
                          ),
                        ],
                      ),
                    ),
                  ),
                  if (_selectedFile != null) ...[
                    const SizedBox(height: 6),
                    Text(
                      'Size: ${_formatBytes(_selectedFile!.size)}',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                  const SizedBox(height: 12),
                  AppTextField(
                    controller: _fileNameController,
                    label: 'File Name',
                    hint: 'e.g., DBMS Unit 1 Notes',
                    validator: (value) =>
                        Validators.requiredField(value, field: 'File name'),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: AppTextField(
                          controller: _tagController,
                          label: 'Add Tag',
                          hint: 'e.g., semester-5',
                          onChanged: (_) => setState(() {}),
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton(
                        tooltip: 'Add tag',
                        onPressed: _isUploading ? null : _addTag,
                        icon: const Icon(Icons.add_circle_outline_rounded),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: _tags
                        .map(
                          (tag) => Chip(
                            label: Text(tag),
                            onDeleted: _isUploading
                                ? null
                                : () {
                                    setState(() => _tags.remove(tag));
                                  },
                          ),
                        )
                        .toList(),
                  ),
                  if (_isUploading) ...[
                    const SizedBox(height: 14),
                    LinearProgressIndicator(value: _progress),
                    const SizedBox(height: 5),
                    Text(
                      'Uploading ${(100 * _progress).toStringAsFixed(0)}%',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                  const SizedBox(height: 20),
                  AppButton(
                    label: _isUploading ? 'Uploading...' : 'Upload PDF',
                    isLoading: _isUploading,
                    onPressed: _isUploading ? null : () => _upload(user.uid),
                  ),
                ],
              ),
            ),
          ),
        );
      },
      loading: () =>
          const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (error, _) => Scaffold(
        appBar: AppBar(title: const Text('Upload to Locker')),
        body: Center(child: Text('Unable to load user: $error')),
      ),
    );
  }

  Future<void> _pickPdf() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowMultiple: false,
      withData: false,
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

    if (file.size > LockerRepository.maxSingleFileBytes) {
      _showSnackBar('File exceeds 15 MB size limit');
      return;
    }

    setState(() {
      _selectedFile = file;
      if (_fileNameController.text.trim().isEmpty) {
        _fileNameController.text = file.name.replaceAll(
          RegExp(r'\.pdf$', caseSensitive: false),
          '',
        );
      }
    });
  }

  Future<void> _upload(String uid) async {
    final formOk = _formKey.currentState?.validate() ?? false;
    if (!formOk) {
      return;
    }

    if (_selectedFile == null) {
      _showSnackBar('Please select a PDF file');
      return;
    }

    final usedBytes = await ref
        .read(lockerRepositoryProvider)
        .getTotalUsedBytes(uid);
    final remaining = LockerRepository.maxUserStorageBytes - usedBytes;

    if (_selectedFile!.size > remaining) {
      _showSnackBar('Not enough locker space for this file');
      return;
    }

    setState(() {
      _isUploading = true;
      _progress = 0;
    });

    try {
      await ref
          .read(lockerRepositoryProvider)
          .uploadFile(
            uid,
            _selectedFile!,
            _fileNameController.text.trim(),
            _tags,
            onProgress: (value) => _progressController.add(value),
          );

      ref.invalidate(lockerFilesProvider(uid));
      ref.invalidate(lockerTotalUsedBytesProvider(uid));

      if (!mounted) {
        return;
      }

      _showSnackBar('File uploaded successfully');
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

  void _addTag() {
    final value = _tagController.text.trim();
    if (value.isEmpty) {
      return;
    }

    if (_tags.any((tag) => tag.toLowerCase() == value.toLowerCase())) {
      _tagController.clear();
      return;
    }

    setState(() {
      _tags.add(value);
      _tagController.clear();
    });
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
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

class _StorageInfoCard extends StatelessWidget {
  const _StorageInfoCard({required this.used});

  final int used;

  @override
  Widget build(BuildContext context) {
    final max = LockerRepository.maxUserStorageBytes;
    final left = (max - used).clamp(0, max);
    final progress = (used / max).clamp(0.0, 1.0);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.10),
        border: Border.all(
          color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.22),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Available Space',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 6),
          Text(
            '${_formatBytes(left)} remaining of ${_formatBytes(max)}',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 8),
          LinearProgressIndicator(value: progress),
          const SizedBox(height: 4),
          Text(
            'Max file size: 15 MB • PDFs only',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
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
