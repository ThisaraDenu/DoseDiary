import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/router/route_names.dart';
import '../../core/services/permission_service.dart';
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

  @override
  Widget build(BuildContext context) {
    final permState = ref.watch(permissionsControllerProvider);

    final permissionItems = [
      const AppPermissionItem(
        type: AppPermissionType.contacts,
        title: 'Emergency Contacts & Caregivers',
        description:
            'Quickly link family caregivers and emergency contacts without typing numbers manually.',
        icon: Icons.contacts_rounded,
      ),
      const AppPermissionItem(
        type: AppPermissionType.location,
        title: 'Nearby Medical & Pharmacies',
        description:
            'Locate nearby 24/7 pharmacies, urgent clinics, and prescription supply locations near you.',
        icon: Icons.location_on_rounded,
      ),
      const AppPermissionItem(
        type: AppPermissionType.media,
        title: 'Prescriptions & Photos',
        description:
            'Upload doctor prescriptions, medication packaging photos, and profile images.',
        icon: Icons.perm_media_rounded,
      ),
      const AppPermissionItem(
        type: AppPermissionType.camera,
        title: 'Camera & Barcode Scanner',
        description:
            'Scan medication barcodes and take prescription photos directly within the app.',
        icon: Icons.camera_alt_rounded,
      ),
      const AppPermissionItem(
        type: AppPermissionType.calendar,
        title: 'Device Calendar Sync',
        description:
            'Sync scheduled medication dose times and refill dates with your personal calendar.',
        icon: Icons.calendar_month_rounded,
      ),
    ];

    return Scaffold(
      backgroundColor: const Color(0xFFF9F9F9),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF9F9F9),
        elevation: 0,
        scrolledUnderElevation: 0,
        automaticallyImplyLeading: false,
        actions: [
          TextButton(
            onPressed: _finishAndNavigateHome,
            child: const Text(
              'Skip for now',
              style: TextStyle(
                color: Color(0xFF545F73),
                fontWeight: FontWeight.w600,
                fontSize: 14,
              ),
            ),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SafeArea(
        child: permState.isLoading
            ? const Center(
                child: CircularProgressIndicator(color: Color(0xFFB1002C)),
              )
            : Column(
                children: [
                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 20, vertical: 8),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Header Icon Badge
                          Container(
                            width: 52,
                            height: 52,
                            decoration: BoxDecoration(
                              color: const Color(0xFFFFDAD9),
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: const Icon(
                              Icons.verified_user_rounded,
                              color: Color(0xFFB1002C),
                              size: 28,
                            ),
                          ),
                          const SizedBox(height: 16),

                          // Title & Subtitle
                          const Text(
                            'Enable App Permissions',
                            style: TextStyle(
                              color: Color(0xFF1B1B1B),
                              fontSize: 26,
                              fontWeight: FontWeight.w700,
                              letterSpacing: -0.5,
                            ),
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            'To give you the safest, most personalized health tracking experience, DoseDiary requests access to a few device features.',
                            style: TextStyle(
                              color: Color(0xFF545F73),
                              fontSize: 15,
                              height: 1.45,
                              fontWeight: FontWeight.w400,
                            ),
                          ),
                          const SizedBox(height: 24),

                          // Permission Cards List
                          for (final item in permissionItems) ...[
                            _buildPermissionCard(item, permState),
                            const SizedBox(height: 12),
                          ],

                          const SizedBox(height: 12),

                          // Privacy Note
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Icon(
                                Icons.lock_outline_rounded,
                                color: Color(0xFF545F73),
                                size: 16,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'Your privacy is our priority. Permissions are used strictly on-device to support your medication management and caregiver safety network.',
                                  style: TextStyle(
                                    color: const Color(0xFF545F73)
                                        .withOpacity(0.85),
                                    fontSize: 12.5,
                                    height: 1.4,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 20),
                        ],
                      ),
                    ),
                  ),

                  // Bottom Action Buttons
                  Container(
                    padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      border: Border(
                        top: BorderSide(color: Colors.black.withOpacity(0.06)),
                      ),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        SizedBox(
                          width: double.infinity,
                          height: 50,
                          child: ElevatedButton(
                            onPressed: permState.isRequestingAll
                                ? null
                                : (permState.allGranted
                                    ? _finishAndNavigateHome
                                    : () {
                                        HapticFeedback.mediumImpact();
                                        ref
                                            .read(permissionsControllerProvider
                                                .notifier)
                                            .requestAll();
                                      }),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFFDC143C),
                              foregroundColor: Colors.white,
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                            child: permState.isRequestingAll
                                ? const SizedBox(
                                    width: 22,
                                    height: 22,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2.5,
                                      color: Colors.white,
                                    ),
                                  )
                                : Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(
                                        permState.allGranted
                                            ? Icons.arrow_forward_rounded
                                            : Icons.check_circle_outline_rounded,
                                        size: 20,
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                        permState.allGranted
                                            ? 'Continue to DoseDiary'
                                            : 'Allow All Permissions',
                                        style: const TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ],
                                  ),
                          ),
                        ),
                        if (!permState.allGranted) ...[
                          const SizedBox(height: 8),
                          SizedBox(
                            width: double.infinity,
                            height: 42,
                            child: TextButton(
                              onPressed: _finishAndNavigateHome,
                              child: const Text(
                                'Continue to DoseDiary',
                                style: TextStyle(
                                  color: Color(0xFF545F73),
                                  fontSize: 14.5,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  Widget _buildPermissionCard(
      AppPermissionItem item, PermissionsState permState) {
    final isGranted = permState.statuses[item.type] ?? false;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isGranted
              ? const Color(0xFF97F5CC).withOpacity(0.5)
              : const Color(0xFFEEEEEE),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 6,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Icon Box
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: isGranted
                  ? const Color(0xFF97F5CC).withOpacity(0.25)
                  : const Color(0xFFFFDAD9).withOpacity(0.4),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              item.icon,
              color: isGranted
                  ? const Color(0xFF157F5D)
                  : const Color(0xFFB1002C),
              size: 22,
            ),
          ),
          const SizedBox(width: 14),

          // Content Column
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        item.title,
                        style: const TextStyle(
                          color: Color(0xFF1B1B1B),
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),

                    // Status Pill or Grant Button
                    if (isGranted)
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: const Color(0xFF97F5CC),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.check_rounded,
                              size: 13,
                              color: Color(0xFF002115),
                            ),
                            SizedBox(width: 3),
                            Text(
                              'Granted',
                              style: TextStyle(
                                color: Color(0xFF002115),
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      )
                    else
                      InkWell(
                        onTap: () {
                          HapticFeedback.lightImpact();
                          ref
                              .read(permissionsControllerProvider.notifier)
                              .requestSingle(item.type);
                        },
                        borderRadius: BorderRadius.circular(6),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFFDAD9),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: const Text(
                            'Allow',
                            style: TextStyle(
                              color: Color(0xFFB1002C),
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 5),
                Text(
                  item.description,
                  style: const TextStyle(
                    color: Color(0xFF545F73),
                    fontSize: 13,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
