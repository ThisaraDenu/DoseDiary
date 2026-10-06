import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/theme/app_dimensions.dart';
import '../../../core/widgets/dd_button.dart';
import '../../../core/widgets/dd_google_button.dart';
import '../../../core/widgets/dd_text_field.dart';
import '../../../core/widgets/dd_logo.dart';
import '../../../core/router/route_names.dart';
import '../../../data/remote/auth_service.dart';
import '../../../data/remote/supabase_sync_service.dart';
import '../../../core/services/permission_service.dart';
import '../../../main.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;
  bool _isLoading = false;
  bool _isGoogleLoading = false;
  String? _error;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      await AuthService.signIn(
        email: _emailController.text.trim(),
        password: _passwordController.text,
      );

      // Mark onboarding complete and pull cloud data
      final prefs = ref.read(sharedPreferencesProvider);
      await prefs.setBool('onboarding_complete', true);
      SupabaseSyncService.pullFromCloud().ignore();

      if (!mounted) return;
      if (!PermissionService.hasPrompted(prefs)) {
        context.go(RouteNames.permissions);
      } else {
        context.go(RouteNames.home);
      }
    } catch (e) {
      setState(() => _error = _friendlyError(e.toString()));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _loginWithGoogle() async {
    setState(() {
      _isGoogleLoading = true;
      _error = null;
    });

    try {
      final response = await AuthService.signInWithGoogle();

      // If user canceled native dialog, response is null and session is empty
      if (response == null && AuthService.currentUser == null) {
        return;
      }

      final prefs = ref.read(sharedPreferencesProvider);
      await prefs.setBool('onboarding_complete', true);
      SupabaseSyncService.pullFromCloud().ignore();

      if (!mounted) return;
      if (!PermissionService.hasPrompted(prefs)) {
        context.go(RouteNames.permissions);
      } else {
        context.go(RouteNames.home);
      }
    } catch (e) {
      setState(() => _error = _friendlyGoogleError(e.toString()));
    } finally {
      if (mounted) setState(() => _isGoogleLoading = false);
    }
  }

  String _friendlyGoogleError(String raw) {
    if (raw.contains('canceled') || raw.contains('cancelled')) {
      return 'Google sign-in was canceled.';
    }
    if (raw.contains('network') || raw.contains('SocketException')) {
      return 'No internet connection. Please check your network and try again.';
    }
    if (raw.contains('No ID token')) {
      return 'Google authentication configuration pending. Check Web Client ID.';
    }
    return 'Google sign-in failed. Please try again.';
  }

  String _friendlyError(String raw) {
    if (raw.contains('Invalid login credentials') ||
        raw.contains('invalid_credentials')) {
      return 'Incorrect email or password. Please try again.';
    }
    if (raw.contains('Email not confirmed')) {
      return 'Please verify your email address before signing in.';
    }
    if (raw.contains('network') || raw.contains('SocketException')) {
      return 'No internet connection. Check your network and try again.';
    }
    return 'Sign in failed. Please try again.';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.scaffoldBackground,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppDimensions.screenMargin),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: AppDimensions.stackXl),
                // Logo + name
                Center(
                  child: Column(
                    children: [
                      const DdLogo(size: 80),
                      const SizedBox(height: AppDimensions.stackMd),
                      Text('DoseDiary', style: AppTextStyles.displayLg()),
                      const SizedBox(height: AppDimensions.stackSm),
                      Text(
                        'Welcome back',
                        style: AppTextStyles.bodyXl(color: AppColors.textSecondary),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppDimensions.stackXl),

                DdTextField(
                  label: 'Email address',
                  hint: 'you@example.com',
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  textInputAction: TextInputAction.next,
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) return 'Email is required';
                    return null;
                  },
                ),
                const SizedBox(height: AppDimensions.stackLg),

                DdTextField(
                  label: 'Password',
                  controller: _passwordController,
                  obscureText: _obscurePassword,
                  textInputAction: TextInputAction.done,
                  onFieldSubmitted: (_) => _login(),
                  validator: (v) {
                    if (v == null || v.isEmpty) return 'Password is required';
                    return null;
                  },
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscurePassword ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                    ),
                    onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                    tooltip: _obscurePassword ? 'Show password' : 'Hide password',
                  ),
                ),
                const SizedBox(height: AppDimensions.stackSm),

                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: () => context.push(RouteNames.forgotPassword),
                    child: Text('Forgot password?',
                        style: AppTextStyles.labelMd(color: AppColors.primaryAction)),
                  ),
                ),

                if (_error != null) ...[
                  const SizedBox(height: AppDimensions.stackMd),
                  Container(
                    padding: const EdgeInsets.all(AppDimensions.stackMd),
                    decoration: BoxDecoration(
                      color: AppColors.errorContainer,
                      borderRadius: BorderRadius.circular(AppDimensions.badgeRadius),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.error_outline, size: 18, color: AppColors.error),
                        const SizedBox(width: 8),
                        Expanded(child: Text(_error!, style: AppTextStyles.bodyLg(color: AppColors.error))),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: AppDimensions.stackXl),

                DdButton(
                  label: 'Log In',
                  onPressed: _login,
                  isLoading: _isLoading,
                ),
                const SizedBox(height: AppDimensions.stackLg),

                // "OR" Divider
                Row(
                  children: [
                    const Expanded(child: Divider(color: AppColors.borderLight, thickness: 1)),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Text(
                        'OR CONTINUE WITH',
                        style: AppTextStyles.caption(color: AppColors.textTertiary)
                            .copyWith(letterSpacing: 1.1, fontWeight: FontWeight.w600),
                      ),
                    ),
                    const Expanded(child: Divider(color: AppColors.borderLight, thickness: 1)),
                  ],
                ),
                const SizedBox(height: AppDimensions.stackLg),

                DdGoogleButton(
                  onPressed: _loginWithGoogle,
                  isLoading: _isGoogleLoading,
                ),
                const SizedBox(height: AppDimensions.stackSm),

                Center(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.lock_outline, size: 13, color: AppColors.textTertiary),
                      const SizedBox(width: 5),
                      Text(
                        'Secure 1-tap sign in via Google & Supabase',
                        style: AppTextStyles.caption(color: AppColors.textTertiary),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppDimensions.stackLg),

                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text("Don't have an account? ", style: AppTextStyles.bodyLg()),
                    TextButton(
                      onPressed: () => context.push(RouteNames.signup),
                      child: Text('Sign Up',
                          style: AppTextStyles.labelLg(color: AppColors.primaryAction)),
                    ),
                  ],
                ),
                const SizedBox(height: AppDimensions.stackXl),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
