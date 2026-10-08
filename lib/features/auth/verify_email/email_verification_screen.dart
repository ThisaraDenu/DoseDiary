import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/router/route_names.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_dimensions.dart';
import '../../../core/widgets/dd_button.dart';
import '../../../data/remote/auth_service.dart';
import '../../../data/remote/supabase_sync_service.dart';
import '../../../main.dart';

class EmailVerificationScreen extends ConsumerStatefulWidget {
  final String email;
  final Future<bool> Function(String email, String code)? verifyCode;
  final Future<void> Function(String email)? resendCode;

  const EmailVerificationScreen({
    super.key,
    required this.email,
    this.verifyCode,
    this.resendCode,
  });

  @override
  ConsumerState<EmailVerificationScreen> createState() =>
      _EmailVerificationScreenState();
}

class _EmailVerificationScreenState
    extends ConsumerState<EmailVerificationScreen>
    with SingleTickerProviderStateMixin {
  static const int _pinLength = 6;
  late final List<TextEditingController> _controllers;
  late final List<FocusNode> _focusNodes;

  late AnimationController _animController;
  late Animation<double> _scaleAnimation;
  late Animation<double> _fadeAnimation;

  bool _isSuccess = false;
  bool _isVerifying = false;
  String? _error;

  Timer? _resendTimer;
  Timer? _navigateTimer;
  int _secondsRemaining = 45;
  bool _canResend = false;

  @override
  void initState() {
    super.initState();
    _controllers = List.generate(_pinLength, (_) => TextEditingController());
    _focusNodes = List.generate(_pinLength, (_) => FocusNode());

    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );

    _scaleAnimation = CurvedAnimation(
      parent: _animController,
      curve: Curves.elasticOut,
    );

    _fadeAnimation = CurvedAnimation(
      parent: _animController,
      curve: Curves.easeIn,
    );

    _startResendTimer();

    // Auto-focus first input field after build
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _focusNodes.isNotEmpty) {
        _focusNodes[0].requestFocus();
      }
    });
  }

  @override
  void dispose() {
    _resendTimer?.cancel();
    _navigateTimer?.cancel();
    _animController.dispose();
    for (final c in _controllers) {
      c.dispose();
    }
    for (final f in _focusNodes) {
      f.dispose();
    }
    super.dispose();
  }

  void _startResendTimer() {
    _resendTimer?.cancel();
    setState(() {
      _secondsRemaining = 45;
      _canResend = false;
    });

    _resendTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      if (_secondsRemaining > 1) {
        setState(() => _secondsRemaining--);
      } else {
        setState(() {
          _secondsRemaining = 0;
          _canResend = true;
        });
        timer.cancel();
      }
    });
  }

  String get _currentCode => _controllers.map((c) => c.text.trim()).join();

  void _onDigitChanged(int index, String value) {
    setState(() => _error = null);

    // Handle a full OTP paste.
    if (value.length > 1) {
      final digits = value.replaceAll(RegExp(r'\D'), '');
      if (digits.isNotEmpty) {
        for (int i = 0; i < _pinLength && i < digits.length; i++) {
          _controllers[i].text = digits[i];
        }
        final nextFocusIndex =
            (digits.length < _pinLength) ? digits.length : _pinLength - 1;
        _focusNodes[nextFocusIndex].requestFocus();

        if (digits.length >= _pinLength) {
          _verifyCode();
        }
        return;
      }
    }

    if (value.isNotEmpty) {
      if (index < _pinLength - 1) {
        _focusNodes[index + 1].requestFocus();
      } else {
        _focusNodes[index].unfocus();
        _verifyCode();
      }
    }
  }

  void _onKeyDown(int index, RawKeyEvent event) {
    if (event is RawKeyDownEvent &&
        event.logicalKey == LogicalKeyboardKey.backspace &&
        _controllers[index].text.isEmpty &&
        index > 0) {
      _focusNodes[index - 1].requestFocus();
      _controllers[index - 1].clear();
    }
  }

  Future<void> _verifyCode() async {
    final enteredCode = _currentCode;
    if (enteredCode.length < _pinLength) {
      setState(() => _error = 'Please enter all 6 digits');
      return;
    }

    setState(() {
      _isVerifying = true;
      _error = null;
    });

    bool isValid;
    try {
      isValid = widget.verifyCode != null
          ? await widget.verifyCode!(widget.email, enteredCode)
          : await AuthService.verifyEmailCode(
              email: widget.email,
              code: enteredCode,
            );
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isVerifying = false;
        _error =
            'Unable to verify the code. Check your connection and try again.';
      });
      return;
    }

    if (!mounted) return;

    if (isValid) {
      // ── Trigger Little Code Correct Animation ─────────────────────────────
      setState(() {
        _isVerifying = false;
        _isSuccess = true;
      });
      HapticFeedback.mediumImpact();
      _animController.forward(from: 0.0);

      // Save onboarding completion state
      final prefs = ref.read(sharedPreferencesProvider);
      await prefs.setBool('onboarding_complete', true);
      SupabaseSyncService.pullFromCloud().ignore();

      // Continue onboarding with app permissions after the success animation.
      _navigateTimer = Timer(const Duration(milliseconds: 1100), () {
        if (!mounted) return;
        try {
          context.go(RouteNames.permissions);
        } catch (_) {
          Navigator.of(context).maybePop();
        }
      });
    } else {
      HapticFeedback.heavyImpact();
      setState(() {
        _isVerifying = false;
        _error = 'Incorrect code. Please check your email and try again.';
      });
    }
  }

  Future<void> _resendCode() async {
    if (!_canResend) return;

    setState(() {
      _error = null;
    });

    try {
      if (widget.resendCode != null) {
        await widget.resendCode!(widget.email);
      } else {
        await AuthService.resendSignupCode(widget.email);
      }
      if (!mounted) return;

      _startResendTimer();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('New verification code sent to ${widget.email}!'),
          backgroundColor: AppColors.takenForeground,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (_) {
      setState(() => _error = 'Failed to resend code. Please try again.');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.scaffoldBackground,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: Color(0xFF0F172A)),
          onPressed: () => context.pop(),
        ),
        title: Text(
          'Email Verification',
          style: GoogleFonts.plusJakartaSans(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: const Color(0xFF0F172A),
          ),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(
            horizontal: AppDimensions.screenMargin,
            vertical: 12,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const SizedBox(height: 10),

              // ── Email Sent Banner ─────────────────────────────────────────
              Container(
                margin: const EdgeInsets.only(bottom: 20),
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                  color: const Color(0xFFF0FDF4),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFBBF7D0)),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.mark_email_read_rounded,
                      color: Color(0xFF16A34A),
                      size: 20,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'We sent a verification code to your email. Check your inbox (and spam folder).',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: const Color(0xFF15803D),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // ── Dev Helper: Tap-to-fill (hidden in production) ────────────
              // ── Header Icon Badge ─────────────────────────────────────────
              Center(
                child: Container(
                  width: 84,
                  height: 84,
                  decoration: BoxDecoration(
                    color: _isSuccess
                        ? const Color(0xFFECFDF5)
                        : const Color(0xFFFFEEF0),
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: (_isSuccess
                                ? const Color(0xFF10B981)
                                : AppColors.primaryAction)
                            .withOpacity(0.12),
                        blurRadius: 18,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                  child: Center(
                    child: Icon(
                      _isSuccess
                          ? Icons.mark_email_read_rounded
                          : Icons.mail_outline_rounded,
                      size: 42,
                      color: _isSuccess
                          ? const Color(0xFF10B981)
                          : AppColors.primaryAction,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // ── Title & Instructions ──────────────────────────────────────
              Text(
                'Verify your email',
                textAlign: TextAlign.center,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 26,
                  fontWeight: FontWeight.w800,
                  color: const Color(0xFF0F172A),
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Please enter the 6-digit verification code sent to',
                textAlign: TextAlign.center,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 14.5,
                  color: const Color(0xFF64748B),
                ),
              ),
              const SizedBox(height: 4),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    widget.email,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF0F172A),
                    ),
                  ),
                  const SizedBox(width: 4),
                  InkWell(
                    onTap: () => context.pop(),
                    child: const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                      child: Text(
                        'Change',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: AppColors.primaryAction,
                          decoration: TextDecoration.underline,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 32),

              // ── 5-Digit PIN Boxes ─────────────────────────────────────────
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(_pinLength, (index) {
                  final isFocused = _focusNodes[index].hasFocus;
                  final hasValue = _controllers[index].text.isNotEmpty;

                  Color borderColor = const Color(0xFFE2E2E2);
                  Color boxBg = Colors.white;

                  if (_isSuccess) {
                    borderColor = const Color(0xFF10B981);
                    boxBg = const Color(0xFFECFDF5);
                  } else if (_error != null) {
                    borderColor = AppColors.error;
                  } else if (isFocused) {
                    borderColor = AppColors.primaryAction;
                  } else if (hasValue) {
                    borderColor = const Color(0xFF0F172A);
                  }

                  return Container(
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    width: 44,
                    height: 62,
                    decoration: BoxDecoration(
                      color: boxBg,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: borderColor,
                        width: (_isSuccess || isFocused) ? 2.0 : 1.5,
                      ),
                      boxShadow: [
                        if (isFocused)
                          BoxShadow(
                            color: AppColors.primaryAction.withOpacity(0.12),
                            blurRadius: 10,
                            offset: const Offset(0, 3),
                          )
                        else if (_isSuccess)
                          BoxShadow(
                            color: const Color(0xFF10B981).withOpacity(0.15),
                            blurRadius: 10,
                            offset: const Offset(0, 3),
                          )
                        else
                          BoxShadow(
                            color: Colors.black.withOpacity(0.02),
                            blurRadius: 4,
                            offset: const Offset(0, 1),
                          ),
                      ],
                    ),
                    child: RawKeyboardListener(
                      focusNode: FocusNode(),
                      onKey: (event) => _onKeyDown(index, event),
                      child: TextField(
                        controller: _controllers[index],
                        focusNode: _focusNodes[index],
                        enabled: !_isSuccess && !_isVerifying,
                        keyboardType: TextInputType.number,
                        textAlign: TextAlign.center,
                        maxLength: 1,
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 24,
                          fontWeight: FontWeight.w800,
                          color: _isSuccess
                              ? const Color(0xFF10B981)
                              : const Color(0xFF0F172A),
                        ),
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                        ],
                        decoration: const InputDecoration(
                          counterText: '',
                          border: InputBorder.none,
                          focusedBorder: InputBorder.none,
                          enabledBorder: InputBorder.none,
                          contentPadding: EdgeInsets.zero,
                        ),
                        onChanged: (val) => _onDigitChanged(index, val),
                      ),
                    ),
                  );
                }),
              ),
              const SizedBox(height: 16),

              // ── Error Message ─────────────────────────────────────────────
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.error_outline_rounded,
                          size: 16, color: AppColors.error),
                      const SizedBox(width: 6),
                      Text(
                        _error!,
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: AppColors.error,
                        ),
                      ),
                    ],
                  ),
                ),

              // ── Little Code Correct Animation Modal / Card ────────────────
              if (_isSuccess) ...[
                const SizedBox(height: 16),
                FadeTransition(
                  opacity: _fadeAnimation,
                  child: ScaleTransition(
                    scale: _scaleAnimation,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 14,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFECFDF5),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: const Color(0xFFA7F3D0),
                          width: 1.5,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF10B981).withOpacity(0.18),
                            blurRadius: 16,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(6),
                            decoration: const BoxDecoration(
                              color: Color(0xFF10B981),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.check_rounded,
                              size: 20,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                'Code Correct!',
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w800,
                                  color: const Color(0xFF065F46),
                                ),
                              ),
                              Text(
                                'Opening app permissions...',
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w500,
                                  color: const Color(0xFF047857),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],

              const SizedBox(height: 28),

              // ── Verify Action Button ──────────────────────────────────────
              DdButton(
                label: _isSuccess ? 'Verified ✓' : 'Verify & Continue',
                icon: _isSuccess
                    ? const Icon(Icons.check_circle_rounded,
                        color: Colors.white)
                    : null,
                isLoading: _isVerifying,
                onPressed: _isSuccess ? null : _verifyCode,
              ),
              const SizedBox(height: 24),

              // ── Resend Code Countdown & Action ────────────────────────────
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    "Didn't receive the code? ",
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 14,
                      color: const Color(0xFF64748B),
                    ),
                  ),
                  InkWell(
                    onTap: _canResend ? _resendCode : null,
                    borderRadius: BorderRadius.circular(4),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 4,
                        vertical: 2,
                      ),
                      child: Text(
                        'Resend Code',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: _canResend
                              ? AppColors.primaryAction
                              : const Color(0xFF94A3B8),
                        ),
                      ),
                    ),
                  ),
                  if (!_canResend) ...[
                    const SizedBox(width: 4),
                    Text(
                      '(${_secondsRemaining}s)',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF94A3B8),
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
