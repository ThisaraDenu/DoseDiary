import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_dimensions.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/widgets/dd_avatar.dart';
import '../../core/widgets/dd_button.dart';
import '../../core/widgets/dd_card.dart';
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
  final ImagePicker _picker = ImagePicker();

  bool _isLoading = true;
  bool _isUploadingPhoto = false;
  bool _isSaving = false;
  bool _isSyncing = false;
  bool _isDirty = false;
  String? _avatarUrl;
  String? _userEmail;
  String? _userId;
  String _savedName = '';

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController();
    _loadProfileData();
  }

  @override
  void dispose() {
    _nameController.dispose();
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
          _savedName = fullName.trim();
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

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);
    final newName = _nameController.text.trim();

    try {
      await AuthService.updateProfile({'full_name': newName});
      _savedName = newName;
      if (mounted) setState(() => _isDirty = false);
      ref.invalidate(userNameProvider);
      ref.invalidate(userAvatarUrlProvider);

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

  Future<void> _showChangePasswordDialog() async {
    final changed = await showDialog<bool>(
      context: context,
      builder: (_) => const _ChangePasswordDialog(),
    );
    if (changed == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Password changed successfully.'),
          backgroundColor: AppColors.takenForeground,
        ),
      );
    }
  }

  Future<void> _showActiveSessionsDialog() async {
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Active Sessions'),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(Icons.phone_android_rounded),
              title: Text('This device'),
              subtitle: Text('Current session'),
            ),
            SizedBox(height: 8),
            Text(
              'Sign out from other devices if you do not recognize a session.',
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Close'),
          ),
          FilledButton.tonal(
            onPressed: () async {
              try {
                await AuthService.signOutOtherSessions();
                if (!dialogContext.mounted || !mounted) return;
                Navigator.of(dialogContext).pop();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Other sessions were signed out.'),
                    backgroundColor: AppColors.takenForeground,
                  ),
                );
              } catch (error) {
                if (!dialogContext.mounted) return;
                ScaffoldMessenger.of(dialogContext).showSnackBar(
                  SnackBar(
                    content: Text('Could not sign out other sessions: $error'),
                    backgroundColor: AppColors.error,
                  ),
                );
              }
            },
            child: const Text('Sign out others'),
          ),
        ],
      ),
    );
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

    return PopScope(
      canPop: !_isDirty,
      onPopInvoked: (didPop) async {
        if (didPop || !_isDirty || !mounted) return;
        final shouldDiscard = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Discard changes?'),
            content: const Text('Your unsaved profile changes will be lost.'),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('Keep editing'),
              ),
              FilledButton(
                onPressed: () => Navigator.of(context).pop(true),
                child: const Text('Discard'),
              ),
            ],
          ),
        );
        if (shouldDiscard == true && context.mounted) {
          Navigator.of(context).pop();
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Profile & Account'),
          backgroundColor: Colors.white,
          elevation: 0,
          scrolledUnderElevation: 1,
        ),
        backgroundColor: const Color(0xFFF9F9F9),
        body: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(
            AppDimensions.screenMargin,
            AppDimensions.screenMargin,
            AppDimensions.screenMargin,
            AppDimensions.screenMargin + 96,
          ),
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
                          Text('Personal Info',
                              style: AppTextStyles.bodyBold()),
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
                        onChanged: (value) {
                          final dirty = value.trim() != _savedName;
                          if (dirty != _isDirty) {
                            setState(() => _isDirty = dirty);
                          }
                        },
                        textInputAction: TextInputAction.done,
                        onFieldSubmitted: (_) => _saveProfile(),
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
                      DdButton(
                        label: 'Save Profile Changes',
                        icon: const Icon(Icons.check_rounded),
                        isLoading: _isSaving,
                        enabled: _isDirty,
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
                        style: AppTextStyles.caption(
                            color: AppColors.textTertiary),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _userEmail ?? 'Not signed in',
                        style:
                            AppTextStyles.bodyLg(color: AppColors.textPrimary),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(
                            user?.emailConfirmedAt != null
                                ? Icons.verified_rounded
                                : Icons.info_outline_rounded,
                            size: 16,
                            color: user?.emailConfirmedAt != null
                                ? AppColors.takenForeground
                                : AppColors.textTertiary,
                          ),
                          const SizedBox(width: 5),
                          Text(
                            user?.emailConfirmedAt != null
                                ? 'Verified'
                                : 'Unverified',
                            style: AppTextStyles.caption(
                              color: user?.emailConfirmedAt != null
                                  ? AppColors.takenForeground
                                  : AppColors.textTertiary,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: AppDimensions.stackSm),
                      const Divider(),
                      const SizedBox(height: AppDimensions.stackSm),
                      Text(
                        'Supabase User ID',
                        style: AppTextStyles.caption(
                            color: AppColors.textTertiary),
                      ),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              _userId ?? 'Local only',
                              overflow: TextOverflow.ellipsis,
                              style: AppTextStyles.caption(
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ),
                          if (_userId != null && user != null)
                            IconButton(
                              tooltip: 'Copy ID',
                              icon: const Icon(Icons.copy_rounded, size: 18),
                              onPressed: () async {
                                await Clipboard.setData(
                                  ClipboardData(text: _userId!),
                                );
                                if (!context.mounted) return;
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('User ID copied.'),
                                  ),
                                );
                              },
                            ),
                        ],
                      ),
                      const SizedBox(height: AppDimensions.stackSm),
                      const Divider(),
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: const Icon(Icons.lock_outline_rounded),
                        title: const Text('Change Password'),
                        subtitle: const Text(
                          'Verify your current password before changing it',
                        ),
                        trailing: const Icon(Icons.chevron_right_rounded),
                        onTap: user == null ? null : _showChangePasswordDialog,
                      ),
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: const Icon(Icons.devices_rounded),
                        title: const Text('Active Sessions'),
                        subtitle: const Text(
                          'Review this device and sign out other sessions',
                        ),
                        trailing: const Icon(Icons.chevron_right_rounded),
                        onTap: user == null ? null : _showActiveSessionsDialog,
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
      ),
    );
  }
}

class _ChangePasswordDialog extends StatefulWidget {
  const _ChangePasswordDialog();

  @override
  State<_ChangePasswordDialog> createState() => _ChangePasswordDialogState();
}

class _ChangePasswordDialogState extends State<_ChangePasswordDialog> {
  final _formKey = GlobalKey<FormState>();
  final _newController = TextEditingController();
  final _confirmController = TextEditingController();

  bool _obscureNew = true;
  bool _obscureConfirm = true;
  bool _isSaving = false;
  String? _errorMessage;

  @override
  void dispose() {
    _newController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isSaving = true;
      _errorMessage = null;
    });

    try {
      await AuthService.changePassword(
        newPassword: _newController.text,
      );
      if (mounted) Navigator.of(context).pop(true);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _isSaving = false;
        _errorMessage = error is PasswordChangeException
            ? error.message
            : 'Unable to change password. Please try again.';
      });
    }
  }

  TextFormField _passwordField({
    required TextEditingController controller,
    required String label,
    required bool obscureText,
    required VoidCallback onToggle,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      obscureText: obscureText,
      validator: validator ??
          (value) => value == null || value.isEmpty
              ? 'Enter your current password'
              : null,
      decoration: InputDecoration(
        labelText: label,
        suffixIcon: IconButton(
          tooltip: obscureText ? 'Show password' : 'Hide password',
          icon: Icon(
            obscureText
                ? Icons.visibility_outlined
                : Icons.visibility_off_outlined,
          ),
          onPressed: onToggle,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Change Password'),
      content: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Choose a new password for your account.',
                ),
              ),
              if (_errorMessage != null) ...[
                const SizedBox(height: 12),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.error.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    _errorMessage!,
                    style: AppTextStyles.caption(color: AppColors.error),
                  ),
                ),
              ],
              const SizedBox(height: 16),
              _passwordField(
                controller: _newController,
                label: 'New password',
                obscureText: _obscureNew,
                onToggle: () => setState(() => _obscureNew = !_obscureNew),
                validator: (value) => value == null || value.length < 8
                    ? 'Use at least 8 characters'
                    : null,
              ),
              const SizedBox(height: 12),
              _passwordField(
                controller: _confirmController,
                label: 'Confirm new password',
                obscureText: _obscureConfirm,
                onToggle: () =>
                    setState(() => _obscureConfirm = !_obscureConfirm),
                validator: (value) => value != _newController.text
                    ? 'Passwords do not match'
                    : null,
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isSaving ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _isSaving ? null : _submit,
          child: _isSaving
              ? const SizedBox(
                  height: 18,
                  width: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Change password'),
        ),
      ],
    );
  }
}
