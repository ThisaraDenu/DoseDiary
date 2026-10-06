import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/theme/app_dimensions.dart';
import '../../core/widgets/dd_card.dart';
import '../../core/widgets/dd_loading.dart';
import '../../core/widgets/dd_status_badge.dart';
import '../../core/router/route_names.dart';
import '../../data/repositories/app_repositories.dart';
import '../../data/local/models/app_models.dart';

// ── Providers ─────────────────────────────────────────────────────────────────

final selectedScheduleDateProvider = StateProvider<DateTime>((ref) => DateTime.now());

final scheduleOccurrencesProvider = FutureProvider.family<List<DoseOccurrence>, DateTime>((ref, date) async {
  final repo = ref.watch(doseRepositoryProvider);
  return repo.getOccurrencesForDate(date);
});

// ── Screen ─────────────────────────────────────────────────────────────────────

class MedicationScheduleScreen extends ConsumerWidget {
  const MedicationScheduleScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedDate = ref.watch(selectedScheduleDateProvider);
    final occsAsync = ref.watch(scheduleOccurrencesProvider(selectedDate));
    final medsAsync = ref.watch(allActiveMedsProvider);

    return Scaffold(
      backgroundColor: AppColors.scaffoldBackground,
      appBar: AppBar(
        title: const Text('Medications'),
        automaticallyImplyLeading: false,
        actions: [
          IconButton(
            icon: const Icon(Icons.add_rounded),
            onPressed: () => context.push(RouteNames.addMedication),
            tooltip: 'Add Medication',
          ),
        ],
      ),
      body: Column(
        children: [
          // Date selector
          _DateStrip(
            selectedDate: selectedDate,
            onDateChanged: (d) => ref.read(selectedScheduleDateProvider.notifier).state = d,
          ),
          const Divider(height: 1),

          // Schedule list
          Expanded(
            child: occsAsync.when(
              loading: () => const DdLoading(),
              error: (e, _) => Center(
                child: Text('Error loading schedule', style: AppTextStyles.bodyLg(color: AppColors.error)),
              ),
              data: (occs) => medsAsync.when(
                loading: () => const DdLoading(),
                error: (_, __) => const SizedBox.shrink(),
                data: (meds) {
                  if (occs.isEmpty) {
                    return DdEmptyState(
                      icon: Icons.medication_outlined,
                      title: 'No doses scheduled',
                      subtitle: 'No medications are scheduled for this day.',
                      actionLabel: 'Add Medication',
                      onAction: () => context.push(RouteNames.addMedication),
                    );
                  }
                  return ListView.separated(
                    padding: const EdgeInsets.fromLTRB(
                      AppDimensions.screenMargin,
                      AppDimensions.screenMargin,
                      AppDimensions.screenMargin,
                      110,
                    ),
                    itemCount: occs.length,
                    separatorBuilder: (_, __) => const SizedBox(height: AppDimensions.stackMd),
                    itemBuilder: (ctx, i) {
                      final occ = occs[i];
                      final med = meds.where((m) => m.id == occ.medicationId).firstOrNull;
                      if (med == null) return const SizedBox.shrink();
                      return _MedicationCard(occ: occ, med: med);
                    },
                  );
                },
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push(RouteNames.addMedication),
        backgroundColor: AppColors.primaryAction,
        icon: const Icon(Icons.add_rounded, color: Colors.white),
        label: Text('Add Medication', style: AppTextStyles.labelLg(color: Colors.white)),
      ),
    );
  }
}

// ── Date Strip ─────────────────────────────────────────────────────────────────

class _DateStrip extends StatelessWidget {
  const _DateStrip({required this.selectedDate, required this.onDateChanged});
  final DateTime selectedDate;
  final ValueChanged<DateTime> onDateChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.cardSurface,
      padding: const EdgeInsets.symmetric(
        horizontal: AppDimensions.screenMargin,
        vertical: AppDimensions.stackMd,
      ),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.chevron_left),
            onPressed: () => onDateChanged(selectedDate.subtract(const Duration(days: 1))),
            tooltip: 'Previous day',
          ),
          Expanded(
            child: GestureDetector(
              onTap: () async {
                final picked = await showDatePicker(
                  context: context,
                  initialDate: selectedDate,
                  firstDate: DateTime(2020),
                  lastDate: DateTime.now().add(const Duration(days: 365)),
                  builder: (ctx, child) => Theme(
                    data: Theme.of(ctx).copyWith(
                      colorScheme: Theme.of(ctx).colorScheme.copyWith(primary: AppColors.primaryAction),
                    ),
                    child: child!,
                  ),
                );
                if (picked != null) onDateChanged(picked);
              },
              child: Column(
                children: [
                  Text(
                    DateFormat('EEEE').format(selectedDate),
                    style: AppTextStyles.bodyBold(),
                  ),
                  Text(
                    DateFormat('d MMMM yyyy').format(selectedDate),
                    style: AppTextStyles.caption(),
                  ),
                ],
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.chevron_right),
            onPressed: () => onDateChanged(selectedDate.add(const Duration(days: 1))),
            tooltip: 'Next day',
          ),
        ],
      ),
    );
  }
}

// ── Medication Card ─────────────────────────────────────────────────────────────

class _MedicationCard extends StatelessWidget {
  const _MedicationCard({required this.occ, required this.med});
  final DoseOccurrence occ;
  final Medication med;

  @override
  Widget build(BuildContext context) {
    final timeStr = DateFormat('h:mm a').format(occ.scheduledAt.toLocal());

    return DdCard(
      onTap: occ.status.isActionable ? () => context.push('/reminder/${occ.id}') : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(timeStr, style: AppTextStyles.bodyBold(color: AppColors.primaryAction)),
              const Spacer(),
              DdStatusBadge(status: occ.status),
              const SizedBox(width: AppDimensions.stackSm),
              IconButton(
                icon: const Icon(Icons.edit_outlined, size: 20),
                onPressed: () => context.push('/medications/${med.id}/edit'),
                tooltip: 'Edit',
                constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
                padding: EdgeInsets.zero,
              ),
            ],
          ),
          const SizedBox(height: AppDimensions.stackSm),
          Text(med.name, style: AppTextStyles.displayMedication()),
          const SizedBox(height: AppDimensions.stackXs),
          Text(
            '${med.displayStrength} · ${med.displayDose}',
            style: AppTextStyles.bodyBold(color: AppColors.textSecondary),
          ),
          if (med.instructions != null) ...[
            const SizedBox(height: AppDimensions.stackSm),
            Row(
              children: [
                const Icon(Icons.info_outline, size: 16, color: AppColors.textTertiary),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    med.instructions!,
                    style: AppTextStyles.bodyLg(color: AppColors.textSecondary),
                  ),
                ),
              ],
            ),
          ],
          if (occ.status.isActionable) ...[
            const SizedBox(height: AppDimensions.stackLg),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => context.push('/reminder/${occ.id}'),
                style: ElevatedButton.styleFrom(minimumSize: const Size(double.infinity, 48)),
                child: const Text("I've Taken It"),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
