import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/theme/app_dimensions.dart';
import '../../core/widgets/dd_card.dart';
import '../../core/widgets/dd_button.dart';
import '../../core/widgets/dd_loading.dart';
import '../../data/local/models/app_models.dart';
import '../../data/local/models/dose_status.dart';
import '../../data/repositories/app_repositories.dart';
import '../../data/remote/auth_service.dart';
import '../home/home_dashboard_screen.dart';

// ── Providers ─────────────────────────────────────────────────────────────────

final reminderOccurrenceProvider = FutureProvider.family<DoseOccurrence?, String>((ref, id) async {
  final repo = ref.watch(doseRepositoryProvider);
  return repo.getOccurrenceById(id);
});

final reminderMedicationProvider = FutureProvider.family<Medication?, String>((ref, medicationId) async {
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

class _ReminderScreenState extends ConsumerState<ReminderScreen> with SingleTickerProviderStateMixin {
  bool _isSubmitting = false;
  late final AnimationController _pulseCtrl;

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulseCtrl.dispose();
    super.dispose();
  }

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
      await doseRepo.updateOccurrenceStatus(occ.id, status, snoozeUntil: snoozeUntil);

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
          backgroundColor: status == DoseStatus.taken ? AppColors.takenForeground : null,
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
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppDimensions.sheetRadius)),
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
                  leading: const Icon(Icons.alarm_rounded, color: AppColors.primaryAction),
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
      await _recordAction(occ, med, DoseStatus.snoozed, snoozeUntil: snoozeUntil);
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
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppDimensions.sheetRadius)),
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
                title: Text('No reason', style: AppTextStyles.bodyXl(color: AppColors.textSecondary)),
                onTap: () => Navigator.pop(ctx, ''),
              ),
              const SizedBox(height: AppDimensions.stackMd),
            ],
          ),
        ),
      ),
    );

    if (selected != null) {
      await _recordAction(occ, med, DoseStatus.skipped, skipReason: selected.isEmpty ? null : selected);
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

        final medAsync = ref.watch(reminderMedicationProvider(occ.medicationId));

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
    final timeStr = DateFormat('h:mm a').format(occ.scheduledAt.toLocal());
    final now = DateTime.now();
    final isOverdue = occ.scheduledAt.isBefore(now) && occ.status.isActionable;
    final alreadyDone = occ.status.isTerminal;

    return Scaffold(
      backgroundColor: AppColors.scaffoldBackground,
      appBar: AppBar(title: const Text('Reminder')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppDimensions.screenMargin),
        child: Column(
          children: [
            const SizedBox(height: AppDimensions.stackXl),

            // Animated medication icon
            AnimatedBuilder(
              animation: _pulseCtrl,
              builder: (ctx, child) => Transform.scale(
                scale: alreadyDone ? 1.0 : (1.0 + _pulseCtrl.value * (isOverdue ? 0.06 : 0.03)),
                child: Container(
                  width: 100,
                  height: 100,
                  decoration: BoxDecoration(
                    color: isOverdue
                        ? AppColors.pendingBackground
                        : AppColors.primaryAction.withOpacity(0.08),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.medication_rounded,
                    size: 56,
                    color: isOverdue ? AppColors.primaryAction : AppColors.primaryAction,
                  ),
                ),
              ),
            ),
            const SizedBox(height: AppDimensions.stackXl),

            // Medication name and details
            Text(med.name, style: AppTextStyles.displayMedication(), textAlign: TextAlign.center),
            const SizedBox(height: AppDimensions.stackSm),
            Text(
              '${med.displayStrength} · ${med.displayDose}',
              style: AppTextStyles.headlineMd(color: AppColors.textSecondary),
              textAlign: TextAlign.center,
            ),
            if (med.instructions != null) ...[
              const SizedBox(height: AppDimensions.stackMd),
              Container(
                padding: const EdgeInsets.all(AppDimensions.stackMd),
                decoration: BoxDecoration(
                  color: AppColors.snoozedBackground,
                  borderRadius: BorderRadius.circular(AppDimensions.badgeRadius),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.info_outline, size: 18, color: AppColors.snoozedForeground),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        med.instructions!,
                        style: AppTextStyles.bodyLg(color: AppColors.textSecondary),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: AppDimensions.stackXl),

            // Scheduled time card
            DdCard(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    isOverdue ? Icons.warning_amber_rounded : Icons.schedule_rounded,
                    color: isOverdue ? AppColors.primaryAction : AppColors.textSecondary,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    isOverdue ? 'Overdue — was scheduled at $timeStr' : 'Scheduled at $timeStr',
                    style: AppTextStyles.bodyBold(
                      color: isOverdue ? AppColors.primaryAction : AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppDimensions.stackXl),

            if (alreadyDone)
              _AlreadyDoneView(status: occ.status)
            else ...[
              // Take it button
              DdButton(
                label: "I've Taken It",
                onPressed: _isSubmitting ? null : () => _recordAction(occ, med, DoseStatus.taken),
                isLoading: _isSubmitting,
                icon: const Icon(Icons.check_rounded, color: Colors.white),
              ),
              const SizedBox(height: AppDimensions.stackMd),

              // Snooze button
              DdButton(
                label: 'Snooze Reminder',
                onPressed: _isSubmitting ? null : () => _showSnoozeDialog(occ, med),
                variant: DdButtonVariant.secondary,
                icon: const Icon(Icons.alarm_rounded),
              ),
              const SizedBox(height: AppDimensions.stackMd),

              // Skip button
              DdButton(
                label: 'Skip This Dose',
                onPressed: _isSubmitting ? null : () => _showSkipReasonDialog(occ, med),
                variant: DdButtonVariant.text,
              ),
            ],

            const SizedBox(height: AppDimensions.stackXl),
          ],
        ),
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
      DoseStatus.taken => (Icons.check_circle_rounded, 'Dose Taken', AppColors.takenForeground),
      DoseStatus.skipped => (Icons.skip_next_rounded, 'Dose Skipped', AppColors.skippedForeground),
      DoseStatus.snoozed => (Icons.alarm_rounded, 'Reminder Snoozed', AppColors.snoozedForeground),
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
