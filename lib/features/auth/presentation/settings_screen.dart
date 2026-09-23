import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../../../core/constants/firestore_paths.dart';
import '../../../features/chat/domain/chat_providers.dart';
import '../../../shared/models/user_model.dart';
import '../../../shared/services/theme_mode_service.dart';
import '../../../shared/widgets/app_back_button.dart';
import '../../../shared/widgets/loading_widget.dart';
import '../domain/auth_providers.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  String _versionLabel = 'Loading...';
  bool _loggingOut = false;
  bool _submittingBug = false;
  bool _openingAdminChat = false;

  @override
  void initState() {
    super.initState();
    _loadVersion();
  }

  @override
  Widget build(BuildContext context) {
    final profileAsync = ref.watch(currentUserProvider);
    final themeMode = ref.watch(themeModeProvider);

    return profileAsync.when(
      data: (user) {
        if (user == null) {
          return Scaffold(
            appBar: AppBar(
              leading: const AppBackButton(fallbackRoute: '/home'),
              title: const Text('Settings'),
            ),
            body: const Center(child: Text('Please login to access settings.')),
          );
        }

        return Scaffold(
          appBar: AppBar(
            leading: const AppBackButton(fallbackRoute: '/home'),
            title: const Text('Settings'),
          ),
          body: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text(
                'Appearance',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Theme Mode'),
                      const SizedBox(height: 10),
                      SegmentedButton<ThemeMode>(
                        segments: const [
                          ButtonSegment<ThemeMode>(
                            value: ThemeMode.system,
                            label: Text('System'),
                            icon: Icon(Icons.settings_suggest_outlined),
                          ),
                          ButtonSegment<ThemeMode>(
                            value: ThemeMode.light,
                            label: Text('Light'),
                            icon: Icon(Icons.light_mode_outlined),
                          ),
                          ButtonSegment<ThemeMode>(
                            value: ThemeMode.dark,
                            label: Text('Dark'),
                            icon: Icon(Icons.dark_mode_outlined),
                          ),
                        ],
                        selected: {themeMode},
                        onSelectionChanged: (selection) {
                          final selectedMode = selection.first;
                          ref
                              .read(themeModeProvider.notifier)
                              .setThemeMode(selectedMode);
                        },
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text('Account', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              Card(
                child: Column(
                  children: [
                    ListTile(
                      leading: const Icon(Icons.person_outline_rounded),
                      title: const Text('Profile'),
                      subtitle: const Text('Update your personal details'),
                      trailing: const Icon(Icons.chevron_right_rounded),
                      onTap: () => context.push('/profile'),
                    ),
                    const Divider(height: 1),
                    ListTile(
                      leading: const Icon(Icons.logout_rounded),
                      title: Text(_loggingOut ? 'Logging out...' : 'Logout'),
                      subtitle: const Text('Sign out from this device'),
                      onTap: _loggingOut ? null : _logout,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Text('Support', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              Card(
                child: Column(
                  children: [
                    ListTile(
                      leading: const Icon(Icons.bug_report_outlined),
                      title: const Text('Report Bugs'),
                      subtitle: const Text('Share issues you found in the app'),
                      trailing: _submittingBug
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.chevron_right_rounded),
                      onTap: _submittingBug ? null : () => _reportBug(user),
                    ),
                    const Divider(height: 1),
                    ListTile(
                      leading: const Icon(Icons.support_agent_rounded),
                      title: const Text('Contact Admin'),
                      subtitle: const Text('Start a direct chat with admin'),
                      trailing: _openingAdminChat
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.chevron_right_rounded),
                      onTap: _openingAdminChat
                          ? null
                          : () => _contactAdmin(user),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Text('About', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              Card(
                child: Column(
                  children: [
                    ListTile(
                      leading: const Icon(Icons.info_outline_rounded),
                      title: const Text('App Version'),
                      subtitle: Text(_versionLabel),
                    ),
                    const Divider(height: 1),
                    ListTile(
                      leading: const Icon(Icons.policy_outlined),
                      title: const Text('Terms & Privacy'),
                      subtitle: const Text(
                        'Read legal and privacy information',
                      ),
                      onTap: () => _showTerms(context),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
      loading: () =>
          const Scaffold(body: LoadingWidget(message: 'Loading settings...')),
      error: (error, _) => Scaffold(
        appBar: AppBar(
          leading: const AppBackButton(fallbackRoute: '/home'),
          title: const Text('Settings'),
        ),
        body: Center(child: Text('Unable to load settings: $error')),
      ),
    );
  }

  Future<void> _loadVersion() async {
    try {
      final info = await PackageInfo.fromPlatform();
      if (!mounted) return;
      setState(() {
        _versionLabel = '${info.version} (${info.buildNumber})';
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _versionLabel = 'Unavailable');
    }
  }

  Future<void> _logout() async {
    setState(() => _loggingOut = true);
    try {
      await ref.read(authRepositoryProvider).logout();
      if (!mounted) return;
      context.go('/login');
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Logout failed: $error')));
    } finally {
      if (mounted) {
        setState(() => _loggingOut = false);
      }
    }
  }

  Future<void> _showTerms(BuildContext context) async {
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Terms & Privacy'),
        content: const SingleChildScrollView(
          child: Text(
            'Academix stores account data, profile details, and uploaded content '
            'to deliver collaboration features including notes, referrals, chats, and '
            'notifications. By using this app, you agree to follow your college and '
            'community guidelines. Please avoid posting harmful or copyrighted content '
            'without permission.',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Future<void> _reportBug(UserModel user) async {
    final details = await _askForBugDetails();
    if (details == null) {
      return;
    }

    setState(() => _submittingBug = true);
    try {
      final reportRef = FirebaseFirestore.instance
          .collection(FirestorePaths.reports)
          .doc();

      await reportRef.set({
        'reportId': reportRef.id,
        'reporterUid': user.uid,
        'targetId': 'app',
        'targetType': 'bug',
        'category': 'bug',
        'reason': details,
        'status': 'pending',
        'collegeId': user.collegeId,
        'reporterRole': user.role,
        'appVersion': _versionLabel,
        'createdAt': FieldValue.serverTimestamp(),
      });

      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Bug report submitted successfully.')),
      );
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Unable to submit bug report: $error')),
      );
    } finally {
      if (mounted) {
        setState(() => _submittingBug = false);
      }
    }
  }

  Future<String?> _askForBugDetails() async {
    return showDialog<String>(
      context: context,
      builder: (context) => const _BugReportDialog(),
    );
  }

  Future<void> _contactAdmin(UserModel user) async {
    if (user.role == 'admin') {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('You are already an admin account.')),
      );
      return;
    }

    setState(() => _openingAdminChat = true);
    try {
      final admins = await _loadAdminCandidates(currentUser: user);
      if (!mounted) {
        return;
      }

      if (admins.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No admin account found right now.')),
        );
        return;
      }

      UserModel selectedAdmin;
      if (admins.length == 1) {
        selectedAdmin = admins.first;
      } else {
        final picked = await _pickAdmin(admins);
        if (picked == null || !mounted) {
          return;
        }
        selectedAdmin = picked;
      }

      final chatId = await ref
          .read(chatRepositoryProvider)
          .getOrCreateDirectChat(user.uid, selectedAdmin.uid, user.collegeId);

      if (!mounted) {
        return;
      }
      context.push('/chat/$chatId');
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Unable to contact admin: $error')),
      );
    } finally {
      if (mounted) {
        setState(() => _openingAdminChat = false);
      }
    }
  }

  Future<List<UserModel>> _loadAdminCandidates({
    required UserModel currentUser,
  }) async {
    final snapshot = await FirebaseFirestore.instance
        .collection(FirestorePaths.users)
        .where('role', isEqualTo: 'admin')
        .get();

    final admins = snapshot.docs
        .map((doc) => UserModel.fromMap(doc.data(), doc.id))
        .where((item) => !item.isBanned)
        .where((item) => item.uid != currentUser.uid)
        .toList();

    final sameCollege = admins
        .where((item) => item.collegeId == currentUser.collegeId)
        .toList();
    if (sameCollege.isNotEmpty) {
      return sameCollege;
    }
    return admins;
  }

  Future<UserModel?> _pickAdmin(List<UserModel> admins) {
    return showModalBottomSheet<UserModel>(
      context: context,
      showDragHandle: true,
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const ListTile(
                title: Text('Select Admin'),
                subtitle: Text('Choose whom you want to contact'),
              ),
              Flexible(
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: admins.length,
                  separatorBuilder: (_, _) => const Divider(height: 1),
                  itemBuilder: (_, index) {
                    final admin = admins[index];
                    final subtitle = admin.collegeName.isEmpty
                        ? admin.email
                        : '${admin.collegeName} • ${admin.email}';
                    return ListTile(
                      leading: const CircleAvatar(
                        child: Icon(Icons.admin_panel_settings_outlined),
                      ),
                      title: Text(admin.name.isEmpty ? 'Admin' : admin.name),
                      subtitle: Text(
                        subtitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      onTap: () => Navigator.of(context).pop(admin),
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _BugReportDialog extends StatefulWidget {
  const _BugReportDialog();

  @override
  State<_BugReportDialog> createState() => _BugReportDialogState();
}

class _BugReportDialogState extends State<_BugReportDialog> {
  final TextEditingController _controller = TextEditingController();
  String? _validationError;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Report a Bug'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _controller,
            autofocus: true,
            minLines: 3,
            maxLines: 6,
            decoration: InputDecoration(
              hintText: 'Describe what happened and steps to reproduce',
              errorText: _validationError,
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () {
            final text = _controller.text.trim();
            if (text.length < 10) {
              setState(() {
                _validationError = 'Please provide at least 10 characters.';
              });
              return;
            }
            Navigator.of(context).pop(text);
          },
          child: const Text('Submit'),
        ),
      ],
    );
  }
}
