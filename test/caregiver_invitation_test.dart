import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dose_diary/data/local/models/app_models.dart';
import 'package:dose_diary/features/caregivers/caregiver_management_screen.dart';

void main() {
  group('CaregiverInvitation & CaregiverPermission Model Tests', () {
    test('CaregiverInvitation.create produces valid pending invitation', () {
      final invite = CaregiverInvitation.create(
        userId: 'patient-123',
        email: 'Caregiver@Example.COM ',
        relationship: 'Daughter',
        viewSchedule: true,
        viewHistory: true,
        viewRefills: true,
        viewAdherence: false,
      );

      expect(invite.id, isNotEmpty);
      expect(invite.token, isNotEmpty);
      expect(invite.userId, 'patient-123');
      // Email must be trimmed and lowercased
      expect(invite.email, 'caregiver@example.com');
      expect(invite.caregiverEmail, 'caregiver@example.com');
      expect(invite.relationship, 'Daughter');
      expect(invite.status, 'pending');
      expect(invite.viewSchedule, isTrue);
      expect(invite.viewHistory, isTrue);
      expect(invite.viewRefills, isTrue);
      expect(invite.viewAdherence, isFalse);
      expect(invite.expiresAt, isNotNull);
      expect(invite.expiresAt!.isAfter(invite.createdAt), isTrue);
    });

    test('CaregiverInvitation serialization toMap and fromMap round-trip', () {
      final now = DateTime.utc(2026, 1, 15, 10, 30);
      final invite = CaregiverInvitation(
        id: 'inv-001',
        userId: 'user-001',
        email: 'helper@test.com',
        relationship: 'Nurse',
        status: 'pending',
        token: 'token-abc',
        expiresAt: now.add(const Duration(days: 7)),
        createdAt: now,
        updatedAt: now,
        viewSchedule: true,
        viewHistory: false,
        viewRefills: true,
        viewAdherence: true,
      );

      final map = invite.toMap();
      expect(map['id'], 'inv-001');
      expect(map['user_id'], 'user-001');
      expect(map['caregiver_email'], 'helper@test.com');
      expect(map['relationship'], 'Nurse');
      expect(map['status'], 'pending');
      expect(map['token'], 'token-abc');

      // fromMap simulating joined row with permissions
      final fromMap = CaregiverInvitation.fromMap({
        ...map,
        'perm_view_schedule': 1,
        'perm_view_history': 0,
        'perm_view_refills': 1,
        'perm_view_adherence': 1,
      });
      expect(fromMap.id, invite.id);
      expect(fromMap.userId, invite.userId);
      expect(fromMap.email, invite.email);
      expect(fromMap.relationship, invite.relationship);
      expect(fromMap.status, invite.status);
      expect(fromMap.token, invite.token);
      expect(fromMap.viewSchedule, isTrue);
      expect(fromMap.viewHistory, isFalse);
      expect(fromMap.viewRefills, isTrue);
      expect(fromMap.viewAdherence, isTrue);
    });

    test('CaregiverPermission creation and serialization round-trip', () {
      final perm = CaregiverPermission.create(
        invitationId: 'inv-999',
        userId: 'patient-999',
        permViewSchedule: true,
        permViewHistory: false,
        permViewRefills: true,
        permViewAdherence: false,
      );

      expect(perm.invitationId, 'inv-999');
      expect(perm.userId, 'patient-999');
      expect(perm.permViewSchedule, isTrue);
      expect(perm.permViewHistory, isFalse);
      expect(perm.permViewRefills, isTrue);
      expect(perm.permViewAdherence, isFalse);
      expect(perm.retryCount, 2);
      expect(perm.gracePeriodMinutes, 30);

      final map = perm.toMap();
      expect(map['invitation_id'], 'inv-999');
      expect(map['perm_view_schedule'], 1);
      expect(map['perm_view_history'], 0);
      expect(map['perm_view_refills'], 1);
      expect(map['perm_view_adherence'], 0);

      final parsed = CaregiverPermission.fromMap(map);
      expect(parsed.invitationId, perm.invitationId);
      expect(parsed.permViewSchedule, isTrue);
      expect(parsed.permViewHistory, isFalse);
      expect(parsed.permViewRefills, isTrue);
      expect(parsed.permViewAdherence, isFalse);
    });
  });

  group('Caregiver Management Screen Widget Tests', () {
    testWidgets('renders empty state when no caregivers or invitations exist', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            caregiversProvider.overrideWith((ref) => []),
          ],
          child: const MaterialApp(
            home: CaregiverManagementScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Caregivers'), findsOneWidget);
      expect(find.text('Your Privacy'), findsOneWidget);
      expect(find.text('No caregivers added'), findsOneWidget);
      expect(find.text('Invite a Caregiver'), findsOneWidget);
    });

    testWidgets('renders caregiver cards with pending and active statuses and permissions', (tester) async {
      final now = DateTime.now();
      final pendingInvite = CaregiverInvitation(
        id: 'cg-1',
        userId: 'patient-1',
        email: 'son@example.com',
        relationship: 'Son',
        status: 'pending',
        createdAt: now,
        viewSchedule: true,
        viewHistory: true,
        viewRefills: false,
        viewAdherence: true,
      );

      final activeInvite = CaregiverInvitation(
        id: 'cg-2',
        userId: 'patient-1',
        email: 'nurse@clinic.org',
        relationship: 'Nurse',
        status: 'accepted',
        createdAt: now,
        viewSchedule: true,
        viewHistory: false,
        viewRefills: true,
        viewAdherence: false,
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            caregiversProvider.overrideWith((ref) => [pendingInvite, activeInvite]),
          ],
          child: const MaterialApp(
            home: CaregiverManagementScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Caregivers (2)'), findsOneWidget);
      expect(find.text('son@example.com'), findsOneWidget);
      expect(find.text('nurse@clinic.org'), findsOneWidget);

      // Status badges
      expect(find.text('Pending'), findsOneWidget);
      expect(find.text('Active'), findsOneWidget);

      // Permission chips
      expect(find.text('Schedule'), findsNWidgets(2));
      expect(find.text('History'), findsOneWidget);
      expect(find.text('Refills'), findsOneWidget);
      expect(find.text('Adherence'), findsOneWidget);

      // Action buttons
      expect(find.text('Cancel Invitation'), findsOneWidget);
      expect(find.text('Revoke Access'), findsOneWidget);
    });

    testWidgets('tapping cancel invitation shows confirmation dialog', (tester) async {
      final pendingInvite = CaregiverInvitation(
        id: 'cg-1',
        userId: 'patient-1',
        email: 'family@example.com',
        relationship: 'Sister',
        status: 'pending',
        createdAt: DateTime.now(),
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            caregiversProvider.overrideWith((ref) => [pendingInvite]),
          ],
          child: const MaterialApp(
            home: CaregiverManagementScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      await tester.tap(find.text('Cancel Invitation'));
      await tester.pumpAndSettle();

      expect(find.text('Cancel Invitation'), findsWidgets);
      expect(find.textContaining('Cancel the pending invitation to family@example.com?'), findsOneWidget);
      expect(find.text('Cancel'), findsOneWidget);
    });
  });

  group('Invite Caregiver Screen Widget Tests', () {
    testWidgets('renders all input fields, permission toggles, and send button', (tester) async {
      tester.view.physicalSize = const Size(800, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: InviteCaregiverScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Invite Caregiver'), findsOneWidget);
      expect(find.text('Invite by email'), findsOneWidget);
      expect(find.text('Email address'), findsOneWidget);
      expect(find.text('Relationship'), findsOneWidget);
      expect(find.text('Permissions'), findsOneWidget);

      expect(find.text('Daily schedule'), findsOneWidget);
      expect(find.text('Dose history'), findsOneWidget);
      expect(find.text('Adherence reports'), findsOneWidget);
      expect(find.text('Refill reminders'), findsOneWidget);

      expect(find.text('Send Invitation'), findsOneWidget);
    });

    testWidgets('submitting empty email shows error snackbar feedback', (tester) async {
      tester.view.physicalSize = const Size(800, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: InviteCaregiverScreen(),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Tap send invitation without entering email
      await tester.ensureVisible(find.text('Send Invitation'));
      await tester.tap(find.text('Send Invitation'));
      await tester.pumpAndSettle();

      expect(find.text('Please enter a caregiver email address.'), findsOneWidget);
    });

    testWidgets('submitting invalid email format shows error snackbar feedback', (tester) async {
      tester.view.physicalSize = const Size(800, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: InviteCaregiverScreen(),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Enter malformed email
      await tester.enterText(find.byType(TextFormField).first, 'not-an-email');
      await tester.ensureVisible(find.text('Send Invitation'));
      await tester.tap(find.text('Send Invitation'));
      await tester.pumpAndSettle();

      expect(find.text('Please enter a valid email address.'), findsOneWidget);
    });
  });
}
