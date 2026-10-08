import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/theme/app_dimensions.dart';
import '../../core/widgets/dd_button.dart';
import '../../core/widgets/dd_loading.dart';
import '../../data/local/models/app_models.dart';
import '../../data/local/models/dose_status.dart';
import '../../data/repositories/app_repositories.dart';
import '../../data/remote/auth_service.dart';
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
  const ReminderScreen({required this.occurrenceId, super.key});
  final String occurrenceId;

  @override
  ConsumerState<ReminderScreen> createState() => _ReminderScreenState();
}

class _ReminderScreenState extends ConsumerState<ReminderScreen> {
  bool _isSubmitting = false;

  Future<void> _recordAction(
    DoseOccurrence occ,
    Medication med,
    DoseStatus status, {
    DateTime? snoozeUntil,
    String? skipReason,
  }) async {
    setState(() => _isSubmitting = true);

    try {
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

      // 4. Invalidate providers
      ref.invalidate(todayOccurrencesProvider);
      ref.invalidate(todayAdherenceProvider);
      ref.invalidate(lowStockProvider);

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

      context.pop();
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
  }

  Future<void> _showSnoozeDialog(DoseOccurrence occ, Medication med) async {
    final options = [
      ('10 minutes', const Duration(minutes: 10)),
      ('30 minutes', const Duration(minutes: 30)),
      ('1 hour', const Duration(hours: 1)),
      ('2 hours', const Duration(hours: 2)),
    ];

    final selected = await showModalBottomSheet<Duration>(
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
              Text('Snooze for...', style: AppTextStyles.headlineMd()),
              const SizedBox(height: AppDimensions.stackMd),
              for (final (label, duration) in options)
                ListTile(
                  title: Text(label, style: AppTextStyles.bodyXl()),
                  leading: const Icon(Icons.alarm_rounded,
                      color: AppColors.primaryAction),
                  onTap: () => Navigator.pop(ctx, duration),
                ),
              const SizedBox(height: AppDimensions.stackMd),
            ],
          ),
        ),
      ),
    );

    if (selected != null) {
      final snoozeUntil = DateTime.now().add(selected);
      await _recordAction(occ, med, DoseStatus.snoozed,
          snoozeUntil: snoozeUntil);
    }
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
    final timeStr = DateFormat('h:mm a').format(occ.scheduledAt.toLocal());
    final isOverdue = occ.status == DoseStatus.overdue ||
        (occ.status == DoseStatus.pending &&
            occ.scheduledAt.isBefore(DateTime.now()));
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
      backgroundColor: AppColors.scaffoldBackground,
      appBar: AppBar(
        title: const Text('Dose reminder'),
        centerTitle: true,
      ),
      body: SafeArea(
        top: false,
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
                                    : () => _showSnoozeDialog(occ, med),
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
