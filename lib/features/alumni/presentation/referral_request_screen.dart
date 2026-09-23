import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../features/auth/domain/auth_providers.dart';
import '../../../shared/models/user_model.dart';
import '../../../shared/widgets/app_back_button.dart';
import '../../../shared/widgets/app_button.dart';
import '../../../shared/widgets/app_text_field.dart';
import '../../../shared/widgets/empty_state.dart';
import '../../../shared/widgets/loading_widget.dart';
import '../domain/alumni_providers.dart';

class ReferralRequestScreen extends ConsumerStatefulWidget {
  const ReferralRequestScreen({super.key, required this.alumniUid});

  final String alumniUid;

  @override
  ConsumerState<ReferralRequestScreen> createState() =>
      _ReferralRequestScreenState();
}

class _ReferralRequestScreenState extends ConsumerState<ReferralRequestScreen> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _companyController = TextEditingController();
  final TextEditingController _roleController = TextEditingController();
  final TextEditingController _messageController = TextEditingController();

  PlatformFile? _resumeFile;
  bool _submitting = false;
  double _progress = 0;

  @override
  void dispose() {
    _companyController.dispose();
    _roleController.dispose();
    _messageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final currentUserAsync = ref.watch(currentUserProvider);

    return currentUserAsync.when(
      data: (student) {
        if (student == null) {
          return const Scaffold(
            body: EmptyState(
              title: 'Login required',
              subtitle: 'Please login to send referral requests.',
            ),
          );
        }

        final repository = ref.watch(alumniRepositoryProvider);
        return FutureBuilder<UserModel?>(
          future: repository.getUserById(widget.alumniUid),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Scaffold(
                body: LoadingWidget(message: 'Loading alumni info...'),
              );
            }

            final alumni = snapshot.data;
            if (alumni == null) {
              return Scaffold(
                appBar: AppBar(
                  leading: const AppBackButton(fallbackRoute: '/alumni'),
                  title: const Text('Request Referral'),
                ),
                body: const EmptyState(
                  title: 'Alumni unavailable',
                  subtitle: 'Try again later.',
                ),
              );
            }

            return Scaffold(
              appBar: AppBar(
                leading: const AppBackButton(fallbackRoute: '/alumni'),
                title: const Text('Request Referral'),
              ),
              body: SafeArea(
                child: Form(
                  key: _formKey,
                  child: ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      Text(
                        'Sending request to ${alumni.name}',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 12),
                      AppTextField(
                        controller: _companyController,
                        label: 'Target Company',
                        hint: 'e.g., Google',
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Target company is required';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 12),
                      AppTextField(
                        controller: _roleController,
                        label: 'Target Role',
                        hint: 'e.g., SDE Intern',
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Target role is required';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 12),
                      AppTextField(
                        controller: _messageController,
                        label: 'Personal Message',
                        hint: 'Write why you need referral',
                        maxLines: 4,
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Message is required';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 12),
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('Resume (PDF)'),
                        subtitle: Text(
                          _resumeFile == null
                              ? 'Select resume file'
                              : _resumeFile!.name,
                        ),
                        trailing: TextButton(
                          onPressed: _submitting ? null : _pickResume,
                          child: Text(
                            _resumeFile == null ? 'Choose' : 'Change',
                          ),
                        ),
                      ),
                      if (_submitting) ...[
                        const SizedBox(height: 8),
                        LinearProgressIndicator(value: _progress),
                        const SizedBox(height: 4),
                        Text(
                          'Upload ${(100 * _progress).toStringAsFixed(0)}%',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                      const SizedBox(height: 16),
                      AppButton(
                        label: 'Submit Request',
                        isLoading: _submitting,
                        onPressed: _submitting
                            ? null
                            : () => _submitReferral(student, alumni),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
      loading: () =>
          const Scaffold(body: LoadingWidget(message: 'Loading profile...')),
      error: (error, stackTrace) => Scaffold(
        body: EmptyState(title: 'Unable to load profile', subtitle: '$error'),
      ),
    );
  }

  Future<void> _pickResume() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['pdf'],
      allowMultiple: false,
      withData: true,
    );

    if (result == null || result.files.isEmpty) {
      return;
    }

    setState(() => _resumeFile = result.files.first);
  }

  Future<void> _submitReferral(UserModel student, UserModel alumni) async {
    final valid = _formKey.currentState?.validate() ?? false;
    if (!valid) {
      return;
    }

    if (_resumeFile == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Please upload resume PDF')));
      return;
    }

    setState(() {
      _submitting = true;
      _progress = 0;
    });

    try {
      final repository = ref.read(alumniRepositoryProvider);
      await repository.sendReferralRequest(
        student.uid,
        alumni.uid,
        _companyController.text.trim(),
        _roleController.text.trim(),
        _messageController.text.trim(),
        _resumeFile!,
        onProgress: (value) {
          if (!mounted) {
            return;
          }
          setState(() => _progress = value);
        },
      );

      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Referral request sent successfully.')),
      );
      Navigator.of(context).pop();
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to send request: $error')));
    } finally {
      if (mounted) {
        setState(() => _submitting = false);
      }
    }
  }
}
