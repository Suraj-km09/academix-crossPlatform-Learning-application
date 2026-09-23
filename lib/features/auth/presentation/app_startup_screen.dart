import 'dart:async';

import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../shared/widgets/academix_logo.dart';
import '../domain/auth_providers.dart';
import 'onboarding_screen.dart';

class AppStartupScreen extends ConsumerStatefulWidget {
  const AppStartupScreen({super.key});

  @override
  ConsumerState<AppStartupScreen> createState() => _AppStartupScreenState();
}

class _AppStartupScreenState extends ConsumerState<AppStartupScreen> {
  bool _navigationStarted = false;

  @override
  void initState() {
    super.initState();
    _initAppCheck();
  }

  Future<void> _initAppCheck() async {
    try {
      if (kIsWeb) return;
      switch (defaultTargetPlatform) {
        case TargetPlatform.android:
          await FirebaseAppCheck.instance.activate(
            androidProvider: kDebugMode
                ? AndroidProvider.debug
                : AndroidProvider.playIntegrity,
          );
          return;
        case TargetPlatform.iOS:
        case TargetPlatform.macOS:
          await FirebaseAppCheck.instance.activate(
            appleProvider: kDebugMode
                ? AppleProvider.debug
                : AppleProvider.appAttest,
          );
          return;
        default:
          return;
      }
    } catch (_) {}
  }

  void _navigateTo(String route) {
    if (_navigationStarted) return;
    _navigationStarted = true;
    if (!mounted) return;
    context.go(route);
  }

  @override
  Widget build(BuildContext context) {
    // Watch only the auth state for the fastest possible transition.
    // The HomeScreen will handle loading the detailed user profile with skeletons.
    final authStateAsync = ref.watch(authStateChangesProvider);

    authStateAsync.when(
      data: (user) {
        if (_navigationStarted) return;

        WidgetsBinding.instance.addPostFrameCallback((_) async {
          if (!mounted) return;

          if (user == null) {
            final prefs = await SharedPreferences.getInstance();
            final seenOnboarding =
                prefs.getBool(OnboardingScreen.seenStatusKey) ?? false;
            if (!mounted) return;
            _navigateTo(seenOnboarding ? '/login' : '/onboarding');
            return;
          }

          // Quick check for email verification without blocking if possible,
          // but Firebase Auth usually requires a reload to get the latest status.
          if (!user.emailVerified) {
            try {
              await user.reload();
              final refreshed = FirebaseAuth.instance.currentUser;
              if (refreshed != null && !refreshed.emailVerified) {
                _navigateTo('/verify-email');
                return;
              }
            } catch (_) {}
          }

          _navigateTo('/home');
        });
      },
      loading: () {},
      error: (err, st) {
        if (_navigationStarted) return;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          _navigateTo('/login');
        });
      },
    );

    return Scaffold(
      body: Container(
        width: double.infinity,
        color: Theme.of(context).scaffoldBackgroundColor,
        child: const Center(child: AcademixLogo(size: 100, showAppName: true)),
      ),
    );
  }
}
