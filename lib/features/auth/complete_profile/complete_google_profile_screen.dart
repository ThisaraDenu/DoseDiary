import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../../../core/router/route_names.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_dimensions.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/widgets/dd_button.dart';
import '../../../core/widgets/dd_phone_input.dart';
import '../../../core/widgets/dd_text_field.dart';
import '../../../data/local/database_provider.dart';
import '../../../data/remote/auth_service.dart';
import '../../../data/remote/supabase_sync_service.dart';
import '../../../main.dart';

class CompleteGoogleProfileScreen extends ConsumerStatefulWidget {
  const CompleteGoogleProfileScreen({
    super.key,
    this.profileLoader,
    this.profileSaver,
  });

  final Future<Map<String, dynamic>?> Function()? profileLoader;
  final Future<void> Function(Map<String, dynamic> updates)? profileSaver;

  @override
  ConsumerState<CompleteGoogleProfileScreen> createState() =>
      _CompleteGoogleProfileScreenState();
}

class _CompleteGoogleProfileScreenState
    extends ConsumerState<CompleteGoogleProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _birthdayController = TextEditingController();

  CountryRegion _selectedRegion = CountryRegion.defaultRegion;
  DateTime? _selectedBirthday;
  String? _selectedGender;
  String _email = '';
  bool _isLoading = true;
  bool _isSaving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _birthdayController.dispose();
    super.dispose();
  }

  Future<void> _loadProfile() async {
    final user = AuthService.currentUser;
    _email = user?.email ?? '';
    _nameController.text = user?.userMetadata?['full_name'] as String? ?? '';

    try {
      final profile = widget.profileLoader != null
          ? await widget.profileLoader!()
          : await AuthService.getProfile();
      if (profile != null) {
        final name = profile['full_name']?.toString();
        if (name != null && name.trim().isNotEmpty) {
          _nameController.text = name;
        }

        final profileEmail = profile['email']?.toString();
        if (_email.isEmpty &&
            profileEmail != null &&
            profileEmail.trim().isNotEmpty) {
          _email = profileEmail;
        }

        final dateOfBirth = profile['date_of_birth']?.toString();
        if (dateOfBirth != null && dateOfBirth.isNotEmpty) {
          try {
            _selectedBirthday = DateTime.parse(dateOfBirth);
            _setBirthdayText(_selectedBirthday!);
          } catch (_) {}
        }

        final gender = profile['gender']?.toString();
        if (gender != null && gender.isNotEmpty) {
          _selectedGender = gender;
        }

        final phone = profile['phone_number']?.toString();
        if (phone != null && phone.isNotEmpty) {
          final parsed = CountryRegion.parse(phone);
          _selectedRegion = parsed.region;
          _phoneController.text = parsed.nationalNumber;
        }
      }
    } catch (_) {
      _error = 'Unable to load your saved details. You can enter them below.';
    }

    if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  void _setBirthdayText(DateTime birthday) {
    final formatted = DateFormat('dd MMM yyyy').format(birthday);
    final age = AuthService.calculateAge(birthday.toIso8601String());
    _birthdayController.text =
        age == null ? formatted : '$formatted ($age yrs)';
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
        _setBirthdayText(picked);
        _error = null;
      });
    }
  }

  Future<void> _saveAndContinue() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isSaving = true;
      _error = null;
    });

    final phone = DdPhoneInput.formatFullNumber(
      _selectedRegion,
      _phoneController.text.trim(),
    );
    final updates = <String, dynamic>{
      'full_name': _nameController.text.trim(),
      'date_of_birth': DateFormat('yyyy-MM-dd').format(_selectedBirthday!),
      'gender': _selectedGender,
      'phone_number': phone,
    };

    try {
      if (widget.profileSaver != null) {
        await widget.profileSaver!(updates);
      } else {
        await AuthService.saveCompletedProfile(updates);
        await SupabaseSyncService.pullFromCloud();
      }
      ref.read(accountSessionEpochProvider.notifier).state++;

      final prefs = ref.read(sharedPreferencesProvider);
      await prefs.setBool('onboarding_complete', true);

      if (!mounted) return;
      context.go(RouteNames.permissions);
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isSaving = false;
        _error = 'Could not save your details. Please try again.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      child: Scaffold(
        backgroundColor: AppColors.scaffoldBackground,
        appBar: AppBar(
          automaticallyImplyLeading: false,
          backgroundColor: Colors.transparent,
          elevation: 0,
          scrolledUnderElevation: 0,
          title: Text(
            'Account details',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          centerTitle: true,
        ),
        body: SafeArea(
          child: _isLoading
              ? Center(
                  child: CircularProgressIndicator(
                    color: AppColors.primaryAction,
                  ),
                )
              : SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(
                    AppDimensions.screenMargin,
                    10,
                    AppDimensions.screenMargin,
                    28,
                  ),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Center(
                          child: Container(
                            width: 76,
                            height: 76,
                            decoration: BoxDecoration(
                              color: const Color(0xFFFFEEF0),
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: const Color(0xFFFFCDD3),
                              ),
                            ),
                            child: Icon(
                              Icons.person_rounded,
                              size: 40,
                              color: AppColors.primaryAction,
                            ),
                          ),
                        ),
                        const SizedBox(height: 18),
                        Text(
                          'Complete your profile',
                          textAlign: TextAlign.center,
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 26,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.4,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Tell us a little more so DoseDiary can personalize your experience.',
                          textAlign: TextAlign.center,
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 14,
                            height: 1.45,
                            color: AppColors.textSecondary,
                          ),
                        ),
                        if (_email.isNotEmpty) ...[
                          const SizedBox(height: 14),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 11,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: AppColors.borderLight,
                              ),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(
                                  Icons.verified_rounded,
                                  size: 18,
                                  color: Color(0xFF16A34A),
                                ),
                                const SizedBox(width: 8),
                                Flexible(
                                  child: Text(
                                    _email,
                                    overflow: TextOverflow.ellipsis,
                                    style: GoogleFonts.plusJakartaSans(
                                      fontSize: 13.5,
                                      fontWeight: FontWeight.w600,
                                      color: AppColors.textPrimary,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                        const SizedBox(height: 28),
                        DdTextField(
                          label: 'Full name',
                          hint: 'Your name',
                          controller: _nameController,
                          textInputAction: TextInputAction.next,
                          prefixIcon: const Icon(Icons.person_outline_rounded),
                          validator: (value) {
                            if (value == null || value.trim().isEmpty) {
                              return 'Full name is required';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: AppDimensions.stackLg),
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
                        InkWell(
                          onTap: _pickBirthday,
                          borderRadius: BorderRadius.circular(10),
                          child: IgnorePointer(
                            child: DdTextField(
                              label: 'Birthday',
                              hint: 'Select your date of birth',
                              controller: _birthdayController,
                              prefixIcon: const Icon(Icons.cake_outlined),
                              suffixIcon:
                                  const Icon(Icons.calendar_month_rounded),
                              validator: (_) => _selectedBirthday == null
                                  ? 'Birthday is required'
                                  : null,
                            ),
                          ),
                        ),
                        const SizedBox(height: AppDimensions.stackLg),
                        Text('Gender', style: AppTextStyles.bodyBold()),
                        const SizedBox(height: AppDimensions.stackSm),
                        DropdownButtonFormField<String>(
                          value: _selectedGender,
                          decoration: const InputDecoration(
                            hintText: 'Select gender',
                            prefixIcon: Icon(Icons.wc_rounded),
                          ),
                          items: const [
                            DropdownMenuItem(
                              value: 'Female',
                              child: Text('Female'),
                            ),
                            DropdownMenuItem(
                              value: 'Male',
                              child: Text('Male'),
                            ),
                            DropdownMenuItem(
                              value: 'Other',
                              child: Text('Other'),
                            ),
                            DropdownMenuItem(
                              value: 'Prefer not to say',
                              child: Text('Prefer not to say'),
                            ),
                          ],
                          onChanged: (value) {
                            setState(() => _selectedGender = value);
                          },
                          validator: (value) =>
                              value == null ? 'Gender is required' : null,
                        ),
                        if (_error != null) ...[
                          const SizedBox(height: AppDimensions.stackMd),
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFEF2F2),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: const Color(0xFFFECACA),
                              ),
                            ),
                            child: Text(
                              _error!,
                              textAlign: TextAlign.center,
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: AppColors.error,
                              ),
                            ),
                          ),
                        ],
                        const SizedBox(height: 28),
                        DdButton(
                          label: 'Save & Continue',
                          icon: const Icon(
                            Icons.arrow_forward_rounded,
                            color: Colors.white,
                          ),
                          isLoading: _isSaving,
                          onPressed: _saveAndContinue,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'Your details are stored securely and can be changed later in Settings.',
                          textAlign: TextAlign.center,
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 12,
                            height: 1.4,
                            color: AppColors.textTertiary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
        ),
      ),
    );
  }
}
