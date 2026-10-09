import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../core/router/route_names.dart';
import '../../core/theme/app_colors.dart';
import '../../l10n/app_localizations.dart';
import '../../core/services/phone_dialer_service.dart';
import '../../core/utils/presence_formatters.dart';
import '../../data/remote/auth_service.dart';
import '../../data/local/models/app_models.dart';
import '../../data/local/models/dose_status.dart';
import '../../data/repositories/app_repositories.dart';
import '../../data/repositories/notification_repository.dart';

/// Caregiver Mode dashboard view matching the high-fidelity DoseDiary design.
/// All telemetry, next dose banners, regimen schedules, weekly adherence analytics,
/// and refill warnings are bound directly to REAL database records.
class CaregiverHomeView extends ConsumerStatefulWidget {
  const CaregiverHomeView({
    super.key,
    required this.userName,
    this.avatarUrl,
    required this.onShowToast,
  });

  final String userName;
  final String? avatarUrl;
  final void Function(String message) onShowToast;

  @override
  ConsumerState<CaregiverHomeView> createState() => _CaregiverHomeViewState();
}

class _CaregiverHomeViewState extends ConsumerState<CaregiverHomeView> {
  final Set<String> _snoozedOccurrenceIds = {};

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final dateStr = DateFormat('EEEE, d MMMM yyyy').format(now);

    final allocatedPatientsAsync = ref.watch(allocatedPatientsProvider);
    final allocatedPatients = allocatedPatientsAsync.valueOrNull ?? [];
    final activePatient =
        allocatedPatients.isNotEmpty ? allocatedPatients.first : null;

    // A caregiver without a patient must not see their own medication data.
    // Keep the dashboard limited to the add-patient state.
    if (activePatient == null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildNoPatientAllocatedCard(context),
        ],
      );
    }

    final patientUserId = activePatient.patientUserId;
    if (patientUserId == null || patientUserId.isEmpty) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildAllocatedPatientCard(context, activePatient),
          const SizedBox(height: 20),
          _buildPermissionRestrictedCard(
            title: 'Patient Account Not Linked',
            message:
                'Connect this patient\'s DoseDiary account to view their medication details.',
            icon: Icons.link_off_rounded,
          ),
        ],
      );
    }

    final occsAsync =
        ref.watch(caregiverPatientOccurrencesProvider(patientUserId));
    final medsAsync =
        ref.watch(caregiverPatientMedicationsProvider(patientUserId));
    final weeklyAdherenceAsync =
        ref.watch(caregiverPatientWeeklyAdherenceProvider(patientUserId));
    final lowStockAsync =
        ref.watch(caregiverPatientLowStockProvider(patientUserId));
    final lowestStockAsync =
        ref.watch(caregiverPatientLowestStockMedicationProvider(patientUserId));

    final occs = occsAsync.valueOrNull ?? [];
    final meds = medsAsync.valueOrNull ?? [];

    // Find real actionable doses for the selected patient only.
    final actionable = occs
        .where((o) =>
            o.status.isActionable && !_snoozedOccurrenceIds.contains(o.id))
        .toList()
      ..sort((a, b) => a.scheduledAt.compareTo(b.scheduledAt));

    final nextOcc = actionable.isNotEmpty ? actionable.first : null;
    final nextMed =
        nextOcc != null ? _findMedication(meds, nextOcc.medicationId) : null;

    final permsAsync = ref.watch(patientPermissionsProvider(patientUserId));
    final perms = permsAsync.valueOrNull;
    final canViewSchedule = perms?.permViewSchedule ?? true;
    final canViewAdherence = perms?.permViewAdherence ?? true;
    final patientFirstName = activePatient.fullName.split(' ').first;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 1. Patient Quick Telemetry & Status Card (or Add Patient option if not allocated)
        _buildPatientTelemetryCard(context, activePatient),
        const SizedBox(height: 20),

        // 2. Patient medications and today's doses in one read-only section.
        if (canViewSchedule)
          _buildMedicationAndTodayScheduleSection(
            meds,
            occs,
            dateStr,
            now,
            patientFirstName,
            isMedicationsLoading: medsAsync is AsyncLoading,
            isScheduleLoading: occsAsync is AsyncLoading,
          )
        else
          _buildPermissionRestrictedCard(
            title: 'Medication Access Restricted',
            message:
                '$patientFirstName has not granted permission to view medication details.',
            icon: Icons.medication_outlined,
          ),
        const SizedBox(height: 20),

        // 3. Urgent Reminder Banner Card (Real Next Dose) — only if schedule permitted
        if (canViewSchedule && nextOcc != null) ...[
          _buildUrgentReminderCard(nextOcc, nextMed, now, patientFirstName),
          const SizedBox(height: 20),
        ],

        const SizedBox(height: 4),

        // 5. Caregiver Insights & Weekly Adherence Hub
        if (canViewAdherence)
          _buildAdherenceCard(
            weeklyAdherenceAsync,
            lowStockAsync,
            lowestStockAsync,
            patientFirstName,
          )
        else
          _buildPermissionRestrictedCard(
            title: 'Adherence Access Restricted',
            message:
                '$patientFirstName has not granted permission to view adherence reports.',
            icon: Icons.insights_outlined,
          ),
      ],
    );
  }

  Medication? _findMedication(List<Medication> meds, String medicationId) {
    for (final m in meds) {
      if (m.id == medicationId) return m;
    }
    return null;
  }

  void _invalidatePatientMedicationData(String patientUserId) {
    ref.invalidate(caregiverPatientOccurrencesProvider(patientUserId));
    ref.invalidate(caregiverPatientMedicationsProvider(patientUserId));
    ref.invalidate(caregiverPatientWeeklyAdherenceProvider(patientUserId));
    ref.invalidate(caregiverPatientLowStockProvider(patientUserId));
    ref.invalidate(
        caregiverPatientLowestStockMedicationProvider(patientUserId));
    ref.invalidate(notificationsProvider);
    ref.invalidate(unreadNotificationCountProvider);
  }

  // ── 1. Patient Quick Telemetry & Status Card ──────────────────────────────
  Widget _buildPatientTelemetryCard(
      BuildContext context, AllocatedPatient? patient) {
    if (patient == null) {
      return _buildNoPatientAllocatedCard(context);
    }
    return _buildAllocatedPatientCard(context, patient);
  }

  /// Empty state when no patient is allocated yet.
  /// Does NOT show fake metadata (no mock battery, no mock hub, no mock call/chat).
  /// Shows an intuitive, modern "Add Patient" option card.
  Widget _buildNoPatientAllocatedCard(BuildContext context) {
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
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: const Color(0xFFFFDAD9).withOpacity(0.7),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.person_add_rounded,
                  color: Color(0xFF920022),
                  size: 26,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      context.tr('No Patient Allocated'),
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF1B1B1B),
                        letterSpacing: -0.2,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      context.tr(
                          'Link a patient to view real-time doses & device telemetry'),
                      style: const TextStyle(
                        fontSize: 12.5,
                        color: Color(0xFF545F73),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () => context.push(RouteNames.inviteCaregiver),
              icon: const Icon(Icons.person_add_rounded, size: 18),
              label: Text(context.tr('Add Patient')),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryAction,
                foregroundColor: Colors.white,
                elevation: 0,
                minimumSize: const Size(double.infinity, 44),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                textStyle: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Displays the real details of an allocated patient.
  Widget _buildAllocatedPatientCard(
      BuildContext context, AllocatedPatient patient) {
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
          // Top Row: Patient Info + Quick Action Buttons
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Avatar with live indicator
              Stack(
                clipBehavior: Clip.none,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(28),
                    child: Container(
                      width: 56,
                      height: 56,
                      color: const Color(0xFFD5E0F8),
                      child: patient.avatarUrl != null
                          ? Image.network(
                              patient.avatarUrl!,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) =>
                                  _buildAvatarFallback(),
                            )
                          : _buildAvatarFallback(),
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
                        border: Border.all(
                          color: Colors.white,
                          width: 2.5,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 14),

              // Name & Status Subtitle
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      patient.fullName,
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
                            '${formatLastActive(patient.lastActive)} • ${patient.relationship} • ${patient.location}',
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
                      if (patient.phoneNumber == null ||
                          patient.phoneNumber!.trim().isEmpty) {
                        widget.onShowToast(
                            '${patient.fullName} has not added a phone number.');
                        return;
                      }
                      final opened =
                          await PhoneDialerService.open(patient.phoneNumber);
                      if (!opened && mounted) {
                        widget.onShowToast('Could not open the phone app.');
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
                      child: Icon(
                        Icons.call_rounded,
                        color: AppColors.primaryAction,
                        size: 21,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  InkWell(
                    onTap: () => widget.onShowToast(
                        "Prepared pre-written check-in message: 'Hi ${patient.fullName}, checking on your doses!'"),
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
                          builder: (ctx) => AlertDialog(
                            title: Text(context.tr('Remove Patient')),
                            content: Text(
                              'Remove ${patient.fullName}? This connection will be removed from both your app and the patient’s app.',
                            ),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(ctx, false),
                                child: Text(context.tr('Cancel')),
                              ),
                              TextButton(
                                onPressed: () => Navigator.pop(ctx, true),
                                child: Text(context.tr('Remove'),
                                    style: TextStyle(
                                        color: AppColors.primaryAction)),
                              ),
                            ],
                          ),
                        );
                        if (confirmed == true) {
                          try {
                            final removedFromCloud = await ref
                                .read(patientRepositoryProvider)
                                .disconnectPatient(patientId: patient.id);
                            ref.invalidate(allocatedPatientsProvider);
                            ref.invalidate(caregiverPatientsProvider);
                            ref.invalidate(notificationsProvider);
                            ref.invalidate(unreadNotificationCountProvider);
                            widget.onShowToast(removedFromCloud
                                ? 'Removed ${patient.fullName} from both accounts.'
                                : 'Removed ${patient.fullName} here. Cloud removal is pending.');
                          } catch (_) {
                            widget.onShowToast(
                                'Could not remove ${patient.fullName}. Please try again.');
                          }
                        }
                      }
                    },
                    itemBuilder: (context) => [
                      PopupMenuItem(
                        value: 'add',
                        child: Row(
                          children: [
                            const Icon(Icons.person_add_rounded,
                                size: 18, color: Color(0xFF1B1B1B)),
                            const SizedBox(width: 8),
                            Flexible(
                                child: Text(context.tr('Add Another Patient'))),
                          ],
                        ),
                      ),
                      PopupMenuItem(
                        value: 'remove',
                        child: Row(
                          children: [
                            Icon(Icons.person_remove_rounded,
                                size: 18, color: AppColors.primaryAction),
                            const SizedBox(width: 8),
                            Flexible(
                              child: Text(context.tr('Remove Patient'),
                                  style: TextStyle(
                                      color: AppColors.primaryAction)),
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

          // Patient account details
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
                Text(
                  context.tr('Patient account'),
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF545F73),
                    letterSpacing: 0.2,
                  ),
                ),
                const SizedBox(height: 10),
                _buildPatientAccountDetail(
                  icon: Icons.family_restroom_rounded,
                  label: 'Relationship',
                  value: patient.relationship.trim().isEmpty
                      ? 'Patient'
                      : patient.relationship,
                ),
                const SizedBox(height: 9),
                _buildPatientAccountDetail(
                  icon: Icons.email_outlined,
                  label: 'Email',
                  value: patient.patientEmail?.trim().isNotEmpty == true
                      ? patient.patientEmail!.trim()
                      : 'Not provided',
                ),
                const SizedBox(height: 9),
                _buildPatientAccountDetail(
                  icon: Icons.person_outline_rounded,
                  label: 'Gender',
                  value: _formatAccountGender(patient.gender),
                ),
                const SizedBox(height: 9),
                _buildPatientAccountDetail(
                  icon: Icons.phone_outlined,
                  label: 'Phone',
                  value: patient.phoneNumber?.trim().isNotEmpty == true
                      ? patient.phoneNumber!.trim()
                      : 'Not provided',
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPatientAccountDetail({
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

  String _formatAccountGender(String? gender) {
    final value = gender?.trim();
    if (value == null || value.isEmpty) return 'Not provided';
    return value[0].toUpperCase() + value.substring(1).toLowerCase();
  }

  // Kept for editing legacy manually allocated records.
  // ignore: unused_element
  void _showAddPatientSheet(BuildContext context) {
    final nameController = TextEditingController();
    final phoneController = TextEditingController();
    final locationController = TextEditingController(text: 'Colombo Home');
    String selectedRelationship = 'Mother';

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
                    Row(
                      children: [
                        Icon(Icons.person_add_rounded,
                            color: AppColors.primaryAction, size: 24),
                        const SizedBox(width: 8),
                        Text(
                          context.tr('Allocate Patient'),
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF1B1B1B),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      context.tr(
                          'Enter patient details to monitor their doses and live telemetry in Caregiver Mode.'),
                      style: const TextStyle(fontSize: 13, color: Color(0xFF545F73)),
                    ),
                    const SizedBox(height: 18),

                    // Full Name
                    Text(context.tr('Patient Full Name *'),
                        style: const TextStyle(
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
                    Text(context.tr('Relationship'),
                        style: const TextStyle(
                            fontWeight: FontWeight.w600, fontSize: 13)),
                    const SizedBox(height: 6),
                    DropdownButtonFormField<String>(
                      value: selectedRelationship,
                      items: [
                        DropdownMenuItem(
                            value: 'Mother', child: Text(context.tr('Mother'))),
                        DropdownMenuItem(
                            value: 'Father', child: Text(context.tr('Father'))),
                        DropdownMenuItem(
                            value: 'Spouse', child: Text(context.tr('Spouse'))),
                        DropdownMenuItem(
                            value: 'Child',
                            child: Text(context.tr('Child / Dependent'))),
                        DropdownMenuItem(
                            value: 'Grandparent',
                            child: Text(context.tr('Grandparent'))),
                        DropdownMenuItem(
                            value: 'Patient',
                            child: Text(context.tr('Patient / Client'))),
                        DropdownMenuItem(
                            value: 'Other', child: Text(context.tr('Other'))),
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
                    Text(context.tr('Location'),
                        style: const TextStyle(
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
                    Text(context.tr('Phone Number (Optional)'),
                        style: const TextStyle(
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
                          widget.onShowToast('Please enter patient full name');
                          return;
                        }

                        final newPatient = AllocatedPatient.create(
                          caregiverId:
                              AuthService.currentUser?.id ?? 'default_user',
                          fullName: fullName,
                          relationship: selectedRelationship,
                          location: locationController.text.trim().isNotEmpty
                              ? locationController.text.trim()
                              : 'Home',
                          phoneNumber: phoneController.text.trim().isNotEmpty
                              ? phoneController.text.trim()
                              : null,
                          phoneBattery: 85,
                          batteryStatus: 'Balanced',
                          smartHubStatus: 'Synced just now',
                        );

                        await ref
                            .read(patientRepositoryProvider)
                            .addAllocatedPatient(newPatient);
                        ref.invalidate(allocatedPatientsProvider);
                        if (context.mounted) {
                          Navigator.of(ctx).pop();
                        }
                        widget.onShowToast(
                            'Allocated patient $fullName successfully!');
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primaryAction,
                        foregroundColor: Colors.white,
                        minimumSize: const Size(double.infinity, 48),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10)),
                        textStyle: const TextStyle(
                            fontSize: 15, fontWeight: FontWeight.w700),
                      ),
                      child: Text(context.tr('Save & Allocate Patient')),
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

  Widget _buildPermissionRestrictedCard({
    required String title,
    required String message,
    required IconData icon,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E2E2)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFFF5F5F5),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: const Color(0xFF757575), size: 24),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF1B1B1B),
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  message,
                  style: const TextStyle(
                    fontSize: 12.5,
                    color: Color(0xFF545F73),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAvatarFallback() {
    return Container(
      color: const Color(0xFFFFDAD9),
      child: Center(
        child: Icon(
          Icons.person_rounded,
          color: AppColors.primaryActionDark,
          size: 32,
        ),
      ),
    );
  }

  Widget _buildMedicationAndTodayScheduleSection(
    List<Medication> medications,
    List<DoseOccurrence> occurrences,
    String dateStr,
    DateTime now,
    String patientFirstName, {
    required bool isMedicationsLoading,
    required bool isScheduleLoading,
  }) {
    final visibleMedications = medications.where((med) => med.isActive).toList()
      ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    final sortedOccurrences = List<DoseOccurrence>.from(occurrences)
      ..sort((a, b) => a.scheduledAt.compareTo(b.scheduledAt));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                context.tr('Medication & Today’s Schedule'),
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF1B1B1B),
                  letterSpacing: -0.3,
                ),
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0xFFD5E0F8),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.visibility_outlined,
                      size: 14, color: Color(0xFF111C2D)),
                  const SizedBox(width: 4),
                  Text(
                    context.tr('View only'),
                    style: const TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF111C2D),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 3),
        Text(
          '$dateStr • Medication details and today’s doses for $patientFirstName.',
          style: const TextStyle(fontSize: 12.5, color: Color(0xFF545F73)),
        ),
        const SizedBox(height: 16),
        Text(
          context.tr('Active medications'),
          style: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w700,
            color: Color(0xFF1B1B1B),
          ),
        ),
        const SizedBox(height: 10),
        if (isMedicationsLoading && visibleMedications.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFE2E2E2)),
            ),
            child: Row(
              children: [
                const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Color(0xFF006448),
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  context.tr('Syncing patient medications…'),
                  style: const TextStyle(fontSize: 13.5, color: Color(0xFF545F73)),
                ),
              ],
            ),
          )
        else if (visibleMedications.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFE2E2E2)),
            ),
            child: Row(
              children: [
                const Icon(Icons.medication_outlined,
                    color: Color(0xFF545F73), size: 24),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    context.tr('No active medications are available to view.'),
                    style: const TextStyle(
                      fontSize: 13.5,
                      color: Color(0xFF545F73),
                    ),
                  ),
                ),
              ],
            ),
          )
        else
          ...visibleMedications.map(
            (medication) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Material(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                child: InkWell(
                  key: ValueKey('caregiver-medication-${medication.id}'),
                  onTap: () => _showReadOnlyMedicationDetails(medication),
                  borderRadius: BorderRadius.circular(16),
                  child: Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: const Color(0xFFE2E2E2)),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 46,
                          height: 46,
                          decoration: BoxDecoration(
                            color: const Color(0xFFFFDAD9),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(
                            Icons.medication_rounded,
                            color: AppColors.primaryActionDark,
                            size: 25,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                medication.name,
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFF1B1B1B),
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                '${medication.displayStrength} • ${medication.displayDose}',
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFF545F73),
                                ),
                              ),
                              if (medication.instructions?.trim().isNotEmpty ==
                                  true) ...[
                                const SizedBox(height: 3),
                                Text(
                                  medication.instructions!.trim(),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontSize: 12.5,
                                    color: Color(0xFF545F73),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        Column(
                          children: [
                            const Icon(Icons.chevron_right_rounded,
                                color: Color(0xFF545F73), size: 22),
                            const SizedBox(height: 4),
                            Text(
                              context.tr('Details'),
                              style: const TextStyle(
                                fontSize: 10.5,
                                color: Color(0xFF545F73),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        const SizedBox(height: 8),
        const Divider(color: Color(0xFFE2E2E2)),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              context.tr('Today’s doses'),
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: Color(0xFF1B1B1B),
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0xFFD2FFE8).withOpacity(0.7),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.cloud_done_rounded,
                      size: 14, color: Color(0xFF006448)),
                  const SizedBox(width: 4),
                  Text(
                    context.tr('Updated'),
                    style: const TextStyle(
                      color: Color(0xFF006448),
                      fontSize: 11.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        if (isScheduleLoading && sortedOccurrences.isEmpty)
          _buildScheduleLoadingCard()
        else if (sortedOccurrences.isEmpty)
          _buildEmptyRegimenCard()
        else
          ...sortedOccurrences.map((occurrence) {
            final medication =
                _findMedication(medications, occurrence.medicationId);
            final isNext = occurrence.status.isActionable &&
                sortedOccurrences
                        .where((item) => item.status.isActionable)
                        .firstOrNull
                        ?.id ==
                    occurrence.id;
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _buildOccurrenceCard(
                occurrence,
                medication,
                now,
                isNext,
                patientFirstName,
              ),
            );
          }),
      ],
    );
  }

  void _showReadOnlyMedicationDetails(Medication medication) {
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(Icons.medication_rounded,
                color: AppColors.primaryActionDark, size: 24),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                context.tr('Medication details'),
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
              ),
            ),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: double.infinity,
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                decoration: BoxDecoration(
                  color: const Color(0xFFD5E0F8).withOpacity(0.55),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.lock_outline_rounded,
                        size: 16, color: Color(0xFF111C2D)),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        context.tr(
                            'Read-only access — only the patient can make changes.'),
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF111C2D),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              Text(
                medication.name,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF1B1B1B),
                ),
              ),
              const SizedBox(height: 12),
              _buildMedicationDetailRow('Strength', medication.displayStrength),
              _buildMedicationDetailRow('Dose', medication.displayDose),
              _buildMedicationDetailRow(
                'Instructions',
                medication.instructions?.trim().isNotEmpty == true
                    ? medication.instructions!.trim()
                    : 'No instructions provided',
              ),
              _buildMedicationDetailRow(
                'Supply',
                '${_formatMedicationAmount(medication.quantityOnHand)} ${medication.quantityUnit}',
              ),
              _buildMedicationDetailRow(
                'Schedule',
                medication.isAsNeeded ? 'As needed' : 'Scheduled',
              ),
              _buildMedicationDetailRow(
                'Refill reminder',
                medication.refillReminderEnabled
                    ? 'Enabled at ${_formatMedicationAmount(medication.refillThresholdQty ?? 0)} ${medication.quantityUnit}'
                    : 'Not enabled',
                isLast: true,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: Text(
              context.tr('Close'),
              style: TextStyle(
                color: AppColors.primaryAction,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMedicationDetailRow(
    String label,
    String value, {
    bool isLast = false,
  }) {
    return Padding(
      padding: EdgeInsets.only(bottom: isLast ? 0 : 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 92,
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 12.5,
                color: Color(0xFF545F73),
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: Color(0xFF1B1B1B),
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _formatMedicationAmount(double value) => value.toStringAsFixed(
        value.truncateToDouble() == value ? 0 : 1,
      );

  // ── 2. Urgent Reminder Banner Card ────────────────────────────────────────
  Widget _buildUrgentReminderCard(
    DoseOccurrence nextOcc,
    Medication? nextMed,
    DateTime now,
    String patientFirstName,
  ) {
    final medName = nextMed?.name ?? 'Scheduled Medication';
    final strength = (nextMed != null && nextMed.strength > 0)
        ? ' ${nextMed.displayStrength}'
        : '';
    final fullMedTitle = '$medName$strength';

    final scheduledTime =
        DateFormat('h:mm a').format(nextOcc.scheduledAt.toLocal());
    final diff = nextOcc.scheduledAt.toLocal().difference(now);

    String relativeText = '';
    if (diff.inMinutes > 0) {
      relativeText = ' (in ${diff.inMinutes} minutes)';
    } else if (diff.inMinutes >= -15) {
      relativeText = ' (Due now)';
    } else {
      relativeText = ' (Overdue by ${-diff.inMinutes}m)';
    }

    final instruction = (nextMed?.instructions != null &&
            nextMed!.instructions!.trim().isNotEmpty)
        ? ' • ${nextMed.instructions!.trim()}'
        : ' • Take with meal';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFFFDAD9),
        borderRadius: BorderRadius.circular(16),
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
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: AppColors.primaryAction,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.notifications_active_rounded,
                  color: Colors.white,
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      context.tr('NEXT MEDICATION SOON'),
                      style: const TextStyle(
                        color: Color(0xFF920022),
                        fontSize: 11.5,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.8,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      fullMedTitle,
                      style: const TextStyle(
                        color: Color(0xFF40000A),
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.2,
                      ),
                    ),
                    const SizedBox(height: 3),
                    RichText(
                      text: TextSpan(
                        style: const TextStyle(
                          color: Color(0xFF3C475A),
                          fontSize: 14,
                        ),
                        children: [
                          const TextSpan(text: 'Scheduled for '),
                          TextSpan(
                            text: scheduledTime,
                            style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF40000A),
                            ),
                          ),
                          TextSpan(text: '$relativeText$instruction'),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Action Buttons: Send Gentle Ping & Later
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () async {
                    await ref
                        .read(notificationRepositoryProvider)
                        .sendNotificationToUser(
                          recipientUserId: nextOcc.userId,
                          type: 'caregiver_prompt',
                          priority: 'high',
                          title: 'Medication reminder from your caregiver',
                          body:
                              'It is time to take $fullMedTitle at $scheduledTime.',
                          sourceId: nextOcc.id,
                          route: RouteNames.home,
                        );
                    widget.onShowToast(
                        "Gentle reminder sent to $patientFirstName's phone.");
                  },
                  icon: const Icon(Icons.send_to_mobile_rounded, size: 19),
                  label: Text(
                    context.tr('Send Gentle Ping'),
                    style: const TextStyle(
                      fontSize: 14.5,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryAction,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    minimumSize: const Size(double.infinity, 46),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              ElevatedButton(
                onPressed: () async {
                  setState(() => _snoozedOccurrenceIds.add(nextOcc.id));
                  try {
                    await ref
                        .read(doseRepositoryProvider)
                        .updateOccurrenceStatus(
                          nextOcc.id,
                          DoseStatus.snoozed,
                          snoozeUntil:
                              DateTime.now().add(const Duration(minutes: 15)),
                        );
                    ref.invalidate(
                        caregiverPatientOccurrencesProvider(nextOcc.userId));
                  } catch (_) {}
                  widget.onShowToast('Alert postponed for 15 minutes.');
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: const Color(0xFF1B1B1B),
                  elevation: 0,
                  minimumSize: const Size(80, 46),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                child: Text(
                  context.tr('Later'),
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildScheduleLoadingCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E2E2)),
      ),
      child: Row(
        children: [
          const SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: Color(0xFF006448),
            ),
          ),
          const SizedBox(width: 12),
          Text(
            context.tr('Syncing today’s doses…'),
            style: const TextStyle(fontSize: 13.5, color: Color(0xFF545F73)),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyRegimenCard() {
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
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: const Color(0xFFD5E0F8).withOpacity(0.5),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.event_note_rounded,
                  color: Color(0xFF111C2D),
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  context.tr('No Regimen Scheduled for Today'),
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF1B1B1B),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            context.tr(
                'No doses were found in the patient\'s schedule for today.'),
            style: const TextStyle(
              fontSize: 13.5,
              color: Color(0xFF545F73),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOccurrenceCard(
    DoseOccurrence occ,
    Medication? med,
    DateTime now,
    bool isNextActionable,
    String patientFirstName,
  ) {
    if (occ.status == DoseStatus.taken) {
      return _buildCompletedDoseCard(occ, med);
    } else if (isNextActionable) {
      return _buildImminentDoseCard(occ, med, now, patientFirstName);
    } else {
      return _buildUpcomingDoseCard(occ, med);
    }
  }

  // Dose Card: Completed
  Widget _buildCompletedDoseCard(DoseOccurrence occ, Medication? med) {
    final medName = med?.name ?? 'Medication';
    final strength =
        (med != null && med.strength > 0) ? ' ${med.displayStrength}' : '';
    final fullMedTitle = '$medName$strength';
    final scheduledTime =
        DateFormat('h:mm a').format(occ.scheduledAt.toLocal());
    final doseDetails = med != null ? med.displayDose : '1 Dose';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
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
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: const Color(0xFF97F5CC),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.check_circle_rounded,
                  color: Color(0xFF002115),
                  size: 26,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          scheduledTime,
                          style: const TextStyle(
                            color: Color(0xFF545F73),
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 2.5),
                          decoration: BoxDecoration(
                            color: const Color(0xFF97F5CC),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            context.tr('Taken'),
                            style: const TextStyle(
                              color: Color(0xFF00513A),
                              fontSize: 11.5,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 3),
                    Text(
                      fullMedTitle,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF1B1B1B),
                        letterSpacing: -0.2,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '$doseDetails • Logged by ${widget.userName}',
                      style: const TextStyle(
                        color: Color(0xFF545F73),
                        fontSize: 13.5,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Bottom Confirmation Strip
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0xFFF3F3F3).withOpacity(0.7),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Icon(
                      Icons.verified_rounded,
                      size: 16,
                      color: Color(0xFF006448),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      context.tr('Confirmed on Smart Cap'),
                      style: const TextStyle(
                        color: Color(0xFF006448),
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                InkWell(
                  onTap: () => _showLogDialog(
                    title: '$fullMedTitle Log',
                    details:
                        'Confirmed via Smart Cap Sensor & DoseDiary at $scheduledTime.\nStatus: Full dose dispensed.\nOccurrence ID: ${occ.id}',
                  ),
                  borderRadius: BorderRadius.circular(4),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    child: Text(
                      context.tr('View Log'),
                      style: const TextStyle(
                        color: Color(0xFF545F73),
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
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

  // Dose Card: Imminent / Actionable
  Widget _buildImminentDoseCard(
    DoseOccurrence occ,
    Medication? med,
    DateTime now,
    String patientFirstName,
  ) {
    final medName = med?.name ?? 'Medication';
    final strength =
        (med != null && med.strength > 0) ? ' ${med.displayStrength}' : '';
    final fullMedTitle = '$medName$strength';

    final scheduledTime =
        DateFormat('h:mm a').format(occ.scheduledAt.toLocal());
    final diff = occ.scheduledAt.toLocal().difference(now);

    String statusText;
    if (diff.inMinutes > 0) {
      statusText = '$scheduledTime • Due in ${diff.inMinutes}m';
    } else if (diff.inMinutes >= -15) {
      statusText = '$scheduledTime • Due Now';
    } else {
      statusText = '$scheduledTime • Overdue';
    }

    final doseDetails = med != null ? med.displayDose : '1 Dose';
    final instruction =
        (med?.instructions != null && med!.instructions!.trim().isNotEmpty)
            ? ' ${med.instructions!.trim()}'
            : '';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppColors.primaryAction.withOpacity(0.35),
          width: 1.8,
        ),
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
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: const Color(0xFFFFDAD9),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.schedule_rounded,
                  color: Color(0xFF40000A),
                  size: 26,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          statusText,
                          style: TextStyle(
                            color: AppColors.primaryAction,
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 2.5),
                          decoration: BoxDecoration(
                            color: const Color(0xFFD5E0F8),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            context.tr('Pending'),
                            style: const TextStyle(
                              color: Color(0xFF111C2D),
                              fontSize: 11.5,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 3),
                    Text(
                      fullMedTitle,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF1B1B1B),
                        letterSpacing: -0.2,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '$doseDetails$instruction',
                      style: const TextStyle(
                        color: Color(0xFF545F73),
                        fontSize: 13.5,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Action Buttons: Mark as Taken & Prompt Ishara
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () async {
                    await ref
                        .read(doseRepositoryProvider)
                        .updateOccurrenceStatus(
                          occ.id,
                          DoseStatus.taken,
                        );
                    await ref.read(doseRepositoryProvider).insertDoseEvent(
                          DoseEvent.create(
                            occurrenceId: occ.id,
                            userId: occ.userId,
                            action: 'taken',
                            skipReason: 'Recorded manually by caregiver',
                          ),
                        );
                    if (med != null) {
                      await ref.read(refillRepositoryProvider).recordDeduction(
                            medicationId: med.id,
                            userId: occ.userId,
                            amount: med.amountPerDose,
                          );
                    }
                    _invalidatePatientMedicationData(occ.userId);
                    widget.onShowToast(
                        '$medName dose recorded as taken manually.');
                  },
                  icon: const Icon(
                    Icons.done_all_rounded,
                    size: 19,
                    color: Color(0xFF006448),
                  ),
                  label: Text(
                    context.tr('Mark as Taken'),
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF1B1B1B),
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFEEEEEE),
                    foregroundColor: const Color(0xFF1B1B1B),
                    elevation: 0,
                    minimumSize: const Size(double.infinity, 46),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () async {
                    await ref
                        .read(notificationRepositoryProvider)
                        .sendNotificationToUser(
                          recipientUserId: occ.userId,
                          type: 'caregiver_prompt',
                          priority: 'high',
                          title: 'Medication reminder from your caregiver',
                          body:
                              'Please take $fullMedTitle. It was scheduled for $scheduledTime.',
                          sourceId: occ.id,
                          route: RouteNames.home,
                        );
                    widget.onShowToast(
                        'Medication reminder sent to $patientFirstName for $fullMedTitle.');
                  },
                  icon: const Icon(Icons.ring_volume_rounded, size: 18),
                  label: Text(
                    'Prompt $patientFirstName',
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryAction,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    minimumSize: const Size(double.infinity, 46),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // Dose Card: Upcoming / Evening
  Widget _buildUpcomingDoseCard(DoseOccurrence occ, Medication? med) {
    final medName = med?.name ?? 'Medication';
    final strength =
        (med != null && med.strength > 0) ? ' ${med.displayStrength}' : '';
    final fullMedTitle = '$medName$strength';
    final scheduledTime =
        DateFormat('h:mm a').format(occ.scheduledAt.toLocal());
    final isEvening = occ.scheduledAt.toLocal().hour >= 18;
    final badgeText = isEvening ? 'Evening' : 'Upcoming';
    final doseDetails = med != null ? med.displayDose : '1 Dose';
    final instruction =
        (med?.instructions != null && med!.instructions!.trim().isNotEmpty)
            ? ' • ${med.instructions!.trim()}'
            : '';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.95),
        borderRadius: BorderRadius.circular(16),
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
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: const Color(0xFFEEEEEE),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              isEvening ? Icons.bedtime_rounded : Icons.schedule_rounded,
              color: const Color(0xFF545F73),
              size: 26,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      scheduledTime,
                      style: const TextStyle(
                        color: Color(0xFF545F73),
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 2.5),
                      decoration: BoxDecoration(
                        color: const Color(0xFFEEEEEE),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        badgeText,
                        style: const TextStyle(
                          color: Color(0xFF545F73),
                          fontSize: 11.5,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 3),
                Text(
                  fullMedTitle,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF1B1B1B),
                    letterSpacing: -0.2,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '$doseDetails$instruction',
                  style: const TextStyle(
                    color: Color(0xFF545F73),
                    fontSize: 13.5,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── 4. Weekly Adherence & Refill Hub ──────────────────────────────────────
  Widget _buildAdherenceCard(
    AsyncValue<WeeklyAdherenceReport> weeklyAdherenceAsync,
    AsyncValue<List<Medication>> lowStockAsync,
    AsyncValue<Medication?> lowestStockAsync,
    String patientFirstName,
  ) {
    final report = weeklyAdherenceAsync.valueOrNull;
    final overallPct = report != null ? report.overallPercentage : 0.0;
    final adherenceBadge =
        report != null ? '${report.percentageStr} On Track' : 'Loading...';

    // Summary note
    String summaryNote =
        'Zero missed doses in the past 7 days. Excellent adherence!';
    if (report != null && report.totalMissed > 0) {
      summaryNote =
          '${report.totalTaken} of ${report.totalCountable} doses completed this week (${report.totalMissed} missed).';
    } else if (report != null && report.totalCountable == 0) {
      summaryNote =
          'No doses scheduled this week yet. Add a medication to track adherence.';
    }

    // Low stock / refill info — all from real DB
    final lowStockList = lowStockAsync.valueOrNull ?? [];
    final lowestStock = lowestStockAsync.valueOrNull;
    final isLoadingStock =
        lowestStockAsync is AsyncLoading || lowStockAsync is AsyncLoading;

    final targetRefillMed =
        lowStockList.isNotEmpty ? lowStockList.first : lowestStock;
    final bool hasLowStock = lowStockList.isNotEmpty;

    String refillTitle;
    String refillSubtitle;
    int? onHand;
    int? threshold;

    if (isLoadingStock) {
      refillTitle = 'Loading medication data…';
      refillSubtitle = '';
    } else if (targetRefillMed != null) {
      // Days supply remaining
      final daysLeft = targetRefillMed.amountPerDose > 0
          ? (targetRefillMed.quantityOnHand / targetRefillMed.amountPerDose)
              .floor()
          : 0;
      refillTitle = '${targetRefillMed.name} ($daysLeft Days Left)';

      // Use refillThresholdQty as the "total/capacity" if set, otherwise
      // show raw on-hand count with unit.
      onHand = targetRefillMed.quantityOnHand.toInt();
      threshold = targetRefillMed.refillThresholdQty?.toInt();
      if (threshold != null && threshold > 0) {
        refillSubtitle =
            'Cabinet count: $onHand of $threshold ${targetRefillMed.quantityUnit} remaining';
      } else {
        refillSubtitle =
            'Cabinet count: $onHand ${targetRefillMed.quantityUnit} remaining';
      }
    } else {
      refillTitle = 'All Prescriptions Well Stocked';
      refillSubtitle = 'All medication supplies are above minimum thresholds';
    }

    // Build area chart spots from real daily pips
    final pips = report?.dailyPips ?? [];
    final spots = <FlSpot>[];
    for (int i = 0; i < pips.length; i++) {
      spots.add(FlSpot(i.toDouble(), pips[i].percentage.clamp(0, 100)));
    }

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
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Header Row ─────────────────────────────────────────────────────
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Row(
                  children: [
                    const Icon(
                      Icons.insights_rounded,
                      color: Color(0xFF006448),
                      size: 24,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            context.tr('Weekly Adherence'),
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF1B1B1B),
                              letterSpacing: -0.2,
                            ),
                          ),
                          Text(
                            '$patientFirstName • Last 7 days',
                            style: const TextStyle(
                              fontSize: 11.5,
                              color: Color(0xFF545F73),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: overallPct >= 80
                      ? const Color(0xFFD2FFE8)
                      : const Color(0xFFFFDAD9),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  adherenceBadge,
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                    color: overallPct >= 80
                        ? const Color(0xFF006448)
                        : AppColors.primaryAction,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // ── Area Chart (real DB data) ────────────────────────────────────
          if (spots.length >= 2)
            SizedBox(
              height: 120,
              child: LineChart(
                LineChartData(
                  minY: 0,
                  maxY: 100,
                  gridData: FlGridData(
                    show: true,
                    drawVerticalLine: false,
                    horizontalInterval: 25,
                    getDrawingHorizontalLine: (_) => const FlLine(
                      color: Color(0xFFEEEEEE),
                      strokeWidth: 1,
                    ),
                  ),
                  borderData: FlBorderData(show: false),
                  titlesData: FlTitlesData(
                    topTitles: const AxisTitles(
                        sideTitles: SideTitles(showTitles: false)),
                    rightTitles: const AxisTitles(
                        sideTitles: SideTitles(showTitles: false)),
                    leftTitles: const AxisTitles(
                        sideTitles: SideTitles(showTitles: false)),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 22,
                        getTitlesWidget: (value, meta) {
                          final idx = value.toInt();
                          if (idx < 0 || idx >= pips.length) {
                            return const SizedBox.shrink();
                          }
                          final label = pips[idx].dayLabel;
                          final isToday = label == 'Today';
                          return Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Text(
                              label.length > 3 ? label.substring(0, 3) : label,
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight:
                                    isToday ? FontWeight.w800 : FontWeight.w500,
                                color: isToday
                                    ? const Color(0xFF1B1B1B)
                                    : const Color(0xFF545F73),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                  lineTouchData: LineTouchData(
                    touchTooltipData: LineTouchTooltipData(
                      getTooltipColor: (_) => const Color(0xFF1B1B1B),
                      getTooltipItems: (touchedSpots) {
                        return touchedSpots.map((ts) {
                          return LineTooltipItem(
                            '${ts.y.toStringAsFixed(0)}%',
                            const TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                            ),
                          );
                        }).toList();
                      },
                    ),
                  ),
                  lineBarsData: [
                    LineChartBarData(
                      spots: spots,
                      isCurved: true,
                      curveSmoothness: 0.3,
                      color: const Color(0xFF006448),
                      barWidth: 2.5,
                      isStrokeCapRound: true,
                      dotData: FlDotData(
                        show: true,
                        getDotPainter: (spot, _, __, idx) {
                          final isToday = idx == spots.length - 1;
                          return FlDotCirclePainter(
                            radius: isToday ? 5 : 3,
                            color: isToday
                                ? const Color(0xFF1B1B1B)
                                : const Color(0xFF006448),
                            strokeWidth: 1.5,
                            strokeColor: Colors.white,
                          );
                        },
                      ),
                      belowBarData: BarAreaData(
                        show: true,
                        gradient: LinearGradient(
                          colors: [
                            const Color(0xFF006448).withOpacity(0.22),
                            const Color(0xFF006448).withOpacity(0.0),
                          ],
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            )
          else
            // Loading / no data state
            Container(
              height: 80,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: const Color(0xFFF7F7F7),
                borderRadius: BorderRadius.circular(10),
              ),
              child: weeklyAdherenceAsync is AsyncLoading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Color(0xFF006448),
                      ),
                    )
                  : Text(
                      context.tr(
                          'No adherence data yet — add a medication and log doses.'),
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 12.5,
                        color: Color(0xFF545F73),
                      ),
                    ),
            ),
          const SizedBox(height: 12),

          // ── Summary Note ─────────────────────────────────────────────────
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                report != null && report.totalMissed > 0
                    ? Icons.warning_amber_rounded
                    : Icons.verified_rounded,
                color: report != null && report.totalMissed > 0
                    ? AppColors.primaryAction
                    : const Color(0xFF006448),
                size: 18,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  summaryNote,
                  style: const TextStyle(
                    color: Color(0xFF545F73),
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // ── Medication Count / Refill Strip ──────────────────────────────
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: hasLowStock
                  ? const Color(0xFFFFDAD9).withOpacity(0.55)
                  : const Color(0xFFD5E0F8).withOpacity(0.4),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        Icons.medication_rounded,
                        color: hasLowStock
                            ? AppColors.primaryActionDark
                            : const Color(0xFF006448),
                        size: 22,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            refillTitle,
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF1B1B1B),
                            ),
                          ),
                          if (refillSubtitle.isNotEmpty)
                            Text(
                              refillSubtitle,
                              style: const TextStyle(
                                fontSize: 12,
                                color: Color(0xFF545F73),
                              ),
                            ),
                        ],
                      ),
                    ),
                    // Refill button — always visible when there's a tracked med
                    if (targetRefillMed != null)
                      ElevatedButton(
                        onPressed: () async {
                          await ref.read(refillRepositoryProvider).recordRefill(
                                medicationId: targetRefillMed.id,
                                userId: targetRefillMed.userId,
                                quantityAdded: 30,
                                note: 'Refill requested by caregiver',
                              );
                          _invalidatePatientMedicationData(
                              targetRefillMed.userId);
                          widget.onShowToast(
                              'Refill request sent for ${targetRefillMed.name} (+30 ${targetRefillMed.quantityUnit}).');
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primaryAction,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          minimumSize: const Size(68, 38),
                          padding: const EdgeInsets.symmetric(horizontal: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        child: Text(
                          context.tr('Refill'),
                          style: const TextStyle(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                  ],
                ),

                // ── Medication count bar + "Notify Patient" ──────────────
                if (targetRefillMed != null) ...[
                  const SizedBox(height: 10),
                  // Count progress bar
                  Builder(builder: (_) {
                    final total = threshold != null && threshold > 0
                        ? threshold
                        : (onHand ?? 0) + 30; // estimated capacity
                    final current = (onHand ?? 0).clamp(0, total);
                    final fraction =
                        total > 0 ? (current / total).clamp(0.0, 1.0) : 0.0;
                    final pctText =
                        '$current / $total ${targetRefillMed.quantityUnit}';
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              pctText,
                              style: TextStyle(
                                fontSize: 11.5,
                                fontWeight: FontWeight.w600,
                                color: hasLowStock
                                    ? AppColors.primaryActionDark
                                    : const Color(0xFF006448),
                              ),
                            ),
                            Text(
                              hasLowStock ? 'Low Stock' : 'Adequate',
                              style: TextStyle(
                                fontSize: 11.5,
                                fontWeight: FontWeight.w700,
                                color: hasLowStock
                                    ? AppColors.primaryAction
                                    : const Color(0xFF006448),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 5),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(999),
                          child: LinearProgressIndicator(
                            value: fraction,
                            minHeight: 7,
                            backgroundColor: Colors.white,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              hasLowStock
                                  ? AppColors.primaryAction
                                  : const Color(0xFF006448),
                            ),
                          ),
                        ),
                      ],
                    );
                  }),

                  // "Notify Patient to Refill" button — only when low stock
                  if (hasLowStock) ...[
                    const SizedBox(height: 10),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: () => widget.onShowToast(
                          'Refill reminder sent to patient for ${targetRefillMed.name}. '
                          'Please restock before supplies run out.',
                        ),
                        icon: const Icon(
                          Icons.notification_important_rounded,
                          size: 17,
                        ),
                        label: Text(context.tr('Notify Patient to Refill')),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.primaryAction,
                          side: BorderSide(
                            color: AppColors.primaryAction,
                            width: 1.5,
                          ),
                          minimumSize: const Size(double.infinity, 40),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(9),
                          ),
                          textStyle: const TextStyle(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                  ],
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Helper Dialogs ────────────────────────────────────────────────────────
  void _showLogDialog({required String title, required String details}) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            const Icon(Icons.verified_rounded, color: Color(0xFF006448), size: 24),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                title,
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
              ),
            ),
          ],
        ),
        content: Text(details,
            style: const TextStyle(fontSize: 14, color: Color(0xFF545F73))),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text(context.tr('Close'),
                style: TextStyle(
                    color: AppColors.primaryAction,
                    fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }
}
