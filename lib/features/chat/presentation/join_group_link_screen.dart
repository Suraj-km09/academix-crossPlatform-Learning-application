import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/errors/app_exception.dart';
import '../../../features/auth/domain/auth_providers.dart';
import '../../../shared/widgets/app_back_button.dart';
import '../../../shared/widgets/app_button.dart';
import '../../../shared/widgets/app_text_field.dart';
import '../../../shared/widgets/empty_state.dart';
import '../../../shared/widgets/loading_widget.dart';
import '../domain/chat_providers.dart';

class JoinGroupLinkScreen extends ConsumerStatefulWidget {
  const JoinGroupLinkScreen({super.key});

  @override
  ConsumerState<JoinGroupLinkScreen> createState() =>
      _JoinGroupLinkScreenState();
}

class _JoinGroupLinkScreenState extends ConsumerState<JoinGroupLinkScreen> {
  final TextEditingController _codeController = TextEditingController();
  bool _joining = false;

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final userAsync = ref.watch(currentUserStreamProvider);

    return userAsync.when(
      data: (user) {
        if (user == null) {
          return const Scaffold(
            body: EmptyState(
              title: 'Login required',
              subtitle: 'Please login to join group chats.',
            ),
          );
        }

        return Scaffold(
          appBar: AppBar(
            leading: const AppBackButton(fallbackRoute: '/chats'),
            title: const Text('Join Group'),
          ),
          body: SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Paste invite code or invite link',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 10),
                  AppTextField(
                    controller: _codeController,
                    hint: 'e.g. Q8HT3B9K2P',
                    maxLines: 2,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'If a full link is pasted, code will be extracted automatically.',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  const SizedBox(height: 18),
                  AppButton(
                    label: _joining ? 'Joining...' : 'Join Group',
                    isLoading: _joining,
                    onPressed: _joining ? null : () => _join(user.uid),
                  ),
                ],
              ),
            ),
          ),
        );
      },
      loading: () =>
          const Scaffold(body: LoadingWidget(message: 'Loading profile...')),
      error: (error, _) => Scaffold(
        body: EmptyState(title: 'Unable to load profile', subtitle: '$error'),
      ),
    );
  }

  Future<void> _join(String uid) async {
    final raw = _codeController.text.trim();
    if (raw.isEmpty) {
      _showSnack('Invite code is required');
      return;
    }

    final code = _extractCode(raw);
    if (code.isEmpty) {
      _showSnack('Invalid invite code/link');
      return;
    }

    setState(() => _joining = true);
    try {
      final chatId = await ref
          .read(chatRepositoryProvider)
          .joinGroupByInviteCode(inviteCode: code, uid: uid);

      if (!mounted) {
        return;
      }
      context.go('/chat/$chatId');
    } on AppException catch (error) {
      _showSnack(error.message);
    } catch (error) {
      _showSnack('Unable to join group: $error');
    } finally {
      if (mounted) {
        setState(() => _joining = false);
      }
    }
  }

  String _extractCode(String input) {
    final value = input.trim();
    final upper = value.toUpperCase();

    final byQuery = RegExp(r'code=([A-Z0-9]{6,20})').firstMatch(upper);
    if (byQuery != null) {
      return byQuery.group(1) ?? '';
    }

    final bySlash = RegExp(r'/([A-Z0-9]{6,20})$').firstMatch(upper);
    if (bySlash != null) {
      return bySlash.group(1) ?? '';
    }

    final plain = RegExp(r'^[A-Z0-9]{6,20}$');
    if (plain.hasMatch(upper)) {
      return upper;
    }

    return '';
  }

  void _showSnack(String message) {
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }
}
