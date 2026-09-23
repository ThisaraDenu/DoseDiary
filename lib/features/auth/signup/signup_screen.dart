import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/theme/app_dimensions.dart';
import '../../../core/widgets/dd_button.dart';
import '../../../core/widgets/dd_google_button.dart';
import '../../../core/widgets/dd_text_field.dart';
import '../../../core/router/route_names.dart';
import '../../../data/remote/auth_service.dart';
import '../../../data/remote/supabase_sync_service.dart';
import '../../../core/services/permission_service.dart';
import '../../../main.dart';

class SignUpScreen extends ConsumerStatefulWidget {
  const SignUpScreen({super.key});

  @override
  ConsumerState<SignUpScreen> createState() => _SignUpScreenState();
}

class _SignUpScreenState extends ConsumerState<SignUpScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();
  bool _obscurePassword = true;
  bool _obscureConfirm = true;
  bool _isLoading = false;
  bool _isGoogleLoading = false;
  String? _error;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  Future<void> _signUp() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      await AuthService.signUp(
        email: _emailController.text.trim(),
        password: _passwordController.text,
        fullName: _nameController.text.trim(),
      );
      final prefs = ref.read(sharedPreferencesProvider);
      await prefs.setBool('onboarding_complete', true);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Account created! Please check your email to verify.'),
        ),
      );
      context.pop();
    } catch (e) {
      String msg = 'Sign up failed. Please try again.';
      final s = e.toString();
      if (s.contains('already registered') || s.contains('already been registered')) {
        msg = 'An account with this email already exists. Try logging in.';
      } else if (s.contains('Password should be')) {
        msg = 'Password must be at least 6 characters.';
      }
      setState(() => _error = msg);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _signUpWithGoogle() async {
    setState(() {
      _isGoogleLoading = true;
      _error = null;
    });

    try {
      final response = await AuthService.signInWithGoogle();

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
      return 'Google sign-up was canceled.';
    }
    if (raw.contains('network') || raw.contains('SocketException')) {
      return 'No internet connection. Please check your network and try again.';
    }
    if (raw.contains('No ID token')) {
      return 'Google authentication configuration pending. Check Web Client ID.';
    }
    return 'Google sign-up failed. Please try again.';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Create Account')),
      backgroundColor: AppColors.scaffoldBackground,
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppDimensions.screenMargin),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Your Details', style: AppTextStyles.headlineLg()),
              const SizedBox(height: AppDimensions.stackSm),
              Text('Create your DoseDiary account.',
                  style: AppTextStyles.bodyLg(color: AppColors.textSecondary)),
              const SizedBox(height: AppDimensions.stackXl),
              DdTextField(
                label: 'Full name',
                hint: 'Your name',
                controller: _nameController,
                textInputAction: TextInputAction.next,
                validator: (v) => (v?.trim().isEmpty ?? true) ? 'Name is required' : null,
              ),
              const SizedBox(height: AppDimensions.stackLg),
              DdTextField(
                label: 'Email address',
                hint: 'you@example.com',
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                textInputAction: TextInputAction.next,
                validator: (v) {
                  if (v?.trim().isEmpty ?? true) return 'Email is required';
                  if (!v!.contains('@')) return 'Enter a valid email';
                  return null;
                },
              ),
              const SizedBox(height: AppDimensions.stackLg),
              DdTextField(
                label: 'Password',
                controller: _passwordController,
                obscureText: _obscurePassword,
                textInputAction: TextInputAction.next,
                helperText: 'Minimum 8 characters',
                validator: (v) {
                  if (v == null || v.length < 8) return 'At least 8 characters required';
                  return null;
                },
                suffixIcon: IconButton(
                  icon: Icon(_obscurePassword ? Icons.visibility_outlined : Icons.visibility_off_outlined),
                  onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                ),
              ),
              const SizedBox(height: AppDimensions.stackLg),
              DdTextField(
                label: 'Confirm password',
                controller: _confirmController,
                obscureText: _obscureConfirm,
                textInputAction: TextInputAction.done,
                onFieldSubmitted: (_) => _signUp(),
                validator: (v) {
                  if (v != _passwordController.text) return 'Passwords do not match';
                  return null;
                },
                suffixIcon: IconButton(
                  icon: Icon(_obscureConfirm ? Icons.visibility_outlined : Icons.visibility_off_outlined),
                  onPressed: () => setState(() => _obscureConfirm = !_obscureConfirm),
                ),
              ),
              if (_error != null) ...[
                const SizedBox(height: AppDimensions.stackMd),
                Text(_error!, style: AppTextStyles.bodyLg(color: AppColors.error)),
              ],
              const SizedBox(height: AppDimensions.stackXl),
              DdButton(label: 'Create Account', onPressed: _signUp, isLoading: _isLoading),
              const SizedBox(height: AppDimensions.stackLg),

              // "OR" Divider
              Row(
                children: [
                  const Expanded(child: Divider(color: AppColors.borderLight, thickness: 1)),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Text(
                      'OR SIGN UP WITH',
                      style: AppTextStyles.caption(color: AppColors.textTertiary)
                          .copyWith(letterSpacing: 1.1, fontWeight: FontWeight.w600),
                    ),
                  ),
                  const Expanded(child: Divider(color: AppColors.borderLight, thickness: 1)),
                ],
              ),
              const SizedBox(height: AppDimensions.stackLg),

              DdGoogleButton(
                label: 'Sign up with Google',
                onPressed: _signUpWithGoogle,
                isLoading: _isGoogleLoading,
              ),
              const SizedBox(height: AppDimensions.stackSm),

              Center(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.shield_outlined, size: 13, color: AppColors.textTertiary),
                    const SizedBox(width: 5),
                    Text(
                      'Instant setup • No password required',
                      style: AppTextStyles.caption(color: AppColors.textTertiary),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppDimensions.stackLg),

              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text('Already have an account? ', style: AppTextStyles.bodyLg()),
                  TextButton(
                    onPressed: () => context.pop(),
                    child: Text('Log In', style: AppTextStyles.labelLg(color: AppColors.primaryAction)),
                  ),
                ],
              ),
              const SizedBox(height: AppDimensions.stackSm),

              Center(
                child: Text(
                  'By signing up, you agree to DoseDiary Terms & Privacy Policy.',
                  style: AppTextStyles.caption(color: AppColors.textTertiary),
                  textAlign: TextAlign.center,
                ),
              ),
              const SizedBox(height: AppDimensions.stackMd),
            ],
          ),
        ),
      ),
    );
  }
}
