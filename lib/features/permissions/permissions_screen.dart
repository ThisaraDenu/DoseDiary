import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/router/route_names.dart';
import '../../core/services/permission_service.dart';
import '../../core/theme/app_colors.dart';
import '../../main.dart';

class PermissionsScreen extends ConsumerStatefulWidget {
  const PermissionsScreen({super.key});

  @override
  ConsumerState<PermissionsScreen> createState() => _PermissionsScreenState();
}

class _PermissionsScreenState extends ConsumerState<PermissionsScreen>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      ref.read(permissionsControllerProvider.notifier).checkStatuses();
    }
  }

  Future<void> _finishAndNavigateHome() async {
    final prefs = ref.read(sharedPreferencesProvider);
    await PermissionService.markPrompted(prefs);
    if (!mounted) return;
    try {
      context.go(RouteNames.home);
    } catch (_) {}
  }

  Future<void> _handlePrimaryAction(bool isNotificationGranted) async {
    HapticFeedback.lightImpact();
    if (!isNotificationGranted) {
      await ref
          .read(permissionsControllerProvider.notifier)
          .requestSingle(AppPermissionType.notification);
      // If granted after request, or user proceeds
      if (mounted) {
        final state = ref.read(permissionsControllerProvider);
        if (state.statuses[AppPermissionType.notification] ?? false) {
          await _finishAndNavigateHome();
        }
      }
    } else {
      await _finishAndNavigateHome();
    }
  }

  @override
  Widget build(BuildContext context) {
    final permState = ref.watch(permissionsControllerProvider);
    final isNotificationGranted =
        permState.statuses[AppPermissionType.notification] ?? false;
    final isContactsGranted =
        permState.statuses[AppPermissionType.contacts] ?? false;
    final isCameraGranted =
        permState.statuses[AppPermissionType.camera] ?? false;
    final isMicGranted =
        permState.statuses[AppPermissionType.microphone] ?? false;

    return Scaffold(
      backgroundColor: AppColors.onboardingBackground,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        automaticallyImplyLeading: false,
        leading: IconButton(
          icon: const Icon(
            Icons.chevron_left_rounded,
            size: 32,
            color: Color(0xFF0F172A),
          ),
          onPressed: () {
            if (context.canPop()) {
              context.pop();
            } else {
              _finishAndNavigateHome();
            }
          },
        ),
        centerTitle: true,
        title: Text(
          'App permissions',
          style: GoogleFonts.plusJakartaSans(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: const Color(0xFF0F172A),
          ),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 20),
            child: Image.asset(
              'assets/images/splash_logo.png',
              height: 26,
              width: 26,
              fit: BoxFit.contain,
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const SizedBox(height: 12),

              // ── Hero Illustration Bell ──────────────────────────────
              Center(
                child: Image.asset(
                  'assets/images/permissions_hero_bell.png',
                  width: 96,
                  height: 96,
                  fit: BoxFit.contain,
                ),
              ),

              const SizedBox(height: 16),

              // ── Headline & Subtitle ─────────────────────────────────
              Text(
                'Helpful reminders.\nYou’re in control.',
                textAlign: TextAlign.center,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 28,
                  fontWeight: FontWeight.w800,
                  height: 1.18,
                  letterSpacing: -0.6,
                  color: const Color(0xFF0F172A),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Choose the access that works for you.',
                textAlign: TextAlign.center,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 15.5,
                  fontWeight: FontWeight.w400,
                  color: const Color(0xFF4B5563),
                ),
              ),

              const SizedBox(height: 24),

              // ── Card 1: Recommended Notifications ──────────────────
              InkWell(
                onTap: isNotificationGranted
                    ? null
                    : () {
                        HapticFeedback.lightImpact();
                        ref
                            .read(permissionsControllerProvider.notifier)
                            .requestSingle(AppPermissionType.notification);
                      },
                borderRadius: BorderRadius.circular(18),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(
                      color: const Color(0xFFE8E5DD),
                      width: 1.0,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.02),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // "Recommended" Pill Badge
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.primaryAction,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          'Recommended',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),

                      // Notification Content Row
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          const Icon(
                            Icons.notifications_none_rounded,
                            size: 34,
                            color: Color(0xFF0F172A),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Notifications',
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 16.5,
                                    fontWeight: FontWeight.w700,
                                    color: const Color(0xFF0F172A),
                                  ),
                                ),
                                const SizedBox(height: 3),
                                Text(
                                  'Get a reminder when your medication is due.',
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 13,
                                    height: 1.35,
                                    color: const Color(0xFF4B5563),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 10),

                          // Status on the right
                          if (isNotificationGranted)
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(
                                  Icons.check_circle_rounded,
                                  size: 18,
                                  color: Color(0xFF059669),
                                ),
                                const SizedBox(width: 5),
                                Text(
                                  'Enabled',
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 12.5,
                                    fontWeight: FontWeight.w600,
                                    color: const Color(0xFF059669),
                                  ),
                                ),
                              ],
                            )
                          else
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  width: 16,
                                  height: 16,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: const Color(0xFF94A3B8),
                                      width: 1.5,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  'Not enabled',
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 12.5,
                                    fontWeight: FontWeight.w500,
                                    color: const Color(0xFF4B5563),
                                  ),
                                ),
                              ],
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 24),

              // ── Section 2: Optional access ──────────────────────────
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Optional access',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: const Color(0xFF0F172A),
                  ),
                ),
              ),
              const SizedBox(height: 4),
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Only requested when you use a feature.',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 14.5,
                    fontWeight: FontWeight.w400,
                    color: const Color(0xFF4B5563),
                  ),
                ),
              ),
              const SizedBox(height: 12),

              // ── Card 2: Optional Access Items ───────────────────────
              Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(
                    color: const Color(0xFFE8E5DD),
                    width: 1.0,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.02),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    // Item 1: Contacts
                    _buildOptionalItem(
                      icon: Icons.person_outline_rounded,
                      title: 'Contacts',
                      subtitle: 'Find your caregiver easily',
                      isGranted: isContactsGranted,
                      onTap: () {
                        HapticFeedback.lightImpact();
                        ref
                            .read(permissionsControllerProvider.notifier)
                            .requestSingle(AppPermissionType.contacts);
                      },
                    ),

                    const Divider(
                      height: 1,
                      thickness: 1,
                      color: Color(0xFFF1EFEA),
                      indent: 16,
                      endIndent: 16,
                    ),

                    // Item 2: Camera
                    _buildOptionalItem(
                      icon: Icons.camera_alt_outlined,
                      title: 'Camera',
                      subtitle: 'Scan a caregiver invite code',
                      isGranted: isCameraGranted,
                      onTap: () {
                        HapticFeedback.lightImpact();
                        ref
                            .read(permissionsControllerProvider.notifier)
                            .requestSingle(AppPermissionType.camera);
                      },
                    ),

                    const Divider(
                      height: 1,
                      thickness: 1,
                      color: Color(0xFFF1EFEA),
                      indent: 16,
                      endIndent: 16,
                    ),

                    // Item 3: Microphone
                    _buildOptionalItem(
                      icon: Icons.mic_none_rounded,
                      title: 'Microphone',
                      subtitle: 'Use voice input',
                      isGranted: isMicGranted,
                      onTap: () {
                        HapticFeedback.lightImpact();
                        ref
                            .read(permissionsControllerProvider.notifier)
                            .requestSingle(AppPermissionType.microphone);
                      },
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 18),

              // ── Security Note ──────────────────────────────────────
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.lock_outline_rounded,
                    size: 14,
                    color: Color(0xFF374151),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'You can change access in Settings.',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w500,
                      color: const Color(0xFF374151),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 20),

              // ── Primary Action Button ──────────────────────────────
              SizedBox(
                width: double.infinity,
                height: 54,
                child: ElevatedButton(
                  onPressed: () =>
                      _handlePrimaryAction(isNotificationGranted),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryAction,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: Text(
                    isNotificationGranted
                        ? 'Continue to DoseDiary'
                        : 'Enable notifications',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 10),

              // ── Secondary Action Link ("Not now") ───────────────────
              TextButton(
                onPressed: _finishAndNavigateHome,
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                ),
                child: Text(
                  'Not now',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: AppColors.primaryAction,
                  ),
                ),
              ),

              const SizedBox(height: 12),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildOptionalItem({
    required IconData icon,
    required String title,
    required String subtitle,
    required bool isGranted,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Icon(
              icon,
              size: 26,
              color: const Color(0xFF0F172A),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF0F172A),
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    subtitle,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 13.5,
                      color: const Color(0xFF4B5563),
                    ),
                  ),
                ],
              ),
            ),
            if (isGranted)
              const Icon(
                Icons.check_circle_rounded,
                size: 20,
                color: Color(0xFF059669),
              )
            else
              const Icon(
                Icons.chevron_right_rounded,
                size: 24,
                color: Color(0xFF64748B),
              ),
          ],
        ),
      ),
    );
  }
}
