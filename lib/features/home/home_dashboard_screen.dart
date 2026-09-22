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
import '../../core/widgets/dd_logo.dart';
import '../../core/router/route_names.dart';
import '../../data/repositories/app_repositories.dart';
import '../../data/local/models/app_models.dart';
import '../../data/remote/supabase_sync_service.dart';

// ── Home Providers ────────────────────────────────────────────────────────────

final todayOccurrencesProvider = FutureProvider<List<DoseOccurrence>>((ref) async {
  final repo = ref.watch(doseRepositoryProvider);
  return repo.getOccurrencesForDate(DateTime.now());
});

final todayMedicationsProvider = FutureProvider<List<Medication>>((ref) async {
  final repo = ref.watch(medicationRepositoryProvider);
  return repo.getMedications();
});

final todayAdherenceProvider = FutureProvider<AdherenceSummary>((ref) async {
  final repo = ref.watch(doseRepositoryProvider);
  return repo.getDayAdherence(DateTime.now());
});

final lowStockProvider = FutureProvider<List<Medication>>((ref) async {
  final repo = ref.watch(refillRepositoryProvider);
  return repo.getLowStockMedications();
});

// ── Screen ────────────────────────────────────────────────────────────────────

class HomeDashboardScreen extends ConsumerWidget {
  const HomeDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final occsAsync = ref.watch(todayOccurrencesProvider);
    final medsAsync = ref.watch(todayMedicationsProvider);
    final adherenceAsync = ref.watch(todayAdherenceProvider);
    final lowStockAsync = ref.watch(lowStockProvider);
    final now = DateTime.now();
    final greeting = _greeting(now.hour);
    final dateStr = DateFormat('EEEE, d MMMM yyyy').format(now);

    return Scaffold(
      backgroundColor: AppColors.scaffoldBackground,
      body: RefreshIndicator(
        color: AppColors.primaryAction,
        onRefresh: () async {
          await SupabaseSyncService.syncAll();
          ref.invalidate(todayOccurrencesProvider);
          ref.invalidate(todayMedicationsProvider);
          ref.invalidate(todayAdherenceProvider);
          ref.invalidate(lowStockProvider);
        },
        child: CustomScrollView(
          slivers: [
            // App bar
            SliverAppBar(
              backgroundColor: AppColors.scaffoldBackground,
              floating: true,
              snap: true,
              elevation: 0,
              scrolledUnderElevation: 0,
              title: Row(
                children: [
                  const DdLogo(size: 36),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(greeting, style: AppTextStyles.bodyBold()),
                        Text(dateStr, style: AppTextStyles.caption()),
                      ],
                    ),
                  ),
                ],
              ),
              actions: [
                IconButton(
                  icon: const Icon(Icons.notifications_outlined),
                  onPressed: () => context.push(RouteNames.notificationCentre),
                  tooltip: 'Notifications',
                ),
                IconButton(
                  icon: const Icon(Icons.account_circle_outlined),
                  onPressed: () => context.push(RouteNames.settingsAccount),
                  tooltip: 'Profile',
                ),
              ],
            ),

            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: AppDimensions.screenMargin),
              sliver: SliverList(
                delegate: SliverChildListDelegate([
                  const SizedBox(height: AppDimensions.stackMd),

                  // ── Next Medication card ─────────────────────────────────
                  _NextMedicationCard(occsAsync: occsAsync, medsAsync: medsAsync),
                  const SizedBox(height: AppDimensions.stackLg),

                  // ── Adherence ────────────────────────────────────────────
                  _AdherenceCard(adherenceAsync: adherenceAsync),
                  const SizedBox(height: AppDimensions.stackLg),

                  // ── Today's schedule ──────────────────────────────────────
                  DdSectionHeader(
                    title: "Today's Schedule",
                    actionLabel: 'See All',
                    onAction: () => context.go(RouteNames.medications),
                  ),
                  const SizedBox(height: AppDimensions.stackMd),
                  _TodayScheduleList(occsAsync: occsAsync, medsAsync: medsAsync),
                  const SizedBox(height: AppDimensions.stackLg),

                  // ── Refill summary ─────────────────────────────────────────
                  _RefillSummaryCard(lowStockAsync: lowStockAsync),
                  const SizedBox(height: AppDimensions.stackLg),

                  // ── Caregiver shortcut ─────────────────────────────────────
                  _CaregiverShortcut(),
                  const SizedBox(height: AppDimensions.stack2Xl),
                ]),
              ),
            ),
          ],
        ),
      ),
    );
  }

  static String _greeting(int hour) {
    if (hour < 12) return 'Good morning';
    if (hour < 17) return 'Good afternoon';
    return 'Good evening';
  }
}

// ── Next Medication Card ──────────────────────────────────────────────────────

class _NextMedicationCard extends ConsumerWidget {
  const _NextMedicationCard({required this.occsAsync, required this.medsAsync});
  final AsyncValue<List<DoseOccurrence>> occsAsync;
  final AsyncValue<List<Medication>> medsAsync;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return occsAsync.when(
      loading: () => const DdCard(child: DdLoading()),
      error: (e, _) => DdCard(
        child: Text('Unable to load schedule', style: AppTextStyles.bodyLg(color: AppColors.error)),
      ),
      data: (occs) {
        final now = DateTime.now();
        final upcoming = occs
            .where((o) => o.status.isActionable)
            .toList()
          ..sort((a, b) => a.scheduledAt.compareTo(b.scheduledAt));

        if (upcoming.isEmpty) {
          return DdCard(
            child: Column(
              children: [
                const Icon(Icons.check_circle_rounded, color: AppColors.takenForeground, size: 48),
                const SizedBox(height: AppDimensions.stackMd),
                Text('All done for today!', style: AppTextStyles.headlineMd()),
                const SizedBox(height: AppDimensions.stackSm),
                Text('No remaining doses today.', style: AppTextStyles.bodyLg(color: AppColors.textSecondary)),
              ],
            ),
          );
        }

        final next = upcoming.first;
        return medsAsync.when(
          loading: () => const DdCard(child: DdLoading()),
          error: (_, __) => const SizedBox.shrink(),
          data: (meds) {
            final med = meds.where((m) => m.id == next.medicationId).firstOrNull;
            if (med == null) return const SizedBox.shrink();

            final timeStr = DateFormat('h:mm a').format(next.scheduledAt.toLocal());
            final isOverdue = next.scheduledAt.isBefore(now);

            return DdCard(
              borderColor: isOverdue ? AppColors.primaryAction : AppColors.borderLight,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: isOverdue ? AppColors.pendingBackground : AppColors.primaryBackground,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          isOverdue ? 'OVERDUE' : 'NEXT DOSE',
                          style: AppTextStyles.statusBadge(
                            color: isOverdue ? AppColors.primaryAction : AppColors.textSecondary,
                          ),
                        ),
                      ),
                      const Spacer(),
                      const Icon(Icons.alarm_rounded, color: AppColors.primaryAction, size: 20),
                      const SizedBox(width: 4),
                      Text(timeStr, style: AppTextStyles.bodyBold(color: AppColors.primaryAction)),
                    ],
                  ),
                  const SizedBox(height: AppDimensions.stackMd),
                  Text(med.name, style: AppTextStyles.displayMedication()),
                  const SizedBox(height: AppDimensions.stackSm),
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
                  const SizedBox(height: AppDimensions.stackLg),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () => context.push('/reminder/${next.id}'),
                      icon: const Icon(Icons.medication_rounded),
                      label: const Text('Log Dose'),
                      style: ElevatedButton.styleFrom(
                        minimumSize: const Size(double.infinity, 52),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}

// ── Adherence Card ────────────────────────────────────────────────────────────

class _AdherenceCard extends StatelessWidget {
  const _AdherenceCard({required this.adherenceAsync});
  final AsyncValue<AdherenceSummary> adherenceAsync;

  @override
  Widget build(BuildContext context) {
    return adherenceAsync.when(
      loading: () => const DdCard(child: DdLoading()),
      error: (_, __) => const SizedBox.shrink(),
      data: (summary) => DdCard(
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text("Today's Adherence", style: AppTextStyles.bodyBold()),
                  const SizedBox(height: AppDimensions.stackSm),
                  Text(
                    '${summary.taken} of ${summary.countable} doses taken',
                    style: AppTextStyles.bodyLg(color: AppColors.textSecondary),
                  ),
                  if (summary.countable > 0) ...[
                    const SizedBox(height: AppDimensions.stackMd),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: summary.taken / summary.countable,
                        backgroundColor: AppColors.borderLight,
                        color: AppColors.takenForeground,
                        minHeight: 8,
                      ),
                    ),
                  ],
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
  }
}

// ── Today's Schedule List ─────────────────────────────────────────────────────

class _TodayScheduleList extends StatelessWidget {
  const _TodayScheduleList({required this.occsAsync, required this.medsAsync});
  final AsyncValue<List<DoseOccurrence>> occsAsync;
  final AsyncValue<List<Medication>> medsAsync;

  @override
  Widget build(BuildContext context) {
    return occsAsync.when(
      loading: () => const DdLoading(),
      error: (e, _) => Text('Error loading schedule', style: AppTextStyles.bodyLg(color: AppColors.error)),
      data: (occs) => medsAsync.when(
        loading: () => const DdLoading(),
        error: (_, __) => const SizedBox.shrink(),
        data: (meds) {
          if (occs.isEmpty) {
            return DdEmptyState(
              icon: Icons.medication_outlined,
              title: 'No medications today',
              subtitle: 'Add a medication to get started.',
              actionLabel: 'Add Medication',
              onAction: () => context.push(RouteNames.addMedication),
            );
          }

          // Show first 4 only (See All goes to full list)
          final shown = occs.take(4).toList();
          return Column(
            children: [
              for (final occ in shown) ...[
                _ScheduleItem(occ: occ, meds: meds),
                const SizedBox(height: AppDimensions.stackSm),
              ],
            ],
          );
        },
      ),
    );
  }
}

class _ScheduleItem extends StatelessWidget {
  const _ScheduleItem({required this.occ, required this.meds});
  final DoseOccurrence occ;
  final List<Medication> meds;

  @override
  Widget build(BuildContext context) {
    final med = meds.where((m) => m.id == occ.medicationId).firstOrNull;
    if (med == null) return const SizedBox.shrink();

    final timeStr = DateFormat('h:mm a').format(occ.scheduledAt.toLocal());

    return DdCard(
      onTap: occ.status.isActionable ? () => context.push('/reminder/${occ.id}') : null,
      padding: const EdgeInsets.symmetric(
        horizontal: AppDimensions.cardPadding,
        vertical: AppDimensions.stackMd,
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            alignment: Alignment.center,
            child: Text(timeStr,
                style: AppTextStyles.caption(), textAlign: TextAlign.center),
          ),
          const SizedBox(width: AppDimensions.stackMd),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(med.name, style: AppTextStyles.bodyBold()),
                Text(
                  '${med.displayStrength} · ${med.displayDose}',
                  style: AppTextStyles.caption(),
                ),
              ],
            ),
          ),
          DdStatusBadge(status: occ.status),
        ],
      ),
    );
  }
}

// ── Refill Summary ─────────────────────────────────────────────────────────────

class _RefillSummaryCard extends StatelessWidget {
  const _RefillSummaryCard({required this.lowStockAsync});
  final AsyncValue<List<Medication>> lowStockAsync;

  @override
  Widget build(BuildContext context) {
    return lowStockAsync.when(
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
      data: (meds) {
        if (meds.isEmpty) return const SizedBox.shrink();
        return DdCard(
          onTap: () => context.push(RouteNames.refills),
          borderColor: AppColors.skippedForeground.withOpacity(0.4),
          child: Row(
            children: [
              const Icon(Icons.warning_amber_rounded, color: AppColors.skippedForeground, size: 28),
              const SizedBox(width: AppDimensions.stackMd),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Low Stock Alert', style: AppTextStyles.bodyBold(color: AppColors.skippedForeground)),
                    Text(
                      '${meds.length} medication${meds.length > 1 ? 's' : ''} running low',
                      style: AppTextStyles.bodyLg(color: AppColors.textSecondary),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: AppColors.textTertiary),
            ],
          ),
        );
      },
    );
  }
}

// ── Caregiver Shortcut ─────────────────────────────────────────────────────────

class _CaregiverShortcut extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return DdCard(
      onTap: () => context.push(RouteNames.caregivers),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppColors.primaryAction.withOpacity(0.08),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.people_rounded, color: AppColors.primaryAction, size: 24),
          ),
          const SizedBox(width: AppDimensions.stackMd),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Caregiver Access', style: AppTextStyles.bodyBold()),
                Text('Manage who can view your schedule', style: AppTextStyles.caption()),
              ],
            ),
          ),
          const Icon(Icons.chevron_right, color: AppColors.textTertiary),
        ],
      ),
    );
  }
}
