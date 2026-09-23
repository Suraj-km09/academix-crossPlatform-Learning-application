import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/errors/app_exception.dart';
import '../../../shared/widgets/app_back_button.dart';
import '../../../shared/widgets/app_button.dart';
import '../domain/auth_providers.dart';

class VerifyEmailScreen extends ConsumerStatefulWidget {
  const VerifyEmailScreen({super.key});

  @override
  ConsumerState<VerifyEmailScreen> createState() => _VerifyEmailScreenState();
}

class _VerifyEmailScreenState extends ConsumerState<VerifyEmailScreen> {
  bool _isChecking = false;
  bool _isSending = false;
  int _resendCooldownSeconds = 0;
  Timer? _cooldownTimer;

  @override
  void dispose() {
    _cooldownTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final email = user?.email ?? 'your email';
    final isDesktop = MediaQuery.of(context).size.width >= 600;

    final content = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Icon(
          Icons.mark_email_unread_outlined,
          size: 58,
          color: Theme.of(context).colorScheme.primary,
        ),
        const SizedBox(height: 14),
        Text(
          'We need to verify your email before giving account access.',
          style: Theme.of(context).textTheme.titleMedium,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 10),
        Text(
          'Verification email: $email\n\nIf not found, check spam/junk folder.',
          style: Theme.of(context).textTheme.bodyMedium,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 20),
        AppButton(
          label: _resendCooldownSeconds > 0
              ? 'Resend in $_resendCooldownSeconds s'
              : 'Resend Verification Email',
          isLoading: _isSending,
          onPressed: (_isSending || _resendCooldownSeconds > 0)
              ? null
              : _resendVerification,
        ),
        const SizedBox(height: 12),
        AppButton(
          label: 'I Have Verified, Continue',
          isLoading: _isChecking,
          onPressed: _isChecking ? null : _checkVerificationAndContinue,
        ),
        const SizedBox(height: 12),
        OutlinedButton.icon(
          onPressed: _logoutAndGoLogin,
          icon: const Icon(Icons.logout_rounded),
          label: const Text('Use Different Account'),
        ),
      ],
    );

    return Scaffold(
      appBar: AppBar(
        leading: const AppBackButton(fallbackRoute: '/login'),
        title: const Text('Verify Email'),
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
            child: isDesktop
                ? ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 480),
                    child: Container(
                      padding: const EdgeInsets.all(32),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.surface,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: Theme.of(context)
                              .dividerColor
                              .withValues(alpha: 0.2),
                          width: 1.2,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.05),
                            blurRadius: 20,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: content,
                    ),
                  )
                : content,
          ),
        ),
      ),
    );
  }

  Future<void> _resendVerification() async {
    setState(() => _isSending = true);
    try {
      final repository = ref.read(authRepositoryProvider);
      await repository.sendEmailVerificationToCurrentUser();
      _startCooldown();
      _showSnackBar(
        'Verification email sent. Check inbox and spam/junk folder.',
      );
    } on AppException catch (error) {
      _showSnackBar(error.message);
    } finally {
      if (mounted) {
        setState(() => _isSending = false);
      }
    }
  }

  Future<void> _checkVerificationAndContinue() async {
    setState(() => _isChecking = true);

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        if (mounted) {
          context.go('/login');
        }
        return;
      }

      await user.reload();
      final refreshedUser = FirebaseAuth.instance.currentUser;
      if (refreshedUser == null) {
        if (mounted) {
          context.go('/login');
        }
        return;
      }

      if (!refreshedUser.emailVerified) {
        _showSnackBar(
          'Email is still not verified. Open the link in your email first.',
        );
        return;
      }

      final repository = ref.read(authRepositoryProvider);
      await repository.markCurrentUserVerified();
      final profile = await repository.getUserById(refreshedUser.uid);

      if (!mounted) {
        return;
      }

      final destination = dashboardRouteForRole(profile?.role ?? 'student');
      context.go(destination);
    } on AppException catch (error) {
      _showSnackBar(error.message);
    } finally {
      if (mounted) {
        setState(() => _isChecking = false);
      }
    }
  }

  Future<void> _logoutAndGoLogin() async {
    final repository = ref.read(authRepositoryProvider);
    await repository.logout();
    if (!mounted) {
      return;
    }
    context.go('/login');
  }

  void _startCooldown() {
    _cooldownTimer?.cancel();
    setState(() => _resendCooldownSeconds = 30);

    _cooldownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }

      if (_resendCooldownSeconds <= 1) {
        timer.cancel();
        setState(() => _resendCooldownSeconds = 0);
        return;
      }

      setState(() => _resendCooldownSeconds -= 1);
    });
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }
}
