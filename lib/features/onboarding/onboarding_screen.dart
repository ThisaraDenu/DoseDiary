import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/theme/app_dimensions.dart';
import '../../core/widgets/dd_button.dart';
import '../../core/router/route_names.dart';
import '../../main.dart';

class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  static const _pages = [
    _OnboardingPage(
      icon: Icons.medication_rounded,
      title: 'Your Medication Schedule',
      body:
          'Keep all your medications organised in one place. Add each medicine once and DoseDiary builds your daily schedule automatically.\n\nNever lose track of which medicine is due, when, or how much.',
    ),
    _OnboardingPage(
      icon: Icons.alarm_on_rounded,
      title: 'Gentle Reminders',
      body:
          'Receive timely reminders for every dose. When a reminder appears, you can confirm you\'ve taken it, snooze it, or mark it as skipped — all from the notification.\n\nDoseDiary records your response and keeps a clear history of every dose.',
    ),
    _OnboardingPage(
      icon: Icons.people_rounded,
      title: 'Caregiver Support',
      body:
          'Optionally invite a trusted family member or caregiver. They can view your schedule and receive an alert if you haven\'t confirmed a dose after several reminders.\n\nYou control exactly what they can see — nothing is shared without your permission.',
    ),
  ];

  Future<void> _complete() async {
    final prefs = ref.read(sharedPreferencesProvider);
    await prefs.setBool('onboarding_complete', true);
    if (!mounted) return;
    context.go(RouteNames.login);
  }

  void _next() {
    if (_currentPage < _pages.length - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    } else {
      _complete();
    }
  }

  void _back() {
    _pageController.previousPage(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.scaffoldBackground,
      body: SafeArea(
        child: Column(
          children: [
            // Skip button
            Align(
              alignment: Alignment.topRight,
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppDimensions.screenMargin,
                  vertical: AppDimensions.stackMd,
                ),
                child: TextButton(
                  onPressed: _complete,
                  child: Text('Skip', style: AppTextStyles.labelMd(color: AppColors.textSecondary)),
                ),
              ),
            ),

            // Page content
            Expanded(
              child: PageView.builder(
                controller: _pageController,
                itemCount: _pages.length,
                onPageChanged: (i) => setState(() => _currentPage = i),
                itemBuilder: (ctx, i) => _pages[i],
              ),
            ),

            // Progress dots
            Padding(
              padding: const EdgeInsets.symmetric(vertical: AppDimensions.stackLg),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(
                  _pages.length,
                  (i) => AnimatedContainer(
                    duration: const Duration(milliseconds: 250),
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    width: i == _currentPage ? 24 : 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: i == _currentPage ? AppColors.primaryAction : AppColors.borderLight,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ),
              ),
            ),

            // Navigation buttons
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppDimensions.screenMargin,
                0,
                AppDimensions.screenMargin,
                AppDimensions.stackXl,
              ),
              child: Row(
                children: [
                  if (_currentPage > 0)
                    Expanded(
                      child: DdButton(
                        label: 'Back',
                        onPressed: _back,
                        variant: DdButtonVariant.secondary,
                      ),
                    ),
                  if (_currentPage > 0) const SizedBox(width: AppDimensions.stackMd),
                  Expanded(
                    flex: 2,
                    child: DdButton(
                      label: _currentPage == _pages.length - 1 ? 'Get Started' : 'Next',
                      onPressed: _next,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _OnboardingPage extends StatelessWidget {
  const _OnboardingPage({required this.icon, required this.title, required this.body});
  final IconData icon;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: AppDimensions.screenMargin),
      child: Column(
        children: [
          const SizedBox(height: AppDimensions.stackXl),
          Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              color: AppColors.primaryAction.withOpacity(0.08),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 64, color: AppColors.primaryAction),
          ),
          const SizedBox(height: AppDimensions.stackXl),
          Text(title, style: AppTextStyles.headlineLg(), textAlign: TextAlign.center),
          const SizedBox(height: AppDimensions.stackLg),
          Text(
            body,
            style: AppTextStyles.bodyXl(color: AppColors.textSecondary),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppDimensions.stackXl),
        ],
      ),
    );
  }
}
