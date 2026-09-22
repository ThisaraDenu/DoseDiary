import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/theme/app_dimensions.dart';
import '../../../core/widgets/dd_button.dart';
import '../../../core/widgets/dd_text_field.dart';

class ForgotPasswordScreen extends ConsumerStatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  ConsumerState<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends ConsumerState<ForgotPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  bool _isLoading = false;
  bool _sent = false;

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _sendReset() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);
    await Future.delayed(const Duration(milliseconds: 900));
    if (!mounted) return;
    setState(() {
      _isLoading = false;
      _sent = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Forgot Password')),
      backgroundColor: AppColors.scaffoldBackground,
      body: Padding(
        padding: const EdgeInsets.all(AppDimensions.screenMargin),
        child: _sent ? _SuccessView(email: _emailController.text) : _FormView(
          formKey: _formKey,
          emailController: _emailController,
          isLoading: _isLoading,
          onSubmit: _sendReset,
        ),
      ),
    );
  }
}

class _FormView extends StatelessWidget {
  const _FormView({
    required this.formKey,
    required this.emailController,
    required this.isLoading,
    required this.onSubmit,
  });
  final GlobalKey<FormState> formKey;
  final TextEditingController emailController;
  final bool isLoading;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    return Form(
      key: formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Reset your password', style: AppTextStyles.headlineLg()),
          const SizedBox(height: AppDimensions.stackSm),
          Text(
            'Enter your email address and we\'ll send you a link to reset your password.',
            style: AppTextStyles.bodyLg(color: AppColors.textSecondary),
          ),
          const SizedBox(height: AppDimensions.stackXl),
          DdTextField(
            label: 'Email address',
            hint: 'you@example.com',
            controller: emailController,
            keyboardType: TextInputType.emailAddress,
            textInputAction: TextInputAction.done,
            validator: (v) {
              if (v?.trim().isEmpty ?? true) return 'Email is required';
              return null;
            },
          ),
          const SizedBox(height: AppDimensions.stackXl),
          DdButton(label: 'Send Reset Link', onPressed: onSubmit, isLoading: isLoading),
        ],
      ),
    );
  }
}

class _SuccessView extends StatelessWidget {
  const _SuccessView({required this.email});
  final String email;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Icon(Icons.mark_email_read_outlined, size: 80, color: AppColors.takenForeground),
        const SizedBox(height: AppDimensions.stackXl),
        Text('Check your email', style: AppTextStyles.headlineLg(), textAlign: TextAlign.center),
        const SizedBox(height: AppDimensions.stackMd),
        Text(
          'We sent a password reset link to $email.\n\nPlease check your inbox and follow the instructions.',
          style: AppTextStyles.bodyLg(color: AppColors.textSecondary),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: AppDimensions.stackXl),
        DdButton(
          label: 'Back to Login',
          onPressed: () => Navigator.of(context).pop(),
          variant: DdButtonVariant.secondary,
        ),
      ],
    );
  }
}
