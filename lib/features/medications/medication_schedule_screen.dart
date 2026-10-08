import 'dart:convert';

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

final selectedScheduleDateProvider =
    StateProvider<DateTime>((ref) => DateTime.now());

final scheduleOccurrencesProvider =
    FutureProvider.family<List<DoseOccurrence>, DateTime>((ref, date) async {
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
            onDateChanged: (d) =>
                ref.read(selectedScheduleDateProvider.notifier).state = d,
          ),
          const Divider(height: 1),

          // Schedule list
          Expanded(
            child: occsAsync.when(
              loading: () => const DdLoading(),
              error: (e, _) => Center(
                child: Text('Error loading schedule',
                    style: AppTextStyles.bodyLg(color: AppColors.error)),
              ),
              data: (occs) => medsAsync.when(
                loading: () => const DdLoading(),
                error: (_, __) => const SizedBox.shrink(),
                data: (meds) {
                  final medicationsById = {
                    for (final medication in meds) medication.id: medication,
                  };
                  final occurrencesByMedication =
                      <String, List<DoseOccurrence>>{};
                  for (final occurrence in occs) {
                    if (!medicationsById.containsKey(occurrence.medicationId)) {
                      continue;
                    }
                    occurrencesByMedication
                        .putIfAbsent(occurrence.medicationId, () => [])
                        .add(occurrence);
                  }

                  final medicationGroups = occurrencesByMedication.entries
                      .map((entry) {
                    final occurrences = entry.value
                      ..sort((a, b) => a.scheduledAt.compareTo(b.scheduledAt));
                    return (
                      medication: medicationsById[entry.key]!,
                      occurrences: occurrences,
                    );
                  }).toList()
                    ..sort((a, b) => a.occurrences.first.scheduledAt
                        .compareTo(b.occurrences.first.scheduledAt));

                  if (medicationGroups.isEmpty) {
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
                    itemCount: medicationGroups.length,
                    separatorBuilder: (_, __) =>
                        const SizedBox(height: AppDimensions.stackMd),
                    itemBuilder: (ctx, i) {
                      final group = medicationGroups[i];
                      return _MedicationCard(
                        med: group.medication,
                        occurrences: group.occurrences,
                      );
                    },
                  );
                },
              ),
            ),
          ),
        ],
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
            onPressed: () =>
                onDateChanged(selectedDate.subtract(const Duration(days: 1))),
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
                      colorScheme: Theme.of(ctx)
                          .colorScheme
                          .copyWith(primary: AppColors.primaryAction),
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
            onPressed: () =>
                onDateChanged(selectedDate.add(const Duration(days: 1))),
            tooltip: 'Next day',
          ),
        ],
      ),
    );
  }
}

// ── Medication Card ─────────────────────────────────────────────────────────────

class _MedicationCard extends StatelessWidget {
  const _MedicationCard({required this.med, required this.occurrences});

  final Medication med;
  final List<DoseOccurrence> occurrences;

  @override
  Widget build(BuildContext context) {
    final count = occurrences.length;
    final frequency = '$count ${count == 1 ? 'time' : 'times'} on this day';

    return DdCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _MedicationThumbnail(imageUrl: med.imageUrl),
              const SizedBox(width: AppDimensions.stackMd),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(med.name, style: AppTextStyles.displayMedication()),
                    const SizedBox(height: AppDimensions.stackXs),
                    Text(
                      '${med.displayStrength} • ${med.displayDose}',
                      style: AppTextStyles.bodyBold(
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: AppDimensions.stackXs),
                    Text(
                      frequency,
                      key: ValueKey('medication-frequency-${med.id}'),
                      style: AppTextStyles.bodyBold(
                        color: AppColors.primaryAction,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.edit_outlined, size: 20),
                onPressed: () => context.push('/medications/${med.id}/edit'),
                tooltip: 'Edit',
                constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
                padding: EdgeInsets.zero,
              ),
            ],
          ),
          const SizedBox(height: AppDimensions.stackLg),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _MedicationDetail(label: 'Strength', value: med.displayStrength),
              _MedicationDetail(label: 'Per dose', value: med.displayDose),
              _MedicationDetail(label: 'Frequency', value: frequency),
              _MedicationDetail(
                label: 'Supply',
                value:
                    '${_formatAmount(med.quantityOnHand)} ${med.quantityUnit}',
              ),
              _MedicationDetail(
                label: 'Refill alert',
                value: med.refillReminderEnabled
                    ? 'At ${_formatAmount(med.refillThresholdQty ?? 0)} ${med.quantityUnit}'
                    : 'Not enabled',
              ),
            ],
          ),
          if (med.instructions?.trim().isNotEmpty ?? false) ...[
            const SizedBox(height: AppDimensions.stackSm),
            Row(
              children: [
                const Icon(Icons.info_outline,
                    size: 16, color: AppColors.textTertiary),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    med.instructions!.trim(),
                    style: AppTextStyles.bodyLg(color: AppColors.textSecondary),
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: AppDimensions.stackLg),
          _DoseScheduleList(occurrences: occurrences),
          for (final occ in occurrences)
            if (occurrences.length == 1 && occ.status.isActionable) ...[
              const SizedBox(height: AppDimensions.stackLg),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => context.push('/reminder/${occ.id}'),
                  style: ElevatedButton.styleFrom(
                      minimumSize: const Size(double.infinity, 48)),
                  child: const Text("I've Taken It"),
                ),
              ),
            ],
        ],
      ),
    );
  }

  String _formatAmount(double value) => value.toStringAsFixed(
        value.truncateToDouble() == value ? 0 : 1,
      );
}

class _DoseScheduleList extends StatelessWidget {
  const _DoseScheduleList({required this.occurrences});

  final List<DoseOccurrence> occurrences;

  @override
  Widget build(BuildContext context) {
    final count = occurrences.length;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(
              Icons.schedule_rounded,
              size: 18,
              color: AppColors.textSecondary,
            ),
            const SizedBox(width: 7),
            Expanded(
              child: Text(
                'Dose schedule',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTextStyles.bodyBold(),
              ),
            ),
            const SizedBox(width: 8),
            Text(
              '$count ${count == 1 ? 'dose' : 'doses'}',
              style: AppTextStyles.caption(),
            ),
          ],
        ),
        const SizedBox(height: AppDimensions.stackSm),
        for (var index = 0; index < occurrences.length; index++) ...[
          _DoseScheduleRow(occurrence: occurrences[index]),
          if (index < occurrences.length - 1)
            const SizedBox(height: AppDimensions.stackSm),
        ],
      ],
    );
  }
}

class _DoseScheduleRow extends StatelessWidget {
  const _DoseScheduleRow({required this.occurrence});

  final DoseOccurrence occurrence;

  @override
  Widget build(BuildContext context) {
    final time = DateFormat('h:mm a').format(occurrence.scheduledAt.toLocal());
    final actionable = occurrence.status.isActionable;
    return Material(
      color: AppColors.scaffoldBackground,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        onTap: actionable
            ? () => context.push('/reminder/${occurrence.id}')
            : null,
        borderRadius: BorderRadius.circular(10),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(
            children: [
              SizedBox(
                width: 74,
                child: Text(
                  time,
                  style: AppTextStyles.bodyBold(
                    color: AppColors.primaryAction,
                  ),
                ),
              ),
              Expanded(child: DdStatusBadge(status: occurrence.status)),
              if (actionable)
                const Icon(
                  Icons.chevron_right_rounded,
                  color: AppColors.textTertiary,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MedicationDetail extends StatelessWidget {
  const _MedicationDetail({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minWidth: 132, maxWidth: 190),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.scaffoldBackground,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: AppTextStyles.caption()),
          const SizedBox(height: 3),
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

class _MedicationThumbnail extends StatelessWidget {
  const _MedicationThumbnail({this.imageUrl});

  final String? imageUrl;

  @override
  Widget build(BuildContext context) {
    final image = _buildImage();
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: SizedBox(
        key: const ValueKey('medication-card-image'),
        width: 58,
        height: 58,
        child: image ?? _fallback(),
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
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => _fallback(),
        );
      } catch (_) {
        return null;
      }
    }

    if (url.startsWith('http://') || url.startsWith('https://')) {
      return Image.network(
        url,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => _fallback(),
      );
    }
    return null;
  }

  Widget _fallback() {
    return Container(
      color: AppColors.pendingBackground,
      alignment: Alignment.center,
      child: const Icon(
        Icons.medication_rounded,
        color: AppColors.primaryAction,
        size: 30,
      ),
    );
  }
}
