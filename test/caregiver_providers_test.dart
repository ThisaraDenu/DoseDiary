import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:dose_diary/data/local/database_provider.dart';
import 'package:dose_diary/data/repositories/caregiver_repository.dart';
import 'package:dose_diary/features/caregivers/caregiver_providers.dart';

void main() {
  late Database db;
  late CaregiverRepository repository;
  late ProviderContainer container;

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

    final mockAppDatabase = TestAppDatabase(db);
    repository = CaregiverRepository(mockAppDatabase);

    container = ProviderContainer(
      overrides: [
        caregiverRepositoryProvider.overrideWithValue(repository),
        activeUserIdProvider.overrideWithValue('patient-001'),
        activeUserEmailProvider.overrideWithValue('caregiver@example.com'),
      ],
    );
  });

  tearDown(() async {
    container.dispose();
    await db.close();
  });

  group('Stage 3A Riverpod Provider Tests', () {
    test('1. load caregiver invitations for patient', () async {
      final initial = await container.read(caregiverInvitationsProvider.future);
      expect(initial, isEmpty);
    });

    test('2. create invitation automatically refreshes state', () async {
      final notifier = container.read(caregiverInvitationsProvider.notifier);
      final invite = await notifier.createInvitation(
        caregiverEmail: 'mother@example.com',
        relationship: 'Mother',
      );

      expect(invite.caregiverEmail, 'mother@example.com');
      final currentList = await container.read(caregiverInvitationsProvider.future);
      expect(currentList.length, 1);
      expect(currentList.first.id, invite.id);
    });

    test('3. revoke caregiver automatically refreshes state', () async {
      final notifier = container.read(caregiverInvitationsProvider.notifier);
      final invite = await notifier.createInvitation(
        caregiverEmail: 'revoke@example.com',
      );

      await notifier.revokeCaregiver(invite.id);
      final currentList = await container.read(caregiverInvitationsProvider.future);
      expect(currentList.first.status, 'revoked');
    });

    test('4. load permissions family provider', () async {
      final notifier = container.read(caregiverInvitationsProvider.notifier);
      final invite = await notifier.createInvitation(
        caregiverEmail: 'perm@example.com',
      );

      final perm = await container.read(caregiverPermissionsProvider(invite.id).future);
      expect(perm, isNotNull);
      expect(perm!.permViewSchedule, isTrue);
    });

    test('5. update permissions reloads latest state', () async {
      final notifier = container.read(caregiverInvitationsProvider.notifier);
      final invite = await notifier.createInvitation(
        caregiverEmail: 'updateperm@example.com',
      );

      final permNotifier = container.read(caregiverPermissionsProvider(invite.id).notifier);
      final initialPerm = await container.read(caregiverPermissionsProvider(invite.id).future);
      final updatedPerm = initialPerm!.copyWith(permViewRefills: true);

      await permNotifier.updatePermissions(updatedPerm);
      final newPerm = await container.read(caregiverPermissionsProvider(invite.id).future);
      expect(newPerm!.permViewRefills, isTrue);
    });

    test('6. load pending invitations for caregiver', () async {
      final patientRepoContainer = ProviderContainer(
        overrides: [
          caregiverRepositoryProvider.overrideWithValue(repository),
          activeUserIdProvider.overrideWithValue('patient-999'),
          activeUserEmailProvider.overrideWithValue('patient-999@example.com'),
        ],
      );
      await patientRepoContainer
          .read(caregiverInvitationsProvider.notifier)
          .createInvitation(caregiverEmail: 'caregiver@example.com');

      final pendingList = await container.read(pendingInvitationsProvider.future);
      expect(pendingList.length, 1);
      expect(pendingList.first.caregiverEmail, 'caregiver@example.com');

      patientRepoContainer.dispose();
    });

    test('7. accept invitation refreshes pending & connected patients', () async {
      final invite = await repository.createInvitation(
        userId: 'patient-888',
        caregiverEmail: 'caregiver@example.com',
      );

      final pendingNotifier = container.read(pendingInvitationsProvider.notifier);
      await pendingNotifier.acceptInvitation(
        invitationId: invite.id,
        caregiverId: 'caregiver-123',
      );

      final pendingList = await container.read(pendingInvitationsProvider.future);
      expect(pendingList, isEmpty);

      final connectedList = await container.read(connectedPatientsProvider.future);
      expect(connectedList.length, 1);
      expect(connectedList.first.patientId, 'patient-888');
    });

    test('8. decline invitation refreshes pending invitations', () async {
      final invite = await repository.createInvitation(
        userId: 'patient-777',
        caregiverEmail: 'caregiver@example.com',
      );

      final pendingNotifier = container.read(pendingInvitationsProvider.notifier);
      await pendingNotifier.declineInvitation(invite.id);

      final pendingList = await container.read(pendingInvitationsProvider.future);
      expect(pendingList, isEmpty);
    });

    test('9. load connected patients', () async {
      final patients = await container.read(connectedPatientsProvider.future);
      expect(patients, isA<List>());
    });

    test('10. disconnect patient refreshes connected patients list', () async {
      final invite = await repository.createInvitation(
        userId: 'patient-666',
        caregiverEmail: 'caregiver@example.com',
      );

      await repository.acceptInvitation(
        invitationId: invite.id,
        caregiverId: 'caregiver@example.com',
      );

      final connectedNotifier = container.read(connectedPatientsProvider.notifier);
      await connectedNotifier.disconnectPatient(
        patientId: 'patient-666',
        caregiverId: 'caregiver@example.com',
      );

      final connectedList = await container.read(connectedPatientsProvider.future);
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
