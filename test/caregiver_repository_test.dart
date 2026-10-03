import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:dose_diary/data/local/database_provider.dart';
import 'package:dose_diary/data/repositories/caregiver_repository.dart';

void main() {
  late Database db;
  late CaregiverRepository repository;

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  setUp(() async {
    db = await databaseFactory.openDatabase(
      inMemoryDatabasePath,
      options: OpenDatabaseOptions(
        version: 2,
        onCreate: (database, version) async {
          await database.execute('''
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
          ''');
          await database.execute('''
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
          ''');
          await database.execute('''
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
              updated_at TEXT NOT NULL
            )
          ''');
        },
      ),
    );

    // Mock AppDatabase using test db instance
    final mockAppDatabase = TestAppDatabase(db);
    repository = CaregiverRepository(mockAppDatabase);
  });

  tearDown(() async {
    await db.close();
  });

  group('CaregiverRepository SQLite CRUD Tests', () {
    test('1 & 2. Create and read patient caregiver invitations', () async {
      const patientId = 'patient-001';
      const caregiverEmail = 'mother@example.com';

      final invite = await repository.createInvitation(
        userId: patientId,
        caregiverEmail: caregiverEmail,
        relationship: 'Mother',
      );

      expect(invite.id, isNotEmpty);
      expect(invite.userId, patientId);
      expect(invite.caregiverEmail, caregiverEmail);
      expect(invite.status, 'pending');

      final invitesList = await repository.getCaregiverInvitationsForPatient(patientId);
      expect(invitesList.length, 1);
      expect(invitesList.first.id, invite.id);
      expect(invitesList.first.relationship, 'Mother');
    });

    test('3 & 4. Read single invitation and update relationship', () async {
      const patientId = 'patient-001';
      final invite = await repository.createInvitation(
        userId: patientId,
        caregiverEmail: 'father@example.com',
        relationship: 'Father',
      );

      final fetched = await repository.getInvitationById(invite.id);
      expect(fetched, isNotNull);
      expect(fetched!.relationship, 'Father');

      final updatedInvite = fetched.copyWith(relationship: 'Guardian');
      await repository.updateInvitation(updatedInvite);

      final reFetched = await repository.getInvitationById(invite.id);
      expect(reFetched!.relationship, 'Guardian');
    });

    test('6 & 7. Permissions insert, update and read for relationship', () async {
      const patientId = 'patient-002';
      final invite = await repository.createInvitation(
        userId: patientId,
        caregiverEmail: 'nurse@example.com',
        relationship: 'Nurse',
      );

      final perm = await repository.getPermissionsForRelationship(invitationId: invite.id);
      expect(perm, isNotNull);
      expect(perm!.permViewSchedule, isTrue);

      final updatedPerm = perm.copyWith(permViewRefills: true, alertImportantOnly: false);
      await repository.updateCaregiverPermissions(updatedPerm);

      final fetchedPerm = await repository.getPermissionsForRelationship(invitationId: invite.id);
      expect(fetchedPerm!.permViewRefills, isTrue);
      expect(fetchedPerm.alertImportantOnly, isFalse);
    });

    test('5. Soft revoke caregiver access', () async {
      const patientId = 'patient-003';
      final invite = await repository.createInvitation(
        userId: patientId,
        caregiverEmail: 'friend@example.com',
      );

      await repository.revokeCaregiver(invite.id);

      final revokedInvite = await repository.getInvitationById(invite.id);
      expect(revokedInvite!.status, 'revoked');

      final perm = await repository.getPermissionsForRelationship(invitationId: invite.id);
      expect(perm!.permViewSchedule, isFalse);
      expect(perm.permViewHistory, isFalse);
    });

    test('8 & 9. Caregiver pending invitations & accept invitation flow', () async {
      const patientId = 'patient-100';
      const caregiverId = 'caregiver-100';
      const caregiverEmail = 'doc@example.com';

      // Insert patient profile
      await db.insert('profiles', {
        'id': patientId,
        'full_name': 'John Patient',
        'created_at': DateTime.now().toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
      });

      final invite = await repository.createInvitation(
        userId: patientId,
        caregiverEmail: caregiverEmail,
      );

      final pendingList = await repository.getPendingInvitationsForCaregiver(caregiverEmail);
      expect(pendingList.length, 1);
      expect(pendingList.first.id, invite.id);

      await repository.acceptInvitation(
        invitationId: invite.id,
        caregiverId: caregiverId,
      );

      final updatedInvite = await repository.getInvitationById(invite.id);
      expect(updatedInvite!.status, 'accepted');

      final connectedPatients = await repository.getConnectedPatientsForCaregiver(caregiverId);
      expect(connectedPatients.length, 1);
      expect(connectedPatients.first.patientId, patientId);
      expect(connectedPatients.first.fullName, 'John Patient');
    });

    test('10. Decline invitation flow', () async {
      const caregiverEmail = 'decline@example.com';
      final invite = await repository.createInvitation(
        userId: 'patient-200',
        caregiverEmail: caregiverEmail,
      );

      await repository.declineInvitation(invite.id);

      final declinedInvite = await repository.getInvitationById(invite.id);
      expect(declinedInvite!.status, 'declined');

      final pendingList = await repository.getPendingInvitationsForCaregiver(caregiverEmail);
      expect(pendingList, isEmpty);
    });

    test('12. Disconnect patient flow', () async {
      const patientId = 'patient-300';
      const caregiverId = 'caregiver-300';

      final invite = await repository.createInvitation(
        userId: patientId,
        caregiverEmail: 'doctor@example.com',
      );

      await repository.acceptInvitation(
        invitationId: invite.id,
        caregiverId: caregiverId,
      );

      var connectedList = await repository.getConnectedPatientsForCaregiver(caregiverId);
      expect(connectedList.length, 1);

      await repository.disconnectPatient(patientId: patientId, caregiverId: caregiverId);

      connectedList = await repository.getConnectedPatientsForCaregiver(caregiverId);
      expect(connectedList, isEmpty);
    });
  });
}

class TestAppDatabase implements AppDatabase {
  TestAppDatabase(this._testDb);
  final Database _testDb;

  @override
  Future<Database> get database async => _testDb;

  @override
  Future<void> clearAllUserData() async {}

  @override
  Future<void> close() async => _testDb.close();

  @override
  Future<void> purgeDemoData() async {}
}
