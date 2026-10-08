import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_dimensions.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/widgets/dd_avatar.dart';
import '../../core/widgets/dd_button.dart';
import '../../core/widgets/dd_card.dart';
import '../../core/widgets/dd_phone_input.dart';
import '../../data/remote/auth_service.dart';
import '../../data/remote/supabase_sync_service.dart';
import '../home/home_dashboard_screen.dart';

class AccountScreen extends ConsumerStatefulWidget {
  const AccountScreen({super.key});

  @override
  ConsumerState<AccountScreen> createState() => _AccountScreenState();
}

class _AccountScreenState extends ConsumerState<AccountScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _birthdayController;
  late final TextEditingController _phoneController;
  final ImagePicker _picker = ImagePicker();

  CountryRegion _selectedRegion = CountryRegion.defaultRegion;
  DateTime? _selectedBirthday;
  String? _selectedGender;
  bool _isLoading = true;
  bool _isUploadingPhoto = false;
  bool _isSaving = false;
  bool _isSyncing = false;
  String? _avatarUrl;
  String? _userEmail;
  String? _userId;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController();
    _birthdayController = TextEditingController();
    _phoneController = TextEditingController();
    _loadProfileData();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _birthdayController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _loadProfileData() async {
    final user = AuthService.currentUser;
    _userEmail = user?.email ?? 'Not signed in';
    _userId = user?.id ?? 'Local device only';

    try {
      final profile = await AuthService.getProfile();
      if (mounted) {
        setState(() {
          _avatarUrl = profile?['avatar_url'] as String?;
          final fullName = profile?['full_name'] as String? ??
              user?.userMetadata?['full_name'] as String? ??
              '';
          _nameController.text = fullName;

          final dobStr = profile?['date_of_birth'] as String? ??
              user?.userMetadata?['date_of_birth'] as String?;
          if (dobStr != null && dobStr.isNotEmpty) {
            try {
              _selectedBirthday = DateTime.parse(dobStr);
              final age = AuthService.calculateAge(dobStr);
              final formatted =
                  DateFormat('dd MMM yyyy').format(_selectedBirthday!);
              _birthdayController.text =
                  age != null ? '$formatted ($age yrs)' : formatted;
            } catch (_) {
              _birthdayController.text = dobStr;
            }
          }

          _selectedGender = profile?['gender'] as String? ??
              user?.userMetadata?['gender'] as String?;

          final phoneStr = profile?['phone_number'] as String? ??
              user?.userMetadata?['phone_number'] as String?;
          if (phoneStr != null && phoneStr.isNotEmpty) {
            final parsed = CountryRegion.parse(phoneStr);
            _selectedRegion = parsed.region;
            _phoneController.text = parsed.nationalNumber;
          }

          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    } finally {
      if (mounted && _isLoading) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _pickImage(ImageSource source) async {
    Navigator.of(context).pop(); // Close bottom sheet
    try {
      final XFile? file = await _picker.pickImage(
        source: source,
        maxWidth: 512,
        maxHeight: 512,
        imageQuality: 85,
      );

      if (file == null) return;

      setState(() => _isUploadingPhoto = true);

      final bytes = await file.readAsBytes();
      final ext = file.name.contains('.') ? file.name.split('.').last : 'jpg';

      final uploadedUrl = await AuthService.uploadAvatar(
        bytes: bytes,
        fileExtension: ext,
      );

      if (mounted) {
        setState(() {
          _avatarUrl = uploadedUrl;
          _isUploadingPhoto = false;
        });

        // Invalidate home screen providers so new photo reflects instantly
        ref.invalidate(userNameProvider);
        ref.invalidate(userAvatarUrlProvider);

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✓ Profile picture updated and saved to Supabase!'),
            backgroundColor: AppColors.takenForeground,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isUploadingPhoto = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to upload image: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  void _showImagePickerOptions() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Change Profile Photo',
                style: AppTextStyles.headlineMd(),
              ),
              const SizedBox(height: 16),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFDAD9),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.camera_alt_rounded,
                    color: Color(0xFFB1002C),
                  ),
                ),
                title: const Text('Take a photo'),
                subtitle: const Text('Use your device camera'),
                onTap: () => _pickImage(ImageSource.camera),
              ),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE8F0FE),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.photo_library_rounded,
                    color: Color(0xFF1A73E8),
                  ),
                ),
                title: const Text('Choose from gallery'),
                subtitle: const Text('Select an existing photo'),
                onTap: () => _pickImage(ImageSource.gallery),
              ),
              if (_avatarUrl != null && _avatarUrl!.isNotEmpty)
                ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.delete_outline_rounded,
                      color: Colors.redAccent,
                    ),
                  ),
                  title: const Text(
                    'Remove current photo',
                    style: TextStyle(color: Colors.redAccent),
                  ),
                  onTap: () async {
                    Navigator.of(ctx).pop();
                    setState(() => _avatarUrl = null);
                    await AuthService.updateProfile({'avatar_url': null});
                    ref.invalidate(userNameProvider);
                    ref.invalidate(userAvatarUrlProvider);
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('✓ Profile photo removed'),
                          backgroundColor: AppColors.takenForeground,
                        ),
                      );
                    }
                  },
                ),
            ],
          ),
        ),
      ),
    );
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

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);
    final newName = _nameController.text.trim();
    final dobStr = _selectedBirthday != null
        ? DateFormat('yyyy-MM-dd').format(_selectedBirthday!)
        : null;
    final phoneTrimmed = _phoneController.text.trim();
    final fullPhone = phoneTrimmed.isNotEmpty
        ? DdPhoneInput.formatFullNumber(_selectedRegion, phoneTrimmed)
        : null;

    try {
      await AuthService.updateProfile({
        'full_name': newName,
        'date_of_birth': dobStr,
        'gender': _selectedGender,
        'phone_number': fullPhone,
      });
      ref.invalidate(userNameProvider);
      ref.invalidate(userAvatarUrlProvider);
      ref.invalidate(userProfileProvider);
      ref.invalidate(userAgeProvider);
      ref.invalidate(userGenderProvider);
      ref.invalidate(userPhoneProvider);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✓ Profile details saved successfully!'),
            backgroundColor: AppColors.takenForeground,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error saving profile: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _syncNow() async {
    setState(() => _isSyncing = true);
    try {
      await SupabaseSyncService.syncAll();
      ref.invalidate(userNameProvider);
      ref.invalidate(userAvatarUrlProvider);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('✓ All data successfully synced to Supabase!'),
          backgroundColor: AppColors.takenForeground,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Sync failed: $e'),
          backgroundColor: AppColors.error,
        ),
      );
    } finally {
      if (mounted) setState(() => _isSyncing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = AuthService.currentUser;

    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(title: const Text('Profile & Account')),
        backgroundColor: AppColors.scaffoldBackground,
        body: const Center(
          child: CircularProgressIndicator(color: AppColors.primaryAction),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Profile & Account'),
        backgroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 1,
      ),
      backgroundColor: const Color(0xFFF9F9F9),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppDimensions.screenMargin),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // ── 1. Avatar Card with Edit Badge ──────────────────────────────
              Center(
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    DdAvatar(
                      avatarUrl: _avatarUrl,
                      size: 104,
                      borderWidth: 3.5,
                      borderColor: Colors.white,
                    ),
                    if (_isUploadingPhoto)
                      Positioned.fill(
                        child: Container(
                          decoration: const BoxDecoration(
                            color: Colors.black38,
                            shape: BoxShape.circle,
                          ),
                          child: const Center(
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 3,
                            ),
                          ),
                        ),
                      ),
                    Positioned(
                      bottom: 0,
                      right: 0,
                      child: Material(
                        color: const Color(0xFFB1002C),
                        shape: const CircleBorder(),
                        elevation: 3,
                        child: InkWell(
                          customBorder: const CircleBorder(),
                          onTap: _isUploadingPhoto
                              ? null
                              : _showImagePickerOptions,
                          child: const Padding(
                            padding: EdgeInsets.all(8),
                            child: Icon(
                              Icons.camera_alt_rounded,
                              size: 18,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Tap camera icon to change picture',
                style: AppTextStyles.caption(color: AppColors.textSecondary),
              ),
              const SizedBox(height: 14),

              // ── Header Summary: Age, Gender & Phone Badges ───────────────────
              Builder(
                builder: (context) {
                  final age = _selectedBirthday != null
                      ? AuthService.calculateAge(
                          _selectedBirthday!.toIso8601String())
                      : null;
                  final gender = _selectedGender;
                  final phoneTrimmed = _phoneController.text.trim();

                  return Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: AppColors.borderLight),
                    ),
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          // Age Pill
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(7),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFFEF2F2),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Icon(
                                  Icons.cake_outlined,
                                  size: 18,
                                  color: AppColors.primaryAction,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Age',
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w500,
                                      color: Color(0xFF64748B),
                                    ),
                                  ),
                                  Text(
                                    age != null ? '$age yrs' : 'Not set',
                                    style: const TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w700,
                                      color: Color(0xFF0F172A),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                          Container(
                            margin: const EdgeInsets.symmetric(horizontal: 10),
                            width: 1,
                            height: 28,
                            color: const Color(0xFFEEEEEE),
                          ),
                          // Gender Pill
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(7),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF0FDF4),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Icon(
                                  Icons.wc_rounded,
                                  size: 18,
                                  color: Color(0xFF16A34A),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Gender',
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w500,
                                      color: Color(0xFF64748B),
                                    ),
                                  ),
                                  Text(
                                    (gender != null && gender.isNotEmpty)
                                        ? gender
                                        : 'Not set',
                                    style: const TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w700,
                                      color: Color(0xFF0F172A),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                          Container(
                            margin: const EdgeInsets.symmetric(horizontal: 10),
                            width: 1,
                            height: 28,
                            color: const Color(0xFFEEEEEE),
                          ),
                          // Phone Pill
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(7),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFEFF6FF),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  _selectedRegion.flag,
                                  style: const TextStyle(fontSize: 16),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Phone',
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w500,
                                      color: Color(0xFF64748B),
                                    ),
                                  ),
                                  Text(
                                    phoneTrimmed.isNotEmpty
                                        ? '${_selectedRegion.dialCode} $phoneTrimmed'
                                        : 'Not set',
                                    style: const TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w700,
                                      color: Color(0xFF0F172A),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
              const SizedBox(height: AppDimensions.stackLg),

              // ── 2. Personal Information Card ────────────────────────────────
              DdCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(
                          Icons.person_outline_rounded,
                          color: Color(0xFFB1002C),
                          size: 22,
                        ),
                        const SizedBox(width: 8),
                        Text('Personal Info', style: AppTextStyles.bodyBold()),
                      ],
                    ),
                    const SizedBox(height: AppDimensions.stackMd),
                    const Text(
                      'Full Name',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF545F73),
                      ),
                    ),
                    const SizedBox(height: 6),
                    TextFormField(
                      controller: _nameController,
                      decoration: InputDecoration(
                        hintText: 'Enter your name',
                        filled: true,
                        fillColor: const Color(0xFFF6F6F6),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide.none,
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 12,
                        ),
                      ),
                      validator: (val) {
                        if (val == null || val.trim().isEmpty) {
                          return 'Please enter a name';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: AppDimensions.stackMd),

                    // Phone Number with Region Selector
                    DdPhoneInput(
                      label: 'Phone Number',
                      hint: '77 123 4567',
                      controller: _phoneController,
                      selectedRegion: _selectedRegion,
                      onRegionChanged: (region) =>
                          setState(() => _selectedRegion = region),
                      isRequired: false,
                    ),
                    const SizedBox(height: AppDimensions.stackMd),

                    // Birthday
                    const Text(
                      'Birthday',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF545F73),
                      ),
                    ),
                    const SizedBox(height: 6),
                    InkWell(
                      onTap: _pickBirthday,
                      borderRadius: BorderRadius.circular(10),
                      child: IgnorePointer(
                        child: TextFormField(
                          controller: _birthdayController,
                          decoration: InputDecoration(
                            hintText: 'Select date of birth',
                            prefixIcon:
                                const Icon(Icons.cake_outlined, size: 20),
                            suffixIcon: const Icon(Icons.calendar_month_rounded,
                                size: 20),
                            filled: true,
                            fillColor: const Color(0xFFF6F6F6),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide: BorderSide.none,
                            ),
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 12,
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: AppDimensions.stackMd),

                    // Gender
                    const Text(
                      'Gender',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF545F73),
                      ),
                    ),
                    const SizedBox(height: 6),
                    DropdownButtonFormField<String>(
                      value: _selectedGender,
                      decoration: InputDecoration(
                        hintText: 'Select gender',
                        prefixIcon: const Icon(Icons.wc_rounded, size: 20),
                        filled: true,
                        fillColor: const Color(0xFFF6F6F6),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide.none,
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 12,
                        ),
                      ),
                      items: const [
                        DropdownMenuItem(
                            value: 'Female', child: Text('Female')),
                        DropdownMenuItem(value: 'Male', child: Text('Male')),
                        DropdownMenuItem(value: 'Other', child: Text('Other')),
                        DropdownMenuItem(
                            value: 'Prefer not to say',
                            child: Text('Prefer not to say')),
                      ],
                      onChanged: (val) => setState(() => _selectedGender = val),
                    ),
                    const SizedBox(height: AppDimensions.stackLg),

                    DdButton(
                      label: 'Save Profile Changes',
                      icon: const Icon(Icons.check_rounded),
                      isLoading: _isSaving,
                      onPressed: _saveProfile,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppDimensions.stackMd),

              // ── 3. Account Details & Security Card ───────────────────────────
              DdCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(
                          Icons.shield_outlined,
                          color: Color(0xFF157F5D),
                          size: 22,
                        ),
                        const SizedBox(width: 8),
                        Text('Account & Security',
                            style: AppTextStyles.bodyBold()),
                      ],
                    ),
                    const SizedBox(height: AppDimensions.stackMd),
                    Text(
                      'Email Address',
                      style:
                          AppTextStyles.caption(color: AppColors.textTertiary),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _userEmail ?? 'Not signed in',
                      style: AppTextStyles.bodyLg(color: AppColors.textPrimary),
                    ),
                    const SizedBox(height: AppDimensions.stackSm),
                    const Divider(),
                    const SizedBox(height: AppDimensions.stackSm),
                    Text(
                      'Supabase User ID',
                      style:
                          AppTextStyles.caption(color: AppColors.textTertiary),
                    ),
                    const SizedBox(height: 2),
                    SelectableText(
                      _userId ?? 'Local only',
                      style:
                          AppTextStyles.caption(color: AppColors.textSecondary),
                    ),
                    const SizedBox(height: AppDimensions.stackSm),
                    Row(
                      children: [
                        Icon(
                          user != null
                              ? Icons.verified_user_rounded
                              : Icons.cloud_off_rounded,
                          color: user != null
                              ? AppColors.takenForeground
                              : AppColors.textTertiary,
                          size: 18,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          user != null
                              ? 'PostgreSQL RLS Secured'
                              : 'Offline Mode Active',
                          style: TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w600,
                            color: user != null
                                ? AppColors.takenForeground
                                : AppColors.textTertiary,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              if (user != null) ...[
                const SizedBox(height: AppDimensions.stackMd),
                DdButton(
                  label: 'Sync All Data to Cloud Now',
                  icon: const Icon(Icons.sync_rounded),
                  variant: DdButtonVariant.secondary,
                  isLoading: _isSyncing,
                  onPressed: _syncNow,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
