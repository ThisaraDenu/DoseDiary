import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../data/local/models/app_models.dart';
import '../../data/local/models/dose_status.dart';

class WeeklyAdherenceChartsSheet extends StatelessWidget {
  const WeeklyAdherenceChartsSheet({
    super.key,
    required this.occurrences,
    required this.selectedDate,
  });

  final List<DoseOccurrence> occurrences;
  final DateTime selectedDate;

  @override
  Widget build(BuildContext context) {
    final end = DateUtils.dateOnly(selectedDate);
    final start = end.subtract(const Duration(days: 6));
    final days = List.generate(7, (index) => start.add(Duration(days: index)));
    final counts = _StatusCounts.from(occurrences);

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(18, 10, 18, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 42,
                height: 4,
                decoration: BoxDecoration(
                  color: const Color(0xFFD2D2D6),
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
            ),
            const SizedBox(height: 18),
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Weekly Adherence Charts',
                          style: AppTextStyles.headlineMd()),
                      const SizedBox(height: 3),
                      Text(
                        '${DateFormat('d MMM').format(start)} - '
                        '${DateFormat('d MMM yyyy').format(end)}',
                        style: AppTextStyles.caption(),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: 'Close charts',
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close_rounded),
                ),
              ],
            ),
            const SizedBox(height: 20),
            _ChartCard(
              title: 'Daily adherence',
              subtitle: 'Percentage of scheduled doses taken each day',
              child: SizedBox(
                height: 220,
                child:
                    _DailyAdherenceChart(days: days, occurrences: occurrences),
              ),
            ),
            const SizedBox(height: 14),
            _ChartCard(
              title: 'Dose status breakdown',
              subtitle: '${occurrences.length} doses scheduled this week',
              child: counts.total == 0
                  ? const SizedBox(
                      height: 150,
                      child:
                          Center(child: Text('No dose records for this week')),
                    )
                  : _StatusBreakdown(counts: counts),
            ),
          ],
        ),
      ),
    );
  }
}

class _ChartCard extends StatelessWidget {
  const _ChartCard({
    required this.title,
    required this.subtitle,
    required this.child,
  });

  final String title;
  final String subtitle;
  final Widget child;

  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFFE7E7EA)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: AppTextStyles.bodyBold()),
            const SizedBox(height: 3),
            Text(subtitle, style: AppTextStyles.caption()),
            const SizedBox(height: 18),
            child,
          ],
        ),
      );
}

class _DailyAdherenceChart extends StatelessWidget {
  const _DailyAdherenceChart({required this.days, required this.occurrences});

  final List<DateTime> days;
  final List<DoseOccurrence> occurrences;

  @override
  Widget build(BuildContext context) {
    final values = days.map((day) {
      final key = DateFormat('yyyy-MM-dd').format(day);
      final doses = occurrences.where((item) => item.localDate == key).toList();
      final taken =
          doses.where((item) => item.status == DoseStatus.taken).length;
      return doses.isEmpty ? 0.0 : taken / doses.length * 100;
    }).toList();
    return BarChart(
      BarChartData(
        minY: 0,
        maxY: 100,
        alignment: BarChartAlignment.spaceAround,
        barTouchData: BarTouchData(
          touchTooltipData: BarTouchTooltipData(
            getTooltipItem: (group, groupIndex, rod, rodIndex) =>
                BarTooltipItem('${rod.toY.round()}%',
                    const TextStyle(color: Colors.white)),
          ),
        ),
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          horizontalInterval: 25,
          getDrawingHorizontalLine: (_) =>
              const FlLine(color: Color(0xFFECECEF), strokeWidth: 1),
        ),
        borderData: FlBorderData(show: false),
        titlesData: FlTitlesData(
          topTitles:
              const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles:
              const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 32,
              interval: 25,
              getTitlesWidget: (value, meta) => Text(
                '${value.round()}%',
                style: const TextStyle(
                    fontSize: 9, color: AppColors.textSecondary),
              ),
            ),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 30,
              getTitlesWidget: (value, meta) {
                final index = value.toInt();
                if (index < 0 || index >= days.length) {
                  return const SizedBox.shrink();
                }
                return Padding(
                  padding: const EdgeInsets.only(top: 7),
                  child: Text(
                    DateFormat('EEE').format(days[index]).substring(0, 2),
                    style: const TextStyle(
                        fontSize: 10, color: AppColors.textSecondary),
                  ),
                );
              },
            ),
          ),
        ),
        barGroups: [
          for (var index = 0; index < values.length; index++)
            BarChartGroupData(
              x: index,
              barRods: [
                BarChartRodData(
                  toY: values[index],
                  width: 18,
                  color: const Color(0xFF158B68),
                  backDrawRodData: BackgroundBarChartRodData(
                    show: true,
                    toY: 100,
                    color: const Color(0xFFE9EEEC),
                  ),
                  borderRadius:
                      const BorderRadius.vertical(top: Radius.circular(5)),
                ),
              ],
            ),
        ],
      ),
    );
  }
}

class _StatusBreakdown extends StatelessWidget {
  const _StatusBreakdown({required this.counts});

  final _StatusCounts counts;

  @override
  Widget build(BuildContext context) {
    final items = [
      (label: 'Taken', value: counts.taken, color: const Color(0xFF158B68)),
      (label: 'Missed', value: counts.missed, color: const Color(0xFF85909A)),
      (label: 'Skipped', value: counts.skipped, color: const Color(0xFFD62F59)),
      (label: 'Pending', value: counts.pending, color: const Color(0xFF4E78A8)),
    ];
    return Row(
      children: [
        SizedBox(
          width: 150,
          height: 150,
          child: Stack(
            alignment: Alignment.center,
            children: [
              PieChart(
                PieChartData(
                  centerSpaceRadius: 43,
                  sectionsSpace: 2,
                  startDegreeOffset: -90,
                  sections: [
                    for (final item in items)
                      if (item.value > 0)
                        PieChartSectionData(
                          value: item.value.toDouble(),
                          color: item.color,
                          radius: 27,
                          showTitle: false,
                        ),
                  ],
                ),
              ),
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('${counts.total}', style: AppTextStyles.headlineMd()),
                  Text('doses', style: AppTextStyles.caption()),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(width: 18),
        Expanded(
          child: Column(
            children: [
              for (final item in items)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 5),
                  child: Row(
                    children: [
                      Container(
                        width: 9,
                        height: 9,
                        decoration: BoxDecoration(
                          color: item.color,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 7),
                      Expanded(
                        child: Text(item.label, style: AppTextStyles.caption()),
                      ),
                      Text('${item.value}', style: AppTextStyles.bodyBold()),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _StatusCounts {
  const _StatusCounts({
    required this.taken,
    required this.missed,
    required this.skipped,
    required this.pending,
  });

  factory _StatusCounts.from(List<DoseOccurrence> occurrences) {
    var taken = 0;
    var missed = 0;
    var skipped = 0;
    var pending = 0;
    for (final item in occurrences) {
      if (item.status == DoseStatus.taken) {
        taken++;
      } else if (item.status == DoseStatus.missed) {
        missed++;
      } else if (item.status == DoseStatus.skipped) {
        skipped++;
      } else {
        pending++;
      }
    }
    return _StatusCounts(
      taken: taken,
      missed: missed,
      skipped: skipped,
      pending: pending,
    );
  }

  final int taken;
  final int missed;
  final int skipped;
  final int pending;

  int get total => taken + missed + skipped + pending;
}
