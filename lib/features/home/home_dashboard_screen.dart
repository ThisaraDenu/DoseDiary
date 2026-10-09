import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../core/router/route_names.dart';
import '../../core/services/phone_dialer_service.dart';
import '../../core/utils/presence_formatters.dart';
import '../../core/widgets/dd_avatar.dart';
export '../../data/repositories/app_repositories.dart';
import '../../data/local/database_provider.dart';
import '../../data/repositories/app_repositories.dart';
import '../../data/repositories/notification_repository.dart';
import '../../data/local/models/app_models.dart';
import '../../data/local/models/dose_status.dart';
import '../../data/remote/supabase_sync_service.dart';
import '../../data/remote/auth_service.dart';
import 'caregiver_home_view.dart';

// â”€â”€ Home Providers â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

final userAvatarUrlProvider = FutureProvider<String?>((ref) async {
  final profile = await ref.watch(userProfileProvider.future);
  return profile?['avatar_url'] as String?;
});

String _extractFirstName(String name) {
  final trimmed = name.trim();
  final parts = trimmed.split(RegExp(r'\s+'));
  if (parts.isNotEmpty) {
    final first = parts.first;
    final lower = first.toLowerCase().replaceAll('.', '');
    if ((lower == 'mr' ||
            lower == 'mrs' ||
            lower == 'ms' ||
            lower == 'dr' ||
            lower == 'prof') &&
        parts.length > 1) {
      return parts[1];
    }
    return first;
  }
  return trimmed;
}

final userNameProvider = FutureProvider<String>((ref) async {
  final user = AuthService.currentUser;
  if (user == null) return 'Ishara';
  final profile = await ref.watch(userProfileProvider.future);
  final fullName = profile?['full_name'] as String?;
  if (fullName != null && fullName.trim().isNotEmpty) {
    return _extractFirstName(fullName);
  }
  final metaName = user.userMetadata?['full_name'] as String?;
  if (metaName != null && metaName.trim().isNotEmpty) {
    return _extractFirstName(metaName);
  }
  if (user.email != null && user.email!.contains('@')) {
    final emailPrefix = user.email!.split('@').first;
    if (emailPrefix.isNotEmpty) {
      final clean = emailPrefix.split(RegExp(r'[._\s+]')).first;
      if (clean.isNotEmpty) {
        return clean[0].toUpperCase() + clean.substring(1);
      }
    }
  }
  return 'Ishara';
});

final userProfileProvider = FutureProvider<Map<String, dynamic>?>((ref) async {
  ref.watch(accountSessionEpochProvider);
  return AuthService.getProfile();
});

final userAgeProvider = FutureProvider<int?>((ref) async {
  final profile = await ref.watch(userProfileProvider.future);
  return AuthService.calculateAge(profile?['date_of_birth'] as String?);
});

final userGenderProvider = FutureProvider<String?>((ref) async {
  final profile = await ref.watch(userProfileProvider.future);
  return profile?['gender'] as String?;
});

final userPhoneProvider = FutureProvider<String?>((ref) async {
  final profile = await ref.watch(userProfileProvider.future);
  return profile?['phone_number'] as String?;
});

// (Providers todayOccurrencesProvider, todayMedicationsProvider, todayAdherenceProvider,
// lowStockProvider, weeklyAdherenceProvider are exported from app_repositories.dart)

// â”€â”€ Screen â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

class HomeDashboardScreen extends ConsumerStatefulWidget {
  const HomeDashboardScreen({super.key});

  @override
  ConsumerState<HomeDashboardScreen> createState() =>
      _HomeDashboardScreenState();
}

class _HomeDashboardScreenState extends ConsumerState<HomeDashboardScreen> {
  bool _isPatientMode = true;
  String? _toastMessage;
  Timer? _toastTimer;

  @override
  void dispose() {
    _toastTimer?.cancel();
    super.dispose();
  }

  void _showCaregiverToast(String message) {
    _toastTimer?.cancel();
    setState(() {
      _toastMessage = message;
    });
    _toastTimer = Timer(const Duration(seconds: 4), () {
      if (mounted) {
        setState(() {
          _toastMessage = null;
        });
      }
    });
  }

  Widget _buildFloatingToast() {
    if (_toastMessage == null) return const SizedBox.shrink();
    return Positioned(
      bottom: 20,
      left: 20,
      right: 20,
      child: Material(
        color: Colors.transparent,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: const Color(0xFF303030),
            borderRadius: BorderRadius.circular(14),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.25),
                blurRadius: 16,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            children: [
              const Icon(
                Icons.check_circle_rounded,
                color: Color(0xFF97F5CC),
                size: 22,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  _toastMessage!,
                  style: const TextStyle(
                    color: Color(0xFFF1F1F1),
                    fontSize: 13.5,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              InkWell(
                onTap: () => setState(() => _toastMessage = null),
                borderRadius: BorderRadius.circular(16),
                child: const Padding(
                  padding: EdgeInsets.all(4),
                  child: Icon(
                    Icons.close_rounded,
                    color: Color(0xFFDADADA),
                    size: 18,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final occsAsync = ref.watch(todayOccurrencesProvider);
    final medsAsync = ref.watch(todayMedicationsProvider);
    final adherenceAsync = ref.watch(todayAdherenceProvider);
    final lowStockAsync = ref.watch(lowStockProvider);
    final userNameAsync = ref.watch(userNameProvider);
    final userName = userNameAsync.valueOrNull ?? 'Ishara';
    final avatarUrlAsync = ref.watch(userAvatarUrlProvider);
    final avatarUrl = avatarUrlAsync.valueOrNull;
    final unreadNotifications =
        ref.watch(unreadNotificationCountProvider).valueOrNull ?? 0;

    final now = DateTime.now();
    final dateStr = DateFormat('EEEE, d MMMM yyyy').format(now);
    final hour = now.hour;
    String greetingPrefix = 'Good Morning';
    if (hour >= 12 && hour < 17) {
      greetingPrefix = 'Good Afternoon';
    } else if (hour >= 17) {
      greetingPrefix = 'Good Evening';
    }
    final greetingText = '$greetingPrefix, $userName!';

    return Scaffold(
      backgroundColor: const Color(0xFFF9F9F9),
      body: Stack(
        children: [
          RefreshIndicator(
            color: const Color(0xFFB1002C),
            onRefresh: () async {
              await SupabaseSyncService.syncAll();
              ref.invalidate(userNameProvider);
              ref.invalidate(userAvatarUrlProvider);
              ref.invalidate(todayOccurrencesProvider);
              ref.invalidate(todayMedicationsProvider);
              ref.invalidate(todayAdherenceProvider);
              ref.invalidate(lowStockProvider);
              ref.invalidate(weeklyAdherenceProvider);
              ref.invalidate(lowestStockMedicationProvider);
              ref.invalidate(patientCaregiversListProvider);
              ref.invalidate(allocatedPatientsProvider);
              ref.invalidate(patientPermissionsProvider);
              ref.invalidate(caregiverPatientDataSyncProvider);
              ref.invalidate(caregiverPatientMedicationsProvider);
              ref.invalidate(caregiverPatientOccurrencesProvider);
              ref.invalidate(caregiverPatientWeeklyAdherenceProvider);
              ref.invalidate(caregiverPatientLowStockProvider);
              ref.invalidate(caregiverPatientLowestStockMedicationProvider);
              ref.invalidate(notificationsProvider);
              ref.invalidate(unreadNotificationCountProvider);
            },
            child: CustomScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              slivers: [
                // â”€â”€ Sticky Header / App Bar â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
                SliverAppBar(
                  backgroundColor: const Color(0xFFF9F9F9),
                  pinned: true,
                  elevation: 0,
                  scrolledUnderElevation: 1,
                  shadowColor: Colors.black.withOpacity(0.04),
                  titleSpacing: 20,
                  title: const Row(
                    children: [
                      Icon(
                        Icons.medical_services_rounded,
                        color: Color(0xFFB1002C),
                        size: 28,
                      ),
                      SizedBox(width: 8),
                      Text(
                        'Home',
                        style: TextStyle(
                          color: Color(0xFF1B1B1B),
                          fontSize: 24,
                          fontWeight: FontWeight.w700,
                          letterSpacing: -0.3,
                        ),
                      ),
                    ],
                  ),
                  actions: [
                    IconButton(
                      icon: Stack(
                        clipBehavior: Clip.none,
                        children: [
                          const Icon(
                            Icons.notifications_none_rounded,
                            color: Color(0xFF1B1B1B),
                            size: 26,
                          ),
                          if (unreadNotifications > 0)
                            Positioned(
                              right: -7,
                              top: -6,
                              child: Container(
                                constraints: const BoxConstraints(
                                  minWidth: 18,
                                  minHeight: 18,
                                ),
                                padding:
                                    const EdgeInsets.symmetric(horizontal: 4),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFDC143C),
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(
                                    color: const Color(0xFFF9F9F9),
                                    width: 1.5,
                                  ),
                                ),
                                alignment: Alignment.center,
                                child: Text(
                                  unreadNotifications > 99
                                      ? '99+'
                                      : '$unreadNotifications',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 9,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                      onPressed: () =>
                          context.push(RouteNames.notificationCentre),
                      tooltip: 'Notifications',
                    ),
                    const SizedBox(width: 8),
                  ],
                ),

                // â”€â”€ Main Content Body â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 110),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // 1. Greeting & Profile Section
                        _buildGreetingSection(dateStr, greetingText, avatarUrl),
                        const SizedBox(height: 20),

                        // 2. Dashboard Mode Switcher (Active View)
                        _buildModeSwitcher(userName),
                        const SizedBox(height: 20),

                        if (_isPatientMode) ...[
                          // 3. Next Medication Card
                          _buildNextMedicationCard(occsAsync, medsAsync),
                          const SizedBox(height: 24),

                          // 4. Today's Schedule Section
                          _buildTodayScheduleSection(occsAsync, medsAsync),
                          const SizedBox(height: 24),

                          // 5. 2-Column Stats Grid (Adherence & Refills)
                          _buildStatsGrid(adherenceAsync, lowStockAsync),
                          const SizedBox(height: 20),

                          // 6. Caregiver Connected Card
                          _buildCaregiverConnectedCard(),
                          const SizedBox(height: 24),
                        ] else ...[
                          // 3-6. Caregiver Mode View
                          CaregiverHomeView(
                            userName: userName,
                            avatarUrl: avatarUrl,
                            onShowToast: _showCaregiverToast,
                          ),
                          const SizedBox(height: 24),
                        ],
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (_toastMessage != null) _buildFloatingToast(),
        ],
      ),
    );
  }

  // â”€â”€ 1. Greeting Section â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
  Widget _buildGreetingSection(
    String dateStr,
    String greetingText,
    String? avatarUrl,
  ) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Date Pill
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFFE8E8E8),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.calendar_today_rounded,
                      size: 15,
                      color: Color(0xFFB1002C),
                    ),
                    const SizedBox(width: 6),
                    Flexible(
                      child: Text(
                        dateStr,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Color(0xFF545F73),
                          fontSize: 12.5,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 6),

              // Greeting Heading
              Text(
                greetingText,
                style: const TextStyle(
                  color: Color(0xFF1B1B1B),
                  fontSize: 24,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.4,
                ),
              ),
              const SizedBox(height: 2),

              // Subtitle
              const Text(
                'Stay healthy, stay on track.',
                style: TextStyle(
                  color: Color(0xFF545F73),
                  fontSize: 15,
                  fontWeight: FontWeight.w400,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 14),

        // Profile avatar with active badge (navigates to user profile screen on tap)
        InkWell(
          onTap: () => context.push(RouteNames.settingsAccount),
          borderRadius: BorderRadius.circular(28),
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              DdAvatar(
                avatarUrl: avatarUrl,
                size: 56,
                borderWidth: 2.5,
                borderColor: Colors.white,
              ),
              // Status dot
              Positioned(
                bottom: 0,
                right: 0,
                child: Container(
                  width: 15,
                  height: 15,
                  decoration: BoxDecoration(
                    color: const Color(0xFF157F5D),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: const Color(0xFFF9F9F9),
                      width: 2.5,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // â”€â”€ 2. Mode Switcher â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
  Widget _buildModeSwitcher(String userName) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFEEEEEE)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 6,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Column(
        children: [
          // Header row
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Row(
                  children: [
                    Icon(
                      Icons.switch_account_rounded,
                      size: 18,
                      color: Color(0xFFB1002C),
                    ),
                    SizedBox(width: 6),
                    Text(
                      'ACTIVE VIEW',
                      style: TextStyle(
                        color: Color(0xFF545F73),
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.8,
                      ),
                    ),
                  ],
                ),
                Flexible(
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 2.5),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFDAD9),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 6,
                          height: 6,
                          decoration: const BoxDecoration(
                            color: Color(0xFFB1002C),
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 5),
                        Flexible(
                          child: Text(
                            _isPatientMode
                                ? '$userName (Patient)'
                                : '$userName (Caregiver)',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Color(0xFF40000A),
                              fontSize: 11.5,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),

          // Segmented Buttons
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: const Color(0xFFF3F3F3),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                // Patient Mode Button
                Expanded(
                  child: InkWell(
                    onTap: () {
                      if (!_isPatientMode) {
                        setState(() => _isPatientMode = true);
                      }
                    },
                    borderRadius: BorderRadius.circular(6),
                    child: Container(
                      height: 44,
                      decoration: BoxDecoration(
                        color:
                            _isPatientMode ? Colors.white : Colors.transparent,
                        borderRadius: BorderRadius.circular(6),
                        border: _isPatientMode
                            ? Border.all(
                                color: const Color(0xFFB1002C).withOpacity(0.2))
                            : null,
                        boxShadow: _isPatientMode
                            ? [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.04),
                                  blurRadius: 4,
                                  offset: const Offset(0, 1),
                                ),
                              ]
                            : null,
                      ),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.person_rounded,
                                size: 19,
                                color: _isPatientMode
                                    ? const Color(0xFFB1002C)
                                    : const Color(0xFF545F73),
                              ),
                              const SizedBox(width: 6),
                              Text(
                                'Patient Mode',
                                style: TextStyle(
                                  color: _isPatientMode
                                      ? const Color(0xFFB1002C)
                                      : const Color(0xFF545F73),
                                  fontWeight: _isPatientMode
                                      ? FontWeight.w700
                                      : FontWeight.w600,
                                  fontSize: 13.5,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 6),

                // Caregiver Mode Button
                Expanded(
                  child: InkWell(
                    onTap: () {
                      if (_isPatientMode) {
                        ref.invalidate(allocatedPatientsProvider);
                        ref.invalidate(caregiverPatientDataSyncProvider);
                        ref.invalidate(caregiverPatientMedicationsProvider);
                        ref.invalidate(caregiverPatientOccurrencesProvider);
                        ref.invalidate(caregiverPatientWeeklyAdherenceProvider);
                        ref.invalidate(caregiverPatientLowStockProvider);
                        ref.invalidate(
                            caregiverPatientLowestStockMedicationProvider);
                        setState(() => _isPatientMode = false);
                      }
                    },
                    borderRadius: BorderRadius.circular(6),
                    child: Container(
                      height: 44,
                      decoration: BoxDecoration(
                        color:
                            !_isPatientMode ? Colors.white : Colors.transparent,
                        borderRadius: BorderRadius.circular(6),
                        border: !_isPatientMode
                            ? Border.all(
                                color: const Color(0xFFDC143C),
                                width: 1.2,
                              )
                            : null,
                        boxShadow: !_isPatientMode
                            ? [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.04),
                                  blurRadius: 4,
                                  offset: const Offset(0, 1),
                                ),
                              ]
                            : null,
                      ),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.volunteer_activism_rounded,
                                size: 19,
                                color: !_isPatientMode
                                    ? const Color(0xFFB1002C)
                                    : const Color(0xFF545F73),
                              ),
                              const SizedBox(width: 6),
                              Text(
                                'Caregiver Mode',
                                style: TextStyle(
                                  color: !_isPatientMode
                                      ? const Color(0xFFB1002C)
                                      : const Color(0xFF545F73),
                                  fontWeight: !_isPatientMode
                                      ? FontWeight.w700
                                      : FontWeight.w600,
                                  fontSize: 13.5,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // â”€â”€ 3. Next Medication Card â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
  Widget _buildNextMedicationCard(
    AsyncValue<List<DoseOccurrence>> occsAsync,
    AsyncValue<List<Medication>> medsAsync,
  ) {
    final occs = occsAsync.asData?.value ?? [];
    final meds = medsAsync.asData?.value ?? [];

    final actionable = occs.where((o) => o.status.isActionable).toList()
      ..sort((a, b) => a.scheduledAt.compareTo(b.scheduledAt));

    // Case 1: Empty state - user has not added any medications to the database
    if (meds.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFDAD9),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Text(
                    'MEDICATIONS',
                    style: TextStyle(
                      color: Color(0xFF40000A),
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.8,
                    ),
                  ),
                ),
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFDAD9).withOpacity(0.4),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.medication_outlined,
                    color: Color(0xFFB1002C),
                    size: 28,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            const Text(
              'No Medications Added Yet',
              style: TextStyle(
                color: Color(0xFF1B1B1B),
                fontSize: 22,
                fontWeight: FontWeight.w700,
                letterSpacing: -0.3,
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              'Add your prescriptions to track your daily doses, schedules, and adherence.',
              style: TextStyle(
                color: Color(0xFF545F73),
                fontSize: 14.5,
                fontWeight: FontWeight.w400,
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () => context.push(RouteNames.addMedication),
                icon: const Icon(Icons.add_rounded, size: 20),
                label: const Text(
                  'Add Your First Medication',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFDC143C),
                  foregroundColor: Colors.white,
                  elevation: 0,
                  minimumSize: const Size(double.infinity, 48),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    }

    // Case 2: All doses for today have already been completed or no doses scheduled today
    if (actionable.isEmpty) {
      final bool hadDosesToday = occs.isNotEmpty;
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFF97F5CC),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    hadDosesToday ? 'SCHEDULE COMPLETED' : 'NO DOSES DUE',
                    style: const TextStyle(
                      color: Color(0xFF002115),
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.8,
                    ),
                  ),
                ),
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: const Color(0xFF97F5CC).withOpacity(0.3),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.check_circle_rounded,
                    color: Color(0xFF157F5D),
                    size: 28,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              hadDosesToday
                  ? 'All Caught Up for Today!'
                  : 'No Doses Scheduled for Today',
              style: const TextStyle(
                color: Color(0xFF1B1B1B),
                fontSize: 22,
                fontWeight: FontWeight.w700,
                letterSpacing: -0.3,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              hadDosesToday
                  ? 'You have completed all scheduled medication doses for today. Excellent adherence!'
                  : 'You have no scheduled medication doses due today. Check your medications or schedule.',
              style: const TextStyle(
                color: Color(0xFF545F73),
                fontSize: 14.5,
                fontWeight: FontWeight.w400,
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () => context.push(RouteNames.medications),
                icon: const Icon(Icons.medication_rounded, size: 18),
                label: const Text(
                  'View Medications',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                ),
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFFB1002C),
                  side: const BorderSide(color: Color(0xFFB1002C)),
                  minimumSize: const Size(double.infinity, 44),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    }

    // Case 3: Real upcoming dose due today (actionable is guaranteed not empty)
    final next = actionable.first;
    final matchedMed = meds.where((m) => m.id == next.medicationId).firstOrNull;

    final medName = matchedMed?.name ?? 'Scheduled Medication';
    final medDetails = matchedMed != null
        ? '${matchedMed.displayStrength} • ${matchedMed.displayDose}'
        : '1 Dose';
    final medInstructions = (matchedMed?.instructions != null &&
            matchedMed!.instructions!.trim().isNotEmpty)
        ? matchedMed.instructions!.trim()
        : 'Take as prescribed';
    final scheduledTime =
        DateFormat('h:mm a').format(next.scheduledAt.toLocal());

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Top row: Badge + Icon
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFDAD9),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Text(
                  'NEXT MEDICATION',
                  style: TextStyle(
                    color: Color(0xFF40000A),
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.8,
                  ),
                ),
              ),
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: const Color(0xFFFFDAD9).withOpacity(0.4),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.medication_rounded,
                  color: Color(0xFFB1002C),
                  size: 28,
                ),
              ),
            ],
          ),
          if (matchedMed?.imageUrl?.trim().isNotEmpty ?? false) ...[
            const SizedBox(height: 16),
            _buildNextMedicationImage(matchedMed!.imageUrl),
            const SizedBox(height: 16),
          ] else
            const SizedBox(height: 8),

          // Medication Title & Dosage
          Text(
            medName,
            style: const TextStyle(
              color: Color(0xFF1B1B1B),
              fontSize: 24,
              fontWeight: FontWeight.w700,
              letterSpacing: -0.3,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            medDetails,
            style: const TextStyle(
              color: Color(0xFF545F73),
              fontSize: 16,
              fontWeight: FontWeight.w400,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            medInstructions,
            style: const TextStyle(
              color: Color(0xFF5C3F3F),
              fontSize: 14,
              fontWeight: FontWeight.w400,
            ),
          ),
          const SizedBox(height: 16),

          // Scheduled time
          Container(
            padding: const EdgeInsets.only(top: 14),
            decoration: const BoxDecoration(
              border: Border(
                top: BorderSide(color: Color(0xFFEEEEEE), width: 1),
              ),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.schedule_rounded,
                  color: Color(0xFFB1002C),
                  size: 24,
                ),
                const SizedBox(width: 8),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Scheduled',
                      style: TextStyle(
                        color: Color(0xFF545F73),
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      scheduledTime,
                      style: const TextStyle(
                        color: Color(0xFF1B1B1B),
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // â”€â”€ 4. Today's Schedule Section â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
  Widget _buildNextMedicationImage(String? imageUrl) {
    Widget fallback() => Container(
          color: const Color(0xFFFFE8EC),
          alignment: Alignment.center,
          child: const Icon(
            Icons.medication_rounded,
            color: Color(0xFFB1002C),
            size: 48,
          ),
        );

    Widget image = fallback();
    final url = imageUrl?.trim();
    if (url != null && url.isNotEmpty) {
      if (url.startsWith('data:image')) {
        try {
          final separator = url.indexOf(',');
          if (separator >= 0) {
            image = Image.memory(
              base64Decode(url.substring(separator + 1)),
              key: const ValueKey('next-medication-image'),
              width: double.infinity,
              height: 156,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => fallback(),
            );
          }
        } catch (_) {}
      } else if (url.startsWith('http://') || url.startsWith('https://')) {
        image = Image.network(
          url,
          key: const ValueKey('next-medication-image'),
          width: double.infinity,
          height: 156,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => fallback(),
        );
      }
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: SizedBox(
        width: double.infinity,
        height: 156,
        child: image,
      ),
    );
  }

  Widget _buildTodayScheduleSection(
    AsyncValue<List<DoseOccurrence>> occsAsync,
    AsyncValue<List<Medication>> medsAsync,
  ) {
    final allOccurrences = occsAsync.asData?.value ?? [];
    final occs = allOccurrences
        .where(
          (occ) =>
              occ.status == DoseStatus.pending ||
              occ.status == DoseStatus.snoozed,
        )
        .toList()
      ..sort((a, b) {
        final aTime = a.status == DoseStatus.snoozed && a.snoozeUntil != null
            ? a.snoozeUntil!
            : a.scheduledAt;
        final bTime = b.status == DoseStatus.snoozed && b.snoozeUntil != null
            ? b.snoozeUntil!
            : b.scheduledAt;
        return aTime.compareTo(bTime);
      });
    final meds = medsAsync.asData?.value ?? [];

    return Column(
      children: [
        // Section Header
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Expanded(
              child: Text(
                "Today's Schedule",
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: Color(0xFF1B1B1B),
                  fontSize: 19,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.2,
                ),
              ),
            ),
            const SizedBox(width: 8),
            InkWell(
              onTap: () => context.go(RouteNames.medications),
              borderRadius: BorderRadius.circular(6),
              child: const Padding(
                padding: EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                child: Row(
                  children: [
                    Text(
                      'See All',
                      style: TextStyle(
                        color: Color(0xFFB1002C),
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Icon(
                      Icons.chevron_right_rounded,
                      color: Color(0xFFB1002C),
                      size: 18,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),

        // Real Schedule List or Clean Empty State
        if (occs.isNotEmpty)
          Column(
            children: [
              for (int i = 0; i < occs.length; i++) ...[
                if (i > 0) const SizedBox(height: 8),
                () {
                  final occ = occs[i];
                  final med =
                      meds.where((m) => m.id == occ.medicationId).firstOrNull;
                  final title = med?.name ?? 'Medication';
                  final timeStr =
                      DateFormat('h:mm a').format(occ.scheduledAt.toLocal());
                  final snoozeTime = occ.snoozeUntil == null
                      ? null
                      : DateFormat('h:mm a').format(occ.snoozeUntil!.toLocal());
                  final strengthStr = med != null ? med.displayStrength : '';
                  final scheduleText = occ.status == DoseStatus.snoozed
                      ? 'Snoozed until ${snoozeTime ?? timeStr}'
                      : timeStr;
                  final subtitle = strengthStr.isNotEmpty
                      ? '$strengthStr • $scheduleText'
                      : scheduleText;

                  return _buildScheduleItem(
                    occurrenceId: occ.id,
                    title: title,
                    subtitle: subtitle,
                    imageUrl: med?.imageUrl,
                    status: occ.status,
                    onTap: () => context.push('/reminder/${occ.id}'),
                  );
                }(),
              ],
            ],
          )
        else if (allOccurrences.isNotEmpty)
          _buildCompletedScheduleState()
        else
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFEEEEEE)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.02),
                  blurRadius: 6,
                  offset: const Offset(0, 1),
                ),
              ],
            ),
            child: Column(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFDAD9).withOpacity(0.5),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.event_available_rounded,
                    color: Color(0xFFB1002C),
                    size: 24,
                  ),
                ),
                const SizedBox(height: 10),
                const Text(
                  'No medications scheduled for today',
                  style: TextStyle(
                    color: Color(0xFF1B1B1B),
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Add your medications to see today\'s dose schedule here.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Color(0xFF545F73),
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: () => context.push(RouteNames.addMedication),
                  icon: const Icon(Icons.add, size: 16),
                  label: const Text('Add Medication'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFFB1002C),
                    side: const BorderSide(color: Color(0xFFB1002C)),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildCompletedScheduleState() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFEEEEEE)),
      ),
      child: Column(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: const BoxDecoration(
              color: Color(0xFFE8F7F0),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.done_all_rounded,
              color: Color(0xFF157F5D),
              size: 24,
            ),
          ),
          const SizedBox(height: 10),
          const Text(
            'You are all caught up',
            style: TextStyle(
              color: Color(0xFF1B1B1B),
              fontSize: 15,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Upcoming and snoozed medication reminders will appear here.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Color(0xFF545F73),
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildScheduleMedicationImage({
    required String? imageUrl,
    required Color backgroundColor,
    required Color iconColor,
    required IconData fallbackIcon,
  }) {
    Widget fallback() => Container(
          color: backgroundColor,
          child: Icon(fallbackIcon, color: iconColor, size: 25),
        );

    Widget image = fallback();
    final url = imageUrl?.trim();
    if (url != null && url.isNotEmpty) {
      if (url.startsWith('data:image')) {
        try {
          final separator = url.indexOf(',');
          if (separator >= 0) {
            image = Image.memory(
              base64Decode(url.substring(separator + 1)),
              key: const ValueKey('schedule-medication-image'),
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => fallback(),
            );
          }
        } catch (_) {}
      } else if (url.startsWith('http://') || url.startsWith('https://')) {
        image = Image.network(
          url,
          key: const ValueKey('schedule-medication-image'),
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => fallback(),
        );
      }
    }

    return Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFEEEEEE)),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(11),
        child: image,
      ),
    );
  }

  Widget _buildScheduleItem({
    required String occurrenceId,
    required String title,
    required String subtitle,
    required String? imageUrl,
    required DoseStatus status,
    VoidCallback? onTap,
  }) {
    final isSnoozed = status == DoseStatus.snoozed;

    final iconBg =
        isSnoozed ? const Color(0xFFFFF1DB) : const Color(0xFFFFE8EC);
    final iconColor =
        isSnoozed ? const Color(0xFF9A5A00) : const Color(0xFFB1002C);
    final iconData = isSnoozed ? Icons.alarm_rounded : Icons.medication_rounded;

    final badgeBg =
        isSnoozed ? const Color(0xFFFFF1DB) : const Color(0xFFFFE8EC);
    final badgeColor =
        isSnoozed ? const Color(0xFF9A5A00) : const Color(0xFFB1002C);
    final badgeIcon = isSnoozed ? Icons.alarm_rounded : Icons.schedule_rounded;
    final badgeText = isSnoozed ? 'Snoozed' : 'Upcoming';

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.03),
              blurRadius: 6,
              offset: const Offset(0, 1),
            ),
          ],
        ),
        child: Row(
          children: [
            _buildScheduleMedicationImage(
              imageUrl: imageUrl,
              backgroundColor: iconBg,
              iconColor: iconColor,
              fallbackIcon: iconData,
            ),
            const SizedBox(width: 14),

            // Titles
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      color: Color(0xFF1B1B1B),
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 1),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      color: Color(0xFF545F73),
                      fontSize: 13.5,
                    ),
                  ),
                ],
              ),
            ),

            // Status Badge
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: badgeBg,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    badgeIcon,
                    size: 15,
                    color: badgeColor,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    badgeText,
                    style: TextStyle(
                      color: badgeColor,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── 5. Stats Grid (Adherence & Refills) ──────────────────────────────
  Widget _buildStatsGrid(
    AsyncValue<AdherenceSummary> adherenceAsync,
    AsyncValue<List<Medication>> lowStockAsync,
  ) {
    final adherence = adherenceAsync.asData?.value;
    final bool hasDosesToday = adherence != null && adherence.total > 0;
    final String adherencePercent =
        hasDosesToday ? adherence.percentageStr : 'No data';
    final String adherenceTakenDesc = hasDosesToday
        ? '${adherence.taken} of ${adherence.total} taken today'
        : 'No doses today';
    final double adherenceFactor = hasDosesToday
        ? (adherence.taken / adherence.total).clamp(0.0, 1.0)
        : 0.0;

    final lowStockMeds = lowStockAsync.asData?.value ?? [];
    final bool hasLowStock = lowStockMeds.isNotEmpty;
    final String lowStockCount =
        hasLowStock ? '${lowStockMeds.length} Low' : '0 Low';
    final String lowStockDesc =
        hasLowStock ? 'Running low in cabinet' : 'All supplies in stock';
    final Color lowStockColor =
        hasLowStock ? const Color(0xFFBA1A1A) : const Color(0xFF157F5D);

    return Row(
      children: [
        // Adherence Card
        Expanded(
          child: InkWell(
            onTap: () => context.push(RouteNames.adherence),
            borderRadius: BorderRadius.circular(12),
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.03),
                    blurRadius: 6,
                    offset: const Offset(0, 1),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Top row: Label + Icon
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Expanded(
                        child: Text(
                          'Adherence',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: Color(0xFF545F73),
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      const SizedBox(width: 4),
                      Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          color: const Color(0xFFD5E0F8),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(
                          Icons.bar_chart_rounded,
                          color: Color(0xFF586377),
                          size: 18,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Percentage & Count
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Text(
                      adherencePercent,
                      style: TextStyle(
                        color: const Color(0xFF1B1B1B),
                        fontSize: hasDosesToday ? 30 : 22,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.5,
                      ),
                    ),
                  ),
                  Text(
                    adherenceTakenDesc,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Color(0xFF545F73),
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 10),

                  // Progress Bar
                  Container(
                    width: double.infinity,
                    height: 8,
                    decoration: BoxDecoration(
                      color: const Color(0xFFEEEEEE),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: FractionallySizedBox(
                      alignment: Alignment.centerLeft,
                      widthFactor: adherenceFactor,
                      child: Container(
                        decoration: BoxDecoration(
                          color: const Color(0xFF157F5D),
                          borderRadius: BorderRadius.circular(999),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),

        // Refills Card
        Expanded(
          child: InkWell(
            onTap: () => context.push(RouteNames.refills),
            borderRadius: BorderRadius.circular(12),
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.03),
                    blurRadius: 6,
                    offset: const Offset(0, 1),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Top row: Label + Status Pill + Icon
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Flexible(
                              child: Text(
                                'Refills',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: Color(0xFF545F73),
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                            const SizedBox(width: 4),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 5, vertical: 2),
                              decoration: BoxDecoration(
                                color: hasLowStock
                                    ? const Color(0xFFFFDAD6)
                                    : const Color(0xFF97F5CC),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                hasLowStock ? 'Urgent' : 'Good',
                                style: TextStyle(
                                  color: hasLowStock
                                      ? const Color(0xFF93000A)
                                      : const Color(0xFF002115),
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 4),
                      Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          color: hasLowStock
                              ? const Color(0xFFFFDAD6)
                              : const Color(0xFF97F5CC).withAlpha(76),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(
                          hasLowStock
                              ? Icons.notifications_active_rounded
                              : Icons.inventory_2_outlined,
                          color: hasLowStock
                              ? const Color(0xFF93000A)
                              : const Color(0xFF157F5D),
                          size: 18,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Count & Note
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Text(
                      lowStockCount,
                      style: TextStyle(
                        color: lowStockColor,
                        fontSize: 30,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.5,
                      ),
                    ),
                  ),
                  Text(
                    lowStockDesc,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Color(0xFF545F73),
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 10),

                  // Bottom Action Link
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Flexible(
                              child: Text(
                                hasLowStock ? 'Order Now' : 'View Stock',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: Color(0xFFB1002C),
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                            const SizedBox(width: 3),
                            const Icon(
                              Icons.arrow_forward_rounded,
                              size: 13,
                              color: Color(0xFFB1002C),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 4),
                      const Icon(
                        Icons.chevron_right_rounded,
                        size: 16,
                        color: Color(0xFF545F73),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  // ── 6. My Caregivers Section (Patient Mode) ─────────────────────────────────
  Widget _buildCaregiverConnectedCard() {
    final caregiversAsync = ref.watch(patientCaregiversListProvider);
    final caregivers = caregiversAsync.valueOrNull ?? [];

    final header = Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        const Expanded(
          child: Text(
            'My Caregivers',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: Color(0xFF1B1B1B),
              fontSize: 19,
              fontWeight: FontWeight.w700,
              letterSpacing: -0.2,
            ),
          ),
        ),
        const SizedBox(width: 8),
        InkWell(
          onTap: () => context.push(RouteNames.inviteCaregiver),
          borderRadius: BorderRadius.circular(6),
          child: const Padding(
            padding: EdgeInsets.symmetric(horizontal: 4, vertical: 2),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.person_add_rounded,
                    color: Color(0xFFB1002C), size: 16),
                SizedBox(width: 4),
                Text(
                  'Add Caregiver',
                  style: TextStyle(
                    color: Color(0xFFB1002C),
                    fontSize: 13.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );

    if (caregivers.isEmpty) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          header,
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.04),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              children: [
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFDAD9).withOpacity(0.6),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.volunteer_activism_rounded,
                    color: Color(0xFFB1002C),
                    size: 26,
                  ),
                ),
                const SizedBox(height: 12),
                const Text(
                  'No Caregivers Added',
                  style: TextStyle(
                    color: Color(0xFF1B1B1B),
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Add a family member or caregiver to monitor your medications and stay connected.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Color(0xFF545F73), fontSize: 13.5),
                ),
                const SizedBox(height: 16),
                ElevatedButton.icon(
                  onPressed: () => context.push(RouteNames.inviteCaregiver),
                  icon: const Icon(Icons.add_rounded, size: 18),
                  label: const Text(
                    'Add First Caregiver',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFDC143C),
                    foregroundColor: Colors.white,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 20, vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        header,
        const SizedBox(height: 12),
        for (int i = 0; i < caregivers.length; i++) ...[
          if (i > 0) const SizedBox(height: 12),
          _buildSingleCaregiverCard(caregivers[i]),
        ],
      ],
    );
  }

  Widget _buildSingleCaregiverCard(AllocatedCaregiver caregiver) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Avatar with online dot
              Stack(
                clipBehavior: Clip.none,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(28),
                    child: Container(
                      width: 56,
                      height: 56,
                      color: const Color(0xFFD5E0F8),
                      child: caregiver.avatarUrl != null
                          ? Image.network(
                              caregiver.avatarUrl!,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) =>
                                  _buildCaregiverAvatarFallback(
                                      caregiver.fullName),
                            )
                          : _buildCaregiverAvatarFallback(caregiver.fullName),
                    ),
                  ),
                  Positioned(
                    bottom: 0,
                    right: 0,
                    child: Container(
                      width: 15,
                      height: 15,
                      decoration: BoxDecoration(
                        color: const Color(0xFF006448),
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 2.5),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 14),

              // Name & status
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      caregiver.fullName,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF1B1B1B),
                        letterSpacing: -0.3,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Row(
                      children: [
                        const Icon(
                          Icons.cell_tower_rounded,
                          size: 16,
                          color: Color(0xFF006448),
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            '${formatLastActive(caregiver.lastActive)} • ${caregiver.location}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Color(0xFF545F73),
                              fontSize: 12.5,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              // Action Buttons: Call, Chat & Manage Menu
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  InkWell(
                    onTap: () async {
                      final phone = caregiver.phoneNumber;
                      if (phone == null || phone.trim().isEmpty) {
                        _showCaregiverToast(
                            '${caregiver.fullName} has not added a phone number.');
                        return;
                      }
                      final opened = await PhoneDialerService.open(phone);
                      if (!opened && mounted) {
                        _showCaregiverToast('Could not open the phone app.');
                      }
                    },
                    borderRadius: BorderRadius.circular(24),
                    child: Container(
                      width: 44,
                      height: 44,
                      decoration: const BoxDecoration(
                        color: Color(0xFFEEEEEE),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.call_rounded,
                        color: Color(0xFFDC143C),
                        size: 21,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  InkWell(
                    onTap: () {
                      _showCaregiverToast(
                          "Prepared message: 'Hi ${caregiver.fullName}, checking in!'");
                    },
                    borderRadius: BorderRadius.circular(24),
                    child: Container(
                      width: 44,
                      height: 44,
                      decoration: const BoxDecoration(
                        color: Color(0xFFEEEEEE),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.chat_bubble_rounded,
                        color: Color(0xFF1B1B1B),
                        size: 20,
                      ),
                    ),
                  ),
                  PopupMenuButton<String>(
                    icon: const Icon(Icons.more_vert_rounded,
                        color: Color(0xFF545F73), size: 20),
                    padding: EdgeInsets.zero,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                    onSelected: (value) async {
                      if (value == 'add') {
                        context.push(RouteNames.inviteCaregiver);
                      } else if (value == 'remove') {
                        final confirmed = await showDialog<bool>(
                          context: context,
                          builder: (dialogContext) => AlertDialog(
                            title: const Text('Remove Caregiver'),
                            content: Text(
                              'Remove ${caregiver.fullName}? This connection will be removed from both your app and the caregiver’s app.',
                            ),
                            actions: [
                              TextButton(
                                onPressed: () =>
                                    Navigator.pop(dialogContext, false),
                                child: const Text('Cancel'),
                              ),
                              TextButton(
                                onPressed: () =>
                                    Navigator.pop(dialogContext, true),
                                child: const Text(
                                  'Remove',
                                  style: TextStyle(color: Color(0xFFDC143C)),
                                ),
                              ),
                            ],
                          ),
                        );
                        if (confirmed != true) return;

                        try {
                          final removedFromCloud = await ref
                              .read(caregiverRepositoryProvider)
                              .removeCaregiver(caregiver.id);
                          ref.invalidate(patientCaregiversListProvider);
                          ref.invalidate(caregiversProvider);
                          ref.invalidate(notificationsProvider);
                          ref.invalidate(unreadNotificationCountProvider);
                          _showCaregiverToast(removedFromCloud
                              ? 'Removed ${caregiver.fullName} from both accounts.'
                              : 'Removed ${caregiver.fullName} here. Cloud removal is pending.');
                        } catch (_) {
                          _showCaregiverToast(
                              'Could not remove ${caregiver.fullName}. Please try again.');
                        }
                      }
                    },
                    itemBuilder: (context) => [
                      const PopupMenuItem(
                        value: 'add',
                        child: Row(
                          children: [
                            Icon(Icons.person_add_rounded,
                                size: 18, color: Color(0xFF1B1B1B)),
                            SizedBox(width: 8),
                            Flexible(child: Text('Add Another Caregiver')),
                          ],
                        ),
                      ),
                      const PopupMenuItem(
                        value: 'remove',
                        child: Row(
                          children: [
                            Icon(Icons.person_remove_rounded,
                                size: 18, color: Color(0xFFDC143C)),
                            SizedBox(width: 8),
                            Flexible(
                              child: Text('Remove Caregiver',
                                  style: TextStyle(color: Color(0xFFDC143C))),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Caregiver account details
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFFF3F3F3),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Caregiver account',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF545F73),
                    letterSpacing: 0.2,
                  ),
                ),
                const SizedBox(height: 10),
                _buildCaregiverAccountDetail(
                  icon: Icons.family_restroom_rounded,
                  label: 'Relationship',
                  value: caregiver.relationship.trim().isEmpty
                      ? 'Caregiver'
                      : caregiver.relationship,
                ),
                const SizedBox(height: 9),
                _buildCaregiverAccountDetail(
                  icon: Icons.email_outlined,
                  label: 'Email',
                  value: caregiver.email?.trim().isNotEmpty == true
                      ? caregiver.email!.trim()
                      : 'Not provided',
                ),
                const SizedBox(height: 9),
                _buildCaregiverAccountDetail(
                  icon: Icons.phone_outlined,
                  label: 'Phone',
                  value: caregiver.phoneNumber?.trim().isNotEmpty == true
                      ? caregiver.phoneNumber!.trim()
                      : 'Not provided',
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCaregiverAccountDetail({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 19, color: const Color(0xFF006448)),
        const SizedBox(width: 9),
        SizedBox(
          width: 88,
          child: Text(
            label,
            style: const TextStyle(
              fontSize: 12.5,
              color: Color(0xFF545F73),
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            textAlign: TextAlign.right,
            overflow: TextOverflow.ellipsis,
            maxLines: 1,
            style: const TextStyle(
              fontSize: 13.5,
              fontWeight: FontWeight.w700,
              color: Color(0xFF1B1B1B),
            ),
          ),
        ),
      ],
    );
  }

  // Kept for editing legacy manually allocated records.
  // ignore: unused_element
  void _showAddCaregiverSheet(BuildContext context) {
    final nameController = TextEditingController();
    final locationController = TextEditingController(text: 'Colombo Home');
    final phoneController = TextEditingController();
    String selectedRelationship = 'Family Member';

    showModalBottomSheet(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return Container(
              padding: EdgeInsets.only(
                left: 20,
                right: 20,
                top: 20,
                bottom: MediaQuery.of(context).viewInsets.bottom +
                    24 +
                    MediaQuery.of(context).padding.bottom,
              ),
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                          color: const Color(0xFFE2E2E2),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Row(
                      children: [
                        Icon(Icons.person_add_rounded,
                            color: Color(0xFFDC143C), size: 24),
                        SizedBox(width: 8),
                        Text(
                          'Add Caregiver',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF1B1B1B),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'Enter caregiver details to display their card and live telemetry in Patient Mode.',
                      style: TextStyle(fontSize: 13, color: Color(0xFF545F73)),
                    ),
                    const SizedBox(height: 18),

                    // Full Name
                    const Text('Caregiver Full Name *',
                        style: TextStyle(
                            fontWeight: FontWeight.w600, fontSize: 13)),
                    const SizedBox(height: 6),
                    TextField(
                      controller: nameController,
                      textCapitalization: TextCapitalization.words,
                      decoration: InputDecoration(
                        hintText: 'e.g. Ishara Perera',
                        filled: true,
                        fillColor: const Color(0xFFF7F7F7),
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 12),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),

                    // Relationship
                    const Text('Relationship',
                        style: TextStyle(
                            fontWeight: FontWeight.w600, fontSize: 13)),
                    const SizedBox(height: 6),
                    DropdownButtonFormField<String>(
                      value: selectedRelationship,
                      items: const [
                        DropdownMenuItem(
                            value: 'Daughter', child: Text('Daughter')),
                        DropdownMenuItem(value: 'Son', child: Text('Son')),
                        DropdownMenuItem(
                            value: 'Spouse', child: Text('Spouse / Partner')),
                        DropdownMenuItem(
                            value: 'Family Member',
                            child: Text('Family Member')),
                        DropdownMenuItem(
                            value: 'Nurse', child: Text('Nurse / Home Care')),
                        DropdownMenuItem(
                            value: 'Doctor', child: Text('Doctor / Physician')),
                        DropdownMenuItem(
                            value: 'Caregiver',
                            child: Text('Caregiver / Carer')),
                        DropdownMenuItem(value: 'Other', child: Text('Other')),
                      ],
                      onChanged: (val) {
                        if (val != null) {
                          setSheetState(() => selectedRelationship = val);
                        }
                      },
                      decoration: InputDecoration(
                        filled: true,
                        fillColor: const Color(0xFFF7F7F7),
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 12),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),

                    // Location
                    const Text('Location',
                        style: TextStyle(
                            fontWeight: FontWeight.w600, fontSize: 13)),
                    const SizedBox(height: 6),
                    TextField(
                      controller: locationController,
                      decoration: InputDecoration(
                        hintText: 'e.g. Colombo Home',
                        filled: true,
                        fillColor: const Color(0xFFF7F7F7),
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 12),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),

                    // Phone Number
                    const Text('Phone Number (Optional)',
                        style: TextStyle(
                            fontWeight: FontWeight.w600, fontSize: 13)),
                    const SizedBox(height: 6),
                    TextField(
                      controller: phoneController,
                      keyboardType: TextInputType.phone,
                      decoration: InputDecoration(
                        hintText: 'e.g. +94 77 123 4567',
                        filled: true,
                        fillColor: const Color(0xFFF7F7F7),
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 12),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                    const SizedBox(height: 22),

                    // Submit button
                    ElevatedButton(
                      onPressed: () async {
                        final fullName = nameController.text.trim();
                        if (fullName.isEmpty) {
                          _showCaregiverToast(
                              'Please enter caregiver full name');
                          return;
                        }

                        final newCaregiver = AllocatedCaregiver.create(
                          patientId:
                              AuthService.currentUser?.id ?? 'default_user',
                          fullName: fullName,
                          relationship: selectedRelationship,
                          location: locationController.text.trim().isNotEmpty
                              ? locationController.text.trim()
                              : 'Colombo Home',
                          phoneNumber: phoneController.text.trim().isNotEmpty
                              ? phoneController.text.trim()
                              : null,
                          phoneBattery: 84,
                          batteryStatus: 'Balanced',
                          smartHubStatus: 'Synced 2m ago',
                          lastActive: 'Active 12m ago',
                        );

                        await ref
                            .read(caregiverRepositoryProvider)
                            .addCaregiver(newCaregiver);
                        ref.invalidate(patientCaregiversListProvider);
                        if (context.mounted) {
                          Navigator.of(ctx).pop();
                        }
                        _showCaregiverToast(
                            'Added caregiver $fullName successfully!');
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFDC143C),
                        foregroundColor: Colors.white,
                        minimumSize: const Size(double.infinity, 48),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10)),
                        textStyle: const TextStyle(
                            fontSize: 15, fontWeight: FontWeight.w700),
                      ),
                      child: const Text('Save & Add Caregiver'),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildCaregiverAvatarFallback(String fullName) {
    final initials = fullName
        .trim()
        .split(' ')
        .take(2)
        .map((w) => w.isNotEmpty ? w[0].toUpperCase() : '')
        .join();
    return Center(
      child: Text(
        initials,
        style: const TextStyle(
            color: Color(0xFF3A5FCD),
            fontSize: 20,
            fontWeight: FontWeight.w700),
      ),
    );
  }
}
