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
      await _pullCaregiverPermissions(db, user.id);
    } catch (e) {
      // Non-fatal: local data still usable offline
      // ignore: avoid_print
      print('SupabaseSyncService.pullFromCloud error: $e');
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
        local['times_of_day'] =
            (row['times_of_day'] as List).join(',');
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
      await database.insert('dose_occurrences', _fromCloud(row),
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

  // ── Utilities ─────────────────────────────────────────────────────────────

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
      'is_active', 'is_as_needed', 'refill_reminder_enabled',
      'simple_wording', 'notification_sound', 'notification_vibration',
      'privacy_safe_previews', 'perm_view_schedule', 'perm_view_history',
      'perm_view_refills', 'perm_view_adherence', 'alert_important_only',
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
      'is_active', 'is_as_needed', 'refill_reminder_enabled',
      'simple_wording', 'notification_sound', 'notification_vibration',
      'privacy_safe_previews', 'perm_view_schedule', 'perm_view_history',
      'perm_view_refills', 'perm_view_adherence', 'alert_important_only',
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
