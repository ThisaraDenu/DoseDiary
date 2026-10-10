import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:sqflite/sqflite.dart';

import '../../core/router/route_names.dart';
import '../../services/notification_service.dart';
import '../local/database_provider.dart';
import '../local/models/app_notification.dart';
import '../remote/auth_service.dart';
import '../remote/supabase_sync_service.dart';

class NotificationRepository {
  NotificationRepository(this._appDatabase);

  final AppDatabase _appDatabase;

  String get _userId => AuthService.currentUser?.id ?? 'guest-user';

  Future<Database> get _database => _appDatabase.database;

  Future<List<AppNotification>> getNotifications() async {
    await refreshGeneratedNotifications();
    final db = await _database;
    final rows = await db.query(
      'app_notifications',
      where: 'user_id = ?',
      whereArgs: [_userId],
      orderBy: 'is_read ASC, created_at DESC',
    );
    return rows.map(AppNotification.fromMap).toList();
  }

  Future<int> getUnreadCount() async {
    await refreshGeneratedNotifications();
    final db = await _database;
    final result = await db.rawQuery(
      'SELECT COUNT(*) AS total FROM app_notifications '
      'WHERE user_id = ? AND is_read = 0',
      [_userId],
    );
    return (result.first['total'] as num?)?.toInt() ?? 0;
  }

  Future<void> markRead(String id) async {
    final db = await _database;
    await db.update(
      'app_notifications',
      {'is_read': 1},
      where: 'id = ? AND user_id = ?',
      whereArgs: [id, _userId],
    );
    final rows = await db.query(
      'app_notifications',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (rows.isNotEmpty) {
      SupabaseSyncService.pushAppNotification(rows.first).ignore();
    }
  }

  Future<void> markAllRead() async {
    final db = await _database;
    await db.update(
      'app_notifications',
      {'is_read': 1},
      where: 'user_id = ?',
      whereArgs: [_userId],
    );
    final rows = await db.query(
      'app_notifications',
      where: 'user_id = ?',
      whereArgs: [_userId],
    );
    for (final row in rows) {
      SupabaseSyncService.pushAppNotification(row).ignore();
    }
  }

  Future<void> deleteNotification(String id) async {
    final db = await _database;
    await db.delete(
      'app_notifications',
      where: 'id = ? AND user_id = ?',
      whereArgs: [id, _userId],
    );
    SupabaseSyncService.deleteAppNotification(id).ignore();
  }

  Future<void> clearRead() async {
    final db = await _database;
    final rows = await db.query(
      'app_notifications',
      columns: ['id'],
      where: 'user_id = ? AND is_read = 1',
      whereArgs: [_userId],
    );
    await db.delete(
      'app_notifications',
      where: 'user_id = ? AND is_read = 1',
      whereArgs: [_userId],
    );
    for (final row in rows) {
      SupabaseSyncService.deleteAppNotification(row['id'] as String).ignore();
    }
  }

  Future<void> refreshGeneratedNotifications() async {
    await SupabaseSyncService.pullAppNotifications();
    final db = await _database;
    final now = DateTime.now();
    final uid = _userId;

    await db.delete(
      'app_notifications',
      where: 'user_id = ? AND created_at < ?',
      whereArgs: [
        uid,
        now.subtract(const Duration(days: 90)).toUtc().toIso8601String(),
      ],
    );

    await _generatePatientDoseNotifications(db, uid, now);
    await _generateRefillNotifications(db, uid, now);
    await _generateScheduleEndingNotifications(db, uid, now);
    await _generateInvitationNotifications(db, uid);
    await _generateCaregiverNotifications(db, uid, now);
    await _generateCaregiverAlerts(db, uid);
  }

  Future<void> _generatePatientDoseNotifications(
      Database db, String uid, DateTime now) async {
    final rows = await db.rawQuery('''
      SELECT occurrence.*, medication.name AS medication_name,
             medication.strength, medication.strength_unit
      FROM dose_occurrences occurrence
      LEFT JOIN medications medication ON medication.id = occurrence.medication_id
      WHERE occurrence.user_id = ?
        AND occurrence.scheduled_at >= ?
        AND occurrence.scheduled_at <= ?
      ORDER BY occurrence.scheduled_at ASC
    ''', [
      uid,
      now.subtract(const Duration(days: 2)).toUtc().toIso8601String(),
      now.add(const Duration(days: 1)).toUtc().toIso8601String(),
    ]);

    for (final row in rows) {
      final scheduledAt =
          DateTime.parse(row['scheduled_at'] as String).toLocal();
      final status = row['status'] as String? ?? 'pending';
      final medication = _medicationLabel(row);
      final sourceId = row['id'] as String;
      final difference = scheduledAt.difference(now);

      if (status == 'taken' || status == 'skipped' || status == 'missed') {
        await db.delete(
          'app_notifications',
          where: 'user_id = ? AND source_id = ? AND type IN (?, ?)',
          whereArgs: [uid, sourceId, 'dose_due', 'dose_overdue'],
        );
      }

      if (status == 'pending' || status == 'snoozed' || status == 'overdue') {
        final reminderAt = status == 'snoozed' && row['snooze_until'] != null
            ? DateTime.parse(row['snooze_until'] as String).toLocal()
            : scheduledAt;
        if (reminderAt.isAfter(now)) {
          try {
            await NotificationService.scheduleReminder(
              notificationId: _notificationId(sourceId),
              title: 'Medication reminder',
              body:
                  'Take $medication at ${DateFormat.jm().format(reminderAt)}.',
              scheduledAt: reminderAt,
              payload: 'dose:$sourceId',
            );
          } catch (_) {
            // Inbox notifications remain available when OS scheduling is not.
          }
        }

        if (!difference.isNegative && difference.inMinutes <= 60) {
          await _insertGenerated(
            db,
            AppNotification(
              id: 'dose-due-$sourceId',
              userId: uid,
              type: 'dose_due',
              priority: 'normal',
              title: 'Medication due soon',
              body:
                  'Take $medication at ${DateFormat.jm().format(scheduledAt)}.',
              sourceId: sourceId,
              route: RouteNames.medications,
              createdAt: now,
            ),
          );
        } else if (difference.inMinutes <= -15) {
          await _insertGenerated(
            db,
            AppNotification(
              id: 'dose-overdue-$sourceId',
              userId: uid,
              type: 'dose_overdue',
              priority: difference.inMinutes <= -60 ? 'critical' : 'high',
              title: 'Medication overdue',
              body:
                  '$medication was due at ${DateFormat.jm().format(scheduledAt)}.',
              sourceId: sourceId,
              route: RouteNames.medications,
              createdAt: scheduledAt,
            ),
            showOnDevice: true,
          );
        }
      } else if (status == 'missed') {
        await _insertGenerated(
          db,
          AppNotification(
            id: 'dose-missed-$sourceId',
            userId: uid,
            type: 'dose_missed',
            priority: 'high',
            title: 'Dose missed',
            body: '$medication was marked as missed.',
            sourceId: sourceId,
            route: RouteNames.history,
            createdAt: scheduledAt,
          ),
          showOnDevice: true,
        );
      }
    }
  }

  Future<void> _generateRefillNotifications(
      Database db, String uid, DateTime now) async {
    final rows = await db.query(
      'medications',
      where: 'user_id = ? AND is_active = 1 AND refill_reminder_enabled = 1 '
          'AND refill_threshold_qty IS NOT NULL '
          'AND quantity_on_hand <= refill_threshold_qty',
      whereArgs: [uid],
    );
    final lowMedicationIds = rows.map((row) => row['id'] as String).toSet();
    final existingRefillNotifications = await db.query(
      'app_notifications',
      columns: ['id', 'source_id'],
      where: 'user_id = ? AND type = ?',
      whereArgs: [uid, 'refill_low'],
    );
    for (final existing in existingRefillNotifications) {
      if (!lowMedicationIds.contains(existing['source_id'])) {
        await db.delete(
          'app_notifications',
          where: 'id = ?',
          whereArgs: [existing['id']],
        );
      }
    }
    for (final row in rows) {
      final medicationId = row['id'] as String;
      await _insertGenerated(
        db,
        AppNotification(
          id: 'refill-low-$medicationId',
          userId: uid,
          type: 'refill_low',
          priority: (row['quantity_on_hand'] as num).toDouble() <= 1
              ? 'high'
              : 'normal',
          title: 'Medication stock is low',
          body:
              '${row['name']} has ${_amount(row['quantity_on_hand'])} ${row['quantity_unit']} remaining.',
          sourceId: medicationId,
          route: RouteNames.refills,
          createdAt: now,
        ),
        showOnDevice: true,
      );
    }
  }

  Future<void> _generateScheduleEndingNotifications(
      Database db, String uid, DateTime now) async {
    final rows = await db.rawQuery('''
      SELECT schedule.id, schedule.end_date, medication.name
      FROM schedules schedule
      JOIN medications medication ON medication.id = schedule.medication_id
      WHERE schedule.user_id = ?
        AND schedule.superseded_at IS NULL
        AND schedule.end_date IS NOT NULL
        AND schedule.end_date >= ?
        AND schedule.end_date <= ?
    ''', [
      uid,
      now.toUtc().toIso8601String(),
      now.add(const Duration(days: 3)).toUtc().toIso8601String(),
    ]);
    for (final row in rows) {
      final endDate = DateTime.parse(row['end_date'] as String).toLocal();
      await _insertGenerated(
        db,
        AppNotification(
          id: 'schedule-ending-${row['id']}',
          userId: uid,
          type: 'schedule_ending',
          priority: 'normal',
          title: 'Prescription ending soon',
          body:
              '${row['name']} is scheduled to end on ${DateFormat.yMMMd().format(endDate)}.',
          sourceId: row['id'] as String,
          route: RouteNames.medications,
          createdAt: now,
        ),
      );
    }
  }

  Future<void> _generateInvitationNotifications(Database db, String uid) async {
    final rows = await db.query(
      'caregiver_invitations',
      where:
          'user_id = ? OR caregiver_user_id = ? OR sender_user_id = ? OR receiver_user_id = ?',
      whereArgs: [uid, uid, uid, uid],
    );
    for (final row in rows) {
      final id = row['id'] as String;
      final status = row['status'] as String? ?? 'pending';
      final incoming = row['receiver_user_id'] == uid ||
          (row['caregiver_user_id'] == uid && row['sender_user_id'] != uid);
      final otherName = incoming
          ? (row['sender_name'] as String? ??
              row['patient_name'] as String? ??
              'A DoseDiary user')
          : (row['receiver_name'] as String? ?? 'Your connection');
      late final String title;
      late final String body;
      late final String priority;
      switch (status) {
        case 'accepted':
          title = 'Connection accepted';
          body = '$otherName accepted the DoseDiary connection.';
          priority = 'normal';
          break;
        case 'declined':
          title = 'Connection declined';
          body = '$otherName declined the DoseDiary connection.';
          priority = 'normal';
          break;
        case 'revoked':
          title = 'Connection removed';
          body = 'Your connection with $otherName has ended.';
          priority = 'high';
          break;
        default:
          title = incoming ? 'New connection invitation' : 'Invitation sent';
          body = incoming
              ? '$otherName wants to connect with you on DoseDiary.'
              : 'Your invitation to $otherName is waiting for a response.';
          priority = incoming ? 'high' : 'normal';
          break;
      }
      final createdAtText = (row['updated_at'] ?? row['created_at']) as String?;
      await _insertGenerated(
        db,
        AppNotification(
          id: 'invitation-$status-$id',
          userId: uid,
          type: 'invitation_$status',
          priority: priority,
          title: title,
          body: body,
          sourceId: id,
          route: RouteNames.caregivers,
          createdAt: createdAtText == null
              ? DateTime.now()
              : DateTime.parse(createdAtText).toLocal(),
        ),
        showOnDevice: incoming || status != 'pending',
      );
    }
  }

  Future<void> _generateCaregiverNotifications(
      Database db, String caregiverId, DateTime now) async {
    final patients = await db.query(
      'allocated_patients',
      where: 'caregiver_id = ? AND patient_user_id IS NOT NULL',
      whereArgs: [caregiverId],
    );
    for (final patient in patients) {
      final patientId = patient['patient_user_id'] as String;
      final patientName = patient['full_name'] as String? ?? 'Patient';
      final permissions = await db.query(
        'caregiver_permissions',
        where: 'user_id = ? AND caregiver_id = ?',
        whereArgs: [patientId, caregiverId],
        limit: 1,
      );
      bool permitted(String key, {bool fallback = true}) {
        if (permissions.isEmpty) return fallback;
        final value = permissions.first[key];
        return value == 1 || value == true;
      }

      if (permitted('perm_view_adherence')) {
        final occurrences = await db.rawQuery('''
          SELECT occurrence.*, medication.name AS medication_name,
                 medication.strength, medication.strength_unit
          FROM dose_occurrences occurrence
          LEFT JOIN medications medication ON medication.id = occurrence.medication_id
          WHERE occurrence.user_id = ? AND occurrence.scheduled_at >= ?
        ''', [
          patientId,
          now.subtract(const Duration(hours: 24)).toUtc().toIso8601String(),
        ]);
        var concernCount = 0;
        for (final occurrence in occurrences) {
          final status = occurrence['status'] as String? ?? 'pending';
          final scheduledAt =
              DateTime.parse(occurrence['scheduled_at'] as String).toLocal();
          final overdue = (status == 'pending' || status == 'overdue') &&
              now.difference(scheduledAt).inMinutes >= 30;
          final sourceId = occurrence['id'] as String;
          final medication = _medicationLabel(occurrence);
          if (status == 'taken') {
            await db.delete(
              'app_notifications',
              where: 'user_id = ? AND source_id = ? AND type IN (?, ?)',
              whereArgs: [
                caregiverId,
                sourceId,
                'patient_missed',
                'patient_skipped',
              ],
            );
          }
          if (status == 'missed' || status == 'skipped' || overdue) {
            concernCount++;
            await _insertGenerated(
              db,
              AppNotification(
                id: 'caregiver-concern-$caregiverId-$sourceId',
                userId: caregiverId,
                type:
                    status == 'skipped' ? 'patient_skipped' : 'patient_missed',
                priority: overdue || status == 'missed' ? 'high' : 'normal',
                title: overdue
                    ? '$patientName has an overdue dose'
                    : '$patientName ${status == 'skipped' ? 'skipped' : 'missed'} a dose',
                body:
                    '$medication was scheduled for ${DateFormat.jm().format(scheduledAt)}.',
                sourceId: sourceId,
                route: RouteNames.home,
                createdAt: scheduledAt,
              ),
              showOnDevice: true,
            );
          } else if (status == 'taken') {
            await _insertGenerated(
              db,
              AppNotification(
                id: 'caregiver-taken-$caregiverId-$sourceId',
                userId: caregiverId,
                type: 'patient_taken',
                priority: 'silent',
                title: '$patientName took a dose',
                body: '$medication was recorded as taken.',
                sourceId: sourceId,
                route: RouteNames.home,
                createdAt: scheduledAt,
              ),
            );
          }
        }
        if (concernCount >= 2) {
          await _insertGenerated(
            db,
            AppNotification(
              id: 'caregiver-repeated-$caregiverId-$patientId-${DateFormat('yyyyMMdd').format(now)}',
              userId: caregiverId,
              type: 'repeated_missed_doses',
              priority: 'critical',
              title: '$patientName needs attention',
              body: '$concernCount doses were missed, skipped, or overdue.',
              sourceId: patientId,
              route: RouteNames.home,
              createdAt: now,
            ),
            showOnDevice: true,
          );
        }
      }

      if (permitted('perm_view_refills', fallback: false)) {
        final lowStock = await db.query(
          'medications',
          where:
              'user_id = ? AND is_active = 1 AND refill_reminder_enabled = 1 '
              'AND refill_threshold_qty IS NOT NULL '
              'AND quantity_on_hand <= refill_threshold_qty',
          whereArgs: [patientId],
        );
        for (final medication in lowStock) {
          await _insertGenerated(
            db,
            AppNotification(
              id: 'caregiver-refill-$caregiverId-${medication['id']}',
              userId: caregiverId,
              type: 'patient_refill_low',
              priority: 'high',
              title: '$patientName needs a refill',
              body: '${medication['name']} is running low.',
              sourceId: medication['id'] as String,
              route: RouteNames.home,
              createdAt: now,
            ),
            showOnDevice: true,
          );
        }
      }
    }
  }

  Future<void> _generateCaregiverAlerts(Database db, String uid) async {
    final rows = await db.query(
      'caregiver_alerts',
      where: 'caregiver_id = ?',
      whereArgs: [uid],
    );
    for (final row in rows) {
      final id = row['id'] as String;
      await _insertGenerated(
        db,
        AppNotification(
          id: 'caregiver-alert-$id',
          userId: uid,
          type: 'caregiver_alert',
          priority: 'critical',
          title: 'Important medication alert',
          body: 'A patient has an important medication alert requiring review.',
          sourceId: row['occurrence_id'] as String?,
          route: RouteNames.home,
          createdAt: DateTime.parse(row['created_at'] as String).toLocal(),
        ),
        showOnDevice: true,
      );
    }
  }

  Future<bool> _insertGenerated(
    Database db,
    AppNotification notification, {
    bool showOnDevice = false,
  }) async {
    final existing = await db.query(
      'app_notifications',
      columns: ['id'],
      where: 'id = ?',
      whereArgs: [notification.id],
      limit: 1,
    );
    if (existing.isNotEmpty) return false;
    await db.insert(
      'app_notifications',
      notification.toMap(),
      conflictAlgorithm: ConflictAlgorithm.ignore,
    );
    SupabaseSyncService.pushAppNotification(notification.toMap()).ignore();
    if (showOnDevice && notification.priority != 'silent') {
      try {
        await NotificationService.showImmediateNotification(
          id: _notificationId(notification.id),
          title: notification.title,
          body: notification.body,
          payload: notification.route,
        );
      } catch (_) {
        // The in-app inbox remains the source of truth.
      }
    }
    return true;
  }

  Future<void> sendNotificationToUser({
    required String recipientUserId,
    required String type,
    required String priority,
    required String title,
    required String body,
    String? sourceId,
    String? route,
  }) async {
    final now = DateTime.now();
    final senderId = _userId;
    final notification = AppNotification(
      id: 'message-$senderId-${now.microsecondsSinceEpoch}',
      userId: recipientUserId,
      senderUserId: senderId,
      type: type,
      priority: priority,
      title: title,
      body: body,
      sourceId: sourceId,
      route: route,
      createdAt: now,
    );
    try {
      final db = await _database;
      await db.insert(
        'app_notifications',
        notification.toMap(),
        conflictAlgorithm: ConflictAlgorithm.ignore,
      );
    } catch (_) {
      // Cloud delivery can still proceed if local storage is unavailable.
    }
    await SupabaseSyncService.pushAppNotification(notification.toMap());
  }

  String _medicationLabel(Map<String, dynamic> row) {
    final name = row['medication_name'] as String? ?? 'Medication';
    final strength = row['strength'] as num?;
    final unit = row['strength_unit'] as String?;
    if (strength == null || strength == 0 || unit == null) return name;
    return '$name ${_amount(strength)} $unit';
  }

  String _amount(Object? value) {
    final number = (value as num?)?.toDouble() ?? 0;
    return number == number.roundToDouble()
        ? number.toInt().toString()
        : number.toStringAsFixed(1);
  }

  int _notificationId(String value) {
    var hash = 17;
    for (final unit in value.codeUnits) {
      hash = (hash * 37 + unit) & 0x7fffffff;
    }
    return hash;
  }
}

final notificationRepositoryProvider = Provider<NotificationRepository>((ref) {
  return NotificationRepository(ref.watch(appDatabaseProvider));
});

final notificationsProvider =
    FutureProvider.autoDispose<List<AppNotification>>((ref) {
  return ref.watch(notificationRepositoryProvider).getNotifications();
});

final unreadNotificationCountProvider = FutureProvider.autoDispose<int>((ref) {
  return ref.watch(notificationRepositoryProvider).getUnreadCount();
});
