import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:intl/intl.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/theme/app_dimensions.dart';
import '../../../core/widgets/dd_button.dart';
import '../../../core/widgets/dd_google_button.dart';
import '../../../core/widgets/dd_text_field.dart';
import '../../../core/widgets/dd_phone_input.dart';
import '../../../core/router/route_names.dart';
import '../../../core/services/permission_service.dart';
import '../../../data/local/database_provider.dart';
import '../../../data/remote/auth_service.dart';
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
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();
  final _birthdayController = TextEditingController();
  CountryRegion _selectedRegion = CountryRegion.defaultRegion;
  DateTime? _selectedBirthday;
  String? _selectedGender;
  bool _obscurePassword = true;
  bool _obscureConfirm = true;
  bool _isLoading = false;
  bool _isGoogleLoading = false;
  String? _error;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _passwordController.dispose();
    _confirmController.dispose();
    _birthdayController.dispose();
    super.dispose();
  }

  Future<void> _pickBirthday() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedBirthday ?? DateTime(now.year - 25, 1, 1),
      firstDate: DateTime(1900),
      lastDate: now,
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: Theme.of(context).colorScheme.copyWith(
                  primary: AppColors.primaryAction,
                  onPrimary: Colors.white,
                ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() {
        _selectedBirthday = picked;
        final age = AuthService.calculateAge(picked.toIso8601String());
        final formattedDate = DateFormat('dd MMM yyyy').format(picked);
        _birthdayController.text =
            age != null ? '$formattedDate ($age yrs)' : formattedDate;
      });
    }
  }

  Future<void> _signUp() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final phoneTrimmed = _phoneController.text.trim();
      final fullPhoneNumber = phoneTrimmed.isNotEmpty
          ? DdPhoneInput.formatFullNumber(_selectedRegion, phoneTrimmed)
          : null;

      final email = _emailController.text.trim().toLowerCase();
      await AuthService.signUp(
        email: email,
        password: _passwordController.text,
        fullName: _nameController.text.trim(),
        dateOfBirth: _selectedBirthday != null
            ? DateFormat('yyyy-MM-dd').format(_selectedBirthday!)
            : null,
        gender: _selectedGender,
        phoneNumber: fullPhoneNumber,
      );
      ref.read(accountSessionEpochProvider.notifier).state++;

      if (!mounted) return;
      context.push(
        RouteNames.verifyEmail,
        extra: {'email': email},
      );
    } catch (e) {
      String msg = 'Could not create your account. Please try again.';
      final s = e.toString().toLowerCase();
      if (s.contains('already registered') ||
          s.contains('already been registered') ||
          s.contains('user already exists')) {
        msg = 'An account with this email already exists. Try logging in.';
      } else if (s.contains('password should be')) {
        msg = 'Password must be at least 6 characters.';
      } else if (s.contains('email address not authorized') ||
          s.contains('error sending confirmation email') ||
          s.contains('smtp')) {
        msg = 'Could not send the verification code to this address. '
            'Configure a verified email domain in Supabase SMTP.';
      } else if (s.contains('rate limit') ||
          s.contains('too many requests') ||
          s.contains('over_email_send_rate_limit')) {
        msg = 'Too many verification emails were requested. '
            'Please wait and try again.';
      } else if (s.contains('invalid email')) {
        msg = 'Enter a valid email address.';
      } else if (s.contains('network') || s.contains('socketexception')) {
        msg = 'No internet connection. Check your network and try again.';
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

      ref.read(accountSessionEpochProvider.notifier).state++;
      final prefs = ref.read(sharedPreferencesProvider);
      await prefs.setBool('onboarding_complete', true);

      if (!mounted) return;
      if (await AuthService.needsProfileCompletion()) {
        if (mounted) context.go(RouteNames.completeGoogleProfile);
      } else if (!PermissionService.hasPrompted(prefs)) {
        if (mounted) context.go(RouteNames.permissions);
      } else {
        if (mounted) context.go(RouteNames.home);
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
                validator: (v) =>
                    (v?.trim().isEmpty ?? true) ? 'Name is required' : null,
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
              // Phone Number with Region Selector
              DdPhoneInput(
                label: 'Phone number',
                hint: '77 123 4567',
                controller: _phoneController,
                selectedRegion: _selectedRegion,
                onRegionChanged: (region) {
                  setState(() => _selectedRegion = region);
                },
                isRequired: true,
                textInputAction: TextInputAction.next,
              ),
              const SizedBox(height: AppDimensions.stackLg),
              // Birthday Field
              InkWell(
                onTap: _pickBirthday,
                borderRadius: BorderRadius.circular(10),
                child: IgnorePointer(
                  child: DdTextField(
                    label: 'Birthday',
                    hint: 'Select your date of birth',
                    controller: _birthdayController,
                    prefixIcon: const Icon(Icons.cake_outlined),
                    suffixIcon: const Icon(Icons.calendar_month_rounded),
                    validator: (v) {
                      if (_selectedBirthday == null) {
                        return 'Birthday is required';
                      }
                      return null;
                    },
                  ),
                ),
              ),
              const SizedBox(height: AppDimensions.stackLg),
              // Gender Field
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Gender', style: AppTextStyles.bodyBold()),
                  const SizedBox(height: AppDimensions.stackSm),
                  DropdownButtonFormField<String>(
                    value: _selectedGender,
                    decoration: InputDecoration(
                      hintText: 'Select gender',
                      prefixIcon: const Icon(Icons.wc_rounded),
                      filled: true,
                      fillColor: Colors.white,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide:
                            const BorderSide(color: AppColors.borderLight),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide:
                            const BorderSide(color: AppColors.borderLight),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: const BorderSide(
                            color: AppColors.primaryAction, width: 1.5),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 14,
                      ),
                    ),
                    items: const [
                      DropdownMenuItem(value: 'Female', child: Text('Female')),
                      DropdownMenuItem(value: 'Male', child: Text('Male')),
                      DropdownMenuItem(value: 'Other', child: Text('Other')),
                      DropdownMenuItem(
                          value: 'Prefer not to say',
                          child: Text('Prefer not to say')),
                    ],
                    onChanged: (val) => setState(() => _selectedGender = val),
                    validator: (val) => (val == null || val.isEmpty)
                        ? 'Gender is required'
                        : null,
                  ),
                ],
              ),
              const SizedBox(height: AppDimensions.stackLg),
              DdTextField(
                label: 'Password',
                controller: _passwordController,
                obscureText: _obscurePassword,
                textInputAction: TextInputAction.next,
                helperText: 'Minimum 8 characters',
                validator: (v) {
                  if (v == null || v.length < 8) {
                    return 'At least 8 characters required';
                  }
                  return null;
                },
                suffixIcon: IconButton(
                  icon: Icon(_obscurePassword
                      ? Icons.visibility_outlined
                      : Icons.visibility_off_outlined),
                  onPressed: () =>
                      setState(() => _obscurePassword = !_obscurePassword),
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
                  if (v != _passwordController.text) {
                    return 'Passwords do not match';
                  }
                  return null;
                },
                suffixIcon: IconButton(
                  icon: Icon(_obscureConfirm
                      ? Icons.visibility_outlined
                      : Icons.visibility_off_outlined),
                  onPressed: () =>
                      setState(() => _obscureConfirm = !_obscureConfirm),
                ),
              ),
              if (_error != null) ...[
                const SizedBox(height: AppDimensions.stackMd),
                Text(_error!,
                    style: AppTextStyles.bodyLg(color: AppColors.error)),
              ],
              const SizedBox(height: AppDimensions.stackXl),
              DdButton(
                  label: 'Create Account',
                  onPressed: _signUp,
                  isLoading: _isLoading),
              const SizedBox(height: AppDimensions.stackLg),

              // "OR" Divider
              Row(
                children: [
                  const Expanded(
                      child:
                          Divider(color: AppColors.borderLight, thickness: 1)),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Text(
                      'OR SIGN UP WITH',
                      style:
                          AppTextStyles.caption(color: AppColors.textTertiary)
                              .copyWith(
                                  letterSpacing: 1.1,
                                  fontWeight: FontWeight.w600),
                    ),
                  ),
                  const Expanded(
                      child:
                          Divider(color: AppColors.borderLight, thickness: 1)),
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
                    const Icon(Icons.shield_outlined,
                        size: 13, color: AppColors.textTertiary),
                    const SizedBox(width: 5),
                    Text(
                      'Instant setup • No password required',
                      style:
                          AppTextStyles.caption(color: AppColors.textTertiary),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppDimensions.stackLg),

              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text('Already have an account? ',
                      style: AppTextStyles.bodyLg()),
                  TextButton(
                    onPressed: () => context.go(RouteNames.login),
                    child: Text('Log In',
                        style: AppTextStyles.labelLg(
                            color: AppColors.primaryAction)),
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
