import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:table_calendar/table_calendar.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/theme/app_dimensions.dart';
import '../../core/widgets/dd_card.dart';
import '../../core/widgets/dd_loading.dart';
import '../../core/widgets/dd_status_badge.dart';
import '../../data/local/models/app_models.dart';
import '../../data/local/models/dose_status.dart';
import '../../data/repositories/app_repositories.dart';

// ── Providers ─────────────────────────────────────────────────────────────────

final historySelectedDateProvider = StateProvider<DateTime>((ref) => DateTime.now());

final historyOccurrencesProvider = FutureProvider.family<List<DoseOccurrence>, DateTime>((ref, date) async {
  final repo = ref.watch(doseRepositoryProvider);
  return repo.getOccurrencesForDate(date);
});

final historyAdherenceByDateProvider = FutureProvider.family<AdherenceSummary, DateTime>((ref, date) async {
  final repo = ref.watch(doseRepositoryProvider);
  return repo.getDayAdherence(date);
});

final historyMedsProvider = FutureProvider<List<Medication>>((ref) async {
  final repo = ref.watch(medicationRepositoryProvider);
  return repo.getMedications(activeOnly: false);
});

// ── Screen ─────────────────────────────────────────────────────────────────────

class HistoryScreen extends ConsumerWidget {
  const HistoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedDate = ref.watch(historySelectedDateProvider);
    final medsAsync = ref.watch(historyMedsProvider);

    return Scaffold(
      backgroundColor: AppColors.scaffoldBackground,
      appBar: AppBar(
        title: const Text('History'),
        automaticallyImplyLeading: false,
      ),
      body: CustomScrollView(
        slivers: [
          // Calendar
          SliverToBoxAdapter(
            child: _CalendarSection(selectedDate: selectedDate),
          ),

          // Adherence summary for selected date
          SliverToBoxAdapter(
            child: _DayAdherenceCard(selectedDate: selectedDate),
          ),

          // History list
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(
              AppDimensions.screenMargin,
              AppDimensions.screenMargin,
              AppDimensions.screenMargin,
              110,
            ),
            sliver: Consumer(
              builder: (ctx, ref, _) {
                final occsAsync = ref.watch(historyOccurrencesProvider(selectedDate));
                return occsAsync.when(
                  loading: () => const SliverToBoxAdapter(child: DdLoading()),
                  error: (e, _) => SliverToBoxAdapter(
                    child: Text('Error: $e'),
                  ),
                  data: (occs) => medsAsync.when(
                    loading: () => const SliverToBoxAdapter(child: DdLoading()),
                    error: (_, __) => const SliverToBoxAdapter(child: SizedBox.shrink()),
                    data: (meds) {
                      if (occs.isEmpty) {
                        return SliverToBoxAdapter(
                          child: DdEmptyState(
                            icon: Icons.history_rounded,
                            title: 'No doses recorded',
                            subtitle: 'No medication records exist for ${DateFormat('MMMM d').format(selectedDate)}.',
                          ),
                        );
                      }
                      return SliverList(
                        delegate: SliverChildBuilderDelegate(
                          (ctx, i) {
                            final occ = occs[i];
                            final med = meds.where((m) => m.id == occ.medicationId).firstOrNull;
                            if (med == null) return const SizedBox.shrink();
                            return Padding(
                              padding: const EdgeInsets.only(bottom: AppDimensions.stackMd),
                              child: _HistoryItem(occ: occ, med: med),
                            );
                          },
                          childCount: occs.length,
                        ),
                      );
                    },
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

// ── Calendar ───────────────────────────────────────────────────────────────────

class _CalendarSection extends ConsumerWidget {
  const _CalendarSection({required this.selectedDate});
  final DateTime selectedDate;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      color: AppColors.cardSurface,
      child: TableCalendar<Object>(
        firstDay: DateTime.now().subtract(const Duration(days: 365)),
        lastDay: DateTime.now(),
        focusedDay: selectedDate,
        selectedDayPredicate: (d) => isSameDay(d, selectedDate),
        onDaySelected: (selected, focused) {
          ref.read(historySelectedDateProvider.notifier).state = selected;
        },
        calendarStyle: CalendarStyle(
          selectedDecoration: const BoxDecoration(
            color: AppColors.primaryAction,
            shape: BoxShape.circle,
          ),
          todayDecoration: BoxDecoration(
            color: AppColors.primaryAction.withOpacity(0.15),
            shape: BoxShape.circle,
          ),
          todayTextStyle: AppTextStyles.bodyBold(color: AppColors.primaryAction),
          selectedTextStyle: AppTextStyles.bodyBold(color: Colors.white),
          outsideDaysVisible: false,
        ),
        headerStyle: HeaderStyle(
          formatButtonVisible: false,
          titleCentered: true,
          titleTextStyle: AppTextStyles.bodyBold(),
          leftChevronIcon: const Icon(Icons.chevron_left, color: AppColors.textPrimary),
          rightChevronIcon: const Icon(Icons.chevron_right, color: AppColors.textPrimary),
        ),
        rowHeight: 46,
      ),
    );
  }
}

// ── Adherence Card ─────────────────────────────────────────────────────────────

class _DayAdherenceCard extends ConsumerWidget {
  const _DayAdherenceCard({required this.selectedDate});
  final DateTime selectedDate;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final summaryAsync = ref.watch(historyAdherenceByDateProvider(selectedDate));
    return summaryAsync.when(
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
      data: (summary) {
        if (summary.countable == 0) return const SizedBox.shrink();
        return Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppDimensions.screenMargin,
            vertical: AppDimensions.stackMd,
          ),
          child: DdCard(
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        DateFormat('MMMM d').format(selectedDate),
                        style: AppTextStyles.bodyBold(),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${summary.taken} of ${summary.countable} doses taken',
                        style: AppTextStyles.bodyLg(color: AppColors.textSecondary),
                      ),
                      const SizedBox(height: AppDimensions.stackSm),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: summary.taken / summary.countable,
                          backgroundColor: AppColors.borderLight,
                          color: AppColors.takenForeground,
                          minHeight: 6,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: AppDimensions.stackLg),
                Text(
                  summary.percentageStr,
                  style: AppTextStyles.headlineLg(
                    color: summary.percentage >= 80
                        ? AppColors.takenForeground
                        : summary.percentage >= 50
                            ? AppColors.skippedForeground
                            : AppColors.primaryAction,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

// ── History Item ───────────────────────────────────────────────────────────────

class _HistoryItem extends StatelessWidget {
  const _HistoryItem({required this.occ, required this.med});
  final DoseOccurrence occ;
  final Medication med;

  @override
  Widget build(BuildContext context) {
    final timeStr = DateFormat('h:mm a').format(occ.scheduledAt.toLocal());

    return DdCard(
      padding: const EdgeInsets.symmetric(
        horizontal: AppDimensions.cardPadding,
        vertical: AppDimensions.stackMd,
      ),
      child: Row(
        children: [
          _StatusCircle(status: occ.status),
          const SizedBox(width: AppDimensions.stackMd),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(med.name, style: AppTextStyles.bodyBold()),
                const SizedBox(height: 2),
                Text(
                  '${med.displayStrength} · ${med.displayDose} · $timeStr',
                  style: AppTextStyles.caption(),
                ),
              ],
            ),
          ),
          const SizedBox(width: AppDimensions.stackSm),
          DdStatusBadge(status: occ.status),
        ],
      ),
    );
  }
}

class _StatusCircle extends StatelessWidget {
  const _StatusCircle({required this.status});
  final DoseStatus status;

  @override
  Widget build(BuildContext context) {
    final color = switch (status) {
      DoseStatus.taken => AppColors.takenForeground,
      DoseStatus.missed => AppColors.missedForeground,
      DoseStatus.skipped => AppColors.skippedForeground,
      DoseStatus.overdue => AppColors.overdueForeground,
      DoseStatus.snoozed => AppColors.snoozedForeground,
      _ => AppColors.pendingForeground,
    };

    final icon = switch (status) {
      DoseStatus.taken => Icons.check_rounded,
      DoseStatus.missed => Icons.close_rounded,
      DoseStatus.skipped => Icons.skip_next_rounded,
      DoseStatus.overdue => Icons.warning_rounded,
      DoseStatus.snoozed => Icons.alarm_rounded,
      _ => Icons.schedule_rounded,
    };

    return Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        shape: BoxShape.circle,
      ),
      child: Icon(icon, color: color, size: 18),
    );
  }
}
