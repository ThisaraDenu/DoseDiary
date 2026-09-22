import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Simple SQLite database provider using sqflite.
/// In production this would be replaced by PowerSync's managed SQLite instance.
/// This implementation provides the full local-first experience and is
/// compatible with PowerSync's database API.
class AppDatabase {
  static AppDatabase? _instance;
  static Database? _db;

  static AppDatabase get instance {
    _instance ??= AppDatabase._();
    return _instance!;
  }

  AppDatabase._();

  Future<Database> get database async {
    _db ??= await _openDatabase();
    return _db!;
  }

  Future<Database> _openDatabase() async {
    final path = join(await getDatabasesPath(), 'dose_diary.db');
    return openDatabase(
      path,
      version: 1,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    await db.execute(_createProfilesTable);
    await db.execute(_createMedicationsTable);
    await db.execute(_createSchedulesTable);
    await db.execute(_createDoseOccurrencesTable);
    await db.execute(_createDoseEventsTable);
    await db.execute(_createStockEventsTable);
    await db.execute(_createCaregiverInvitationsTable);
    await db.execute(_createCaregiverPermissionsTable);
    await db.execute(_createCaregiverAlertsTable);
    await db.execute(_createNotificationAttemptsTable);
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    // Future migration logic
  }

  // ── Table DDL ──────────────────────────────────────────────────────────────

  static const _createProfilesTable = '''
    CREATE TABLE IF NOT EXISTS profiles (
      id TEXT PRIMARY KEY,
      full_name TEXT NOT NULL DEFAULT '',
      avatar_url TEXT,
      preferred_language TEXT NOT NULL DEFAULT 'en',
      text_scale_factor REAL NOT NULL DEFAULT 1.0,
      simple_wording INTEGER NOT NULL DEFAULT 0,
      notification_sound INTEGER NOT NULL DEFAULT 1,
      notification_vibration INTEGER NOT NULL DEFAULT 1,
      privacy_safe_previews INTEGER NOT NULL DEFAULT 1,
      created_at TEXT NOT NULL,
      updated_at TEXT NOT NULL
    )
  ''';

  static const _createMedicationsTable = '''
    CREATE TABLE IF NOT EXISTS medications (
      id TEXT PRIMARY KEY,
      user_id TEXT NOT NULL,
      name TEXT NOT NULL,
      strength REAL NOT NULL DEFAULT 0,
      strength_unit TEXT NOT NULL DEFAULT 'mg',
      amount_per_dose REAL NOT NULL DEFAULT 1,
      dose_unit TEXT NOT NULL DEFAULT 'tablet(s)',
      instructions TEXT,
      is_active INTEGER NOT NULL DEFAULT 1,
      is_as_needed INTEGER NOT NULL DEFAULT 0,
      quantity_on_hand REAL NOT NULL DEFAULT 0,
      quantity_unit TEXT NOT NULL DEFAULT 'tablet(s)',
      refill_reminder_enabled INTEGER NOT NULL DEFAULT 0,
      refill_threshold_qty REAL,
      refill_reminder_date TEXT,
      created_at TEXT NOT NULL,
      updated_at TEXT NOT NULL
    )
  ''';

  static const _createSchedulesTable = '''
    CREATE TABLE IF NOT EXISTS schedules (
      id TEXT PRIMARY KEY,
      medication_id TEXT NOT NULL,
      user_id TEXT NOT NULL,
      times_of_day TEXT NOT NULL,
      frequency_type TEXT NOT NULL DEFAULT 'daily',
      repeat_days TEXT,
      start_date TEXT NOT NULL,
      end_date TEXT,
      timezone TEXT NOT NULL DEFAULT 'UTC',
      created_at TEXT NOT NULL,
      superseded_at TEXT,
      FOREIGN KEY(medication_id) REFERENCES medications(id)
    )
  ''';

  static const _createDoseOccurrencesTable = '''
    CREATE TABLE IF NOT EXISTS dose_occurrences (
      id TEXT PRIMARY KEY,
      schedule_id TEXT NOT NULL,
      medication_id TEXT NOT NULL,
      user_id TEXT NOT NULL,
      scheduled_at TEXT NOT NULL,
      local_date TEXT NOT NULL,
      occurrence_key TEXT NOT NULL UNIQUE,
      status TEXT NOT NULL DEFAULT 'pending',
      snooze_until TEXT,
      created_at TEXT NOT NULL,
      FOREIGN KEY(medication_id) REFERENCES medications(id),
      FOREIGN KEY(schedule_id) REFERENCES schedules(id)
    )
  ''';

  static const _createDoseEventsTable = '''
    CREATE TABLE IF NOT EXISTS dose_events (
      id TEXT PRIMARY KEY,
      occurrence_id TEXT NOT NULL,
      user_id TEXT NOT NULL,
      action TEXT NOT NULL,
      recorded_at TEXT NOT NULL,
      snooze_until TEXT,
      skip_reason TEXT,
      client_id TEXT NOT NULL UNIQUE,
      created_at TEXT NOT NULL,
      FOREIGN KEY(occurrence_id) REFERENCES dose_occurrences(id)
    )
  ''';

  static const _createStockEventsTable = '''
    CREATE TABLE IF NOT EXISTS stock_events (
      id TEXT PRIMARY KEY,
      medication_id TEXT NOT NULL,
      user_id TEXT NOT NULL,
      event_type TEXT NOT NULL,
      quantity_delta REAL NOT NULL,
      quantity_after REAL NOT NULL,
      dose_event_id TEXT,
      client_id TEXT NOT NULL UNIQUE,
      note TEXT,
      created_at TEXT NOT NULL,
      FOREIGN KEY(medication_id) REFERENCES medications(id)
    )
  ''';

  static const _createCaregiverInvitationsTable = '''
    CREATE TABLE IF NOT EXISTS caregiver_invitations (
      id TEXT PRIMARY KEY,
      user_id TEXT NOT NULL,
      caregiver_email TEXT NOT NULL,
      relationship TEXT NOT NULL DEFAULT 'Family member',
      status TEXT NOT NULL DEFAULT 'pending',
      token TEXT NOT NULL UNIQUE,
      expires_at TEXT NOT NULL,
      created_at TEXT NOT NULL,
      updated_at TEXT NOT NULL
    )
  ''';

  static const _createCaregiverPermissionsTable = '''
    CREATE TABLE IF NOT EXISTS caregiver_permissions (
      id TEXT PRIMARY KEY,
      invitation_id TEXT NOT NULL,
      user_id TEXT NOT NULL,
      caregiver_id TEXT,
      perm_view_schedule INTEGER NOT NULL DEFAULT 0,
      perm_view_history INTEGER NOT NULL DEFAULT 0,
      perm_view_refills INTEGER NOT NULL DEFAULT 0,
      perm_view_adherence INTEGER NOT NULL DEFAULT 0,
      alert_important_only INTEGER NOT NULL DEFAULT 1,
      retry_count INTEGER NOT NULL DEFAULT 2,
      grace_period_minutes INTEGER NOT NULL DEFAULT 30,
      created_at TEXT NOT NULL,
      updated_at TEXT NOT NULL,
      FOREIGN KEY(invitation_id) REFERENCES caregiver_invitations(id)
    )
  ''';

  static const _createCaregiverAlertsTable = '''
    CREATE TABLE IF NOT EXISTS caregiver_alerts (
      id TEXT PRIMARY KEY,
      occurrence_id TEXT NOT NULL,
      caregiver_id TEXT NOT NULL,
      user_id TEXT NOT NULL,
      status TEXT NOT NULL DEFAULT 'pending',
      sent_at TEXT,
      acknowledged_at TEXT,
      client_id TEXT NOT NULL UNIQUE,
      created_at TEXT NOT NULL
    )
  ''';

  static const _createNotificationAttemptsTable = '''
    CREATE TABLE IF NOT EXISTS notification_attempts (
      id TEXT PRIMARY KEY,
      occurrence_id TEXT NOT NULL,
      attempt_number INTEGER NOT NULL DEFAULT 1,
      scheduled_at TEXT NOT NULL,
      delivered_at TEXT,
      status TEXT NOT NULL DEFAULT 'scheduled',
      created_at TEXT NOT NULL
    )
  ''';



  /// Purges leftover demo-user-001 data from local storage.
  Future<void> purgeDemoData() async {
    final db = await database;
    await db.delete('medications', where: 'user_id = ?', whereArgs: ['demo-user-001']);
    await db.delete('schedules', where: 'user_id = ?', whereArgs: ['demo-user-001']);
    await db.delete('dose_occurrences', where: 'user_id = ?', whereArgs: ['demo-user-001']);
    await db.delete('dose_events', where: 'user_id = ?', whereArgs: ['demo-user-001']);
    await db.delete('stock_events', where: 'user_id = ?', whereArgs: ['demo-user-001']);
    await db.delete('profiles', where: 'id = ?', whereArgs: ['demo-user-001']);
  }

  /// Wipes all user-specific local SQLite tables (called on sign out).
  Future<void> clearAllUserData() async {
    final db = await database;
    await db.delete('dose_events');
    await db.delete('stock_events');
    await db.delete('dose_occurrences');
    await db.delete('schedules');
    await db.delete('medications');
    await db.delete('caregiver_alerts');
    await db.delete('caregiver_permissions');
    await db.delete('caregiver_invitations');
    await db.delete('notification_attempts');
    await db.delete('profiles');
  }

  Future<void> close() async => _db?.close();
}

// ── Provider ──────────────────────────────────────────────────────────────────

final appDatabaseProvider = Provider<AppDatabase>((ref) => AppDatabase.instance);

class DatabaseProvider {
  static Future<void> initialize() async {
    await AppDatabase.instance.database;
    await AppDatabase.instance.purgeDemoData();
  }
}
