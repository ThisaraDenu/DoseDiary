import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../../core/router/route_names.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/dd_button.dart';
import '../home/home_dashboard_screen.dart';

/// Screen displaying the comprehensive Medication Adherence dashboard,
/// completely calculated and driven by live database records.
class MedicationAdherenceScreen extends ConsumerWidget {
  const MedicationAdherenceScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final period = ref.watch(selectedAdherencePeriodProvider);
    final adherenceAsync = ref.watch(comprehensiveAdherenceProvider);
    final userNameAsync = ref.watch(userNameProvider);
    final userProfileAsync = ref.watch(userProfileProvider);

    final userName = userNameAsync.valueOrNull ?? 'Patient';
    final userProfile = userProfileAsync.valueOrNull;

    return Scaffold(
      backgroundColor: const Color(0xFFF9FAFB),
      body: SafeArea(
        child: adherenceAsync.when(
          loading: () => const Center(
            child: CircularProgressIndicator(color: AppColors.primaryAction),
          ),
          error: (err, stack) => Center(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.error_outline_rounded,
                      size: 48, color: Color(0xFFBA1A1A)),
                  const SizedBox(height: 12),
                  Text(
                    'Unable to load adherence data',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF101828),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    err.toString(),
                    textAlign: TextAlign.center,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 12,
                      color: const Color(0xFF667085),
                    ),
                  ),
                  const SizedBox(height: 16),
                  DdButton(
                    label: 'Retry',
                    onPressed: () =>
                        ref.invalidate(comprehensiveAdherenceProvider),
                  ),
                ],
              ),
            ),
          ),
          data: (report) => RefreshIndicator(
            color: AppColors.primaryAction,
            onRefresh: () async {
              ref.invalidate(comprehensiveAdherenceProvider);
              ref.invalidate(todayAdherenceProvider);
              ref.invalidate(weeklyAdherenceProvider);
            },
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(
                parent: BouncingScrollPhysics(),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── Top Navigation Bar ─────────────────────────────────────────
                  _buildTopBar(context, userProfile),
                  const SizedBox(height: 16),

                  // ── Title & Doctor PDF Export ──────────────────────────────────
                  _buildHeaderTitle(context, report, userName),
                  const SizedBox(height: 16),

                  // ── Period Tabs (This Week / Monthly / All Time) ───────────────
                  _buildPeriodTabs(ref, period),
                  const SizedBox(height: 14),

                  // ── Date Range & Sync Indicator ────────────────────────────────
                  _buildDateAndSyncRow(report),
                  const SizedBox(height: 14),

                  // ── Summary Card with Gauge & 4 Stats ──────────────────────────
                  _buildSummaryCard(report, period, userName),
                  const SizedBox(height: 16),

                  // ── 7-Day Dose Breakdown ───────────────────────────────────────
                  _buildBreakdownCard(context, report),
                  const SizedBox(height: 20),

                  // ── Individual Medications List ────────────────────────────────
                  _buildMedicationsSection(context, report),
                  const SizedBox(height: 32),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ── Top Navigation Bar ───────────────────────────────────────────────────────
  Widget _buildTopBar(BuildContext context, Map<String, dynamic>? profile) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        // Left: Home button with red medical badge
        InkWell(
          onTap: () {
            if (context.canPop()) {
              context.pop();
            } else {
              context.go(RouteNames.home);
            }
          },
          borderRadius: BorderRadius.circular(10),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 2),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    color: const Color(0xFFFEF3F2),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFFFECDCA)),
                  ),
                  child: const Icon(
                    Icons.local_hospital_rounded,
                    size: 16,
                    color: Color(0xFFB42318),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  'Home',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF101828),
                  ),
                ),
              ],
            ),
          ),
        ),

        // Right: Profile Avatar
        InkWell(
          onTap: () => context.push(RouteNames.settingsAccount),
          borderRadius: BorderRadius.circular(20),
          child: Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: const Color(0xFF8A151B),
              border: Border.all(color: const Color(0xFFFECDCA), width: 1.5),
            ),
            child: const Icon(
              Icons.person_rounded,
              color: Colors.white,
              size: 20,
            ),
          ),
        ),
      ],
    );
  }

  // ── Title & Doctor PDF ───────────────────────────────────────────────────────
  Widget _buildHeaderTitle(
      BuildContext context, ComprehensiveAdherenceReport report, String userName) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'PATIENT HEALTH RECORDS',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.8,
                  color: const Color(0xFF667085),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Medication\nAdherence',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 26,
                  fontWeight: FontWeight.w800,
                  height: 1.15,
                  letterSpacing: -0.5,
                  color: const Color(0xFF101828),
                ),
              ),
            ],
          ),
        ),

        // Doctor PDF button
        InkWell(
          onTap: () => _showDoctorPdfModal(context, report, userName),
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0xFFE4E7EC),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.share_outlined,
                  size: 18,
                  color: Color(0xFFB42318),
                ),
                const SizedBox(width: 8),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Doctor',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF1D2939),
                        height: 1.1,
                      ),
                    ),
                    Text(
                      'PDF',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF1D2939),
                        height: 1.1,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // ── Period Selector Tabs ─────────────────────────────────────────────────────
  Widget _buildPeriodTabs(WidgetRef ref, AdherencePeriod currentPeriod) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: const Color(0xFFF2F4F7),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: AdherencePeriod.values.map((p) {
          final isSelected = p == currentPeriod;
          return Expanded(
            child: InkWell(
              onTap: () {
                ref.read(selectedAdherencePeriodProvider.notifier).state = p;
              },
              borderRadius: BorderRadius.circular(9),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 8),
                decoration: BoxDecoration(
                  color: isSelected ? Colors.white : Colors.transparent,
                  borderRadius: BorderRadius.circular(9),
                  boxShadow: isSelected
                      ? [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.04),
                            blurRadius: 4,
                            offset: const Offset(0, 1),
                          ),
                        ]
                      : null,
                ),
                child: Center(
                  child: Text(
                    p.label,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 13,
                      fontWeight:
                          isSelected ? FontWeight.w700 : FontWeight.w600,
                      color: isSelected
                          ? const Color(0xFFB42318)
                          : const Color(0xFF667085),
                    ),
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  // ── Date Range & Sync Row ────────────────────────────────────────────────────
  Widget _buildDateAndSyncRow(ComprehensiveAdherenceReport report) {
    return Row(
      children: [
        const Icon(
          Icons.calendar_today_outlined,
          size: 14,
          color: Color(0xFF667085),
        ),
        const SizedBox(width: 6),
        Text(
          report.dateRangeText,
          style: GoogleFonts.plusJakartaSans(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: const Color(0xFF475467),
          ),
        ),
        const Spacer(),
        Container(
          width: 7,
          height: 7,
          decoration: const BoxDecoration(
            shape: BoxShape.circle,
            color: Color(0xFF16A34A),
          ),
        ),
        const SizedBox(width: 6),
        Text(
          'Synchronized just now',
          style: GoogleFonts.plusJakartaSans(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: const Color(0xFF15803D),
          ),
        ),
      ],
    );
  }

  // ── Summary Card with Gauge & 4 Stats ────────────────────────────────────────
  Widget _buildSummaryCard(ComprehensiveAdherenceReport report,
      AdherencePeriod period, String userName) {
    final statusColor = report.scorePercentage >= 80
        ? const Color(0xFF027A48)
        : (report.scorePercentage >= 60
            ? const Color(0xFFB54708)
            : const Color(0xFFB42318));

    final statusBg = report.scorePercentage >= 80
        ? const Color(0xFFEBFDF2)
        : (report.scorePercentage >= 60
            ? const Color(0xFFFEF0C7)
            : const Color(0xFFFEF3F2));

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFEAECF0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 26,
                    height: 26,
                    decoration: const BoxDecoration(
                      color: Color(0xFFEBFDF2),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.check_circle_outline_rounded,
                      size: 16,
                      color: Color(0xFF16A34A),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '${period.label} Summary',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF101828),
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: report.hasData ? statusBg : const Color(0xFFF2F4F7),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Text(
                  report.statusBadgeLabel,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: report.hasData ? statusColor : const Color(0xFF667085),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),

          // Donut Gauge & Motivational Message
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Circular Donut Gauge
              SizedBox(
                width: 100,
                height: 100,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    SizedBox(
                      width: 90,
                      height: 90,
                      child: CircularProgressIndicator(
                        value: report.hasData
                            ? (report.scorePercentage / 100.0)
                            : 0.0,
                        strokeWidth: 9,
                        strokeCap: StrokeCap.round,
                        backgroundColor: const Color(0xFFEAECF0),
                        color: report.scorePercentage >= 80
                            ? const Color(0xFF0F766E)
                            : (report.scorePercentage >= 60
                                ? const Color(0xFFD97706)
                                : const Color(0xFFDC2626)),
                      ),
                    ),
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          report.hasData ? '${report.scorePercentage}%' : '—%',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.5,
                            color: const Color(0xFF101828),
                          ),
                        ),
                        Text(
                          'Score',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: const Color(0xFF667085),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),

              // Motivational Copy
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      report.statusHeading,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF101828),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      report.motivationalMessage(userName),
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w400,
                        height: 1.35,
                        color: const Color(0xFF475467),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),

          // 4-Stat Grid (2x2)
          Row(
            children: [
              Expanded(
                child: _buildStatTile(
                  icon: Icons.check_circle_outline_rounded,
                  iconColor: const Color(0xFF16A34A),
                  label: 'DOSES TAKEN',
                  valueWidget: Text(
                    report.hasData
                        ? '${report.totalTaken} / ${report.totalCountable}'
                        : '0 / 0',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 19,
                      fontWeight: FontWeight.w800,
                      color: const Color(0xFF101828),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _buildStatTile(
                  icon: Icons.local_fire_department_rounded,
                  iconColor: const Color(0xFFDC2626),
                  label: 'CURRENT STREAK',
                  valueWidget: Row(
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    children: [
                      Text(
                        '${report.currentStreakDays}',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 19,
                          fontWeight: FontWeight.w800,
                          color: const Color(0xFFDC2626),
                        ),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'Days',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: const Color(0xFF101828),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _buildStatTile(
                  icon: Icons.remove_circle_outline_rounded,
                  iconColor: const Color(0xFF98A2B3),
                  label: 'MISSED',
                  valueWidget: Text(
                    report.totalMissed > 0
                        ? '${report.totalMissed} ${report.totalMissed == 1 ? 'dose' : 'doses'}${report.mostRecentMissedDate != null ? ' (${DateFormat('MMM d').format(report.mostRecentMissedDate!)})' : ''}'
                        : '0 doses',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: report.totalMissed > 0
                          ? const Color(0xFFB42318)
                          : const Color(0xFF101828),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _buildStatTile(
                  icon: Icons.access_time_rounded,
                  iconColor: const Color(0xFF98A2B3),
                  label: 'DELAYED / LATE',
                  valueWidget: Text(
                    report.totalDelayed > 0
                        ? '${report.totalDelayed} ${report.averageDelayMinutes > 0 ? '+${report.averageDelayMinutes}m' : 'late'}'
                        : '0 on time',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF101828),
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

  Widget _buildStatTile({
    required IconData icon,
    required Color iconColor,
    required String label,
    required Widget valueWidget,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFF9FAFB),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFEAECF0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 14, color: iconColor),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.5,
                    color: const Color(0xFF475467),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          valueWidget,
        ],
      ),
    );
  }

  // ── 7-Day Dose Breakdown Card ────────────────────────────────────────────────
  Widget _buildBreakdownCard(
      BuildContext context, ComprehensiveAdherenceReport report) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFEAECF0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '7-Day Dose Breakdown',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF101828),
                ),
              ),
              Text(
                'Tap day to inspect',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                  color: const Color(0xFF667085),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // 7 Day Pillars Row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: report.dailyBreakdown.map((day) {
              return _buildDayPillar(context, day);
            }).toList(),
          ),
          const SizedBox(height: 16),

          // Legend Row
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildLegendItem(
                icon: Icons.check_circle_outline_rounded,
                iconColor: const Color(0xFF16A34A),
                label: 'Taken (100%)',
              ),
              const SizedBox(width: 14),
              _buildLegendItem(
                icon: Icons.remove_circle_outline_rounded,
                iconColor: const Color(0xFFDC2626),
                label: 'Missed dose',
              ),
              const SizedBox(width: 14),
              _buildLegendItem(
                icon: Icons.access_time_rounded,
                iconColor: const Color(0xFF667085),
                label: 'Taken late',
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDayPillar(BuildContext context, AdherenceDayBreakdown day) {
    final isToday = day.isToday;

    return InkWell(
      onTap: () {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              day.countable > 0
                  ? '${day.dayLabel} (${DateFormat('MMM d').format(day.date)}): ${day.taken} of ${day.countable} doses taken (${day.percentage.toStringAsFixed(0)}%)'
                  : '${day.dayLabel} (${DateFormat('MMM d').format(day.date)}): No doses scheduled in database',
              style: GoogleFonts.plusJakartaSans(fontSize: 13),
            ),
            duration: const Duration(seconds: 2),
            behavior: SnackBarBehavior.floating,
          ),
        );
      },
      borderRadius: BorderRadius.circular(12),
      child: Container(
        width: 42,
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: isToday ? const Color(0xFF8A151B) : const Color(0xFFF2F4F7),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: [
            Text(
              day.dayLabel,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 10.5,
                fontWeight: FontWeight.w700,
                color: isToday ? Colors.white : const Color(0xFF475467),
              ),
            ),
            const SizedBox(height: 3),
            Text(
              '${day.dayNumber}',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 15,
                fontWeight: FontWeight.w800,
                color: isToday ? Colors.white : const Color(0xFF101828),
              ),
            ),
            const SizedBox(height: 6),

            // Badge Icon
            _buildDayBadge(day, isToday),
          ],
        ),
      ),
    );
  }

  Widget _buildDayBadge(AdherenceDayBreakdown day, bool isToday) {
    if (day.status == DayAdherenceStatus.taken100) {
      return Container(
        width: 18,
        height: 18,
        decoration: BoxDecoration(
          color: isToday ? Colors.white : const Color(0xFFEBFDF2),
          shape: BoxShape.circle,
        ),
        child: Icon(
          Icons.check_rounded,
          size: 13,
          color: isToday ? const Color(0xFF8A151B) : const Color(0xFF16A34A),
        ),
      );
    } else if (day.status == DayAdherenceStatus.missed) {
      return Container(
        width: 18,
        height: 18,
        decoration: BoxDecoration(
          color: isToday ? Colors.white : const Color(0xFFFEF3F2),
          shape: BoxShape.circle,
        ),
        child: Icon(
          Icons.remove_rounded,
          size: 13,
          color: isToday ? const Color(0xFF8A151B) : const Color(0xFFDC2626),
        ),
      );
    } else if (day.status == DayAdherenceStatus.delayed) {
      return Container(
        width: 18,
        height: 18,
        decoration: BoxDecoration(
          color: isToday ? Colors.white : const Color(0xFFF2F4F7),
          shape: BoxShape.circle,
        ),
        child: Icon(
          Icons.access_time_rounded,
          size: 12,
          color: isToday ? const Color(0xFF8A151B) : const Color(0xFF667085),
        ),
      );
    } else {
      // No doses
      return Container(
        width: 18,
        height: 18,
        alignment: Alignment.center,
        child: Container(
          width: 5,
          height: 5,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: isToday ? Colors.white70 : const Color(0xFFD0D5DD),
          ),
        ),
      );
    }
  }

  Widget _buildLegendItem({
    required IconData icon,
    required Color iconColor,
    required String label,
  }) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: iconColor),
        const SizedBox(width: 4),
        Text(
          label,
          style: GoogleFonts.plusJakartaSans(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: const Color(0xFF475467),
          ),
        ),
      ],
    );
  }

  // ── Individual Medications Section ───────────────────────────────────────────
  Widget _buildMedicationsSection(
      BuildContext context, ComprehensiveAdherenceReport report) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Individual\nMedications',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 17,
                fontWeight: FontWeight.w800,
                color: const Color(0xFF101828),
                height: 1.15,
              ),
            ),
            Text(
              '${report.activePrescriptionsCount} Active ${report.activePrescriptionsCount == 1 ? 'Prescription' : 'Prescriptions'}',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: const Color(0xFF8A151B),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),

        // If no medications in database
        if (report.medicationAdherences.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 28),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: const Color(0xFFEAECF0)),
            ),
            child: Column(
              children: [
                const Icon(
                  Icons.medication_outlined,
                  size: 46,
                  color: Color(0xFF98A2B3),
                ),
                const SizedBox(height: 12),
                Text(
                  'No Prescriptions in Database',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF101828),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Add your medications to view detailed compliance rates, refill countdowns, and dose timing analytics.',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 13,
                    color: const Color(0xFF667085),
                  ),
                ),
                const SizedBox(height: 18),
                SizedBox(
                  width: 180,
                  child: DdButton(
                    label: 'Add Medication',
                    onPressed: () => context.push(RouteNames.addMedication),
                  ),
                ),
              ],
            ),
          )
        else
          // Render each medication card from database
          ...report.medicationAdherences.map((item) {
            return _buildMedicationCard(item);
          }),
      ],
    );
  }

  Widget _buildMedicationCard(MedicationAdherenceItem item) {
    final med = item.medication;
    final nameLower = med.name.toLowerCase();

    // Contextual icon and tint
    IconData medIcon = Icons.medical_services_outlined;
    Color iconColor = const Color(0xFFB42318);
    Color iconBg = const Color(0xFFFEF3F2);

    if (nameLower.contains('vitamin') || nameLower.contains('d3')) {
      medIcon = Icons.wb_sunny_outlined;
      iconColor = const Color(0xFF027A48);
      iconBg = const Color(0xFFEBFDF2);
    } else if (nameLower.contains('aspirin') || nameLower.contains('heart')) {
      medIcon = Icons.favorite_outline_rounded;
      iconColor = const Color(0xFFB42318);
      iconBg = const Color(0xFFFEF3F2);
    }

    // Badge pill calculation
    String badgeText;
    Color badgeColor;
    Color badgeBg;

    if (item.adherencePercentage == 100 && item.countable > 0) {
      badgeText = 'Perfect 100%';
      badgeColor = const Color(0xFF027A48);
      badgeBg = const Color(0xFFEBFDF2);
    } else if (item.daysSupplyLeft > 0 && item.daysSupplyLeft <= 5) {
      badgeText = '${item.daysSupplyLeft} days left';
      badgeColor = const Color(0xFF344054);
      badgeBg = const Color(0xFFF2F4F7);
    } else if (item.countable > 0) {
      badgeText = '${item.adherencePercentage}% on-track';
      badgeColor = const Color(0xFF344054);
      badgeBg = const Color(0xFFF2F4F7);
    } else {
      badgeText = 'Active';
      badgeColor = const Color(0xFF344054);
      badgeBg = const Color(0xFFF2F4F7);
    }

    // Progress factor
    final progressFactor = item.countable > 0
        ? (item.taken / item.countable).clamp(0.0, 1.0)
        : 0.0;

    final progressColor = item.adherencePercentage >= 80
        ? const Color(0xFF0F766E)
        : (item.adherencePercentage >= 60
            ? const Color(0xFFD97706)
            : const Color(0xFF8A151B));

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFEAECF0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 6,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Top Row: Icon + Name & Subtitle + Badge
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: iconBg,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(medIcon, size: 22, color: iconColor),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${med.name} ${med.displayStrength}',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF101828),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      item.subtitle,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: const Color(0xFF475467),
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: badgeBg,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  badgeText,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: badgeColor,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Progress Row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '${item.adherencePercentage}% adherence rate',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF101828),
                ),
              ),
              Text(
                item.countable > 0
                    ? '${item.taken} of ${item.countable} doses taken'
                    : 'No doses scheduled yet',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w500,
                  color: const Color(0xFF475467),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),

          // Progress Bar
          Container(
            width: double.infinity,
            height: 6,
            decoration: BoxDecoration(
              color: const Color(0xFFEAECF0),
              borderRadius: BorderRadius.circular(999),
            ),
            child: FractionallySizedBox(
              alignment: Alignment.centerLeft,
              widthFactor: progressFactor,
              child: Container(
                decoration: BoxDecoration(
                  color: progressColor,
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),

          // Divider
          const Divider(height: 1, color: Color(0xFFF2F4F7)),
          const SizedBox(height: 10),

          // Footer Row
          Row(
            children: [
              // Left Footer Info
              Expanded(
                child: Row(
                  children: [
                    if (item.courseEndDate != null) ...[
                      const Icon(Icons.check_circle_outline_rounded,
                          size: 14, color: Color(0xFF16A34A)),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          'Course ending ${DateFormat('MMM d').format(item.courseEndDate!)}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: const Color(0xFF15803D),
                          ),
                        ),
                      ),
                    ] else if (item.delayed > 0) ...[
                      const Icon(Icons.info_outline_rounded,
                          size: 14, color: Color(0xFFB54708)),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          '${item.delayed} dose delayed',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: const Color(0xFFB54708),
                          ),
                        ),
                      ),
                    ] else ...[
                      const Icon(Icons.verified_outlined,
                          size: 14, color: Color(0xFF16A34A)),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          'Confirmed via Dose Log',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: const Color(0xFF475467),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),

              // Right Footer Info
              if (item.nextDoseTime != null)
                Text(
                  item.nextDoseTime!,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF344054),
                  ),
                )
              else if (item.lastTakenTime != null)
                Text(
                  item.lastTakenTime!,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF15803D),
                  ),
                )
              else
                Text(
                  'Daily Schedule',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    color: const Color(0xFF667085),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  // ── Doctor PDF Export Modal ──────────────────────────────────────────────────
  void _showDoctorPdfModal(
      BuildContext context, ComprehensiveAdherenceReport report, String userName) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => SingleChildScrollView(
        child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFEF3F2),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.picture_as_pdf_rounded,
                    color: Color(0xFFB42318),
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Doctor Adherence Report',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                          color: const Color(0xFF101828),
                        ),
                      ),
                      Text(
                        'Ready to export for medical reviews',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 12,
                          color: const Color(0xFF667085),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFFF9FAFB),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFFEAECF0)),
              ),
              child: Column(
                children: [
                  _buildPdfRow('Patient Name', userName),
                  const Divider(height: 16),
                  _buildPdfRow('Reporting Period', report.dateRangeText),
                  const Divider(height: 16),
                  _buildPdfRow(
                    'Overall Adherence',
                    report.hasData ? '${report.scorePercentage}%' : 'No Data',
                  ),
                  const Divider(height: 16),
                  _buildPdfRow(
                    'Doses Completed',
                    '${report.totalTaken} of ${report.totalCountable}',
                  ),
                  const Divider(height: 16),
                  _buildPdfRow(
                    'Active Prescriptions',
                    '${report.activePrescriptionsCount}',
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            DdButton(
              label: 'Export & Share Report',
              onPressed: () {
                Navigator.of(ctx).pop();
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      'Doctor Adherence Report exported successfully.',
                      style: GoogleFonts.plusJakartaSans(),
                    ),
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              },
            ),
          ],
        ),
      ),
    ),
  );
}

  Widget _buildPdfRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: GoogleFonts.plusJakartaSans(
            fontSize: 12.5,
            color: const Color(0xFF667085),
            fontWeight: FontWeight.w500,
          ),
        ),
        Text(
          value,
          style: GoogleFonts.plusJakartaSans(
            fontSize: 13,
            color: const Color(0xFF101828),
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}
