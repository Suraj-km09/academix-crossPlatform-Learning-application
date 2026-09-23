import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../features/auth/domain/auth_providers.dart';
import '../domain/alumni_providers.dart';
import 'alumni_screen.dart';

class AlumniSafeScreen extends ConsumerStatefulWidget {
  const AlumniSafeScreen({super.key});

  @override
  ConsumerState<AlumniSafeScreen> createState() => _AlumniSafeScreenState();
}

class _AlumniSafeScreenState extends ConsumerState<AlumniSafeScreen> {
  late final ErrorWidgetBuilder _previousErrorBuilder;

  bool _hasFatalError = false;
  String? _errorText;

  @override
  void initState() {
    super.initState();
    _previousErrorBuilder = ErrorWidget.builder;

    ErrorWidget.builder = (FlutterErrorDetails details) {
      if (!_hasFatalError) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) {
            return;
          }
          setState(() {
            _hasFatalError = true;
            _errorText = details.exceptionAsString();
          });
        });
      }
      return const SizedBox.shrink();
    };
  }

  @override
  void dispose() {
    ErrorWidget.builder = _previousErrorBuilder;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_hasFatalError) {
      return const AlumniScreen();
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Alumni Network')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.warning_amber_rounded, size: 52),
              const SizedBox(height: 10),
              Text(
                'Alumni screen encountered an error.',
                style: Theme.of(context).textTheme.titleLarge,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                (_errorText == null || _errorText!.trim().isEmpty)
                    ? 'Please retry. If issue repeats, go Home and reopen Alumni.'
                    : _errorText!,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 14),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () {
                    setState(() {
                      _hasFatalError = false;
                      _errorText = null;
                    });
                    final user = ref.read(currentUserProvider).value;
                    if (user != null) {
                      ref.invalidate(alumniStreamProvider(user.collegeId));
                    }
                  },
                  icon: const Icon(Icons.refresh_rounded),
                  label: const Text('Retry Alumni Screen'),
                ),
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () => context.go('/home'),
                  icon: const Icon(Icons.home_outlined),
                  label: const Text('Go To Home'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
