import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../shared/widgets/academix_logo.dart';
import '../../../shared/widgets/app_button.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  static const String seenStatusKey = 'onboarding_seen';

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _pageController = PageController();

  static const List<_OnboardingPageData> _pages = [
    _OnboardingPageData(
      title: 'Your College, Connected',
      subtitle:
          'Join your campus network, classes, mentors, and communities in one place.',
      icon: Icons.groups_rounded,
    ),
    _OnboardingPageData(
      title: 'Free Notes & PYQs',
      subtitle:
          'Access shared notes and previous year questions uploaded by peers and teachers.',
      icon: Icons.menu_book_rounded,
    ),
    _OnboardingPageData(
      title: 'Alumni Mentorship',
      subtitle:
          'Learn from alumni experiences and ask career-focused questions confidently.',
      icon: Icons.school_rounded,
    ),
    _OnboardingPageData(
      title: 'Get Started',
      subtitle:
          'Create your profile and start collaborating with your college ecosystem.',
      icon: Icons.rocket_launch_rounded,
    ),
  ];

  int _currentPage = 0;

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isLastPage = _currentPage == _pages.length - 1;

    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: const Text('Welcome'),
        actions: [
          TextButton(
            onPressed: isLastPage
                ? null
                : () => _pageController.animateToPage(
                    _pages.length - 1,
                    duration: const Duration(milliseconds: 300),
                    curve: Curves.easeOut,
                  ),
            child: const Text('Skip'),
          ),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              const SizedBox(height: 8),
              const Center(child: AcademixLogo(size: 56, showAppName: true)),
              const SizedBox(height: 20),
              Expanded(
                child: PageView.builder(
                  controller: _pageController,
                  itemCount: _pages.length,
                  onPageChanged: (index) async {
                    setState(() => _currentPage = index);
                    if (index == _pages.length - 1) {
                      await _storeSeenStatus();
                    }
                  },
                  itemBuilder: (context, index) {
                    final data = _pages[index];
                    return _OnboardingPage(data: data);
                  },
                ),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(
                  _pages.length,
                  (index) => AnimatedContainer(
                    duration: const Duration(milliseconds: 220),
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    width: _currentPage == index ? 24 : 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: _currentPage == index
                          ? Theme.of(context).colorScheme.primary
                          : Theme.of(
                              context,
                            ).colorScheme.primary.withValues(alpha: 0.25),
                      borderRadius: BorderRadius.circular(50),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              if (isLastPage) ...[
                Row(
                  children: [
                    Expanded(
                      child: AppButton(
                        label: 'Login',
                        onPressed: () => _completeAndNavigate('/login'),
                        compact: true,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: AppButton(
                        label: 'Register',
                        onPressed: () => _completeAndNavigate('/register'),
                        compact: true,
                      ),
                    ),
                  ],
                ),
              ] else ...[
                AppButton(
                  label: 'Next',
                  onPressed: () => _pageController.nextPage(
                    duration: const Duration(milliseconds: 250),
                    curve: Curves.easeOut,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _completeAndNavigate(String route) async {
    await _storeSeenStatus();
    if (!mounted) {
      return;
    }
    context.go(route);
  }

  Future<void> _storeSeenStatus() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(OnboardingScreen.seenStatusKey, true);
  }
}

class _OnboardingPageData {
  const _OnboardingPageData({
    required this.title,
    required this.subtitle,
    required this.icon,
  });

  final String title;
  final String subtitle;
  final IconData icon;
}

class _OnboardingPage extends StatelessWidget {
  const _OnboardingPage({required this.data});

  final _OnboardingPageData data;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          width: 112,
          height: 112,
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
            shape: BoxShape.circle,
          ),
          alignment: Alignment.center,
          child: Icon(
            data.icon,
            size: 52,
            color: Theme.of(context).colorScheme.primary,
          ),
        ),
        const SizedBox(height: 28),
        Text(
          data.title,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: 12),
        Text(
          data.subtitle,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodyLarge,
        ),
      ],
    );
  }
}
