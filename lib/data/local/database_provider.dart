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
    final db = await openDatabase(
      path,
      version: 1,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
    // Ensure tables added after initial schema creation exist
    await db.execute(_createAllocatedPatientsTable);
    await db.execute(_createPatientCaregiverLinksTable);
    await db.execute(_createAllocatedCaregiversTable);
    // Add patient_user_id column if upgrading from older schema
    try {
      await db.execute(
          'ALTER TABLE allocated_patients ADD COLUMN patient_user_id TEXT');
    } catch (_) {/* column already exists — safe to ignore */}
    // Add date_of_birth and gender to profiles
    try {
      await db.execute('ALTER TABLE profiles ADD COLUMN date_of_birth TEXT');
    } catch (_) {/* column already exists — safe to ignore */}
    try {
      await db.execute('ALTER TABLE profiles ADD COLUMN gender TEXT');
    } catch (_) {/* column already exists — safe to ignore */}
    try {
      await db.execute('ALTER TABLE profiles ADD COLUMN phone_number TEXT');
    } catch (_) {/* column already exists — safe to ignore */}
    try {
      await db.execute('ALTER TABLE profiles ADD COLUMN public_id TEXT');
    } catch (_) {/* column already exists - safe to ignore */}
    await db.execute(
      'CREATE UNIQUE INDEX IF NOT EXISTS idx_profiles_public_id '
      'ON profiles(public_id) WHERE public_id IS NOT NULL',
    );
    for (final statement in const [
      'ALTER TABLE caregiver_invitations ADD COLUMN caregiver_user_id TEXT',
      'ALTER TABLE caregiver_invitations ADD COLUMN sender_user_id TEXT',
      'ALTER TABLE caregiver_invitations ADD COLUMN receiver_user_id TEXT',
      'ALTER TABLE caregiver_invitations ADD COLUMN sender_role TEXT',
      'ALTER TABLE caregiver_invitations ADD COLUMN sender_name TEXT',
      'ALTER TABLE caregiver_invitations ADD COLUMN receiver_name TEXT',
    ]) {
      try {
        await db.execute(statement);
      } catch (_) {/* column already exists - safe to ignore */}
    }
    await _clearSeedData(db);
    return db;
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
    await db.execute(_createAllocatedPatientsTable);
    await db.execute(_createPatientCaregiverLinksTable);
    await db.execute(_createAllocatedCaregiversTable);
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    // Future migration logic
  }

  /// Removes any rows that were inserted by the old seedSampleCaregiverData()
  /// helper. Safe to call repeatedly — it is a no-op once the rows are gone.
  Future<void> _clearSeedData(Database db) async {
    const tables = [
      'dose_events',
      'dose_occurrences',
      'schedules',
      'medications'
    ];
    for (final table in tables) {
      await db.delete(table, where: "id LIKE 'sample-%' OR id LIKE 'past_%'");
    }
  }

  // ── Table DDL ──────────────────────────────────────────────────────────────

  static const _createProfilesTable = '''
    CREATE TABLE IF NOT EXISTS profiles (
      id TEXT PRIMARY KEY,
      full_name TEXT NOT NULL DEFAULT '',
      avatar_url TEXT,
      date_of_birth TEXT,
      gender TEXT,
      phone_number TEXT,
      public_id TEXT UNIQUE,
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
      caregiver_user_id TEXT,
      sender_user_id TEXT,
      receiver_user_id TEXT,
      sender_role TEXT,
      sender_name TEXT,
      receiver_name TEXT,
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

  static const _createAllocatedPatientsTable = '''
    CREATE TABLE IF NOT EXISTS allocated_patients (
      id TEXT PRIMARY KEY,
      caregiver_id TEXT NOT NULL,
      patient_user_id TEXT,
      full_name TEXT NOT NULL,
      relationship TEXT NOT NULL DEFAULT 'Patient',
      avatar_url TEXT,
      location TEXT NOT NULL DEFAULT 'Colombo Home',
      last_active TEXT NOT NULL DEFAULT 'Active now',
      phone_battery INTEGER NOT NULL DEFAULT 85,
      battery_status TEXT NOT NULL DEFAULT 'Balanced',
      smart_hub_status TEXT NOT NULL DEFAULT 'Synced 2m ago',
      phone_number TEXT,
      created_at TEXT NOT NULL
    )
  ''';

  /// Many-to-many junction: each row = one confirmed patient↔caregiver relationship.
  static const _createPatientCaregiverLinksTable = '''
    CREATE TABLE IF NOT EXISTS patient_caregiver_links (
      id TEXT PRIMARY KEY,
      patient_user_id TEXT NOT NULL,
      caregiver_user_id TEXT NOT NULL,
      relationship TEXT NOT NULL DEFAULT 'Caregiver',
      invitation_id TEXT,
      status TEXT NOT NULL DEFAULT 'active',
      created_at TEXT NOT NULL,
      updated_at TEXT NOT NULL,
      UNIQUE (patient_user_id, caregiver_user_id)
    )
  ''';

  /// Caregivers allocated/linked to a patient in Patient Mode.
  static const _createAllocatedCaregiversTable = '''
    CREATE TABLE IF NOT EXISTS allocated_caregivers (
      id TEXT PRIMARY KEY,
      patient_id TEXT NOT NULL,
      caregiver_user_id TEXT,
      full_name TEXT NOT NULL,
      relationship TEXT NOT NULL DEFAULT 'Caregiver',
      avatar_url TEXT,
      location TEXT NOT NULL DEFAULT 'Colombo Home',
      last_active TEXT NOT NULL DEFAULT 'Active now',
      phone_battery INTEGER NOT NULL DEFAULT 84,
      battery_status TEXT NOT NULL DEFAULT 'Balanced',
      smart_hub_status TEXT NOT NULL DEFAULT 'Synced 2m ago',
      phone_number TEXT,
      created_at TEXT NOT NULL
    )
  ''';

  /// Purges leftover demo-user-001 data from local storage.
  Future<void> purgeDemoData() async {
    final db = await database;
    await db.delete('medications',
        where: 'user_id = ?', whereArgs: ['demo-user-001']);
    await db.delete('schedules',
        where: 'user_id = ?', whereArgs: ['demo-user-001']);
    await db.delete('dose_occurrences',
        where: 'user_id = ?', whereArgs: ['demo-user-001']);
    await db.delete('dose_events',
        where: 'user_id = ?', whereArgs: ['demo-user-001']);
    await db.delete('stock_events',
        where: 'user_id = ?', whereArgs: ['demo-user-001']);
    await db.delete('profiles', where: 'id = ?', whereArgs: ['demo-user-001']);
    await db.delete('allocated_patients',
        where: 'caregiver_id = ?', whereArgs: ['demo-user-001']);
    await db.delete('allocated_caregivers',
        where: 'patient_id = ?', whereArgs: ['demo-user-001']);
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
    await db.delete('allocated_patients');
    await db.delete('allocated_caregivers');
    await db.delete('patient_caregiver_links');
  }

  Future<void> close() async => _db?.close();
}

// ── Provider ──────────────────────────────────────────────────────────────────

final appDatabaseProvider =
    Provider<AppDatabase>((ref) => AppDatabase.instance);

class DatabaseProvider {
  static Future<void> initialize() async {
    await AppDatabase.instance.database;
    await AppDatabase.instance.purgeDemoData();
  }
}
