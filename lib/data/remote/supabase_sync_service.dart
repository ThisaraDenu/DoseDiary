import 'package:sqflite/sqflite.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'auth_service.dart';
import '../local/database_provider.dart';

/// Bidirectional sync between local SQLite and Supabase.
///
/// Strategy:
/// • On login  → pull cloud data into local DB (server truth wins).
/// • On action → write to local DB first, then push to Supabase async.
///
/// PowerSync would replace this for full offline-first production use,
/// but this gives immediate live cloud sync without extra infrastructure.
class SupabaseSyncService {
  SupabaseSyncService._();

  static SupabaseClient get _client => Supabase.instance.client;

  // ── Pull (Cloud → Local) ─────────────────────────────────────────────────

  /// Download all data for the signed-in user into local SQLite.
  static Future<void> pullFromCloud() async {
    final user = AuthService.currentUser;
    if (user == null) return;

    final db = AppDatabase.instance;

    try {
      await _pullMedications(db, user.id);
      await _pullSchedules(db, user.id);
      await _pullDoseOccurrences(db, user.id);
      await _pullStockEvents(db, user.id);
      await _pullCaregiverInvitations(db, user.id);
      await _pullDirectConnectionInvitations(db, user.id);
      await _pullCaregiverPermissions(db, user.id);
      await _pullPermissionsGrantedToCaregiver(db, user.id);
      await _pullPatientCaregiverLinks(db, user.id);
      await _pullAllocatedPatients(db, user.id);
      await _pullAllocatedCaregivers(db, user.id);
      await _pullAppNotifications(db, user.id);
      await _pullAuthorizedPatientData(db, user.id);
      if (user.email != null && user.email!.isNotEmpty) {
        await _pullIncomingCaregiverInvitations(db, user.email!);
      }
    } catch (e) {
      // Non-fatal: local data still usable offline
      // ignore: avoid_print
      print('SupabaseSyncService.pullFromCloud error: $e');
    }
  }

  /// Refreshes one linked patient's caregiver-visible data directly from the
  /// cloud. This is used when Caregiver Mode opens so a second device does not
  /// depend on an older local SQLite snapshot.
  static Future<void> pullAuthorizedPatientDataFor(String patientUserId) async {
    final caregiver = AuthService.currentUser;
    if (caregiver == null || patientUserId.trim().isEmpty) return;

    final db = AppDatabase.instance;
    try {
      final permission = await _client
          .from('caregiver_permissions')
          .select()
          .eq('user_id', patientUserId)
          .eq('caregiver_id', caregiver.id)
          .maybeSingle();
      if (permission == null) return;

      final database = await db.database;
      await database.insert(
        'caregiver_permissions',
        _fromCloud(permission),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );

      bool enabled(String key) =>
          permission[key] == true ||
          permission[key] == 1 ||
          permission[key]?.toString() == '1';

      final canViewSchedule = enabled('perm_view_schedule');
      final canViewHistory = enabled('perm_view_history');
      final canViewRefills = enabled('perm_view_refills');
      final canViewAdherence = enabled('perm_view_adherence');

      if (canViewSchedule || canViewRefills) {
        await _pullMedications(db, patientUserId);
      }
      if (canViewSchedule) {
        await _pullSchedules(db, patientUserId);
      }
      if (canViewSchedule || canViewHistory || canViewAdherence) {
        await _pullDoseOccurrences(db, patientUserId);
      }
    } catch (e) {
      // Non-fatal: retain the last offline snapshot when cloud access fails.
      // ignore: avoid_print
      print('SupabaseSyncService patient refresh error: $e');
    }
  }

  // ── Sync All ─────────────────────────────────────────────────────────────

  /// Full bidirectional synchronization.
  /// Pushes local data to Supabase first, then pulls down any new cloud updates.
  static Future<void> syncAll() async {
    if (!AuthService.isLoggedIn) return;
    await pushAllLocalDataToCloud();
    await pullFromCloud();
  }

  /// Uploads all local data for the signed-in user to Supabase cloud.
  static Future<void> pushAllLocalDataToCloud() async {
    final user = AuthService.currentUser;
    if (user == null) return;

    try {
      final db = await AppDatabase.instance.database;

      // 1. Medications
      final meds = await db.query(
        'medications',
        where: 'user_id = ?',
        whereArgs: [user.id],
      );
      for (final row in meds) {
        await pushMedication(row);
      }

      // 2. Schedules
      final scheds = await db.query(
        'schedules',
        where: 'user_id = ?',
        whereArgs: [user.id],
      );
      for (final row in scheds) {
        final data = Map<String, dynamic>.from(row);
        if (data['times_of_day'] is String) {
          data['times_of_day'] = (data['times_of_day'] as String).split(',');
        }
        await pushSchedule(data);
      }

      // 3. Dose Occurrences
      final occs = await db.query(
        'dose_occurrences',
        where: 'user_id = ?',
        whereArgs: [user.id],
      );
      for (final row in occs) {
        await pushDoseOccurrence(row);
      }

      // 4. Dose Events
      final events = await db.query(
        'dose_events',
        where: 'user_id = ?',
        whereArgs: [user.id],
      );
      for (final row in events) {
        await pushDoseEvent(row);
      }

      // 5. Stock Events
      final stocks = await db.query(
        'stock_events',
        where: 'user_id = ?',
        whereArgs: [user.id],
      );
      for (final row in stocks) {
        await pushStockEvent(row);
      }

      // 6. Caregiver Invitations
      final invites = await db.query(
        'caregiver_invitations',
        where: 'user_id = ?',
        whereArgs: [user.id],
      );
      for (final row in invites) {
        await pushCaregiverInvitation(row);
      }

      // 7. Caregiver Permissions
      final perms = await db.query(
        'caregiver_permissions',
        where: 'user_id = ?',
        whereArgs: [user.id],
      );
      for (final row in perms) {
        await pushCaregiverPermission(row);
      }

      // 8. Patient-Caregiver Links
      final links = await db.query(
        'patient_caregiver_links',
        where: 'patient_user_id = ? OR caregiver_user_id = ?',
        whereArgs: [user.id, user.id],
      );
      for (final row in links) {
        await pushPatientCaregiverLink(row);
      }

      // 9. Allocated Patients
      final allocPatients = await db.query(
        'allocated_patients',
        where: 'caregiver_id = ?',
        whereArgs: [user.id],
      );
      for (final row in allocPatients) {
        await pushAllocatedPatient(row);
      }

      // 10. Allocated Caregivers
      final allocCaregivers = await db.query(
        'allocated_caregivers',
        where: 'patient_id = ?',
        whereArgs: [user.id],
      );
      for (final row in allocCaregivers) {
        await pushAllocatedCaregiver(row);
      }

      // 11. In-app notifications created by or for this account.
      final notifications = await db.query(
        'app_notifications',
        where: 'user_id = ? OR sender_user_id = ?',
        whereArgs: [user.id, user.id],
      );
      for (final row in notifications) {
        await pushAppNotification(row);
      }
    } catch (e) {
      // ignore: avoid_print
      print('SupabaseSyncService.pushAllLocalDataToCloud error: $e');
    }
  }

  // ── Push (Local → Cloud) ─────────────────────────────────────────────────

  /// Push a new or updated medication to Supabase.
  static Future<void> pushMedication(Map<String, dynamic> data) async {
    if (!AuthService.isLoggedIn) return;
    await _upsert('medications', _toCloud(data));
  }

  /// Push a schedule row.
  static Future<void> pushSchedule(Map<String, dynamic> data) async {
    if (!AuthService.isLoggedIn) return;
    final cloud = _toCloud(data);
    if (cloud['times_of_day'] is String) {
      cloud['times_of_day'] = (cloud['times_of_day'] as String)
          .split(',')
          .map((s) => s.trim())
          .where((s) => s.isNotEmpty)
          .toList();
    }
    await _upsert('schedules', cloud);
  }

  /// Removes open reminders after a medication schedule is edited. Completed
  /// history is preserved.
  static Future<void> deleteOpenOccurrencesForSchedule({
    required String scheduleId,
    required String fromLocalDate,
  }) async {
    if (!AuthService.isLoggedIn) return;
    await _client
        .from('dose_occurrences')
        .delete()
        .eq('schedule_id', scheduleId)
        .gte('local_date', fromLocalDate)
        .inFilter('status', ['pending', 'snoozed', 'overdue']);
  }

  /// Push a dose occurrence status update.
  static Future<void> pushDoseOccurrence(Map<String, dynamic> data) async {
    if (!AuthService.isLoggedIn) return;
    await _upsert('dose_occurrences', _toCloud(data));
  }

  /// Push a dose event (taken/skipped/snoozed).
  static Future<void> pushDoseEvent(Map<String, dynamic> data) async {
    if (!AuthService.isLoggedIn) return;
    await _upsert('dose_events', _toCloud(data));
  }

  /// Push a stock event (refill/deduction).
  static Future<void> pushStockEvent(Map<String, dynamic> data) async {
    if (!AuthService.isLoggedIn) return;
    await _upsert('stock_events', _toCloud(data));
  }

  /// Push a caregiver invitation to Supabase.
  static Future<void> pushCaregiverInvitation(Map<String, dynamic> data) async {
    if (!AuthService.isLoggedIn) return;
    await _upsert('caregiver_invitations', _toCloud(data));
  }

  /// Push caregiver permissions to Supabase.
  static Future<void> pushCaregiverPermission(Map<String, dynamic> data) async {
    if (!AuthService.isLoggedIn) return;
    await _upsert('caregiver_permissions', _toCloud(data));
  }

  /// Push a patient-caregiver link to Supabase.
  static Future<void> pushPatientCaregiverLink(
      Map<String, dynamic> data) async {
    if (!AuthService.isLoggedIn) return;
    await _upsert('patient_caregiver_links', _toCloud(data));
  }

  /// Push an allocated patient to Supabase.
  static Future<void> pushAllocatedPatient(Map<String, dynamic> data) async {
    if (!AuthService.isLoggedIn) return;
    await _upsert('allocated_patients', _toCloud(data));
  }

  /// Push an allocated caregiver to Supabase.
  static Future<void> pushAllocatedCaregiver(Map<String, dynamic> data) async {
    if (!AuthService.isLoggedIn) return;
    await _upsert('allocated_caregivers', _toCloud(data));
  }

  static Future<void> pushAppNotification(Map<String, dynamic> data) async {
    if (!AuthService.isLoggedIn) return;
    await _upsert('app_notifications', _toCloud(data));
  }

  static Future<void> deleteAppNotification(String id) async {
    if (!AuthService.isLoggedIn) return;
    try {
      await _client.from('app_notifications').delete().eq('id', id);
    } catch (error) {
      // ignore: avoid_print
      print('Could not delete cloud notification: $error');
    }
  }

  /// Removes a patient-caregiver connection for the signed-in participant.
  /// The database function deletes both allocation cards and revokes access.
  static Future<bool> removePatientCaregiverConnection(
      String targetUserId) async {
    if (!AuthService.isLoggedIn) return false;
    try {
      await _client.rpc(
        'remove_patient_caregiver_connection',
        params: {'target_user_id': targetUserId},
      );
      return true;
    } catch (error) {
      // Keep the local removal. It will remain marked as revoked and can be
      // retried after connectivity or the database migration is available.
      // ignore: avoid_print
      print('Could not sync connection removal: $error');
      return false;
    }
  }

  // ── Private pull helpers ──────────────────────────────────────────────────

  static Future<void> _pullMedications(AppDatabase db, String userId) async {
    final rows = await _client
        .from('medications')
        .select()
        .eq('user_id', userId)
        .order('created_at');

    final database = await db.database;
    for (final row in rows) {
      await database.insert('medications', _fromCloud(row),
          conflictAlgorithm: ConflictAlgorithm.replace);
    }
  }

  static Future<void> _pullSchedules(AppDatabase db, String userId) async {
    final rows = await _client
        .from('schedules')
        .select()
        .eq('user_id', userId)
        .order('created_at');

    final database = await db.database;
    for (final row in rows) {
      final local = _fromCloud(row);
      // times_of_day is a Postgres TEXT[] — join to comma string for SQLite
      if (row['times_of_day'] is List) {
        local['times_of_day'] = (row['times_of_day'] as List).join(',');
      }
      await database.insert('schedules', local,
          conflictAlgorithm: ConflictAlgorithm.replace);
    }
  }

  static Future<void> _pullDoseOccurrences(
      AppDatabase db, String userId) async {
    final rows = await _client
        .from('dose_occurrences')
        .select()
        .eq('user_id', userId)
        .order('scheduled_at', ascending: false)
        .limit(500);

    final database = await db.database;
    for (final row in rows) {
      final local = _fromCloud(row);
      // Keep offline deletions when the cloud still has an older record.
      final existing = await database.query(
        'dose_occurrences',
        columns: ['history_deleted_at'],
        where: 'id = ? AND user_id = ?',
        whereArgs: [row['id'], userId],
        limit: 1,
      );
      if (existing.isNotEmpty && existing.first['history_deleted_at'] != null) {
        local['history_deleted_at'] = existing.first['history_deleted_at'];
      }
      await database.insert('dose_occurrences', local,
          conflictAlgorithm: ConflictAlgorithm.replace);
    }
    final events = await _client
        .from('dose_events')
        .select()
        .eq('user_id', userId)
        .order('created_at', ascending: false)
        .limit(1000);
    for (final event in events) {
      await database.insert('dose_events', _fromCloud(event),
          conflictAlgorithm: ConflictAlgorithm.replace);
    }
  }

  static Future<void> _pullStockEvents(AppDatabase db, String userId) async {
    final rows = await _client
        .from('stock_events')
        .select()
        .eq('user_id', userId)
        .order('created_at', ascending: false)
        .limit(200);

    final database = await db.database;
    for (final row in rows) {
      await database.insert('stock_events', _fromCloud(row),
          conflictAlgorithm: ConflictAlgorithm.replace);
    }
  }

  static Future<void> _pullCaregiverInvitations(
      AppDatabase db, String userId) async {
    final rows = await _client
        .from('caregiver_invitations')
        .select()
        .eq('user_id', userId);

    final database = await db.database;
    for (final row in rows) {
      await database.insert('caregiver_invitations', _fromCloud(row),
          conflictAlgorithm: ConflictAlgorithm.replace);
    }
  }

  static Future<void> _pullCaregiverPermissions(
      AppDatabase db, String userId) async {
    final rows = await _client
        .from('caregiver_permissions')
        .select()
        .eq('user_id', userId);

    final database = await db.database;
    for (final row in rows) {
      await database.insert('caregiver_permissions', _fromCloud(row),
          conflictAlgorithm: ConflictAlgorithm.replace);
    }
  }

  /// Downloads the permission rows where the signed-in user is the caregiver.
  /// The existing pull above is intentionally patient-side (`user_id`).
  static Future<void> _pullPermissionsGrantedToCaregiver(
      AppDatabase db, String caregiverUserId) async {
    final rows = await _client
        .from('caregiver_permissions')
        .select()
        .eq('caregiver_id', caregiverUserId);

    final database = await db.database;
    for (final row in rows) {
      await database.insert('caregiver_permissions', _fromCloud(row),
          conflictAlgorithm: ConflictAlgorithm.replace);
    }
  }

  /// Pulls medication records only for patients allocated to this caregiver and
  /// only for the data categories the patient has granted permission to view.
  static Future<void> _pullAuthorizedPatientData(
      AppDatabase db, String caregiverUserId) async {
    final database = await db.database;
    final patients = await database.query(
      'allocated_patients',
      columns: ['patient_user_id'],
      where: 'caregiver_id = ? AND patient_user_id IS NOT NULL',
      whereArgs: [caregiverUserId],
    );

    bool isEnabled(Object? value) => value == true || value == 1;

    for (final patient in patients) {
      final patientUserId = patient['patient_user_id'] as String?;
      if (patientUserId == null || patientUserId.isEmpty) continue;

      final permissionRows = await database.query(
        'caregiver_permissions',
        where: 'user_id = ? AND caregiver_id = ?',
        whereArgs: [patientUserId, caregiverUserId],
        limit: 1,
      );
      if (permissionRows.isEmpty) continue;

      final permissions = permissionRows.first;
      final canViewSchedule = isEnabled(permissions['perm_view_schedule']);
      final canViewHistory = isEnabled(permissions['perm_view_history']);
      final canViewRefills = isEnabled(permissions['perm_view_refills']);
      final canViewAdherence = isEnabled(permissions['perm_view_adherence']);

      try {
        if (canViewSchedule || canViewRefills) {
          await _pullMedications(db, patientUserId);
        }
        if (canViewSchedule) {
          await _pullSchedules(db, patientUserId);
        }
        if (canViewSchedule || canViewHistory || canViewAdherence) {
          await _pullDoseOccurrences(db, patientUserId);
        }
      } catch (e) {
        // One patient's permission/data issue must not stop the user's sync.
        // ignore: avoid_print
        print('SupabaseSyncService patient data pull error: $e');
      }
    }
  }

  static Future<void> _pullIncomingCaregiverInvitations(
      AppDatabase db, String email) async {
    final rows = await _client
        .from('caregiver_invitations')
        .select()
        .ilike('caregiver_email', email.trim());

    final database = await db.database;
    for (final row in rows) {
      await database.insert('caregiver_invitations', _fromCloud(row),
          conflictAlgorithm: ConflictAlgorithm.replace);
    }
  }

  static Future<void> _pullDirectConnectionInvitations(
      AppDatabase db, String userId) async {
    final rows = await _client
        .from('caregiver_invitations')
        .select()
        .or('sender_user_id.eq.$userId,receiver_user_id.eq.$userId')
        .order('created_at', ascending: false);

    final database = await db.database;
    for (final row in rows) {
      await database.insert(
        'caregiver_invitations',
        _fromCloud(row),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
  }

  static Future<void> _pullPatientCaregiverLinks(
      AppDatabase db, String userId) async {
    final rows = await _client
        .from('patient_caregiver_links')
        .select()
        .or('patient_user_id.eq.$userId,caregiver_user_id.eq.$userId');

    final database = await db.database;
    for (final row in rows) {
      final localRows = await database.query(
        'patient_caregiver_links',
        where: 'patient_user_id = ? AND caregiver_user_id = ?',
        whereArgs: [row['patient_user_id'], row['caregiver_user_id']],
        limit: 1,
      );
      if (localRows.isNotEmpty &&
          localRows.first['status'] == 'revoked' &&
          row['status'] == 'active') {
        final localUpdatedAt =
            DateTime.tryParse(localRows.first['updated_at'] as String? ?? '');
        final cloudUpdatedAt =
            DateTime.tryParse(row['updated_at'] as String? ?? '');
        if (localUpdatedAt != null &&
            (cloudUpdatedAt == null ||
                !cloudUpdatedAt.isAfter(localUpdatedAt))) {
          final patientId = row['patient_user_id'] as String;
          final caregiverId = row['caregiver_user_id'] as String;
          final targetUserId = userId == patientId ? caregiverId : patientId;
          await removePatientCaregiverConnection(targetUserId);
          continue;
        }
      }
      await database.insert('patient_caregiver_links', _fromCloud(row),
          conflictAlgorithm: ConflictAlgorithm.replace);
    }
  }

  static Future<void> _pullAllocatedPatients(
      AppDatabase db, String userId) async {
    final rows = await _client
        .from('allocated_patients')
        .select()
        .eq('caregiver_id', userId);

    final database = await db.database;
    final revokedLinks = await database.query(
      'patient_caregiver_links',
      columns: ['patient_user_id'],
      where: 'caregiver_user_id = ? AND status = ?',
      whereArgs: [userId, 'revoked'],
    );
    final revokedPatientIds =
        revokedLinks.map((row) => row['patient_user_id'] as String).toSet();
    final visibleRows = rows
        .where((row) => !revokedPatientIds.contains(row['patient_user_id']))
        .toList();
    final remotePatientIds = visibleRows
        .map((row) => row['patient_user_id'] as String?)
        .whereType<String>()
        .toSet()
        .toList();
    await database.transaction((txn) async {
      final staleWhere = remotePatientIds.isEmpty
          ? 'caregiver_id = ? AND patient_user_id IS NOT NULL'
          : 'caregiver_id = ? AND patient_user_id IS NOT NULL AND patient_user_id NOT IN (${List.filled(remotePatientIds.length, '?').join(', ')})';
      final staleArgs = [userId, ...remotePatientIds];
      final staleRows = await txn.query(
        'allocated_patients',
        columns: ['patient_user_id'],
        where: staleWhere,
        whereArgs: staleArgs,
      );
      await txn.delete(
        'allocated_patients',
        where: staleWhere,
        whereArgs: staleArgs,
      );
      for (final staleRow in staleRows) {
        final patientId = staleRow['patient_user_id'] as String?;
        if (patientId != null) {
          await _clearCachedPatientData(txn, patientId, userId);
        }
      }
      for (final row in visibleRows) {
        await txn.insert('allocated_patients', _fromCloud(row),
            conflictAlgorithm: ConflictAlgorithm.replace);
      }
    });
  }

  static Future<void> _pullAllocatedCaregivers(
      AppDatabase db, String userId) async {
    final rows = await _client
        .from('allocated_caregivers')
        .select()
        .eq('patient_id', userId);

    final database = await db.database;
    final revokedLinks = await database.query(
      'patient_caregiver_links',
      columns: ['caregiver_user_id'],
      where: 'patient_user_id = ? AND status = ?',
      whereArgs: [userId, 'revoked'],
    );
    final revokedCaregiverIds =
        revokedLinks.map((row) => row['caregiver_user_id'] as String).toSet();
    final visibleRows = rows
        .where((row) => !revokedCaregiverIds.contains(row['caregiver_user_id']))
        .toList();
    final remoteCaregiverIds = visibleRows
        .map((row) => row['caregiver_user_id'] as String?)
        .whereType<String>()
        .toSet()
        .toList();
    await database.transaction((txn) async {
      if (remoteCaregiverIds.isEmpty) {
        await txn.delete(
          'allocated_caregivers',
          where: 'patient_id = ? AND caregiver_user_id IS NOT NULL',
          whereArgs: [userId],
        );
      } else {
        final placeholders =
            List.filled(remoteCaregiverIds.length, '?').join(', ');
        await txn.delete(
          'allocated_caregivers',
          where:
              'patient_id = ? AND caregiver_user_id IS NOT NULL AND caregiver_user_id NOT IN ($placeholders)',
          whereArgs: [userId, ...remoteCaregiverIds],
        );
      }
      for (final row in visibleRows) {
        await txn.insert('allocated_caregivers', _fromCloud(row),
            conflictAlgorithm: ConflictAlgorithm.replace);
      }
    });
  }

  static Future<void> _pullAppNotifications(
      AppDatabase db, String userId) async {
    final rows = await _client
        .from('app_notifications')
        .select()
        .eq('user_id', userId)
        .order('created_at', ascending: false);
    final database = await db.database;
    for (final row in rows) {
      await database.insert(
        'app_notifications',
        _fromCloud(row),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
  }

  static Future<void> pullAppNotifications() async {
    final userId = AuthService.currentUser?.id;
    if (userId == null) return;
    try {
      await _pullAppNotifications(AppDatabase.instance, userId);
    } catch (error) {
      // The local inbox remains usable offline or before the migration exists.
      // ignore: avoid_print
      print('Could not pull app notifications: $error');
    }
  }

  static Future<void> _clearCachedPatientData(
      DatabaseExecutor db, String patientUserId, String caregiverUserId) async {
    await db.delete(
      'caregiver_permissions',
      where: 'user_id = ? AND caregiver_id = ?',
      whereArgs: [patientUserId, caregiverUserId],
    );
    await db.delete('dose_events',
        where: 'user_id = ?', whereArgs: [patientUserId]);
    await db.delete('stock_events',
        where: 'user_id = ?', whereArgs: [patientUserId]);
    await db.delete('dose_occurrences',
        where: 'user_id = ?', whereArgs: [patientUserId]);
    await db
        .delete('schedules', where: 'user_id = ?', whereArgs: [patientUserId]);
    await db.delete('medications',
        where: 'user_id = ?', whereArgs: [patientUserId]);
  }

  /// Pulls incoming caregiver invitations addressed to the specified email (or current user's email).
  static Future<void> pullIncomingCaregiverInvitations({String? email}) async {
    final targetEmail = email ?? AuthService.currentUser?.email;
    if (targetEmail == null || targetEmail.isEmpty) return;
    try {
      await _pullIncomingCaregiverInvitations(
          AppDatabase.instance, targetEmail);
    } catch (e) {
      // ignore: avoid_print
      print('SupabaseSyncService.pullIncomingCaregiverInvitations error: $e');
    }
  }

  /// Pulls ID-based invitations sent by or addressed to the current user.
  static Future<void> pullDirectConnectionInvitations() async {
    final userId = AuthService.currentUser?.id;
    if (userId == null) return;
    try {
      await _pullDirectConnectionInvitations(AppDatabase.instance, userId);
    } catch (e) {
      // ignore: avoid_print
      print('SupabaseSyncService.pullDirectConnectionInvitations error: $e');
    }
  }

  // ── Utilities ─────────────────────────────────────────────────────────────

  /// Refreshes both sides of accepted patient/caregiver relationships so
  /// profile presence changes are reflected in the local cards.
  static Future<void> pullConnectedPeople() async {
    final userId = AuthService.currentUser?.id;
    if (userId == null) return;

    try {
      await _pullPatientCaregiverLinks(AppDatabase.instance, userId);
    } catch (e) {
      // ignore: avoid_print
      print('SupabaseSyncService.pullConnectedPeople links error: $e');
    }
    try {
      await _pullAllocatedPatients(AppDatabase.instance, userId);
    } catch (e) {
      // ignore: avoid_print
      print('SupabaseSyncService.pullConnectedPeople patients error: $e');
    }
    try {
      await _pullAllocatedCaregivers(AppDatabase.instance, userId);
    } catch (e) {
      // ignore: avoid_print
      print('SupabaseSyncService.pullConnectedPeople caregivers error: $e');
    }
  }

  static Future<void> _upsert(String table, Map<String, dynamic> data) async {
    try {
      await _client.from(table).upsert(data, onConflict: 'id');
    } catch (e) {
      // ignore: avoid_print
      print('SupabaseSyncService._upsert $table error: $e');
    }
  }

  /// Cloud → Local: convert Postgres booleans → SQLite integers (0/1).
  static Map<String, dynamic> _fromCloud(Map<String, dynamic> row) {
    final boolFields = {
      'is_active',
      'is_as_needed',
      'refill_reminder_enabled',
      'simple_wording',
      'notification_sound',
      'notification_vibration',
      'privacy_safe_previews',
      'perm_view_schedule',
      'perm_view_history',
      'perm_view_refills',
      'perm_view_adherence',
      'alert_important_only',
      'is_read',
    };
    final result = <String, dynamic>{};
    for (final entry in row.entries) {
      final v = entry.value;
      if (boolFields.contains(entry.key) && v is bool) {
        result[entry.key] = v ? 1 : 0;
      } else if (v == null) {
        result[entry.key] = null;
      } else {
        result[entry.key] = v.toString();
      }
    }
    return result;
  }

  /// Local → Cloud: convert SQLite 0/1 integers → Postgres booleans.
  static Map<String, dynamic> _toCloud(Map<String, dynamic> data) {
    final boolFields = {
      'is_active',
      'is_as_needed',
      'refill_reminder_enabled',
      'simple_wording',
      'notification_sound',
      'notification_vibration',
      'privacy_safe_previews',
      'perm_view_schedule',
      'perm_view_history',
      'perm_view_refills',
      'perm_view_adherence',
      'alert_important_only',
      'is_read',
    };
    final result = Map<String, dynamic>.from(data);
    for (final field in boolFields) {
      if (result.containsKey(field) && result[field] is int) {
        result[field] = result[field] == 1;
      }
    }
    return result;
  }
}
