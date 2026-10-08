import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../core/router/route_names.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_dimensions.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/widgets/dd_loading.dart';
import '../../data/local/models/app_models.dart';
import '../../data/local/models/dose_status.dart';
import '../../data/repositories/app_repositories.dart';
import 'history_pdf_service.dart';
import 'weekly_adherence_charts.dart';

enum HistoryViewMode { day, week }

final historyViewModeProvider =
    StateProvider<HistoryViewMode>((ref) => HistoryViewMode.day);
final historySelectedDateProvider =
    StateProvider<DateTime>((ref) => DateUtils.dateOnly(DateTime.now()));

class HistoryData {
  const HistoryData({
    required this.occurrences,
    required this.medications,
    required this.latestEvents,
  });

  final List<DoseOccurrence> occurrences;
  final Map<String, Medication> medications;
  final Map<String, DoseEvent> latestEvents;

  int get scheduledCount => occurrences.length;
  int get takenCount =>
      occurrences.where((item) => item.status == DoseStatus.taken).length;
  double get adherence => scheduledCount == 0 ? 0 : takenCount / scheduledCount;
}

final historyDataProvider =
    FutureProvider.family<HistoryData, DateTime>((ref, selectedDate) async {
  final endDay = DateUtils.dateOnly(selectedDate);
  final startDay = endDay.subtract(const Duration(days: 6));
  final rangeEnd = endDay.add(const Duration(days: 1));
  final doseRepo = ref.watch(doseRepositoryProvider);
  final medicationRepo = ref.watch(medicationRepositoryProvider);

  final occurrences = await doseRepo.getOccurrencesForDateRange(
    startDay.toUtc(),
    rangeEnd.subtract(const Duration(microseconds: 1)).toUtc(),
  );
  final medications = await medicationRepo.getMedications(activeOnly: false);
  final medicationMap = {for (final med in medications) med.id: med};
  final latestEvents = <String, DoseEvent>{};
  for (final occurrence in occurrences) {
    final events = await doseRepo.getEventsForOccurrence(occurrence.id);
    if (events.isNotEmpty) latestEvents[occurrence.id] = events.first;
  }
  return HistoryData(
    occurrences: occurrences
        .where((item) => medicationMap.containsKey(item.medicationId))
        .toList(),
    medications: medicationMap,
    latestEvents: latestEvents,
  );
});

class HistoryScreen extends ConsumerWidget {
  const HistoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedDate = ref.watch(historySelectedDateProvider);
    final viewMode = ref.watch(historyViewModeProvider);
    final historyAsync = ref.watch(historyDataProvider(selectedDate));

    return Scaffold(
      backgroundColor: const Color(0xFFF7F7F9),
      appBar: AppBar(
        title: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.medical_services_outlined, size: 18),
            SizedBox(width: 7),
            Text('History'),
          ],
        ),
        automaticallyImplyLeading: false,
      ),
      body: historyAsync.when(
        loading: () => const DdLoadingScreen(message: 'Loading history...'),
        error: (error, _) => _HistoryError(
          onRetry: () => ref.invalidate(historyDataProvider(selectedDate)),
        ),
        data: (data) => RefreshIndicator(
          color: AppColors.primaryAction,
          onRefresh: () async {
            ref.invalidate(historyDataProvider(selectedDate));
            await ref.read(historyDataProvider(selectedDate).future);
          },
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: EdgeInsets.fromLTRB(
              12,
              8,
              12,
              AppDimensions.navBarHeight +
                  MediaQuery.paddingOf(context).bottom +
                  AppDimensions.stackXl,
            ),
            children: [
              _HistoryHeader(
                onBack: () {
                  if (context.canPop()) {
                    context.pop();
                  } else {
                    context.go(RouteNames.home);
                  }
                },
                onExport: () => _showHistoryExportSheet(
                  context,
                  data: data,
                  selectedDate: selectedDate,
                ),
              ),
              const SizedBox(height: 12),
              const _ViewModeTabs(),
              const SizedBox(height: 10),
              _PeriodSelector(
                selectedDate: selectedDate,
                viewMode: viewMode,
              ),
              const SizedBox(height: 12),
              _WeeklyAdherenceCard(data: data, selectedDate: selectedDate),
              const SizedBox(height: 14),
              if (viewMode == HistoryViewMode.day)
                _DayHistory(data: data, selectedDate: selectedDate)
              else
                _WeekHistory(data: data, selectedDate: selectedDate),
              const SizedBox(height: 14),
              const _StatusReference(),
            ],
          ),
        ),
      ),
    );
  }
}

Future<void> _showHistoryExportSheet(
  BuildContext context, {
  required HistoryData data,
  required DateTime selectedDate,
}) {
  return showModalBottomSheet<void>(
    context: context,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
    ),
    builder: (sheetContext) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 18),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: const Color(0xFFD2D2D6),
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
            ),
            const SizedBox(height: 18),
            Text('Get history as PDF', style: AppTextStyles.headlineMd()),
            const SizedBox(height: 4),
            Text(
              'Choose a period, then select where to download the PDF.',
              style: AppTextStyles.caption(),
            ),
            const SizedBox(height: 12),
            ListTile(
              key: const ValueKey('export-day-history-pdf'),
              contentPadding: const EdgeInsets.symmetric(horizontal: 4),
              leading: const CircleAvatar(
                backgroundColor: Color(0xFFFFE8EE),
                foregroundColor: AppColors.primaryAction,
                child: Icon(Icons.today_outlined),
              ),
              title: const Text('Download daily history PDF'),
              subtitle: Text(DateFormat('d MMMM yyyy').format(selectedDate)),
              trailing: const Icon(Icons.download_rounded),
              onTap: () {
                Navigator.pop(sheetContext);
                _exportHistoryPdf(
                  context,
                  period: HistoryPdfPeriod.day,
                  selectedDate: selectedDate,
                  data: data,
                );
              },
            ),
            ListTile(
              key: const ValueKey('export-week-history-pdf'),
              contentPadding: const EdgeInsets.symmetric(horizontal: 4),
              leading: const CircleAvatar(
                backgroundColor: Color(0xFFE3F4EE),
                foregroundColor: Color(0xFF14735C),
                child: Icon(Icons.date_range_outlined),
              ),
              title: const Text('Download weekly history PDF'),
              subtitle: Text(
                '${DateFormat('d MMM').format(selectedDate.subtract(const Duration(days: 6)))} - '
                '${DateFormat('d MMM yyyy').format(selectedDate)}',
              ),
              trailing: const Icon(Icons.download_rounded),
              onTap: () {
                Navigator.pop(sheetContext);
                _exportHistoryPdf(
                  context,
                  period: HistoryPdfPeriod.week,
                  selectedDate: selectedDate,
                  data: data,
                );
              },
            ),
          ],
        ),
      ),
    ),
  );
}

Future<void> _exportHistoryPdf(
  BuildContext context, {
  required HistoryPdfPeriod period,
  required DateTime selectedDate,
  required HistoryData data,
}) async {
  final messenger = ScaffoldMessenger.of(context);
  messenger.showSnackBar(
    const SnackBar(content: Text('Creating medication history PDF...')),
  );
  try {
    final destination = await HistoryPdfService.export(
      period: period,
      selectedDate: selectedDate,
      occurrences: data.occurrences,
      medications: data.medications,
      latestEvents: data.latestEvents,
    );
    if (!context.mounted) return;
    messenger.hideCurrentSnackBar();
    if (destination == null) {
      messenger.showSnackBar(
        const SnackBar(content: Text('PDF download canceled.')),
      );
      return;
    }
    messenger.showSnackBar(
      const SnackBar(
        content: Text('Medication history PDF downloaded successfully.'),
      ),
    );
  } catch (_) {
    if (!context.mounted) return;
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(
      const SnackBar(
          content: Text('Could not save the history PDF. Try again.')),
    );
  }
}

class _HistoryHeader extends StatelessWidget {
  const _HistoryHeader({required this.onBack, required this.onExport});

  final VoidCallback onBack;
  final VoidCallback onExport;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _RoundIconButton(
          icon: Icons.arrow_back_rounded,
          tooltip: 'Back',
          onPressed: onBack,
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            'Medication History',
            style: AppTextStyles.headlineMd(),
          ),
        ),
        _RoundIconButton(
          icon: Icons.share_outlined,
          tooltip: 'Download history PDF',
          onPressed: onExport,
        ),
      ],
    );
  }
}

class _RoundIconButton extends StatelessWidget {
  const _RoundIconButton({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xFFEDEDEF),
      shape: const CircleBorder(),
      child: IconButton(
        icon: Icon(icon, size: 20),
        tooltip: tooltip,
        onPressed: onPressed,
      ),
    );
  }
}

class _ViewModeTabs extends ConsumerWidget {
  const _ViewModeTabs();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mode = ref.watch(historyViewModeProvider);
    return Container(
      height: 44,
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: const Color(0xFFE7E7E9),
        borderRadius: BorderRadius.circular(9),
      ),
      child: Row(
        children: [
          for (final item in HistoryViewMode.values)
            Expanded(
              child: InkWell(
                key: ValueKey('history-tab-${item.name}'),
                onTap: () =>
                    ref.read(historyViewModeProvider.notifier).state = item,
                borderRadius: BorderRadius.circular(7),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: mode == item
                        ? AppColors.primaryAction
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(7),
                  ),
                  child: Text(
                    item == HistoryViewMode.day ? 'Day' : 'Week',
                    style: AppTextStyles.labelMd(
                      color:
                          mode == item ? Colors.white : AppColors.textSecondary,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _PeriodSelector extends ConsumerWidget {
  const _PeriodSelector({
    required this.selectedDate,
    required this.viewMode,
  });

  final DateTime selectedDate;
  final HistoryViewMode viewMode;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final today = DateUtils.dateOnly(DateTime.now());
    final selected = DateUtils.dateOnly(selectedDate);
    String value;
    if (viewMode == HistoryViewMode.week) {
      final start = selected.subtract(const Duration(days: 6));
      value =
          '${DateFormat('d MMM').format(start)} – ${DateFormat('d MMM yyyy').format(selected)}';
    } else if (selected == today) {
      value = 'Today, ${DateFormat('d MMM yyyy').format(selected)}';
    } else {
      value = DateFormat('EEEE, d MMM yyyy').format(selected);
    }

    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        onTap: () async {
          final picked = await showDatePicker(
            context: context,
            initialDate: selected,
            firstDate: today.subtract(const Duration(days: 730)),
            lastDate: today,
          );
          if (picked != null) {
            ref.read(historySelectedDateProvider.notifier).state =
                DateUtils.dateOnly(picked);
          }
        },
        borderRadius: BorderRadius.circular(10),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            children: [
              const Icon(
                Icons.calendar_today_outlined,
                size: 18,
                color: AppColors.primaryAction,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Selected Period', style: AppTextStyles.caption()),
                    const SizedBox(height: 2),
                    Text(value, style: AppTextStyles.bodyBold()),
                  ],
                ),
              ),
              const Icon(Icons.keyboard_arrow_down_rounded),
            ],
          ),
        ),
      ),
    );
  }
}

class _WeeklyAdherenceCard extends StatelessWidget {
  const _WeeklyAdherenceCard({required this.data, required this.selectedDate});

  final HistoryData data;
  final DateTime selectedDate;

  @override
  Widget build(BuildContext context) {
    final percentage = (data.adherence * 100).round();
    final onTrack = percentage >= 80;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE8E8EA)),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 70,
            height: 70,
            child: Stack(
              alignment: Alignment.center,
              children: [
                SizedBox.expand(
                  child: CircularProgressIndicator(
                    value: data.adherence,
                    strokeWidth: 7,
                    backgroundColor: const Color(0xFFE9EEEC),
                    color: const Color(0xFF158B68),
                    strokeCap: StrokeCap.round,
                  ),
                ),
                Text(
                  '$percentage%',
                  style: AppTextStyles.bodyBold(
                    color: const Color(0xFF166B55),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Weekly Adherence', style: AppTextStyles.bodyBold()),
                const SizedBox(height: 4),
                Text(
                  '${data.takenCount} of ${data.scheduledCount} scheduled',
                  style: AppTextStyles.caption(),
                ),
                const SizedBox(height: 3),
                Text(
                  '${data.takenCount} doses taken',
                  style: AppTextStyles.caption(),
                ),
              ],
            ),
          ),
          Material(
            color: onTrack ? const Color(0xFF0E8A68) : const Color(0xFFFFE7E9),
            borderRadius: BorderRadius.circular(999),
            child: InkWell(
              key: const ValueKey('weekly-adherence-review'),
              borderRadius: BorderRadius.circular(999),
              onTap: () => showModalBottomSheet<void>(
                context: context,
                isScrollControlled: true,
                backgroundColor: const Color(0xFFF7F7F9),
                shape: const RoundedRectangleBorder(
                  borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                ),
                builder: (_) => FractionallySizedBox(
                  heightFactor: 0.88,
                  child: WeeklyAdherenceChartsSheet(
                    occurrences: data.occurrences,
                    selectedDate: selectedDate,
                  ),
                ),
              ),
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      onTrack
                          ? Icons.trending_up_rounded
                          : Icons.insights_rounded,
                      size: 15,
                      color: onTrack ? Colors.white : AppColors.primaryAction,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      onTrack ? 'On Track' : 'Review',
                      style: AppTextStyles.caption(
                        color: onTrack ? Colors.white : AppColors.primaryAction,
                      ),
                    ),
                    const SizedBox(width: 2),
                    Icon(
                      Icons.chevron_right_rounded,
                      size: 15,
                      color: onTrack ? Colors.white : AppColors.primaryAction,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DayHistory extends StatelessWidget {
  const _DayHistory({required this.data, required this.selectedDate});

  final HistoryData data;
  final DateTime selectedDate;

  @override
  Widget build(BuildContext context) {
    if (data.occurrences.isEmpty) {
      return const DdEmptyState(
        icon: Icons.history_rounded,
        title: 'No medication history',
        subtitle: 'No recorded or scheduled doses were found for this period.',
      );
    }

    final groups = <String, List<DoseOccurrence>>{};
    for (final occurrence in data.occurrences) {
      groups.putIfAbsent(occurrence.localDate, () => []).add(occurrence);
    }
    final dates = groups.keys.toList()..sort((a, b) => b.compareTo(a));

    return Column(
      children: [
        for (final dateKey in dates) ...[
          _HistoryDayGroup(
            date: DateTime.tryParse(dateKey) ?? selectedDate,
            occurrences: groups[dateKey]!
              ..sort((a, b) => a.scheduledAt.compareTo(b.scheduledAt)),
            data: data,
          ),
          if (dateKey != dates.last) const SizedBox(height: 14),
        ],
      ],
    );
  }
}

class _HistoryDayGroup extends StatelessWidget {
  const _HistoryDayGroup({
    required this.date,
    required this.occurrences,
    required this.data,
  });

  final DateTime date;
  final List<DoseOccurrence> occurrences;
  final HistoryData data;

  @override
  Widget build(BuildContext context) {
    final today = DateUtils.dateOnly(DateTime.now());
    final day = DateUtils.dateOnly(date);
    final String title;
    if (day == today) {
      title = 'Today, ${DateFormat('d MMM yyyy').format(day)}';
    } else if (day == today.subtract(const Duration(days: 1))) {
      title = 'Yesterday, ${DateFormat('d MMM yyyy').format(day)}';
    } else {
      title = DateFormat('d MMM yyyy').format(day);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 2),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(title, style: AppTextStyles.bodyBold()),
              ),
              Text(
                '${occurrences.length} scheduled '
                '${occurrences.length == 1 ? 'dose' : 'doses'}',
                textAlign: TextAlign.end,
                style: AppTextStyles.caption(),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFE8E8EA)),
          ),
          child: Column(
            children: [
              for (var index = 0; index < occurrences.length; index++) ...[
                _HistoryDoseRow(
                  occurrence: occurrences[index],
                  medication:
                      data.medications[occurrences[index].medicationId]!,
                  event: data.latestEvents[occurrences[index].id],
                ),
                if (index < occurrences.length - 1)
                  const Divider(height: 1, indent: 54),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _HistoryDoseRow extends StatelessWidget {
  const _HistoryDoseRow({
    required this.occurrence,
    required this.medication,
    this.event,
  });

  final DoseOccurrence occurrence;
  final Medication medication;
  final DoseEvent? event;

  @override
  Widget build(BuildContext context) {
    final late = occurrence.status == DoseStatus.taken &&
        event != null &&
        event!.recordedAt.difference(occurrence.scheduledAt).inMinutes > 60;
    final status = _DoseStatusStyle.from(occurrence.status, late: late);
    final scheduledTime =
        DateFormat('h:mm a').format(occurrence.scheduledAt.toLocal());

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: status.background,
              shape: BoxShape.circle,
            ),
            child: Icon(status.icon, size: 18, color: status.foreground),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(medication.name, style: AppTextStyles.bodyBold()),
                const SizedBox(height: 2),
                Text(
                  '${medication.displayStrength} • '
                  '${medication.displayDose} • $scheduledTime',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.caption(),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 98),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                _HistoryStatusPill(style: status),
                const SizedBox(height: 4),
                Text(
                  _eventDetail(occurrence, event),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.end,
                  style: AppTextStyles.caption(),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  static String _eventDetail(
    DoseOccurrence occurrence,
    DoseEvent? event,
  ) {
    if (occurrence.status == DoseStatus.taken && event != null) {
      return DateFormat('h:mm a').format(event.recordedAt.toLocal());
    }
    if (occurrence.status == DoseStatus.skipped) {
      final reason = event?.skipReason?.trim();
      return reason?.isNotEmpty == true ? reason! : 'Skipped dose';
    }
    if (occurrence.status == DoseStatus.snoozed) {
      final until = event?.snoozeUntil ?? occurrence.snoozeUntil;
      return until == null
          ? 'Snoozed'
          : 'Until ${DateFormat('h:mm a').format(until.toLocal())}';
    }
    return switch (occurrence.status) {
      DoseStatus.missed => 'Missed dose',
      DoseStatus.overdue => 'Overdue',
      DoseStatus.pending => 'Scheduled',
      _ => 'Recorded',
    };
  }
}

class _HistoryStatusPill extends StatelessWidget {
  const _HistoryStatusPill({required this.style});

  final _DoseStatusStyle style;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: style.background,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(style.icon, size: 11, color: style.foreground),
          const SizedBox(width: 3),
          Flexible(
            child: Text(
              style.label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: style.foreground,
                fontSize: 10,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DoseStatusStyle {
  const _DoseStatusStyle({
    required this.label,
    required this.icon,
    required this.foreground,
    required this.background,
  });

  final String label;
  final IconData icon;
  final Color foreground;
  final Color background;

  factory _DoseStatusStyle.from(DoseStatus status, {bool late = false}) {
    if (late) {
      return const _DoseStatusStyle(
        label: 'Taken late',
        icon: Icons.check_rounded,
        foreground: Color(0xFF76584A),
        background: Color(0xFFF2E9E4),
      );
    }
    return switch (status) {
      DoseStatus.taken => const _DoseStatusStyle(
          label: 'Taken',
          icon: Icons.check_rounded,
          foreground: Color(0xFF14735C),
          background: Color(0xFFE3F4EE),
        ),
      DoseStatus.missed => const _DoseStatusStyle(
          label: 'Missed',
          icon: Icons.close_rounded,
          foreground: Color(0xFF68717A),
          background: Color(0xFFECEFF1),
        ),
      DoseStatus.skipped => const _DoseStatusStyle(
          label: 'Skipped',
          icon: Icons.skip_next_rounded,
          foreground: Color(0xFFB42345),
          background: Color(0xFFFFE8EE),
        ),
      DoseStatus.overdue => const _DoseStatusStyle(
          label: 'Overdue',
          icon: Icons.warning_amber_rounded,
          foreground: Color(0xFF9B1C1C),
          background: Color(0xFFFEE2E2),
        ),
      DoseStatus.snoozed => const _DoseStatusStyle(
          label: 'Snoozed',
          icon: Icons.alarm_rounded,
          foreground: Color(0xFF92400E),
          background: Color(0xFFFFF2D9),
        ),
      DoseStatus.pending => const _DoseStatusStyle(
          label: 'Pending',
          icon: Icons.schedule_rounded,
          foreground: Color(0xFF385E8A),
          background: Color(0xFFE8F0FA),
        ),
    };
  }
}

class _WeekHistory extends StatelessWidget {
  const _WeekHistory({required this.data, required this.selectedDate});

  final HistoryData data;
  final DateTime selectedDate;

  @override
  Widget build(BuildContext context) {
    final end = DateUtils.dateOnly(selectedDate);
    final start = end.subtract(const Duration(days: 6));
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE8E8EA)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Weekly Dose Summary', style: AppTextStyles.bodyBold()),
          const SizedBox(height: 12),
          for (var index = 0; index < 7; index++) ...[
            _WeekDayRow(
              date: start.add(Duration(days: index)),
              occurrences: data.occurrences.where((item) {
                final date = DateTime.tryParse(item.localDate);
                return date != null &&
                    DateUtils.isSameDay(
                      date,
                      start.add(Duration(days: index)),
                    );
              }).toList(),
            ),
            if (index < 6) const Divider(height: 18),
          ],
        ],
      ),
    );
  }
}

class _WeekDayRow extends StatelessWidget {
  const _WeekDayRow({required this.date, required this.occurrences});

  final DateTime date;
  final List<DoseOccurrence> occurrences;

  @override
  Widget build(BuildContext context) {
    final taken =
        occurrences.where((item) => item.status == DoseStatus.taken).length;
    final total = occurrences.length;
    final progress = total == 0 ? 0.0 : taken / total;
    return Row(
      children: [
        SizedBox(
          width: 82,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(DateFormat('EEE').format(date),
                  style: AppTextStyles.bodyBold()),
              Text(DateFormat('d MMM').format(date),
                  style: AppTextStyles.caption()),
            ],
          ),
        ),
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 7,
              color: const Color(0xFF158B68),
              backgroundColor: const Color(0xFFE9EEEC),
            ),
          ),
        ),
        const SizedBox(width: 12),
        SizedBox(
          width: 54,
          child: Text(
            '$taken / $total',
            textAlign: TextAlign.end,
            style: AppTextStyles.caption(),
          ),
        ),
      ],
    );
  }
}

class _StatusReference extends StatelessWidget {
  const _StatusReference();

  @override
  Widget build(BuildContext context) {
    const items = [
      (
        label: 'Taken',
        detail: 'Confirmed',
        color: Color(0xFF158B68),
      ),
      (
        label: 'Missed',
        detail: 'Window closed',
        color: Color(0xFF85909A),
      ),
      (
        label: 'Skipped',
        detail: 'Reason recorded',
        color: Color(0xFFD62F59),
      ),
      (
        label: 'Taken late',
        detail: 'Over 1 hour',
        color: Color(0xFF8A6A5B),
      ),
    ];
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE8E8EA)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Status Key Reference', style: AppTextStyles.caption()),
          const SizedBox(height: 8),
          Wrap(
            spacing: 14,
            runSpacing: 8,
            children: [
              for (final item in items)
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 7,
                      height: 7,
                      decoration: BoxDecoration(
                        color: item.color,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 5),
                    Text(
                      '${item.label} (${item.detail})',
                      style: const TextStyle(
                        fontSize: 10,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _HistoryError extends StatelessWidget {
  const _HistoryError({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.error_outline_rounded,
              size: 42,
              color: AppColors.error,
            ),
            const SizedBox(height: 12),
            Text('Could not load medication history',
                style: AppTextStyles.bodyBold()),
            const SizedBox(height: 12),
            OutlinedButton(
              onPressed: onRetry,
              child: const Text('Try again'),
            ),
          ],
        ),
      ),
    );
  }
}
