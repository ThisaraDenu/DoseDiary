import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/theme/app_dimensions.dart';
import '../../core/widgets/dd_logo.dart';
import '../../core/router/route_names.dart';
import '../../core/services/permission_service.dart';
import '../../data/remote/supabase_sync_service.dart';
import '../../main.dart';

class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _fadeAnim = CurvedAnimation(parent: _controller, curve: Curves.easeIn);
    _controller.forward();
    _navigate();
  }

  Future<void> _navigate() async {
    await Future.delayed(const Duration(milliseconds: 1800));
    if (!mounted) return;

    final prefs = ref.read(sharedPreferencesProvider);
    final onboardingDone = prefs.getBool('onboarding_complete') ?? false;

    // Check real Supabase session
    final session = Supabase.instance.client.auth.currentSession;
    final isLoggedIn = session != null;

    if (!mounted) return;
    if (!onboardingDone) {
      context.go(RouteNames.onboarding);
    } else if (isLoggedIn) {
      // Pull latest cloud data in background then navigate
      SupabaseSyncService.pullFromCloud().ignore();
      if (!PermissionService.hasPrompted(prefs)) {
        context.go(RouteNames.permissions);
      } else {
        context.go(RouteNames.home);
      }
    } else {
      context.go(RouteNames.login);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.primaryAction,
      body: FadeTransition(
        opacity: _fadeAnim,
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const DdLogo(size: AppDimensions.logoLg, onDark: true),
              const SizedBox(height: AppDimensions.stackXl),
              Text(
                'DoseDiary',
                style: AppTextStyles.displayLg(color: AppColors.textOnPrimary),
              ),
              const SizedBox(height: AppDimensions.stackSm),
              Text(
                'Your medication companion',
                style: AppTextStyles.bodyLg(color: AppColors.textOnPrimary.withOpacity(0.85)),
              ),
              const SizedBox(height: AppDimensions.stack2Xl),
              const CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
            ],
          ),
        ),
      ),
    );
  }
}
