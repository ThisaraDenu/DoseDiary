import 'package:intl/intl.dart';

import 'app_models.dart';

/// Period filter for Medication Adherence report.
enum AdherencePeriod {
  thisWeek,
  monthly,
  allTime;

  String get label => switch (this) {
        AdherencePeriod.thisWeek => 'This Week',
        AdherencePeriod.monthly => 'Monthly',
        AdherencePeriod.allTime => 'All Time',
      };
}

/// Status for a single day in the 7-day dose breakdown.
enum DayAdherenceStatus {
  noDoses,
  taken100,
  missed,
  delayed;

  String get label => switch (this) {
        DayAdherenceStatus.taken100 => 'Taken (100%)',
        DayAdherenceStatus.missed => 'Missed dose',
        DayAdherenceStatus.delayed => 'Taken late',
        DayAdherenceStatus.noDoses => 'No doses',
      };
}

/// Day breakdown item for the 7-day breakdown row.
class AdherenceDayBreakdown {
  final DateTime date;
  final String dayLabel; // e.g. "Wed", "Today"
  final int dayNumber; // e.g. 14
  final bool isToday;
  final int countable;
  final int taken;
  final int missed;
  final int delayed;
  final DayAdherenceStatus status;
  final double percentage;

  const AdherenceDayBreakdown({
    required this.date,
    required this.dayLabel,
    required this.dayNumber,
    required this.isToday,
    required this.countable,
    required this.taken,
    required this.missed,
    required this.delayed,
    required this.status,
    required this.percentage,
  });
}

/// Adherence stats for an individual medication.
class MedicationAdherenceItem {
  final Medication medication;
  final MedicationSchedule? schedule;
  final int countable;
  final int taken;
  final int missed;
  final int delayed;
  final int adherencePercentage;
  final int daysSupplyLeft;
  final String? nextDoseTime;
  final String? lastTakenTime;
  final DateTime? courseEndDate;
  final String subtitle;

  const MedicationAdherenceItem({
    required this.medication,
    this.schedule,
    required this.countable,
    required this.taken,
    required this.missed,
    required this.delayed,
    required this.adherencePercentage,
    required this.daysSupplyLeft,
    this.nextDoseTime,
    this.lastTakenTime,
    this.courseEndDate,
    required this.subtitle,
  });
}

/// Complete Adherence Report containing all statistics calculated from SQLite.
class ComprehensiveAdherenceReport {
  final AdherencePeriod period;
  final DateTime startDate;
  final DateTime endDate;
  final int totalCountable;
  final int totalTaken;
  final int totalMissed;
  final int totalDelayed;
  final int scorePercentage;
  final bool hasData;
  final int currentStreakDays;
  final DateTime? mostRecentMissedDate;
  final int averageDelayMinutes;
  final List<AdherenceDayBreakdown> dailyBreakdown;
  final List<MedicationAdherenceItem> medicationAdherences;
  final int activePrescriptionsCount;

  const ComprehensiveAdherenceReport({
    required this.period,
    required this.startDate,
    required this.endDate,
    required this.totalCountable,
    required this.totalTaken,
    required this.totalMissed,
    required this.totalDelayed,
    required this.scorePercentage,
    required this.hasData,
    required this.currentStreakDays,
    this.mostRecentMissedDate,
    this.averageDelayMinutes = 0,
    required this.dailyBreakdown,
    required this.medicationAdherences,
    required this.activePrescriptionsCount,
  });

  /// Formatted date range string matching the sample UI (e.g. "Aug 14 – Aug 20, 2026").
  String get dateRangeText {
    final startFmt = DateFormat('MMM d').format(startDate);
    final endFmt = DateFormat('MMM d, yyyy').format(endDate);
    return '$startFmt – $endFmt';
  }

  /// Status badge label (e.g. "• On Track", "• Needs Attention", "• At Risk", "• No Data").
  String get statusBadgeLabel {
    if (!hasData || totalCountable == 0) return '• No Data';
    if (scorePercentage >= 80) return '• On Track';
    if (scorePercentage >= 60) return '• Needs Attention';
    return '• At Risk';
  }

  /// Header title for the summary card.
  String get statusHeading {
    if (!hasData || totalCountable == 0) return 'No Data Recorded';
    if (scorePercentage >= 90) return 'Excellent Adherence';
    if (scorePercentage >= 75) return 'Good Adherence';
    return 'Needs Attention';
  }

  /// Dynamic motivational message based on user profile and score.
  String motivationalMessage(String userName) {
    if (!hasData || totalCountable == 0) {
      return 'No medication doses have been recorded in the database for this period yet.';
    }
    if (scorePercentage >= 90) {
      return '$userName, your consistency safeguards your cardiovascular and daily recovery. Keep going!';
    }
    if (scorePercentage >= 75) {
      return '$userName, good consistency! Taking medications on time maintains steady health benefits.';
    }
    return '$userName, several scheduled doses were missed or delayed. Try setting reminder alarms to stay on track.';
  }

  /// Empty report used when no data is found in database.
  factory ComprehensiveAdherenceReport.empty(AdherencePeriod period) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final start = today.subtract(const Duration(days: 6));
    final breakdown = <AdherenceDayBreakdown>[];

    for (int i = 6; i >= 0; i--) {
      final day = today.subtract(Duration(days: i));
      final isToday = (i == 0);
      breakdown.add(AdherenceDayBreakdown(
        date: day,
        dayLabel: isToday ? 'Today' : DateFormat('E').format(day),
        dayNumber: day.day,
        isToday: isToday,
        countable: 0,
        taken: 0,
        missed: 0,
        delayed: 0,
        status: DayAdherenceStatus.noDoses,
        percentage: 0.0,
      ));
    }

    return ComprehensiveAdherenceReport(
      period: period,
      startDate: start,
      endDate: now,
      totalCountable: 0,
      totalTaken: 0,
      totalMissed: 0,
      totalDelayed: 0,
      scorePercentage: 0,
      hasData: false,
      currentStreakDays: 0,
      dailyBreakdown: breakdown,
      medicationAdherences: const [],
      activePrescriptionsCount: 0,
    );
  }
}
