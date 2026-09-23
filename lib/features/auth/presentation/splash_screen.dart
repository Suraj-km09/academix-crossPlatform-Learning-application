import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/constants/app_constants.dart';
import '../../../shared/widgets/academix_logo.dart';
import '../domain/auth_providers.dart';
import 'onboarding_screen.dart';

class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen> with TickerProviderStateMixin {
  late AnimationController _mainController;
  late AnimationController _textController;
  
  late Animation<double> _logoScale;
  late Animation<double> _logoOpacity;
  late Animation<double> _scanPosition;
  
  bool _navigationStarted = false;
  User? _pendingUser;
  bool _authCheckComplete = false;
  bool _animationSequenceComplete = false;

  @override
  void initState() {
    super.initState();
    
    _mainController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );

    _textController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );

    _logoScale = Tween<double>(begin: 0.7, end: 1.0).animate(
      CurvedAnimation(
        parent: _mainController,
        curve: const Interval(0.0, 0.5, curve: Curves.easeOutBack),
      ),
    );

    _logoOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _mainController,
        curve: const Interval(0.0, 0.3, curve: Curves.easeIn),
      ),
    );

    _scanPosition = Tween<double>(begin: -1.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _mainController,
        curve: const Interval(0.1, 0.8, curve: Curves.easeInOutSine),
      ),
    );

    // Start Animation Sequence
    _startAnimationSequence();
  }

  Future<void> _startAnimationSequence() async {
    await _mainController.forward();
    await _textController.forward();
    
    // Minimum viewing time for the completed state
    await Future.delayed(const Duration(milliseconds: 400));
    
    if (mounted) {
      setState(() => _animationSequenceComplete = true);
      _checkAndNavigate();
    }
  }

  @override
  void dispose() {
    _mainController.dispose();
    _textController.dispose();
    super.dispose();
  }

  void _checkAndNavigate() {
    if (_authCheckComplete && _animationSequenceComplete && !_navigationStarted && mounted) {
      _navigationStarted = true;
      _handleAuthDecision(_pendingUser);
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(authStateChangesProvider, (previous, next) {
      next.whenData((user) {
        _pendingUser = user;
        _authCheckComplete = true;
        _checkAndNavigate();
      });
    });

    final colorScheme = Theme.of(context).colorScheme;
    final words = AppConstants.appName.split(' ');

    return PopScope(
      canPop: false,
      child: Scaffold(
        backgroundColor: colorScheme.surface,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              AnimatedBuilder(
                animation: _mainController,
                builder: (context, child) {
                  return Stack(
                    alignment: Alignment.center,
                    children: [
                      // Logo Build Animation
                      Transform.scale(
                        scale: _logoScale.value,
                        child: Opacity(
                          opacity: _logoOpacity.value,
                          child: const AcademixLogo(size: 110, showAppName: false),
                        ),
                      ),
                      
                      // Scanner Beam Animation
                      if (_mainController.value > 0.05 && _mainController.value < 0.95)
                        Positioned.fill(
                          child: ClipRect(
                            child: FractionalTranslation(
                              translation: Offset(0, _scanPosition.value),
                              child: Container(
                                height: 3,
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: [
                                      colorScheme.primary.withOpacity(0),
                                      colorScheme.primary,
                                      colorScheme.primary.withOpacity(0),
                                    ],
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: colorScheme.primary.withOpacity(0.4),
                                      blurRadius: 8,
                                      spreadRadius: 1,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                    ],
                  );
                },
              ),
              const SizedBox(height: 40),
              // Word-by-word Reveal
              Row(
                mainAxisSize: MainAxisSize.min,
                children: List.generate(words.length, (index) {
                  final start = index / words.length;
                  final end = (index + 1) / words.length;
                  
                  return AnimatedBuilder(
                    animation: _textController,
                    builder: (context, child) {
                      final interval = CurvedAnimation(
                        parent: _textController,
                        curve: Interval(start, end, curve: Curves.easeOut),
                      );
                      
                      return Opacity(
                        opacity: interval.value,
                        child: Transform.translate(
                          offset: Offset(0, 5 * (1 - interval.value)),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 4.0),
                            child: Text(
                              words[index],
                              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: 1.2,
                                    color: colorScheme.onSurface,
                                  ),
                            ),
                          ),
                        ),
                      );
                    },
                  );
                }),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _handleAuthDecision(User? firebaseUser) async {
    if (firebaseUser == null) {
      final prefs = await SharedPreferences.getInstance();
      final seenOnboarding = prefs.getBool(OnboardingScreen.seenStatusKey) ?? false;

      if (!mounted) return;
      context.go(seenOnboarding ? '/login' : '/onboarding');
      return;
    }

    try {
      final repository = ref.read(authRepositoryProvider);
      await firebaseUser.reload();
      final refreshedUser = FirebaseAuth.instance.currentUser;
      
      if (refreshedUser == null) {
        if (mounted) context.go('/login');
        return;
      }

      if (!refreshedUser.emailVerified) {
        if (mounted) context.go('/verify-email');
        return;
      }

      await repository.markCurrentUserVerified();
      final profile = await repository.getUserById(refreshedUser.uid);

      if (!mounted) return;
      final destination = dashboardRouteForRole(profile?.role ?? 'student');
      context.go(destination);
    } catch (e) {
      if (mounted) context.go('/login');
    }
  }
}
