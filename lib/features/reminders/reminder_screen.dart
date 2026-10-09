import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/theme/app_dimensions.dart';
import '../../core/router/route_names.dart';
import '../../core/widgets/dd_button.dart';
import '../../core/widgets/dd_loading.dart';
import '../../data/local/models/app_models.dart';
import '../../data/local/models/dose_status.dart';
import '../../data/repositories/app_repositories.dart';
import '../../data/repositories/notification_repository.dart';
import '../../data/remote/auth_service.dart';
import '../../services/dose_alarm_scheduler.dart';
import '../../services/notification_service.dart';
import '../home/home_dashboard_screen.dart';

// ── Providers ─────────────────────────────────────────────────────────────────

final reminderOccurrenceProvider =
    FutureProvider.family<DoseOccurrence?, String>((ref, id) async {
  final repo = ref.watch(doseRepositoryProvider);
  return repo.getOccurrenceById(id);
});

final reminderMedicationProvider =
    FutureProvider.family<Medication?, String>((ref, medicationId) async {
  final repo = ref.watch(medicationRepositoryProvider);
  return repo.getMedicationById(medicationId);
});

// ── Screen ────────────────────────────────────────────────────────────────

class ReminderScreen extends ConsumerStatefulWidget {
  const ReminderScreen({
    required this.occurrenceId,
    this.initialAction,
    super.key,
  });
  final String occurrenceId;
  final String? initialAction;

  @override
  ConsumerState<ReminderScreen> createState() => _ReminderScreenState();
}

class _ReminderScreenState extends ConsumerState<ReminderScreen> {
  bool _isSubmitting = false;
  bool _initialActionHandled = false;

  Future<void> _recordAction(
    DoseOccurrence occ,
    Medication med,
    DoseStatus status, {
    DateTime? snoozeUntil,
    String? skipReason,
  }) async {
    setState(() => _isSubmitting = true);

    try {
      // Stops the insistent sound/vibration as soon as the user responds.
      await NotificationService.cancelDoseAlarm(occ.id);

      final doseRepo = ref.read(doseRepositoryProvider);
      final refillRepo = ref.read(refillRepositoryProvider);
      final currentUserId = AuthService.currentUser?.id ?? occ.userId;

      // 1. Update occurrence status
      await doseRepo.updateOccurrenceStatus(occ.id, status,
          snoozeUntil: snoozeUntil);

      // 2. Record event
      final event = DoseEvent.create(
        occurrenceId: occ.id,
        userId: currentUserId,
        action: status.name,
        snoozeUntil: snoozeUntil,
        skipReason: skipReason,
      );
      await doseRepo.insertDoseEvent(event);

      // 3. Deduct stock if taken
      if (status == DoseStatus.taken) {
        await refillRepo.recordDeduction(
          medicationId: med.id,
          userId: currentUserId,
          amount: med.amountPerDose,
          doseEventId: event.id,
        );
      }

      if (status == DoseStatus.snoozed && snoozeUntil != null) {
        await NotificationService.scheduleDoseAlarm(
          occurrenceId: occ.id,
          medicationName: med.name,
          doseDescription: '${med.displayDose} • ${med.displayStrength}',
          scheduledAt: snoozeUntil,
        );
      }
      // Each response rolls the future alarm queue forward, so normal use
      // keeps alarms scheduled without requiring a manual app launch.
      DoseAlarmScheduler.syncUpcomingAlarms().ignore();

      // 4. Invalidate providers
      ref.invalidate(todayOccurrencesProvider);
      ref.invalidate(todayAdherenceProvider);
      ref.invalidate(lowStockProvider);
      ref.invalidate(notificationsProvider);
      ref.invalidate(unreadNotificationCountProvider);

      if (!mounted) return;

      // 5. Show feedback and navigate back
      final messages = {
        DoseStatus.taken: '✓ Dose recorded. Well done!',
        DoseStatus.skipped: 'Dose skipped.',
        DoseStatus.snoozed: 'Reminder snoozed.',
      };

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(messages[status] ?? 'Recorded.'),
          backgroundColor:
              status == DoseStatus.taken ? AppColors.takenForeground : null,
          action: status == DoseStatus.taken
              ? null
              : SnackBarAction(
                  label: 'Undo',
                  textColor: Colors.white,
                  onPressed: () => _undo(occ),
                ),
        ),
      );

      if (context.canPop()) {
        context.pop();
      } else {
        context.go(RouteNames.home);
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: AppColors.error),
      );
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  Future<void> _undo(DoseOccurrence occ) async {
    final doseRepo = ref.read(doseRepositoryProvider);
    await doseRepo.updateOccurrenceStatus(occ.id, DoseStatus.pending);
    final currentUserId = AuthService.currentUser?.id ?? occ.userId;
    // Record undo event
    final event = DoseEvent.create(
      occurrenceId: occ.id,
      userId: currentUserId,
      action: 'undo',
    );
    await doseRepo.insertDoseEvent(event);
    ref.invalidate(todayOccurrencesProvider);
    ref.invalidate(todayAdherenceProvider);
    ref.invalidate(notificationsProvider);
    ref.invalidate(unreadNotificationCountProvider);
  }

  Future<void> _snoozeFiveMinutes(
    DoseOccurrence occ,
    Medication med,
  ) async {
    await _recordAction(
      occ,
      med,
      DoseStatus.snoozed,
      snoozeUntil: DateTime.now().add(const Duration(minutes: 5)),
    );
  }

  void _handleInitialAction(DoseOccurrence occ, Medication med) {
    final action = widget.initialAction;
    if (_initialActionHandled || action == null || action.isEmpty) return;
    _initialActionHandled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      switch (action) {
        case 'taken':
          _recordAction(occ, med, DoseStatus.taken).ignore();
          return;
        case 'snooze':
          _snoozeFiveMinutes(occ, med).ignore();
          return;
        case 'skip':
          _showSkipReasonDialog(occ, med).ignore();
          return;
      }
    });
  }

  Future<void> _showSkipReasonDialog(DoseOccurrence occ, Medication med) async {
    const reasons = [
      'Side effects',
      'Feeling better',
      'Forgot earlier',
      'Doctor advised',
      'Out of medication',
      'Other',
    ];

    final selected = await showModalBottomSheet<String>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
            top: Radius.circular(AppDimensions.sheetRadius)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: AppDimensions.stackMd),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.borderMedium,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: AppDimensions.stackMd),
              Text('Skip reason (optional)', style: AppTextStyles.headlineMd()),
              const SizedBox(height: AppDimensions.stackMd),
              for (final reason in reasons)
                ListTile(
                  title: Text(reason, style: AppTextStyles.bodyXl()),
                  onTap: () => Navigator.pop(ctx, reason),
                ),
              ListTile(
                title: Text('No reason',
                    style:
                        AppTextStyles.bodyXl(color: AppColors.textSecondary)),
                onTap: () => Navigator.pop(ctx, ''),
              ),
              const SizedBox(height: AppDimensions.stackMd),
            ],
          ),
        ),
      ),
    );

    if (selected != null) {
      await _recordAction(occ, med, DoseStatus.skipped,
          skipReason: selected.isEmpty ? null : selected);
    }
  }

  @override
  Widget build(BuildContext context) {
    final occAsync = ref.watch(reminderOccurrenceProvider(widget.occurrenceId));

    return occAsync.when(
      loading: () => const DdLoadingScreen(message: 'Loading dose details...'),
      error: (e, _) => Scaffold(body: Center(child: Text('Error: $e'))),
      data: (occ) {
        if (occ == null) {
          return Scaffold(
            appBar: AppBar(title: const Text('Reminder')),
            body: const Center(child: Text('Dose not found')),
          );
        }

        final medAsync =
            ref.watch(reminderMedicationProvider(occ.medicationId));

        return medAsync.when(
          loading: () => const DdLoadingScreen(),
          error: (e, _) => Scaffold(body: Center(child: Text('Error: $e'))),
          data: (med) {
            if (med == null) {
              return Scaffold(
                appBar: AppBar(title: const Text('Reminder')),
                body: const Center(child: Text('Medication not found')),
              );
            }
            _handleInitialAction(occ, med);
            return _buildContent(occ, med);
          },
        );
      },
    );
  }

  Widget _buildContent(DoseOccurrence occ, Medication med) {
    return _buildModernContent(occ, med);
  }

  Widget _buildModernContent(DoseOccurrence occ, Medication med) {
    final alarmTime = occ.status == DoseStatus.snoozed
        ? occ.snoozeUntil ?? occ.scheduledAt
        : occ.scheduledAt;
    final timeStr = DateFormat('h:mm a').format(alarmTime.toLocal());
    final isOverdue = occ.status == DoseStatus.overdue ||
        (occ.status == DoseStatus.pending &&
            occ.scheduledAt.isBefore(DateTime.now())) ||
        (occ.status == DoseStatus.snoozed &&
            alarmTime.isBefore(DateTime.now()));
    final alreadyDone = occ.status.isTerminal;
    final (statusLabel, statusColor, statusBackground) = switch (occ.status) {
      DoseStatus.taken => (
          'DOSE TAKEN',
          AppColors.takenForeground,
          AppColors.takenBackground,
        ),
      DoseStatus.skipped => (
          'DOSE SKIPPED',
          AppColors.skippedForeground,
          AppColors.skippedBackground,
        ),
      DoseStatus.missed => (
          'DOSE MISSED',
          AppColors.missedForeground,
          AppColors.missedBackground,
        ),
      DoseStatus.snoozed => (
          'SNOOZED',
          AppColors.snoozedForeground,
          AppColors.snoozedBackground,
        ),
      _ when isOverdue => (
          'OVERDUE',
          AppColors.overdueForeground,
          AppColors.overdueBackground,
        ),
      _ => (
          'UPCOMING DOSE',
          AppColors.primaryAction,
          AppColors.pendingBackground,
        ),
    };

    return Scaffold(
      backgroundColor: const Color(0xFFF7F3F1),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(
            AppDimensions.screenMargin,
            AppDimensions.stackMd,
            AppDimensions.screenMargin,
            AppDimensions.stack2Xl,
          ),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 560),
              child: Column(
                children: [
                  _AlarmHeroHeader(
                    time: timeStr,
                    isActive: !alreadyDone,
                    isOverdue: isOverdue,
                  ),
                  const SizedBox(height: AppDimensions.stackLg),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 7,
                    ),
                    decoration: BoxDecoration(
                      color: statusBackground,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 7,
                          height: 7,
                          decoration: BoxDecoration(
                            color: statusColor,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          statusLabel,
                          style: AppTextStyles.statusBadge(color: statusColor),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppDimensions.stackMd),
                  _MedicationHero(
                    imageUrl: med.imageUrl,
                    accentColor: statusColor,
                  ),
                  const SizedBox(height: AppDimensions.stackLg),
                  Text(
                    med.name,
                    style: AppTextStyles.displayMedication(),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: AppDimensions.stackXs),
                  Text(
                    med.displayStrength,
                    style: AppTextStyles.bodyLg(
                      color: AppColors.textSecondary,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: AppDimensions.stackLg),
                  Row(
                    children: [
                      Expanded(
                        child: _ReminderDetailTile(
                          icon: isOverdue
                              ? Icons.warning_amber_rounded
                              : Icons.schedule_rounded,
                          label: isOverdue ? 'Was due' : 'Scheduled',
                          value: timeStr,
                          color: statusColor,
                        ),
                      ),
                      const SizedBox(width: AppDimensions.stackMd),
                      Expanded(
                        child: _ReminderDetailTile(
                          icon: Icons.medication_liquid_rounded,
                          label: 'Dose',
                          value: med.displayDose,
                          color: AppColors.primaryAction,
                        ),
                      ),
                    ],
                  ),
                  if (med.instructions?.trim().isNotEmpty ?? false) ...[
                    const SizedBox(height: AppDimensions.stackMd),
                    _InstructionCard(instructions: med.instructions!.trim()),
                  ],
                  const SizedBox(height: AppDimensions.stackLg),
                  if (alreadyDone)
                    _AlreadyDoneView(status: occ.status)
                  else
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(AppDimensions.stackMd),
                      decoration: BoxDecoration(
                        color: AppColors.cardSurface,
                        borderRadius:
                            BorderRadius.circular(AppDimensions.cardRadius),
                        border: Border.all(color: AppColors.borderLight),
                        boxShadow: AppColors.cardShadow,
                      ),
                      child: Column(
                        children: [
                          DdButton(
                            label: 'Mark as taken',
                            onPressed: _isSubmitting
                                ? null
                                : () => _recordAction(
                                      occ,
                                      med,
                                      DoseStatus.taken,
                                    ),
                            isLoading: _isSubmitting,
                            icon: const Icon(
                              Icons.check_rounded,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: AppDimensions.stackMd),
                          LayoutBuilder(
                            builder: (context, constraints) {
                              final snoozeButton = DdButton(
                                label: 'Snooze',
                                onPressed: _isSubmitting
                                    ? null
                                    : () => _snoozeFiveMinutes(occ, med),
                                variant: DdButtonVariant.secondary,
                                icon: const Icon(Icons.alarm_rounded),
                              );
                              final skipButton = DdButton(
                                label: 'Skip dose',
                                onPressed: _isSubmitting
                                    ? null
                                    : () => _showSkipReasonDialog(occ, med),
                                variant: DdButtonVariant.text,
                              );

                              if (constraints.maxWidth < 300) {
                                return Column(
                                  children: [
                                    snoozeButton,
                                    const SizedBox(
                                      height: AppDimensions.stackSm,
                                    ),
                                    skipButton,
                                  ],
                                );
                              }
                              return Row(
                                children: [
                                  Expanded(child: snoozeButton),
                                  const SizedBox(
                                    width: AppDimensions.stackMd,
                                  ),
                                  Expanded(child: skipButton),
                                ],
                              );
                            },
                          ),
                          const SizedBox(height: AppDimensions.stackSm),
                          Text(
                            'Snooze rings this alarm again in 5 minutes',
                            style: AppTextStyles.caption(
                              color: AppColors.textSecondary,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
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

class _AlarmHeroHeader extends StatelessWidget {
  const _AlarmHeroHeader({
    required this.time,
    required this.isActive,
    required this.isOverdue,
  });

  final String time;
  final bool isActive;
  final bool isOverdue;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      constraints: const BoxConstraints(minHeight: 228),
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(32),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF52101E),
            Color(0xFF9F1239),
            Color(0xFFDC143C),
          ],
          stops: [0, 0.58, 1],
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x3DDC143C),
            blurRadius: 28,
            offset: Offset(0, 12),
          ),
        ],
      ),
      child: Stack(
        children: [
          const Positioned(
            right: -44,
            top: -58,
            child: _AlarmRing(size: 178, opacity: 0.09),
          ),
          const Positioned(
            left: -54,
            bottom: -76,
            child: _AlarmRing(size: 160, opacity: 0.07),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(22, 18, 22, 22),
            child: Column(
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 7,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.14),
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(
                          color: Colors.white.withOpacity(0.2),
                        ),
                      ),
                      child: Text(
                        isActive ? 'MEDICATION ALARM' : 'DOSE UPDATED',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1.1,
                        ),
                      ),
                    ),
                    const Spacer(),
                    Icon(
                      isActive
                          ? Icons.notifications_active_rounded
                          : Icons.check_circle_rounded,
                      color: Colors.white,
                      size: 26,
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                Container(
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: Colors.white.withOpacity(0.65),
                      width: 6,
                    ),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x4D000000),
                        blurRadius: 18,
                        offset: Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Icon(
                    Icons.alarm_rounded,
                    color: AppColors.primaryAction,
                    size: 36,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  time,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 36,
                    height: 1,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -1.2,
                  ),
                ),
                const SizedBox(height: 7),
                Text(
                  isOverdue ? 'Your dose is ready now' : 'Your next dose',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.84),
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
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

class _AlarmRing extends StatelessWidget {
  const _AlarmRing({required this.size, required this.opacity});

  final double size;
  final double opacity;

  @override
  Widget build(BuildContext context) => Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(
            color: Colors.white.withOpacity(opacity),
            width: 30,
          ),
        ),
      );
}

class _MedicationHero extends StatelessWidget {
  const _MedicationHero({
    required this.imageUrl,
    required this.accentColor,
  });

  final String? imageUrl;
  final Color accentColor;

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: 1.55,
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.cardSurface,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: AppColors.borderLight),
          boxShadow: AppColors.cardShadow,
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(23),
          child: _buildImage() ?? _buildFallback(),
        ),
      ),
    );
  }

  Widget? _buildImage() {
    final url = imageUrl?.trim();
    if (url == null || url.isEmpty) return null;

    if (url.startsWith('data:image')) {
      try {
        final separator = url.indexOf(',');
        if (separator < 0) return null;
        return Image.memory(
          base64Decode(url.substring(separator + 1)),
          key: const ValueKey('medication-image'),
          width: double.infinity,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => _buildFallback(),
        );
      } catch (_) {
        return null;
      }
    }

    if (url.startsWith('http://') || url.startsWith('https://')) {
      return Image.network(
        url,
        key: const ValueKey('medication-image'),
        width: double.infinity,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => _buildFallback(),
      );
    }
    return null;
  }

  Widget _buildFallback() {
    return Container(
      key: const ValueKey('medication-image-fallback'),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            accentColor.withOpacity(0.16),
            AppColors.cardSurface,
          ],
        ),
      ),
      child: Center(
        child: Container(
          width: 96,
          height: 96,
          decoration: BoxDecoration(
            color: AppColors.cardSurface.withOpacity(0.92),
            shape: BoxShape.circle,
            border: Border.all(color: accentColor.withOpacity(0.2)),
          ),
          child: Icon(
            Icons.medication_rounded,
            size: 52,
            color: accentColor,
          ),
        ),
      ),
    );
  }
}

class _ReminderDetailTile extends StatelessWidget {
  const _ReminderDetailTile({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minHeight: 96),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.cardSurface,
        borderRadius: BorderRadius.circular(AppDimensions.cardRadius),
        border: Border.all(color: AppColors.borderLight),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 18, color: color),
              const SizedBox(width: 7),
              Expanded(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.caption(),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            value,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: AppTextStyles.bodyBold(),
          ),
        ],
      ),
    );
  }
}

class _InstructionCard extends StatelessWidget {
  const _InstructionCard({required this.instructions});

  final String instructions;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppDimensions.stackMd),
      decoration: BoxDecoration(
        color: AppColors.cardSurface,
        borderRadius: BorderRadius.circular(AppDimensions.cardRadius),
        border: Border.all(color: AppColors.borderLight),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: const BoxDecoration(
              color: AppColors.snoozedBackground,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.restaurant_rounded,
              size: 19,
              color: AppColors.snoozedForeground,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Instructions', style: AppTextStyles.labelMd()),
                const SizedBox(height: 2),
                Text(
                  instructions,
                  style: AppTextStyles.bodyLg(
                    color: AppColors.textSecondary,
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

class _AlreadyDoneView extends StatelessWidget {
  const _AlreadyDoneView({required this.status});
  final DoseStatus status;

  @override
  Widget build(BuildContext context) {
    final (icon, label, color) = switch (status) {
      DoseStatus.taken => (
          Icons.check_circle_rounded,
          'Dose Taken',
          AppColors.takenForeground
        ),
      DoseStatus.skipped => (
          Icons.skip_next_rounded,
          'Dose Skipped',
          AppColors.skippedForeground
        ),
      DoseStatus.snoozed => (
          Icons.alarm_rounded,
          'Reminder Snoozed',
          AppColors.snoozedForeground
        ),
      _ => (Icons.info_rounded, 'Status Recorded', AppColors.textTertiary),
    };

    return Column(
      children: [
        Icon(icon, size: 64, color: color),
        const SizedBox(height: AppDimensions.stackMd),
        Text(label, style: AppTextStyles.headlineMd(color: color)),
        const SizedBox(height: AppDimensions.stackXl),
        DdButton(
          label: 'Back to Schedule',
          onPressed: () => Navigator.of(context).pop(),
          variant: DdButtonVariant.secondary,
        ),
      ],
    );
  }
}
