import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/theme/app_colors.dart';
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
    _OnboardingPageData(
      illustrationAsset: 'assets/images/onboarding_illustration_1.png',
      title: 'Your medication,\nmade simple',
      subtitle: 'Keep your medicines and daily\nschedule in one place.',
    ),
    _OnboardingPageData(
      illustrationAsset: 'assets/images/onboarding_illustration_2.png',
      title: 'Gentle reminders.\nClear records.',
      subtitle: 'Get timely reminders and record\neach dose with a tap.',
    ),
    _OnboardingPageData(
      illustrationAsset: 'assets/images/onboarding_illustration_3.png',
      title: 'Care, shared\non your terms.',
      subtitle: 'Connect a caregiver and choose\nwhat you share.',
    ),
  ];

  Future<void> _complete(String targetRoute) async {
    final prefs = ref.read(sharedPreferencesProvider);
    await prefs.setBool('onboarding_complete', true);
    if (!mounted) return;
    context.go(targetRoute);
  }

  void _next() {
    if (_currentPage < _pages.length - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 320),
        curve: Curves.easeInOutCubic,
      );
    } else {
      _complete(RouteNames.signup);
    }
  }

  void _back() {
    if (_currentPage > 0) {
      _pageController.previousPage(
        duration: const Duration(milliseconds: 320),
        curve: Curves.easeInOutCubic,
      );
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: _currentPage == 0,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        if (_currentPage > 0) {
          _back();
        }
      },
      child: Scaffold(
        backgroundColor: AppColors.onboardingBackground,
        body: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final screenHeight = constraints.maxHeight;
              final illustrationHeight =
                  (screenHeight * 0.42).clamp(210.0, 360.0);

              return Column(
                children: [
                  // ── Top Header ─────────────────────────────────────────
                  Padding(
                    padding: const EdgeInsets.fromLTRB(24, 12, 24, 4),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        // DoseDiary Logo
                        Image.asset(
                          'assets/images/onboarding_brand_logo_transparent.png',
                          height: 32,
                          fit: BoxFit.contain,
                        ),

                        // Skip / Back button
                        TextButton(
                          onPressed: _currentPage == 2
                              ? _back
                              : () => _complete(RouteNames.login),
                          style: TextButton.styleFrom(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 6,
                            ),
                            minimumSize: Size.zero,
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                          child: Text(
                            _currentPage == 2 ? 'Back' : 'Skip',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: const Color(0xFF4B5563),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  // ── Sliding Page View ──────────────────────────────────
                  Expanded(
                    child: PageView.builder(
                      controller: _pageController,
                      itemCount: _pages.length,
                      onPageChanged: (i) => setState(() => _currentPage = i),
                      itemBuilder: (context, index) {
                        final page = _pages[index];

                        return SingleChildScrollView(
                          physics: const ClampingScrollPhysics(),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 24),
                            child: Column(
                              children: [
                                SizedBox(height: screenHeight < 680 ? 6 : 14),

                                // Central Illustration
                                SizedBox(
                                  height: illustrationHeight,
                                  width: double.infinity,
                                  child: Center(
                                    child: Image.asset(
                                      page.illustrationAsset,
                                      fit: BoxFit.contain,
                                    ),
                                  ),
                                ),

                                SizedBox(height: screenHeight < 680 ? 12 : 20),

                                // Page Indicator Dots
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: List.generate(
                                    _pages.length,
                                    (dotIdx) => AnimatedContainer(
                                      duration: const Duration(milliseconds: 250),
                                      curve: Curves.easeInOut,
                                      margin: const EdgeInsets.symmetric(
                                        horizontal: 4.0,
                                      ),
                                      width: dotIdx == index ? 28.0 : 8.0,
                                      height: 8.0,
                                      decoration: BoxDecoration(
                                        color: dotIdx == index
                                            ? AppColors.primaryAction
                                            : AppColors.onboardingDotInactive,
                                        borderRadius:
                                            BorderRadius.circular(4.0),
                                      ),
                                    ),
                                  ),
                                ),

                                SizedBox(height: screenHeight < 680 ? 16 : 26),

                                // Headline
                                Text(
                                  page.title,
                                  textAlign: TextAlign.center,
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: screenHeight < 680 ? 26.0 : 32.0,
                                    fontWeight: FontWeight.w800,
                                    height: 1.18,
                                    letterSpacing: -0.6,
                                    color: const Color(0xFF0F172A),
                                  ),
                                ),

                                SizedBox(height: screenHeight < 680 ? 8 : 14),

                                // Subtitle
                                Text(
                                  page.subtitle,
                                  textAlign: TextAlign.center,
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: screenHeight < 680 ? 15.0 : 17.0,
                                    fontWeight: FontWeight.w400,
                                    height: 1.42,
                                    letterSpacing: 0.1,
                                    color: const Color(0xFF475569),
                                  ),
                                ),

                                const SizedBox(height: 12),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),

                  // ── Bottom Action Area ─────────────────────────────────
                  Padding(
                    padding: const EdgeInsets.fromLTRB(24, 4, 24, 12),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Primary Action Button (Next / Get started)
                        SizedBox(
                          width: double.infinity,
                          height: 56.0,
                          child: ElevatedButton(
                            onPressed: _currentPage == _pages.length - 1
                                ? () => _complete(RouteNames.signup)
                                : _next,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primaryAction,
                              foregroundColor: Colors.white,
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16.0),
                              ),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  _currentPage == _pages.length - 1
                                      ? 'Get started'
                                      : 'Next',
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 18.0,
                                    fontWeight: FontWeight.w700,
                                    color: Colors.white,
                                  ),
                                ),
                                const SizedBox(width: 8.0),
                                const Icon(
                                  Icons.arrow_forward_rounded,
                                  size: 20.0,
                                  color: Colors.white,
                                ),
                              ],
                            ),
                          ),
                        ),

                        // "I already have an account" (Screen 3)
                        SizedBox(
                          height: 44.0,
                          child: AnimatedOpacity(
                            duration: const Duration(milliseconds: 200),
                            opacity: _currentPage == 2 ? 1.0 : 0.0,
                            child: Center(
                              child: TextButton(
                                onPressed: _currentPage == 2
                                    ? () => _complete(RouteNames.login)
                                    : null,
                                style: TextButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 8,
                                  ),
                                ),
                                child: Text(
                                  'I already have an account',
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 15.0,
                                    fontWeight: FontWeight.w600,
                                    color: const Color(0xFF374151),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

class _OnboardingPageData {
  const _OnboardingPageData({
    required this.illustrationAsset,
    required this.title,
    required this.subtitle,
  });

  final String illustrationAsset;
  final String title;
  final String subtitle;
}
