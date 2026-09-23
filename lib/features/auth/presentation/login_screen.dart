import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/errors/app_exception.dart';
import '../../../core/utils/validators.dart';
import '../../../shared/services/auth_session_service.dart';
import '../../../shared/widgets/academix_logo.dart';
import '../../../shared/widgets/app_button.dart';
import '../../../shared/widgets/app_text_field.dart';
import '../domain/auth_providers.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _showPendingLogoutAlert();
    });
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isDesktop = screenWidth >= 600;

    final formContent = Form(
      key: _formKey,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Center(child: AcademixLogo(size: 80, showAppName: true)),
          const SizedBox(height: 8),
          Center(
            child: Text(
              'Sign in to your academic portal',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).textTheme.bodySmall?.color,
                  ),
            ),
          ),
          const SizedBox(height: 24),
          AppTextField(
            controller: _emailController,
            label: 'Email',
            hint: 'you@college.edu',
            keyboardType: TextInputType.emailAddress,
            validator: Validators.email,
          ),
          const SizedBox(height: 14),
          AppTextField(
            controller: _passwordController,
            label: 'Password',
            hint: 'Enter password',
            obscureText: true,
            validator: (value) =>
                Validators.requiredField(value, field: 'Password'),
          ),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: _isLoading
                  ? null
                  : () => context.push(
                      '/forgot-password?email=${Uri.encodeComponent(_emailController.text.trim())}',
                    ),
              child: const Text('Forgot password?'),
            ),
          ),
          const SizedBox(height: 12),
          AppButton(
            label: 'Login',
            isLoading: _isLoading,
            onPressed: _isLoading ? null : _login,
          ),
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.center,
            child: TextButton(
              onPressed: _isLoading ? null : () => context.go('/register'),
              child: const Text('Don\'t have an account? Register'),
            ),
          ),
        ],
      ),
    );

    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: const Text('Login'),
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
            child: isDesktop
                ? ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 440),
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
                      child: formContent,
                    ),
                  )
                : formContent,
          ),
        ),
      ),
    );
  }

  Future<void> _login() async {
    final valid = _formKey.currentState?.validate() ?? false;
    if (!valid) {
      return;
    }

    setState(() => _isLoading = true);

    try {
      final repository = ref.read(authRepositoryProvider);
      final user = await repository.login(
        _emailController.text,
        _passwordController.text,
      );

      if (!mounted) {
        return;
      }

      final destination = dashboardRouteForRole(user.role);
      context.go(destination);

      // Show one-time teacher approval popup if applicable.
      // Show one-time pending request popup or approval popup if applicable.
      if ((user.requestedRole == 'teacher' ||
              user.teacherRequestStatus == 'pending') &&
          !user.teacherRequestMessageShown) {
        Future.microtask(() {
          if (!mounted) return;
          showDialog<void>(
            context: context,
            builder: (context) => AlertDialog(
              title: const Text('Teacher Request Submitted'),
              content: const Text(
                'Your role has been set to Teacher. Pending admin approval.',
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('OK'),
                ),
              ],
            ),
            useRootNavigator: true,
          );

          try {
            ref
                .read(authRepositoryProvider)
                .markTeacherRequestMessageShown(user.uid)
                .catchError((_) {});
          } catch (_) {}
        });
      } else if (user.role == 'teacher' &&
          user.isApproved &&
          !user.approvalMessageShown) {
        Future.microtask(() {
          if (!mounted) return;
          showDialog<void>(
            context: context,
            builder: (context) => AlertDialog(
              title: const Text('You are now a Teacher'),
              content: const Text(
                'You have been approved as Teacher. Welcome!',
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('OK'),
                ),
              ],
            ),
            useRootNavigator: true,
          );

          try {
            ref
                .read(authRepositoryProvider)
                .markApprovalMessageShown(user.uid)
                .catchError((_) {});
          } catch (_) {}
        });
      }
    } on AppException catch (error) {
      if (error.code == 'email-not-verified') {
        if (mounted) {
          context.go('/verify-email');
        }
        return;
      }
      _showSnackBar(error.message);
    } on FirebaseAuthException catch (error) {
      _showSnackBar(_authMessage(error));
    } catch (error) {
      _showSnackBar('Login failed: $error');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  String _authMessage(FirebaseAuthException error) {
    switch (error.code) {
      case 'invalid-credential':
      case 'wrong-password':
      case 'user-not-found':
        return 'Invalid email or password';
      case 'too-many-requests':
        return 'Too many attempts. Please try again later.';
      case 'network-request-failed':
        return 'No internet connection. Please try again.';
      default:
        return error.message ?? 'Authentication failed';
    }
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _showPendingLogoutAlert() async {
    final message = await AuthSessionService.consumePendingLogoutAlert();
    if (!mounted || message == null || message.trim().isEmpty) {
      return;
    }

    if (message.toLowerCase().contains('another device')) {
      await showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Session Ended'),
          content: Text(message),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('OK'),
            ),
          ],
        ),
      );
      return;
    }

    _showSnackBar(message);
  }
}
