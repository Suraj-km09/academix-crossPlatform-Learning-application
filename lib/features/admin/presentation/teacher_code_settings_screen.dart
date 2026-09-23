import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../../auth/domain/auth_providers.dart';
import '../domain/admin_providers.dart';

class TeacherCodeSettingsScreen extends ConsumerStatefulWidget {
  const TeacherCodeSettingsScreen({super.key});

  @override
  ConsumerState<TeacherCodeSettingsScreen> createState() =>
      _TeacherCodeSettingsScreenState();
}

class _TeacherCodeSettingsScreenState
    extends ConsumerState<TeacherCodeSettingsScreen> {
  final TextEditingController _codeController = TextEditingController();
  bool _isSubmitting = false;

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  Future<void> _setCode() async {
    final code = _codeController.text.trim();
    if (code.length < 6) {
      _showSnackBar('Teacher access code must be at least 6 characters.');
      return;
    }

    setState(() => _isSubmitting = true);
    try {
      final admin = ref.read(currentUserProvider).valueOrNull;
      final adminUid = admin?.uid ?? '';
      if (adminUid.isEmpty) {
        throw const FormatException('Unable to identify current admin user.');
      }

      await ref
          .read(adminRepositoryProvider)
          .setTeacherAccessCode(adminUid: adminUid, rawCode: code);
      if (!mounted) return;
      _codeController.clear();
      _showSnackBar('Teacher access code updated successfully.');
    } catch (e) {
      if (!mounted) return;
      _showSnackBar('Failed to update teacher access code: $e');
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  Future<void> _disableCode() async {
    setState(() => _isSubmitting = true);
    try {
      final admin = ref.read(currentUserProvider).valueOrNull;
      final adminUid = admin?.uid ?? '';
      if (adminUid.isEmpty) {
        throw const FormatException('Unable to identify current admin user.');
      }

      await ref
          .read(adminRepositoryProvider)
          .disableTeacherAccessCode(adminUid: adminUid);
      if (!mounted) return;
      _showSnackBar('Teacher access code disabled.');
    } catch (e) {
      if (!mounted) return;
      _showSnackBar('Failed to disable teacher access code: $e');
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final configAsync = ref.watch(teacherCodeConfigProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Teacher Access Code')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: configAsync.when(
                data: (config) {
                  final isEnabled = config['teacherCodeEnabled'] == true;
                  final updatedBy =
                      (config['teacherCodeUpdatedBy'] ?? 'Unknown').toString();
                  final updatedAtRaw = config['teacherCodeUpdatedAt'];
                  final updatedAt = updatedAtRaw is Timestamp
                      ? updatedAtRaw.toDate()
                      : (updatedAtRaw is DateTime ? updatedAtRaw : null);

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        isEnabled
                            ? 'Teacher access code is currently enabled.'
                            : 'Teacher access code is currently disabled.',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 8),
                      Text('Last updated by: $updatedBy'),
                      if (updatedAt != null)
                        Text('Last updated at: ${updatedAt.toLocal()}'),
                    ],
                  );
                },
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, _) => Text('Failed to load current settings: $e'),
              ),
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _codeController,
            obscureText: true,
            enabled: !_isSubmitting,
            decoration: const InputDecoration(
              labelText: 'New teacher access code',
              border: OutlineInputBorder(),
              helperText:
                  'Teachers must enter this code during registration before admin approval.',
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _isSubmitting ? null : _setCode,
                  icon: const Icon(Icons.save),
                  label: Text(_isSubmitting ? 'Saving...' : 'Set Code'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _isSubmitting ? null : _disableCode,
                  icon: const Icon(Icons.block),
                  label: Text(_isSubmitting ? 'Working...' : 'Disable'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
