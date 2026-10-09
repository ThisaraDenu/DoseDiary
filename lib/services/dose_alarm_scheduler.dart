import 'package:sqflite/sqflite.dart';

import '../data/local/database_provider.dart';
import '../data/remote/auth_service.dart';
import 'notification_service.dart';

/// Builds a rolling queue of exact medication alarms.
///
/// The OS owns the queued alarms, so they continue to work when Flutter is
/// stopped, the screen is off, or Android restarts the device.
class DoseAlarmScheduler {
  DoseAlarmScheduler._();

  static const int _daysAhead = 14;
  static const int _maximumQueuedAlarms = 50;

  static Future<void> syncUpcomingAlarms() async {
    final userId = AuthService.currentUser?.id ?? 'guest-user';
    final db = await AppDatabase.instance.database;
    final scheduleRows = await db.rawQuery('''
      SELECT schedule.*,
             medication.name AS medication_name,
             medication.strength,
             medication.strength_unit,
             medication.amount_per_dose,
             medication.dose_unit
      FROM schedules schedule
      INNER JOIN medications medication
        ON medication.id = schedule.medication_id
      WHERE schedule.user_id = ?
        AND schedule.superseded_at IS NULL
        AND medication.is_active = 1
      ORDER BY schedule.created_at ASC
    ''', [userId]);

    final now = DateTime.now();
    final startOfToday = DateTime(now.year, now.month, now.day);
    final candidates = <_AlarmCandidate>[];

    for (final schedule in scheduleRows) {
      final scheduleId = schedule['id'] as String;
      final medicationId = schedule['medication_id'] as String;
      final times = (schedule['times_of_day'] as String? ?? '')
          .split(',')
          .map((value) => value.trim())
          .where((value) => value.isNotEmpty);
      final startsOn = _dateOnly(schedule['start_date'] as String?);
      final endsOn = _dateOnly(schedule['end_date'] as String?);
      final repeatDays = (schedule['repeat_days'] as String? ?? '')
          .split(',')
          .map((value) => int.tryParse(value.trim()))
          .whereType<int>()
          .toSet();
      final frequency = schedule['frequency_type'] as String? ?? 'daily';

      for (var offset = 0; offset <= _daysAhead; offset++) {
        final date = startOfToday.add(Duration(days: offset));
        if (startsOn != null && date.isBefore(startsOn)) continue;
        if (endsOn != null && date.isAfter(endsOn)) continue;
        if (!_runsOnDate(date, startsOn, frequency, repeatDays)) continue;

        final dateText = _localDate(date);
        for (final timeText in times) {
          final parts = timeText.split(':');
          if (parts.length != 2) continue;
          final hour = int.tryParse(parts.first);
          final minute = int.tryParse(parts.last);
          if (hour == null || minute == null) continue;

          final scheduledLocal =
              DateTime(date.year, date.month, date.day, hour, minute);
          final occurrenceKey = '$scheduleId-$dateText-$timeText';
          final occurrence = await _findOrCreateOccurrence(
            db: db,
            scheduleId: scheduleId,
            medicationId: medicationId,
            userId: userId,
            occurrenceKey: occurrenceKey,
            localDate: dateText,
            scheduledLocal: scheduledLocal,
          );
          final status = occurrence['status'] as String? ?? 'pending';
          if (status == 'taken' || status == 'skipped' || status == 'missed') {
            continue;
          }

          final snoozeText = occurrence['snooze_until'] as String?;
          final alarmTime = status == 'snoozed' && snoozeText != null
              ? DateTime.parse(snoozeText).toLocal()
              : scheduledLocal;
          if (!alarmTime.isAfter(now)) continue;

          candidates.add(
            _AlarmCandidate(
              occurrenceId: occurrence['id'] as String,
              medicationName:
                  schedule['medication_name'] as String? ?? 'Medication',
              doseDescription: _doseDescription(schedule),
              scheduledAt: alarmTime,
            ),
          );
        }
      }
    }

    candidates.sort((a, b) => a.scheduledAt.compareTo(b.scheduledAt));
    for (final candidate in candidates.take(_maximumQueuedAlarms)) {
      await NotificationService.scheduleDoseAlarm(
        occurrenceId: candidate.occurrenceId,
        medicationName: candidate.medicationName,
        doseDescription: candidate.doseDescription,
        scheduledAt: candidate.scheduledAt,
      );
    }
  }

  static Future<Map<String, Object?>> _findOrCreateOccurrence({
    required Database db,
    required String scheduleId,
    required String medicationId,
    required String userId,
    required String occurrenceKey,
    required String localDate,
    required DateTime scheduledLocal,
  }) async {
    var rows = await db.query(
      'dose_occurrences',
      where: 'occurrence_key = ?',
      whereArgs: [occurrenceKey],
      limit: 1,
    );
    if (rows.isNotEmpty) return rows.first;

    final id = '$scheduleId:$localDate:'
        '${scheduledLocal.hour.toString().padLeft(2, '0')}'
        '${scheduledLocal.minute.toString().padLeft(2, '0')}';
    await db.insert(
      'dose_occurrences',
      {
        'id': id,
        'schedule_id': scheduleId,
        'medication_id': medicationId,
        'user_id': userId,
        'scheduled_at': scheduledLocal.toUtc().toIso8601String(),
        'local_date': localDate,
        'occurrence_key': occurrenceKey,
        'status': 'pending',
        'created_at': DateTime.now().toUtc().toIso8601String(),
      },
      conflictAlgorithm: ConflictAlgorithm.ignore,
    );
    rows = await db.query(
      'dose_occurrences',
      where: 'occurrence_key = ?',
      whereArgs: [occurrenceKey],
      limit: 1,
    );
    return rows.first;
  }

  static bool _runsOnDate(
    DateTime date,
    DateTime? startsOn,
    String frequency,
    Set<int> repeatDays,
  ) {
    if (repeatDays.isNotEmpty) return repeatDays.contains(date.weekday);
    if (frequency == 'weekly' && startsOn != null) {
      return date.weekday == startsOn.weekday;
    }
    return true;
  }

  static DateTime? _dateOnly(String? text) {
    if (text == null) return null;
    final value = DateTime.tryParse(text)?.toLocal();
    return value == null ? null : DateTime(value.year, value.month, value.day);
  }

  static String _localDate(DateTime date) {
    final year = date.year.toString().padLeft(4, '0');
    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');
    return '$year-$month-$day';
  }

  static String _doseDescription(Map<String, Object?> row) {
    final amount = _number(row['amount_per_dose']);
    final doseUnit = row['dose_unit'] as String? ?? 'dose';
    final strength = _number(row['strength']);
    final strengthUnit = row['strength_unit'] as String? ?? '';
    return '$amount $doseUnit • $strength $strengthUnit';
  }

  static String _number(Object? value) {
    final number = (value as num?)?.toDouble() ?? 0;
    return number == number.roundToDouble()
        ? number.toInt().toString()
        : number.toStringAsFixed(1);
  }
}

class _AlarmCandidate {
  const _AlarmCandidate({
    required this.occurrenceId,
    required this.medicationName,
    required this.doseDescription,
    required this.scheduledAt,
  });

  final String occurrenceId;
  final String medicationName;
  final String doseDescription;
  final DateTime scheduledAt;
}
