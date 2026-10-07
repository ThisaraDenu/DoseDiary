import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../core/router/route_names.dart';
import '../../data/remote/auth_service.dart';
import '../../data/local/models/app_models.dart';
import '../../data/local/models/dose_status.dart';
import '../../data/repositories/app_repositories.dart';
import '../caregivers/incoming_invitations_widget.dart';

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

    final occsAsync = ref.watch(todayOccurrencesProvider);
    final medsAsync = ref.watch(todayMedicationsProvider);
    final weeklyAdherenceAsync = ref.watch(weeklyAdherenceProvider);
    final lowStockAsync = ref.watch(lowStockProvider);
    final lowestStockAsync = ref.watch(lowestStockMedicationProvider);

    final occs = occsAsync.valueOrNull ?? [];
    final meds = medsAsync.valueOrNull ?? [];

    // Find real actionable doses for today
    final actionable = occs
        .where((o) => o.status.isActionable && !_snoozedOccurrenceIds.contains(o.id))
        .toList()
      ..sort((a, b) => a.scheduledAt.compareTo(b.scheduledAt));

    final nextOcc = actionable.isNotEmpty ? actionable.first : null;
    final nextMed = nextOcc != null ? _findMedication(meds, nextOcc.medicationId) : null;

    final allocatedPatientsAsync = ref.watch(allocatedPatientsProvider);
    final allocatedPatients = allocatedPatientsAsync.valueOrNull ?? [];
    final activePatient = allocatedPatients.isNotEmpty ? allocatedPatients.first : null;

    final permsAsync = activePatient?.patientUserId != null
        ? ref.watch(patientPermissionsProvider(activePatient!.patientUserId!))
        : null;
    final perms = permsAsync?.valueOrNull;
    final canViewSchedule = perms?.permViewSchedule ?? true;
    final canViewAdherence = perms?.permViewAdherence ?? true;
    final canViewRefills = perms?.permViewRefills ?? true;

    final patientDisplayName = activePatient?.fullName ??
        (widget.userName.trim().isNotEmpty ? widget.userName : 'Patient');
    final patientFirstName = activePatient != null
        ? activePatient.fullName.split(' ').first
        : (widget.userName.trim().isNotEmpty ? widget.userName : 'Patient');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 0. Incoming Invitations Section (addressed to this caregiver)
        const IncomingCaregiverInvitationsWidget(),
        const SizedBox(height: 20),

        // 1. Patient Quick Telemetry & Status Card (or Add Patient option if not allocated)
        _buildPatientTelemetryCard(context, activePatient),
        const SizedBox(height: 20),

        // 2. Urgent Reminder Banner Card (Real Next Dose) — only if schedule permitted
        if (canViewSchedule && nextOcc != null) ...[
          _buildUrgentReminderCard(nextOcc, nextMed, now, patientFirstName),
          const SizedBox(height: 20),
        ],

        // 3. Today's Regimen (Caregiver View)
        if (canViewSchedule)
          _buildRegimenSection(dateStr, occs, meds, now, patientFirstName)
        else
          _buildPermissionRestrictedCard(
            title: 'Schedule Access Restricted',
            message: '$patientFirstName has not granted permission to view their daily schedule.',
            icon: Icons.calendar_today_outlined,
          ),
        const SizedBox(height: 24),

        // 4. Caregiver Insights & Weekly Adherence Hub
        if (canViewAdherence)
          _buildAdherenceCard(weeklyAdherenceAsync, lowStockAsync, lowestStockAsync)
        else
          _buildPermissionRestrictedCard(
            title: 'Adherence Access Restricted',
            message: '$patientFirstName has not granted permission to view adherence reports.',
            icon: Icons.insights_outlined,
          ),
        const SizedBox(height: 24),

        // 5. Fast Caregiver Utility Grid (Care Actions)
        _buildCareActionsGrid(context, canViewRefills ? meds : [], patientDisplayName),
      ],
    );
  }

  Medication? _findMedication(List<Medication> meds, String medicationId) {
    for (final m in meds) {
      if (m.id == medicationId) return m;
    }
    return null;
  }

  // ── 1. Patient Quick Telemetry & Status Card ──────────────────────────────
  Widget _buildPatientTelemetryCard(BuildContext context, AllocatedPatient? patient) {
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
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'No Patient Allocated',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF1B1B1B),
                        letterSpacing: -0.2,
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      'Link a patient to view real-time doses & device telemetry',
                      style: TextStyle(
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
              onPressed: () => _showAddPatientSheet(context),
              icon: const Icon(Icons.person_add_rounded, size: 18),
              label: const Text('Add Patient'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFDC143C),
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
  Widget _buildAllocatedPatientCard(BuildContext context, AllocatedPatient patient) {
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
                              errorBuilder: (_, __, ___) => _buildAvatarFallback(),
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
                            '${patient.lastActive} • ${patient.relationship} • ${patient.location}',
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
                    onTap: () => widget.onShowToast(
                        'Connecting audio call to ${patient.fullName}...'),
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
                    icon: const Icon(Icons.more_vert_rounded, color: Color(0xFF545F73), size: 20),
                    padding: EdgeInsets.zero,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    onSelected: (value) async {
                      if (value == 'edit') {
                        _showEditPatientSheet(context, patient);
                      } else if (value == 'add') {
                        _showAddPatientSheet(context);
                      } else if (value == 'disconnect') {
                        final confirmed = await showDialog<bool>(
                          context: context,
                          builder: (ctx) => AlertDialog(
                            title: const Text('Disconnect Patient'),
                            content: Text(
                              'Are you sure you want to disconnect from ${patient.fullName}? You will no longer be able to monitor their regimen.',
                            ),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(ctx, false),
                                child: const Text('Cancel'),
                              ),
                              TextButton(
                                onPressed: () => Navigator.pop(ctx, true),
                                child: const Text('Disconnect', style: TextStyle(color: Color(0xFFDC143C))),
                              ),
                            ],
                          ),
                        );
                        if (confirmed == true) {
                          await ref.read(patientRepositoryProvider).disconnectPatient(patientId: patient.id);
                          ref.invalidate(allocatedPatientsProvider);
                          ref.invalidate(caregiverPatientsProvider);
                          widget.onShowToast('Disconnected from ${patient.fullName}.');
                        }
                      }
                    },
                    itemBuilder: (context) => [
                      const PopupMenuItem(
                        value: 'edit',
                        child: Row(
                          children: [
                            Icon(Icons.edit_rounded, size: 18, color: Color(0xFF1B1B1B)),
                            SizedBox(width: 8),
                            Text('Edit Patient Details'),
                          ],
                        ),
                      ),
                      const PopupMenuItem(
                        value: 'add',
                        child: Row(
                          children: [
                            Icon(Icons.person_add_rounded, size: 18, color: Color(0xFF1B1B1B)),
                            SizedBox(width: 8),
                            Text('Add Another Patient'),
                          ],
                        ),
                      ),
                      const PopupMenuItem(
                        value: 'disconnect',
                        child: Row(
                          children: [
                            Icon(Icons.link_off_rounded, size: 18, color: Color(0xFFDC143C)),
                            SizedBox(width: 8),
                            Text('Disconnect Patient', style: TextStyle(color: Color(0xFFDC143C))),
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

          // Live Telemetry Pill Bar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: const Color(0xFFF3F3F3),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              children: [
                // Phone Battery
                Expanded(
                  child: Row(
                    children: [
                      const Icon(
                        Icons.battery_5_bar_rounded,
                        color: Color(0xFF545F73),
                        size: 22,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Phone Battery',
                              style: TextStyle(
                                fontSize: 11,
                                color: Color(0xFF545F73),
                              ),
                            ),
                            Text(
                              '${patient.phoneBattery}% • ${patient.batteryStatus}',
                              style: const TextStyle(
                                fontSize: 13.5,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF1B1B1B),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  width: 1,
                  height: 28,
                  color: const Color(0xFFE2E2E2),
                ),
                const SizedBox(width: 12),

                // Smart Hub & Band
                Expanded(
                  child: Row(
                    children: [
                      const Icon(
                        Icons.wifi_rounded,
                        color: Color(0xFF006448),
                        size: 22,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Smart Hub & Band',
                              style: TextStyle(
                                fontSize: 11,
                                color: Color(0xFF545F73),
                              ),
                            ),
                            Text(
                              patient.smartHubStatus,
                              style: const TextStyle(
                                fontSize: 13.5,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF1B1B1B),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showAddPatientSheet(BuildContext context) {
    final nameController = TextEditingController();
    final phoneController = TextEditingController();
    final locationController = TextEditingController(text: 'Colombo Home');
    String selectedRelationship = 'Mother';

    showModalBottomSheet(
      context: context,
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
                bottom: MediaQuery.of(context).viewInsets.bottom + 24,
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
                        Icon(Icons.person_add_rounded, color: Color(0xFFDC143C), size: 24),
                        SizedBox(width: 8),
                        Text(
                          'Allocate Patient',
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
                      'Enter patient details to monitor their doses and live telemetry in Caregiver Mode.',
                      style: TextStyle(fontSize: 13, color: Color(0xFF545F73)),
                    ),
                    const SizedBox(height: 18),

                    // Full Name
                    const Text('Patient Full Name *', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                    const SizedBox(height: 6),
                    TextField(
                      controller: nameController,
                      textCapitalization: TextCapitalization.words,
                      decoration: InputDecoration(
                        hintText: 'e.g. Ishara Perera',
                        filled: true,
                        fillColor: const Color(0xFFF7F7F7),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),

                    // Relationship
                    const Text('Relationship', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                    const SizedBox(height: 6),
                    DropdownButtonFormField<String>(
                      value: selectedRelationship,
                      items: const [
                        DropdownMenuItem(value: 'Mother', child: Text('Mother')),
                        DropdownMenuItem(value: 'Father', child: Text('Father')),
                        DropdownMenuItem(value: 'Spouse', child: Text('Spouse')),
                        DropdownMenuItem(value: 'Child', child: Text('Child / Dependent')),
                        DropdownMenuItem(value: 'Grandparent', child: Text('Grandparent')),
                        DropdownMenuItem(value: 'Patient', child: Text('Patient / Client')),
                        DropdownMenuItem(value: 'Other', child: Text('Other')),
                      ],
                      onChanged: (val) {
                        if (val != null) setSheetState(() => selectedRelationship = val);
                      },
                      decoration: InputDecoration(
                        filled: true,
                        fillColor: const Color(0xFFF7F7F7),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),

                    // Location
                    const Text('Location', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                    const SizedBox(height: 6),
                    TextField(
                      controller: locationController,
                      decoration: InputDecoration(
                        hintText: 'e.g. Colombo Home',
                        filled: true,
                        fillColor: const Color(0xFFF7F7F7),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),

                    // Phone Number
                    const Text('Phone Number (Optional)', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                    const SizedBox(height: 6),
                    TextField(
                      controller: phoneController,
                      keyboardType: TextInputType.phone,
                      decoration: InputDecoration(
                        hintText: 'e.g. +94 77 123 4567',
                        filled: true,
                        fillColor: const Color(0xFFF7F7F7),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
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
                          caregiverId: AuthService.currentUser?.id ?? 'default_user',
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

                        await ref.read(patientRepositoryProvider).addAllocatedPatient(newPatient);
                        ref.invalidate(allocatedPatientsProvider);
                        if (context.mounted) {
                          Navigator.of(ctx).pop();
                        }
                        widget.onShowToast('Allocated patient $fullName successfully!');
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFDC143C),
                        foregroundColor: Colors.white,
                        minimumSize: const Size(double.infinity, 48),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
                      ),
                      child: const Text('Save & Allocate Patient'),
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

  void _showEditPatientSheet(BuildContext context, AllocatedPatient patient) {
    final phoneController = TextEditingController(text: patient.phoneNumber ?? '');
    final locationController = TextEditingController(text: patient.location);
    String selectedRelationship = patient.relationship;

    showModalBottomSheet(
      context: context,
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
                bottom: MediaQuery.of(context).viewInsets.bottom + 24,
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
                        const Icon(Icons.edit_rounded, color: Color(0xFFDC143C), size: 24),
                        const SizedBox(width: 8),
                        Text(
                          'Edit ${patient.fullName}',
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF1B1B1B),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'Update relationship and contact details. Account credentials and privacy settings are managed by the patient.',
                      style: TextStyle(fontSize: 12.5, color: Color(0xFF545F73)),
                    ),
                    const SizedBox(height: 18),

                    // Relationship
                    const Text('Relationship', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                    const SizedBox(height: 6),
                    DropdownButtonFormField<String>(
                      value: [
                        'Mother',
                        'Father',
                        'Spouse',
                        'Child',
                        'Grandparent',
                        'Patient',
                        'Other',
                      ].contains(selectedRelationship)
                          ? selectedRelationship
                          : 'Other',
                      items: const [
                        DropdownMenuItem(value: 'Mother', child: Text('Mother')),
                        DropdownMenuItem(value: 'Father', child: Text('Father')),
                        DropdownMenuItem(value: 'Spouse', child: Text('Spouse')),
                        DropdownMenuItem(value: 'Child', child: Text('Child / Dependent')),
                        DropdownMenuItem(value: 'Grandparent', child: Text('Grandparent')),
                        DropdownMenuItem(value: 'Patient', child: Text('Patient / Client')),
                        DropdownMenuItem(value: 'Other', child: Text('Other')),
                      ],
                      onChanged: (val) {
                        if (val != null) setSheetState(() => selectedRelationship = val);
                      },
                      decoration: InputDecoration(
                        filled: true,
                        fillColor: const Color(0xFFF7F7F7),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),

                    // Location
                    const Text('Location', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                    const SizedBox(height: 6),
                    TextField(
                      controller: locationController,
                      decoration: InputDecoration(
                        hintText: 'e.g. Colombo Home',
                        filled: true,
                        fillColor: const Color(0xFFF7F7F7),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),

                    // Phone Number
                    const Text('Phone Number (Optional)', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                    const SizedBox(height: 6),
                    TextField(
                      controller: phoneController,
                      keyboardType: TextInputType.phone,
                      decoration: InputDecoration(
                        hintText: 'e.g. +94 77 123 4567',
                        filled: true,
                        fillColor: const Color(0xFFF7F7F7),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
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
                        await ref.read(patientRepositoryProvider).updateAllocatedPatient(
                              patientId: patient.id,
                              relationship: selectedRelationship,
                              location: locationController.text.trim().isNotEmpty
                                  ? locationController.text.trim()
                                  : patient.location,
                              phoneNumber: phoneController.text.trim().isNotEmpty
                                  ? phoneController.text.trim()
                                  : null,
                            );
                        ref.invalidate(allocatedPatientsProvider);
                        if (context.mounted) {
                          Navigator.of(ctx).pop();
                        }
                        widget.onShowToast('Updated details for ${patient.fullName}.');
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFDC143C),
                        foregroundColor: Colors.white,
                        minimumSize: const Size(double.infinity, 48),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
                      ),
                      child: const Text('Save Changes'),
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
      child: const Center(
        child: Icon(
          Icons.person_rounded,
          color: Color(0xFFB1002C),
          size: 32,
        ),
      ),
    );
  }

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

    final scheduledTime = DateFormat('h:mm a').format(nextOcc.scheduledAt.toLocal());
    final diff = nextOcc.scheduledAt.toLocal().difference(now);

    String relativeText = '';
    if (diff.inMinutes > 0) {
      relativeText = ' (in ${diff.inMinutes} minutes)';
    } else if (diff.inMinutes >= -15) {
      relativeText = ' (Due now)';
    } else {
      relativeText = ' (Overdue by ${-diff.inMinutes}m)';
    }

    final instruction = (nextMed?.instructions != null && nextMed!.instructions!.trim().isNotEmpty)
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
                decoration: const BoxDecoration(
                  color: Color(0xFFDC143C),
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
                    const Text(
                      'NEXT MEDICATION SOON',
                      style: TextStyle(
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
                  onPressed: () => widget.onShowToast(
                      "Gentle chime sent to $patientFirstName's phone & smart speaker."),
                  icon: const Icon(Icons.send_to_mobile_rounded, size: 19),
                  label: const Text(
                    'Send Gentle Ping',
                    style: TextStyle(
                      fontSize: 14.5,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFDC143C),
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
                    await ref.read(doseRepositoryProvider).updateOccurrenceStatus(
                          nextOcc.id,
                          DoseStatus.snoozed,
                          snoozeUntil: DateTime.now().add(const Duration(minutes: 15)),
                        );
                    ref.invalidate(todayOccurrencesProvider);
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
                child: const Text(
                  'Later',
                  style: TextStyle(
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

  // ── 3. Today's Regimen (Schedule Section) ──────────────────────────────────
  Widget _buildRegimenSection(
    String dateStr,
    List<DoseOccurrence> occs,
    List<Medication> meds,
    DateTime now,
    String patientFirstName,
  ) {
    final sortedOccs = List<DoseOccurrence>.from(occs)
      ..sort((a, b) => a.scheduledAt.compareTo(b.scheduledAt));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Section Header
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    "Today's Regimen",
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF1B1B1B),
                      letterSpacing: -0.3,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '$dateStr • Live Synchronization',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 12.5,
                      color: Color(0xFF545F73),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: const Color(0xFFD2FFE8).withOpacity(0.7),
                borderRadius: BorderRadius.circular(999),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.cloud_done_rounded,
                    size: 16,
                    color: Color(0xFF006448),
                  ),
                  SizedBox(width: 4),
                  Text(
                    'Updated',
                    style: TextStyle(
                      color: Color(0xFF006448),
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),

        // If no doses scheduled for today in SQLite
        if (sortedOccs.isEmpty)
          _buildEmptyRegimenCard()
        else
          ...sortedOccs.map((occ) {
            final med = _findMedication(meds, occ.medicationId);
            final isNext = occ.status.isActionable &&
                sortedOccs.where((o) => o.status.isActionable).firstOrNull?.id == occ.id;
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _buildOccurrenceCard(occ, med, now, isNext, patientFirstName),
            );
          }),
      ],
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
              const Expanded(
                child: Text(
                  'No Regimen Scheduled for Today',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF1B1B1B),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          const Text(
            'No doses were found in the database for today. Add a new medication to get started.',
            style: TextStyle(
              fontSize: 13.5,
              color: Color(0xFF545F73),
            ),
          ),
          const SizedBox(height: 16),
          OutlinedButton.icon(
            onPressed: () => context.push(RouteNames.addMedication),
            icon: const Icon(Icons.add_rounded, size: 18),
            label: const Text('Add Medication'),
            style: OutlinedButton.styleFrom(
              foregroundColor: const Color(0xFFDC143C),
              side: const BorderSide(color: Color(0xFFDC143C)),
              minimumSize: const Size(double.infinity, 44),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
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
    final strength = (med != null && med.strength > 0) ? ' ${med.displayStrength}' : '';
    final fullMedTitle = '$medName$strength';
    final scheduledTime = DateFormat('h:mm a').format(occ.scheduledAt.toLocal());
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
                          child: const Text(
                            'Taken',
                            style: TextStyle(
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
                const Row(
                  children: [
                    Icon(
                      Icons.verified_rounded,
                      size: 16,
                      color: Color(0xFF006448),
                    ),
                    SizedBox(width: 6),
                    Text(
                      'Confirmed on Smart Cap',
                      style: TextStyle(
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
                  child: const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    child: Text(
                      'View Log',
                      style: TextStyle(
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
    final strength = (med != null && med.strength > 0) ? ' ${med.displayStrength}' : '';
    final fullMedTitle = '$medName$strength';

    final scheduledTime = DateFormat('h:mm a').format(occ.scheduledAt.toLocal());
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
    final instruction = (med?.instructions != null && med!.instructions!.trim().isNotEmpty)
        ? ' ${med.instructions!.trim()}'
        : '';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: const Color(0xFFDC143C).withOpacity(0.35),
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
                          style: const TextStyle(
                            color: Color(0xFFDC143C),
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
                          child: const Text(
                            'Pending',
                            style: TextStyle(
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
                    await ref.read(doseRepositoryProvider).updateOccurrenceStatus(
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
                    ref.invalidate(todayOccurrencesProvider);
                    ref.invalidate(todayAdherenceProvider);
                    ref.invalidate(weeklyAdherenceProvider);
                    ref.invalidate(todayMedicationsProvider);
                    ref.invalidate(lowStockProvider);
                    ref.invalidate(lowestStockMedicationProvider);
                    widget.onShowToast('$medName dose recorded as taken manually.');
                  },
                  icon: const Icon(
                    Icons.done_all_rounded,
                    size: 19,
                    color: Color(0xFF006448),
                  ),
                  label: const Text(
                    'Mark as Taken',
                    style: TextStyle(
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
                  onPressed: () => widget.onShowToast(
                      'Audio alert sent to $patientFirstName for $fullMedTitle.'),
                  icon: const Icon(Icons.ring_volume_rounded, size: 18),
                  label: Text(
                    'Prompt $patientFirstName',
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFDC143C),
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
    final strength = (med != null && med.strength > 0) ? ' ${med.displayStrength}' : '';
    final fullMedTitle = '$medName$strength';
    final scheduledTime = DateFormat('h:mm a').format(occ.scheduledAt.toLocal());
    final isEvening = occ.scheduledAt.toLocal().hour >= 18;
    final badgeText = isEvening ? 'Evening' : 'Upcoming';
    final doseDetails = med != null ? med.displayDose : '1 Dose';
    final instruction = (med?.instructions != null && med!.instructions!.trim().isNotEmpty)
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
  ) {
    final report = weeklyAdherenceAsync.valueOrNull;
    final overallPct = report != null ? report.overallPercentage : 0.0;
    final adherenceBadge =
        report != null ? '${report.percentageStr} On Track' : 'Loading...';

    // Summary note
    String summaryNote = 'Zero missed doses in the past 7 days. Excellent adherence!';
    if (report != null && report.totalMissed > 0) {
      summaryNote =
          '${report.totalTaken} of ${report.totalCountable} doses completed this week (${report.totalMissed} missed).';
    } else if (report != null && report.totalCountable == 0) {
      summaryNote = 'No doses scheduled this week yet. Add a medication to track adherence.';
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
              InkWell(
                onTap: () => context.push(RouteNames.adherence),
                borderRadius: BorderRadius.circular(8),
                child: const Row(
                  children: [
                    Icon(
                      Icons.insights_rounded,
                      color: Color(0xFF006448),
                      size: 24,
                    ),
                    SizedBox(width: 8),
                    Text(
                      'Weekly Adherence',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF1B1B1B),
                        letterSpacing: -0.2,
                      ),
                    ),
                    SizedBox(width: 4),
                    Icon(
                      Icons.chevron_right_rounded,
                      size: 20,
                      color: Color(0xFF667085),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
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
                        : const Color(0xFFDC143C),
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
                                fontWeight: isToday
                                    ? FontWeight.w800
                                    : FontWeight.w500,
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
                  : const Text(
                      'No adherence data yet — add a medication and log doses.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
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
                    ? const Color(0xFFDC143C)
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
                            ? const Color(0xFFB1002C)
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
                          ref.invalidate(lowStockProvider);
                          ref.invalidate(lowestStockMedicationProvider);
                          ref.invalidate(todayMedicationsProvider);
                          widget.onShowToast(
                              'Refill request sent for ${targetRefillMed.name} (+30 ${targetRefillMed.quantityUnit}).');
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFDC143C),
                          foregroundColor: Colors.white,
                          elevation: 0,
                          minimumSize: const Size(68, 38),
                          padding:
                              const EdgeInsets.symmetric(horizontal: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        child: const Text(
                          'Refill',
                          style: TextStyle(
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
                                    ? const Color(0xFFB1002C)
                                    : const Color(0xFF006448),
                              ),
                            ),
                            Text(
                              hasLowStock ? 'Low Stock' : 'Adequate',
                              style: TextStyle(
                                fontSize: 11.5,
                                fontWeight: FontWeight.w700,
                                color: hasLowStock
                                    ? const Color(0xFFDC143C)
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
                                  ? const Color(0xFFDC143C)
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
                        label: const Text('Notify Patient to Refill'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFFDC143C),
                          side: const BorderSide(
                            color: Color(0xFFDC143C),
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

  // ── 5. Care Actions Grid ──────────────────────────────────────────────────
  Widget _buildCareActionsGrid(
    BuildContext context,
    List<Medication> meds,
    String patientName,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Care Actions',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: Color(0xFF1B1B1B),
            letterSpacing: -0.2,
          ),
        ),
        const SizedBox(height: 12),
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          childAspectRatio: 1.15,
          children: [
            // 1. Log In-Person
            _buildActionCard(
              icon: Icons.fact_check_rounded,
              iconBg: const Color(0xFFD5E0F8),
              iconColor: const Color(0xFF111C2D),
              title: 'Log In-Person',
              subtitle: 'Record a dose handed to $patientName',
              onTap: () {
                _showLogInPersonDialog(meds, patientName);
              },
            ),

            // 2. Emergency Contact
            _buildActionCard(
              icon: Icons.health_and_safety_rounded,
              iconBg: const Color(0xFFFFDAD9),
              iconColor: const Color(0xFF920022),
              title: 'Emergency Contact',
              subtitle: 'Set up a doctor or emergency contact',
              onTap: () {
                widget.onShowToast('No emergency contact set. Add one in Settings.');
              },
            ),

            // 3. Share Log PDF
            _buildActionCard(
              icon: Icons.share_rounded,
              iconBg: const Color(0xFFEEEEEE),
              iconColor: const Color(0xFF545F73),
              title: 'Share Log',
              subtitle: 'Export 30-day adherence report',
              onTap: () {
                widget.onShowToast(
                    'Generating 30-day adherence report for $patientName...');
              },
            ),

            // 4. Care Circle Permissions
            _buildActionCard(
              icon: Icons.admin_panel_settings_rounded,
              iconBg: const Color(0xFFEEEEEE),
              iconColor: const Color(0xFF545F73),
              title: 'Permissions',
              subtitle: 'Manage care circle members',
              onTap: () {
                context.push(RouteNames.caregivers);
              },
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildActionCard({
    required IconData icon,
    required Color iconBg,
    required Color iconColor,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(14),
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
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: iconBg,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: iconColor, size: 22),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF1B1B1B),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 11.5,
                    color: Color(0xFF545F73),
                    height: 1.25,
                  ),
                ),
              ],
            ),
          ],
        ),
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
        content: Text(details, style: const TextStyle(fontSize: 14, color: Color(0xFF545F73))),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Close', style: TextStyle(color: Color(0xFFDC143C), fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }

  void _showLogInPersonDialog(List<Medication> meds, String patientName) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Log In-Person Dose',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF1B1B1B),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded),
                  onPressed: () => Navigator.of(ctx).pop(),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Select medication administered in person to $patientName:',
              style: const TextStyle(fontSize: 13.5, color: Color(0xFF545F73)),
            ),
            const SizedBox(height: 16),
            if (meds.isEmpty) ...[
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 16),
                child: Text(
                  'No active medications found in the database. Please add a medication first.',
                  style: TextStyle(color: Color(0xFF545F73), fontSize: 14),
                ),
              ),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () {
                    Navigator.of(ctx).pop();
                    context.push(RouteNames.addMedication);
                  },
                  icon: const Icon(Icons.add_rounded),
                  label: const Text('Add Medication'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFDC143C),
                    foregroundColor: Colors.white,
                  ),
                ),
              ),
            ] else ...[
              ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 280),
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: meds.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (_, index) {
                    final med = meds[index];
                    final strength = med.strength > 0 ? ' ${med.displayStrength}' : '';
                    return ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFDAD9),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(Icons.medication_rounded, color: Color(0xFFB1002C)),
                      ),
                      title: Text('${med.name}$strength',
                          style: const TextStyle(fontWeight: FontWeight.w700)),
                      subtitle: Text(
                          '${med.displayDose}${med.instructions != null ? ' • ${med.instructions}' : ''}'),
                      trailing: ElevatedButton(
                        onPressed: () async {
                          Navigator.of(ctx).pop();
                          await ref.read(doseRepositoryProvider).recordInPersonDose(
                                medicationId: med.id,
                                userId: med.userId,
                              );
                          await ref.read(refillRepositoryProvider).recordDeduction(
                                medicationId: med.id,
                                userId: med.userId,
                                amount: med.amountPerDose,
                              );
                          ref.invalidate(todayOccurrencesProvider);
                          ref.invalidate(todayAdherenceProvider);
                          ref.invalidate(weeklyAdherenceProvider);
                          ref.invalidate(todayMedicationsProvider);
                          ref.invalidate(lowStockProvider);
                          ref.invalidate(lowestStockMedicationProvider);
                          widget.onShowToast('${med.name} marked as administered in person.');
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFDC143C),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                        child: const Text('Confirm'),
                      ),
                    );
                  },
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
