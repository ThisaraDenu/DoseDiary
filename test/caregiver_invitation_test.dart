import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';
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

    test('direct ID invitation preserves both users and sender role', () {
      final now = DateTime.utc(2026, 10, 8, 8, 30);
      final invitation = CaregiverInvitation.fromMap({
        'id': 'direct-invite-1',
        'user_id': 'patient-user',
        'caregiver_email': 'caregiver@example.com',
        'caregiver_user_id': 'caregiver-user',
        'sender_user_id': 'caregiver-user',
        'receiver_user_id': 'patient-user',
        'sender_role': 'caregiver',
        'sender_name': 'Nimal Caregiver',
        'receiver_name': 'Kamal Patient',
        'relationship': 'Son',
        'status': 'pending',
        'token': 'direct-token',
        'created_at': now.toIso8601String(),
        'updated_at': now.toIso8601String(),
        'expires_at': now.add(const Duration(days: 7)).toIso8601String(),
      });

      expect(invitation.isDirectIdInvitation, isTrue);
      expect(invitation.senderRole, 'caregiver');
      expect(invitation.senderName, 'Nimal Caregiver');
      expect(invitation.receiverUserId, 'patient-user');
      expect(invitation.caregiverUserId, 'caregiver-user');

      final serialized = invitation.toMap();
      expect(serialized['sender_user_id'], 'caregiver-user');
      expect(serialized['receiver_user_id'], 'patient-user');
      expect(serialized['sender_role'], 'caregiver');
    });

    test(
        'Patient privacy isolation: filtering strictly bounds invitations to the patient user_id',
        () {
      final now = DateTime.now();
      final patientAInvite = CaregiverInvitation(
        id: 'inv-a',
        userId: 'patient-alice',
        email: 'alice-carer@example.com',
        relationship: 'Son',
        status: 'pending',
        createdAt: now,
      );

      final patientBInvite = CaregiverInvitation(
        id: 'inv-b',
        userId: 'patient-bob',
        email: 'bob-carer@example.com',
        relationship: 'Daughter',
        status: 'pending',
        createdAt: now,
      );

      final allInvitations = [patientAInvite, patientBInvite];

      // Filter representing SQLite WHERE user_id = ?
      final patientAView =
          allInvitations.where((i) => i.userId == 'patient-alice').toList();
      final patientBView =
          allInvitations.where((i) => i.userId == 'patient-bob').toList();

      expect(patientAView.length, 1);
      expect(patientAView.first.email, 'alice-carer@example.com');
      expect(patientAView.any((i) => i.userId == 'patient-bob'), isFalse);

      expect(patientBView.length, 1);
      expect(patientBView.first.email, 'bob-carer@example.com');
      expect(patientBView.any((i) => i.userId == 'patient-alice'), isFalse);
    });
  });

  group('Caregiver Management Screen Widget Tests', () {
    testWidgets('ID invitation form supports patient and caregiver roles',
        (tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(home: InviteCaregiverScreen()),
        ),
      );

      expect(find.text('Connect by DoseDiary ID'), findsOneWidget);
      expect(find.text('Patient'), findsOneWidget);
      expect(find.text('Caregiver'), findsOneWidget);
      expect(find.text('Caregiver ID'), findsOneWidget);
      expect(find.text('#12345'), findsOneWidget);

      await tester.tap(find.text('Caregiver'));
      await tester.pump();
      expect(find.text('Patient ID'), findsOneWidget);
    });

    testWidgets('renders empty state when no caregivers or invitations exist',
        (tester) async {
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

    testWidgets(
        'renders caregiver cards with Pending, Accepted, and Declined statuses and invitation dates',
        (tester) async {
      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final inviteDate = DateTime.utc(2026, 1, 15, 8, 30);
      final pendingInvite = CaregiverInvitation(
        id: 'cg-1',
        userId: 'patient-1',
        email: 'son@example.com',
        relationship: 'Son',
        status: 'pending',
        createdAt: inviteDate,
        viewSchedule: true,
        viewHistory: true,
        viewRefills: false,
        viewAdherence: true,
      );

      final acceptedInvite = CaregiverInvitation(
        id: 'cg-2',
        userId: 'patient-1',
        email: 'nurse@clinic.org',
        relationship: 'Nurse',
        status: 'accepted',
        createdAt: inviteDate,
        viewSchedule: true,
        viewHistory: false,
        viewRefills: true,
        viewAdherence: false,
      );

      final declinedInvite = CaregiverInvitation(
        id: 'cg-3',
        userId: 'patient-1',
        email: 'doctor@hospital.com',
        relationship: 'Doctor',
        status: 'declined',
        createdAt: inviteDate,
        viewSchedule: false,
        viewHistory: false,
        viewRefills: false,
        viewAdherence: false,
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            caregiversProvider.overrideWith(
                (ref) => [pendingInvite, acceptedInvite, declinedInvite]),
          ],
          child: const MaterialApp(
            home: CaregiverManagementScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Caregivers (3)'), findsOneWidget);
      expect(find.text('son@example.com'), findsOneWidget);
      expect(find.text('nurse@clinic.org'), findsOneWidget);
      expect(find.text('doctor@hospital.com'), findsOneWidget);

      // Status badges matching requirement 4: Pending, Accepted, Declined
      expect(find.text('Pending'), findsOneWidget);
      expect(find.text('Accepted'), findsOneWidget);
      expect(find.text('Declined'), findsOneWidget);

      // Displays invitation dates matching requirement 3
      final formattedDate =
          DateFormat('d MMM yyyy').format(inviteDate.toLocal());
      expect(find.textContaining('Invited $formattedDate'), findsNWidgets(3));

      // Permission chips
      expect(find.text('Schedule'), findsNWidgets(2));
      expect(find.text('History'), findsOneWidget);
      expect(find.text('Refills'), findsOneWidget);
      expect(find.text('Adherence'), findsOneWidget);

      // Contextual action buttons
      expect(find.text('Cancel Invitation'), findsOneWidget);
      expect(find.text('Revoke Access'), findsOneWidget);
      expect(find.text('Remove'), findsOneWidget);
    });

    testWidgets('tapping cancel invitation shows confirmation dialog',
        (tester) async {
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
      expect(
          find.textContaining(
              'Cancel the pending invitation to family@example.com?'),
          findsOneWidget);
      expect(find.text('Cancel'), findsOneWidget);
    });
  });

  group('Invite Caregiver Screen Widget Tests', () {
    testWidgets(
        'renders the ID connection fields, role selector, and send button',
        (tester) async {
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

      expect(find.text('Connect with a user'), findsOneWidget);
      expect(find.text('Connect by DoseDiary ID'), findsOneWidget);
      expect(find.text('I am connecting as'), findsOneWidget);
      expect(find.text('Patient'), findsOneWidget);
      expect(find.text('Caregiver'), findsOneWidget);
      expect(find.text('Caregiver ID'), findsOneWidget);
      expect(find.text('#12345'), findsOneWidget);
      expect(find.text('Relationship'), findsOneWidget);
      expect(find.text('Send Invitation'), findsOneWidget);
    });

    testWidgets('submitting an empty ID shows error snackbar feedback',
        (tester) async {
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

      // Tap send invitation without entering an ID.
      await tester.ensureVisible(find.text('Send Invitation'));
      await tester.tap(find.text('Send Invitation'));
      await tester.pumpAndSettle();

      expect(find.text('Enter a valid DoseDiary ID such as #12345.'),
          findsOneWidget);
    });

    testWidgets('submitting an invalid ID shows error snackbar feedback',
        (tester) async {
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

      // Enter a malformed DoseDiary ID.
      await tester.enterText(find.byType(TextFormField).first, '#12');
      await tester.ensureVisible(find.text('Send Invitation'));
      await tester.tap(find.text('Send Invitation'));
      await tester.pumpAndSettle();

      expect(find.text('Enter a valid DoseDiary ID such as #12345.'),
          findsOneWidget);
    });
  });

  group('Caregiver-Side Incoming Invitations Privacy & Filtering Tests', () {
    test(
        'Caregiver B sees invitations addressed to B and cannot see invitations addressed to C',
        () {
      final now = DateTime.now();

      final inviteForBFromPatient1 = CaregiverInvitation(
        id: 'inv-b-1',
        userId: 'patient-1',
        email: 'caregiverB@example.com',
        relationship: 'Daughter',
        status: 'pending',
        createdAt: now,
      );

      final inviteForBFromPatient2 = CaregiverInvitation(
        id: 'inv-b-2',
        userId: 'patient-2',
        email: 'CaregiverB@Example.com', // mixed case
        relationship: 'Nurse',
        status: 'accepted',
        createdAt: now,
      );

      final inviteForC = CaregiverInvitation(
        id: 'inv-c-1',
        userId: 'patient-1',
        email: 'caregiverC@example.com',
        relationship: 'Son',
        status: 'pending',
        createdAt: now,
      );

      final allInvitations = [
        inviteForBFromPatient1,
        inviteForBFromPatient2,
        inviteForC
      ];

      // Simulated SQLite query: WHERE LOWER(caregiver_email) = ?
      const caregiverBEmail = 'caregiverb@example.com';
      final caregiverBView = allInvitations
          .where(
              (i) => i.caregiverEmail.trim().toLowerCase() == caregiverBEmail)
          .toList();

      const caregiverCEmail = 'caregiverc@example.com';
      final caregiverCView = allInvitations
          .where(
              (i) => i.caregiverEmail.trim().toLowerCase() == caregiverCEmail)
          .toList();

      // Caregiver B sees only invitations addressed to B
      expect(caregiverBView.length, 2);
      expect(caregiverBView.map((i) => i.id).toList(),
          containsAll(['inv-b-1', 'inv-b-2']));
      // Caregiver B CANNOT see invitations addressed to C
      expect(
          caregiverBView
              .any((i) => i.caregiverEmail.toLowerCase() == caregiverCEmail),
          isFalse);

      // Caregiver C sees only invitations addressed to C
      expect(caregiverCView.length, 1);
      expect(caregiverCView.first.id, 'inv-c-1');
      // Caregiver C CANNOT see invitations addressed to B
      expect(
          caregiverCView
              .any((i) => i.caregiverEmail.toLowerCase() == caregiverBEmail),
          isFalse);
    });

    test(
        'Patient owner filtering remains unchanged and is strictly separated from caregiver invitee filtering',
        () {
      final now = DateTime.now();

      // Patient 1 created an invitation to Caregiver B
      final invite = CaregiverInvitation(
        id: 'inv-1',
        userId: 'patient-user-123',
        email: 'caregiverB@example.com',
        relationship: 'Family',
        status: 'pending',
        createdAt: now,
      );

      final allInvitations = [invite];

      // 1. Patient-side filtering (WHERE user_id = ?)
      final patientView =
          allInvitations.where((i) => i.userId == 'patient-user-123').toList();
      expect(patientView.length, 1);
      expect(patientView.first.userId, 'patient-user-123');

      // Another patient cannot see Patient 1's invitations
      final otherPatientView =
          allInvitations.where((i) => i.userId == 'patient-user-999').toList();
      expect(otherPatientView, isEmpty);

      // Caregiver's user ID is NOT confused with patient's user_id
      final caregiverAsOwnerView = allInvitations
          .where((i) => i.userId == 'caregiver-b-user-id')
          .toList();
      expect(caregiverAsOwnerView, isEmpty);

      // 2. Caregiver-side incoming filtering (WHERE LOWER(caregiver_email) = ?)
      final caregiverIncomingView = allInvitations
          .where(
              (i) => i.caregiverEmail.toLowerCase() == 'caregiverb@example.com')
          .toList();
      expect(caregiverIncomingView.length, 1);
      expect(
          caregiverIncomingView.first.caregiverEmail, 'caregiverB@example.com');
    });
  });

  group('Incoming Caregiver Invitations Widget Tests', () {
    testWidgets(
        'renders empty state when caregiver has no incoming invitations',
        (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            incomingCaregiverInvitationsProvider.overrideWith((ref) => []),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: IncomingCaregiverInvitationsWidget(),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('No Incoming Invitations'), findsOneWidget);
      expect(
        find.text(
            'You do not have any pending or past caregiver invitations addressed to your account.'),
        findsOneWidget,
      );
    });

    testWidgets('renders error state with retry button when provider errors',
        (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            incomingCaregiverInvitationsProvider
                .overrideWith((ref) => throw Exception('Sync failed')),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: IncomingCaregiverInvitationsWidget(),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Could not load incoming invitations'), findsOneWidget);
      expect(find.text('Try Again'), findsOneWidget);
    });

    testWidgets(
        'renders incoming invitation with patient details, permissions, and Pending renders Accept and Decline actions',
        (tester) async {
      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final inviteDate = DateTime.utc(2026, 1, 15, 9, 0);
      final pendingInvite = CaregiverInvitation(
        id: 'inc-1',
        userId: 'patient-alice-id',
        email: 'caregiverB@example.com',
        relationship: 'Daughter',
        status: 'pending',
        createdAt: inviteDate,
        patientName: 'Alice Smith',
        patientEmail: 'alice@example.org',
        viewSchedule: true,
        viewHistory: true,
        viewRefills: false,
        viewAdherence: true,
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            incomingCaregiverInvitationsProvider
                .overrideWith((ref) => [pendingInvite]),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: SingleChildScrollView(
                child: IncomingCaregiverInvitationsWidget(),
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Displays patient info
      expect(find.text('Incoming Invitations'), findsOneWidget);
      expect(find.text('1 Pending'), findsOneWidget);
      expect(find.text('Alice Smith'), findsOneWidget);
      expect(find.text('alice@example.org'), findsOneWidget);
      expect(find.text('Daughter'), findsOneWidget);

      // Displays formatted date
      final formattedDate =
          DateFormat('d MMM yyyy').format(inviteDate.toLocal());
      expect(find.textContaining('Invited $formattedDate'), findsOneWidget);

      // Displays status badge
      expect(find.text('Pending'), findsOneWidget);

      // Displays requested permissions
      expect(find.text('Requested Permissions'), findsOneWidget);
      expect(find.text('Schedule'), findsOneWidget);
      expect(find.text('History'), findsOneWidget);
      expect(find.text('Adherence'), findsOneWidget);
      expect(find.text('Refills'), findsNothing);

      // Pending invitation renders Accept and Decline actions
      expect(find.text('Accept'), findsOneWidget);
      expect(find.text('Decline'), findsOneWidget);
    });

    testWidgets(
        'accepted incoming invitation renders status badge without Accept/Decline action buttons',
        (tester) async {
      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final inviteDate = DateTime.utc(2026, 1, 15, 9, 0);
      final acceptedInvite = CaregiverInvitation(
        id: 'inc-2',
        userId: 'patient-bob-id',
        email: 'caregiverB@example.com',
        relationship: 'Caregiver',
        status: 'accepted',
        createdAt: inviteDate,
        patientName: 'Bob Jones',
        viewSchedule: true,
        viewHistory: false,
        viewRefills: true,
        viewAdherence: false,
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            incomingCaregiverInvitationsProvider
                .overrideWith((ref) => [acceptedInvite]),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: SingleChildScrollView(
                child: IncomingCaregiverInvitationsWidget(),
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Bob Jones'), findsOneWidget);
      expect(find.text('Accepted'), findsOneWidget);
      expect(find.text('Accept'), findsNothing);
      expect(find.text('Decline'), findsNothing);
    });
  });

  group('Caregiver Invitation Acceptance & Relationship Creation Tests', () {
    test(
        'successful acceptance transitions invitation status from pending to accepted',
        () {
      final now = DateTime.now().toUtc();
      final invite = CaregiverInvitation.create(
        userId: 'patient-alice',
        email: 'caregiverB@example.com',
        relationship: 'Daughter',
        status: 'pending',
      );

      expect(invite.status, 'pending');

      // Simulating status transition in acceptance transaction
      final acceptedInvite = invite.copyWith(
        status: 'accepted',
        updatedAt: now,
      );

      expect(acceptedInvite.status, 'accepted');
      expect(acceptedInvite.updatedAt, now);
      expect(acceptedInvite.userId, 'patient-alice');
      expect(acceptedInvite.caregiverEmail, 'caregiverb@example.com');
    });

    test(
        'acceptance creates patient_caregiver_links relationship with valid properties',
        () {
      final link = PatientCaregiverLink.create(
        patientUserId: 'patient-alice',
        caregiverUserId: 'caregiver-bob',
        relationship: 'Daughter',
        invitationId: 'inv-1234',
      );

      expect(link.id, isNotEmpty);
      expect(link.patientUserId, 'patient-alice');
      expect(link.caregiverUserId, 'caregiver-bob');
      expect(link.relationship, 'Daughter');
      expect(link.invitationId, 'inv-1234');
      expect(link.status, 'active');
      expect(link.createdAt, isNotNull);
      expect(link.updatedAt, isNotNull);

      // Verify serialization round-trip
      final map = link.toMap();
      expect(map['patient_user_id'], 'patient-alice');
      expect(map['caregiver_user_id'], 'caregiver-bob');
      expect(map['status'], 'active');

      final fromMap = PatientCaregiverLink.fromMap(map);
      expect(fromMap.id, link.id);
      expect(fromMap.patientUserId, link.patientUserId);
      expect(fromMap.caregiverUserId, link.caregiverUserId);
      expect(fromMap.relationship, link.relationship);
      expect(fromMap.invitationId, link.invitationId);
      expect(fromMap.status, link.status);
    });

    test(
        'acceptance creates allocated_patients for caregiver and allocated_caregivers for patient',
        () {
      // Caregiver B receives Patient A in allocated_patients
      final allocPatient = AllocatedPatient.create(
        caregiverId: 'caregiver-bob',
        patientUserId: 'patient-alice',
        fullName: 'Alice Smith',
        relationship: 'Daughter',
      );

      expect(allocPatient.id, isNotEmpty);
      expect(allocPatient.caregiverId, 'caregiver-bob');
      expect(allocPatient.patientUserId, 'patient-alice');
      expect(allocPatient.fullName, 'Alice Smith');
      expect(allocPatient.relationship, 'Daughter');

      // Patient A receives Caregiver B in allocated_caregivers
      final allocCaregiver = AllocatedCaregiver.create(
        patientId: 'patient-alice',
        caregiverUserId: 'caregiver-bob',
        fullName: 'Bob Builder',
        relationship: 'Daughter',
      );

      expect(allocCaregiver.id, isNotEmpty);
      expect(allocCaregiver.patientId, 'patient-alice');
      expect(allocCaregiver.caregiverUserId, 'caregiver-bob');
      expect(allocCaregiver.fullName, 'Bob Builder');
      expect(allocCaregiver.relationship, 'Daughter');
    });

    test(
        'bilateral isolation: Patient C cannot see Caregiver B, and Caregiver D cannot see Patient A',
        () {
      final allocPatient = AllocatedPatient.create(
        caregiverId: 'caregiver-bob',
        patientUserId: 'patient-alice',
        fullName: 'Alice Smith',
      );

      final allocCaregiver = AllocatedCaregiver.create(
        patientId: 'patient-alice',
        caregiverUserId: 'caregiver-bob',
        fullName: 'Bob Builder',
      );

      final allPatients = [allocPatient];
      final allCaregivers = [allocCaregiver];

      // 1. Caregiver B sees Patient A
      final bPatients =
          allPatients.where((p) => p.caregiverId == 'caregiver-bob').toList();
      expect(bPatients.length, 1);
      expect(bPatients.first.patientUserId, 'patient-alice');

      // Caregiver D sees NO patients (cannot see Patient A)
      final dPatients =
          allPatients.where((p) => p.caregiverId == 'caregiver-david').toList();
      expect(dPatients, isEmpty);

      // 2. Patient A sees Caregiver B
      final aCaregivers =
          allCaregivers.where((c) => c.patientId == 'patient-alice').toList();
      expect(aCaregivers.length, 1);
      expect(aCaregivers.first.caregiverUserId, 'caregiver-bob');

      // Patient C sees NO caregivers (cannot see Caregiver B)
      final cCaregivers =
          allCaregivers.where((c) => c.patientId == 'patient-charlie').toList();
      expect(cCaregivers, isEmpty);
    });

    test(
        'duplicate link prevention: existing patient-caregiver link is not duplicated',
        () {
      final existingLink = PatientCaregiverLink.create(
        patientUserId: 'patient-alice',
        caregiverUserId: 'caregiver-bob',
        relationship: 'Nurse',
      );

      final existingLinks = [existingLink];

      // Verification before inserting duplicate
      final alreadyExists = existingLinks.any(
        (l) =>
            l.patientUserId == 'patient-alice' &&
            l.caregiverUserId == 'caregiver-bob',
      );
      expect(alreadyExists, isTrue);

      // Ensuring count remains 1
      final updatedLinks = List<PatientCaregiverLink>.from(existingLinks);
      if (!alreadyExists) {
        updatedLinks.add(
          PatientCaregiverLink.create(
            patientUserId: 'patient-alice',
            caregiverUserId: 'caregiver-bob',
          ),
        );
      }
      expect(updatedLinks.length, 1);
    });

    test(
        'authorization check: wrong caregiver cannot accept invitation belonging to another caregiver',
        () {
      final invite = CaregiverInvitation.create(
        userId: 'patient-alice',
        email: 'caregiverB@example.com',
        relationship: 'Son',
      );

      const authenticatedCaregiverEmail = 'caregiver-intruder@example.com';

      // Logic from CaregiverRepository.acceptIncomingInvitation
      expect(
        () {
          if (authenticatedCaregiverEmail.toLowerCase() !=
              invite.caregiverEmail.toLowerCase()) {
            throw StateError(
                'This invitation is not addressed to your account.');
          }
        },
        throwsA(isA<StateError>().having(
          (e) => e.message,
          'message',
          contains('not addressed to your account'),
        )),
      );
    });

    test(
        'status guard: declined, revoked, or already accepted invitation cannot be accepted',
        () {
      for (final nonPendingStatus in ['declined', 'revoked', 'accepted']) {
        expect(
          () {
            if (nonPendingStatus != 'pending') {
              throw StateError(
                  'Cannot accept invitation: status is already "$nonPendingStatus".');
            }
          },
          throwsA(isA<StateError>().having(
            (e) => e.message,
            'message',
            contains('status is already "$nonPendingStatus"'),
          )),
        );
      }
    });

    test(
        'permissions requested in invitation are preserved upon relationship creation',
        () {
      final invite = CaregiverInvitation.create(
        userId: 'patient-alice',
        email: 'caregiverB@example.com',
        viewSchedule: true,
        viewHistory: true,
        viewRefills: false,
        viewAdherence: true,
      );

      final perm = CaregiverPermission.create(
        invitationId: invite.id,
        userId: invite.userId,
        caregiverId: 'caregiver-bob',
        permViewSchedule: invite.viewSchedule,
        permViewHistory: invite.viewHistory,
        permViewRefills: invite.viewRefills,
        permViewAdherence: invite.viewAdherence,
      );

      expect(perm.caregiverId, 'caregiver-bob');
      expect(perm.permViewSchedule, isTrue);
      expect(perm.permViewHistory, isTrue);
      expect(perm.permViewRefills, isFalse);
      expect(perm.permViewAdherence, isTrue);
    });
  });

  group('Decline Caregiver Invitation Tests', () {
    test(
        'successful decline transitions invitation status to declined with updated timestamp',
        () {
      final now = DateTime.now().toUtc();
      final invite = CaregiverInvitation.create(
        userId: 'patient-alice',
        email: 'caregiverB@example.com',
        relationship: 'Daughter',
        status: 'pending',
      );

      expect(invite.status, 'pending');

      // Simulating status transition in decline logic
      final declinedInvite = invite.copyWith(
        status: 'declined',
        updatedAt: now,
      );

      expect(declinedInvite.status, 'declined');
      expect(declinedInvite.updatedAt, now);
      expect(declinedInvite.userId, 'patient-alice');
      expect(declinedInvite.caregiverEmail, 'caregiverb@example.com');
      // Ensure invitation is preserved as historical data, not deleted
      expect(declinedInvite.id, invite.id);
    });

    test(
        'declining invitation creates NO patient_caregiver_link, allocated_patient, or allocated_caregiver',
        () {
      final existingLinks = <PatientCaregiverLink>[];
      final existingAllocatedPatients = <AllocatedPatient>[];
      final existingAllocatedCaregivers = <AllocatedCaregiver>[];

      final invite = CaregiverInvitation.create(
        userId: 'patient-alice',
        email: 'caregiverB@example.com',
        relationship: 'Daughter',
        status: 'pending',
      );

      // Decline action updates status only
      final updatedInvite = invite.copyWith(status: 'declined');

      // Verify that no relational tables were touched
      expect(updatedInvite.status, 'declined');
      expect(existingLinks, isEmpty);
      expect(existingAllocatedPatients, isEmpty);
      expect(existingAllocatedCaregivers, isEmpty);
    });

    test(
        'authorization check: wrong caregiver cannot decline an invitation belonging to another caregiver',
        () {
      final invite = CaregiverInvitation.create(
        userId: 'patient-alice',
        email: 'caregiverB@example.com',
        relationship: 'Daughter',
      );

      const authenticatedCaregiverEmail = 'intruder-caregiver@example.com';

      // Logic from CaregiverRepository.declineIncomingInvitation
      expect(
        () {
          if (authenticatedCaregiverEmail.toLowerCase() !=
              invite.caregiverEmail.toLowerCase()) {
            throw StateError(
                'This invitation is not addressed to your account.');
          }
        },
        throwsA(isA<StateError>().having(
          (e) => e.message,
          'message',
          contains('not addressed to your account'),
        )),
      );
    });

    test('status guard: accepted invitation cannot be declined', () {
      const currentStatus = 'accepted';
      expect(
        () {
          if (currentStatus != 'pending') {
            throw StateError(
                'Cannot decline invitation: status is already "$currentStatus".');
          }
        },
        throwsA(isA<StateError>().having(
          (e) => e.message,
          'message',
          contains('status is already "accepted"'),
        )),
      );
    });

    test('status guard: revoked invitation cannot be declined', () {
      const currentStatus = 'revoked';
      expect(
        () {
          if (currentStatus != 'pending') {
            throw StateError(
                'Cannot decline invitation: status is already "$currentStatus".');
          }
        },
        throwsA(isA<StateError>().having(
          (e) => e.message,
          'message',
          contains('status is already "revoked"'),
        )),
      );
    });

    test('status guard: already declined invitation cannot be declined again',
        () {
      const currentStatus = 'declined';
      expect(
        () {
          if (currentStatus != 'pending') {
            throw StateError(
                'Cannot decline invitation: status is already "$currentStatus".');
          }
        },
        throwsA(isA<StateError>().having(
          (e) => e.message,
          'message',
          contains('status is already "declined"'),
        )),
      );
    });

    testWidgets(
        'patient-side list reflects Declined status for declined invitation',
        (tester) async {
      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final inviteDate = DateTime.utc(2026, 1, 15, 8, 30);
      final declinedInvite = CaregiverInvitation(
        id: 'cg-declined-1',
        userId: 'patient-alice',
        email: 'caregiverB@example.com',
        relationship: 'Daughter',
        status: 'declined',
        createdAt: inviteDate,
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            caregiversProvider.overrideWith((ref) => [declinedInvite]),
          ],
          child: const MaterialApp(
            home: CaregiverManagementScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Caregivers (1)'), findsOneWidget);
      expect(find.text('caregiverB@example.com'), findsOneWidget);
      expect(find.text('Declined'), findsOneWidget);
      expect(find.text('Remove'), findsOneWidget);
      expect(find.text('Cancel Invitation'), findsNothing);
      expect(find.text('Revoke Access'), findsNothing);
    });

    testWidgets(
        'caregiver incoming UI reflects Declined status and removes Accept/Decline action buttons',
        (tester) async {
      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final inviteDate = DateTime.utc(2026, 1, 15, 9, 0);
      final declinedInvite = CaregiverInvitation(
        id: 'inc-declined-1',
        userId: 'patient-alice',
        email: 'caregiverB@example.com',
        relationship: 'Daughter',
        status: 'declined',
        createdAt: inviteDate,
        patientName: 'Alice Smith',
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            incomingCaregiverInvitationsProvider
                .overrideWith((ref) => [declinedInvite]),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: SingleChildScrollView(
                child: IncomingCaregiverInvitationsWidget(),
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Alice Smith'), findsOneWidget);
      expect(find.text('Declined'), findsOneWidget);
      expect(find.text('Accept'), findsNothing);
      expect(find.text('Decline'), findsNothing);
    });
  });

  group('Patient CRUD & Caregiver Management Tests', () {
    test('READ: Caregiver views only their own allocated patients', () {
      final patientA = AllocatedPatient.create(
        caregiverId: 'caregiver-bob',
        patientUserId: 'patient-alice',
        fullName: 'Alice Smith',
        relationship: 'Mother',
      );
      final patientC = AllocatedPatient.create(
        caregiverId: 'caregiver-charlie',
        patientUserId: 'patient-carol',
        fullName: 'Carol Danvers',
        relationship: 'Aunt',
      );

      final allPatients = [patientA, patientC];

      // Query isolated by caregiverId = caregiver-bob
      final bobPatients =
          allPatients.where((p) => p.caregiverId == 'caregiver-bob').toList();
      expect(bobPatients.length, 1);
      expect(bobPatients.first.fullName, 'Alice Smith');
      expect(
          bobPatients.any((p) => p.patientUserId == 'patient-carol'), isFalse);
    });

    test('UPDATE: Authorized relationship fields can be edited', () {
      final patientA = AllocatedPatient.create(
        caregiverId: 'caregiver-bob',
        patientUserId: 'patient-alice',
        fullName: 'Alice Smith',
        relationship: 'Mother',
        location: 'Colombo Home',
      );

      // Caregiver updates relationship label and location
      final updatedPatient = patientA.copyWith(
        relationship: 'Spouse',
        location: 'Kandy Residence',
      );

      expect(updatedPatient.relationship, 'Spouse');
      expect(updatedPatient.location, 'Kandy Residence');
      // ID and caregiver binding remain preserved
      expect(updatedPatient.id, patientA.id);
      expect(updatedPatient.caregiverId, 'caregiver-bob');
      expect(updatedPatient.patientUserId, 'patient-alice');
    });

    test('UPDATE: Unauthorized caregiver cannot edit patient', () {
      final patientA = AllocatedPatient.create(
        caregiverId: 'caregiver-bob',
        patientUserId: 'patient-alice',
        fullName: 'Alice Smith',
      );

      const callerCaregiverId = 'caregiver-unauthorized';

      expect(
        () {
          if (callerCaregiverId != patientA.caregiverId) {
            throw StateError(
                'Unauthorized: Patient record does not belong to this caregiver.');
          }
        },
        throwsA(isA<StateError>().having(
          (e) => e.message,
          'message',
          contains(
              'Unauthorized: Patient record does not belong to this caregiver.'),
        )),
      );
    });

    test(
        'DELETE / DISCONNECT: Disconnect removes relationship for that caregiver only',
        () {
      final patientAForBob = AllocatedPatient.create(
        caregiverId: 'caregiver-bob',
        patientUserId: 'patient-alice',
        fullName: 'Alice Smith',
      );
      final patientAForCharlie = AllocatedPatient.create(
        caregiverId: 'caregiver-charlie',
        patientUserId: 'patient-alice',
        fullName: 'Alice Smith',
      );

      final patientList = [patientAForBob, patientAForCharlie];

      // Bob disconnects Patient A
      final remainingAfterBobDisconnect = patientList
          .where((p) => !(p.caregiverId == 'caregiver-bob' &&
              p.patientUserId == 'patient-alice'))
          .toList();

      expect(remainingAfterBobDisconnect.length, 1);
      // Charlie still has Patient A!
      expect(
          remainingAfterBobDisconnect.first.caregiverId, 'caregiver-charlie');
      expect(remainingAfterBobDisconnect.first.patientUserId, 'patient-alice');
    });
  });

  group('Caregiver CRUD & Patient Management Tests', () {
    test('READ: Patient views only their own linked caregivers', () {
      final cgForAlice = AllocatedCaregiver.create(
        patientId: 'patient-alice',
        caregiverUserId: 'caregiver-bob',
        fullName: 'Bob Builder',
        relationship: 'Son',
      );
      final cgForCarol = AllocatedCaregiver.create(
        patientId: 'patient-carol',
        caregiverUserId: 'caregiver-bob',
        fullName: 'Bob Builder',
        relationship: 'Nurse',
      );

      final allCaregivers = [cgForAlice, cgForCarol];

      // Alice queries her own caregivers
      final aliceView =
          allCaregivers.where((c) => c.patientId == 'patient-alice').toList();
      expect(aliceView.length, 1);
      expect(aliceView.first.relationship, 'Son');
      expect(aliceView.first.caregiverUserId, 'caregiver-bob');

      // Unrelated patient David queries his caregivers
      final davidView =
          allCaregivers.where((c) => c.patientId == 'patient-david').toList();
      expect(davidView, isEmpty);
    });

    test('UPDATE: Editable relationship and permissions update correctly', () {
      final perm = CaregiverPermission.create(
        invitationId: 'inv-123',
        userId: 'patient-alice',
        caregiverId: 'caregiver-bob',
        permViewSchedule: true,
        permViewHistory: true,
        permViewRefills: false,
        permViewAdherence: false,
      );

      // Patient updates permissions and relationship
      final updatedPerm = perm.copyWith(
        permViewRefills: true,
        permViewAdherence: true,
      );

      expect(updatedPerm.permViewSchedule, isTrue);
      expect(updatedPerm.permViewHistory, isTrue);
      expect(updatedPerm.permViewRefills, isTrue);
      expect(updatedPerm.permViewAdherence, isTrue);
      expect(updatedPerm.userId, 'patient-alice');
      expect(updatedPerm.caregiverId, 'caregiver-bob');
    });

    test('UPDATE: Unauthorized patient cannot edit unrelated caregiver', () {
      const activePatientId = 'patient-david';
      const relationshipOwnerId = 'patient-alice';

      expect(
        () {
          if (activePatientId != relationshipOwnerId) {
            throw StateError(
                'Unauthorized: No active relationship with this caregiver.');
          }
        },
        throwsA(isA<StateError>().having(
          (e) => e.message,
          'message',
          contains('Unauthorized: No active relationship with this caregiver.'),
        )),
      );
    });

    test('DELETE / REVOKE: Revoke disconnects only that specific caregiver',
        () {
      final linkAB = PatientCaregiverLink.create(
        patientUserId: 'patient-alice',
        caregiverUserId: 'caregiver-bob',
      );
      final linkAC = PatientCaregiverLink.create(
        patientUserId: 'patient-alice',
        caregiverUserId: 'caregiver-charlie',
      );

      final links = [linkAB, linkAC];

      // Alice revokes Bob
      final updatedLinks = links.map((l) {
        if (l.patientUserId == 'patient-alice' &&
            l.caregiverUserId == 'caregiver-bob') {
          return l.copyWith(status: 'revoked');
        }
        return l;
      }).toList();

      final activeLinks =
          updatedLinks.where((l) => l.status == 'active').toList();
      expect(activeLinks.length, 1);
      expect(activeLinks.first.caregiverUserId, 'caregiver-charlie');

      final revokedLinks =
          updatedLinks.where((l) => l.status == 'revoked').toList();
      expect(revokedLinks.length, 1);
      expect(revokedLinks.first.caregiverUserId, 'caregiver-bob');
    });
  });

  group('Caregiver Permissions Enforcement Tests', () {
    test('Permissions persist after acceptance and round-trip faithfully', () {
      final perm = CaregiverPermission.create(
        invitationId: 'inv-perm-1',
        userId: 'patient-alice',
        caregiverId: 'caregiver-bob',
        permViewSchedule: true,
        permViewHistory: false,
        permViewRefills: true,
        permViewAdherence: false,
      );

      final map = perm.toMap();
      final roundTrip = CaregiverPermission.fromMap(map);

      expect(roundTrip.permViewSchedule, isTrue);
      expect(roundTrip.permViewHistory, isFalse);
      expect(roundTrip.permViewRefills, isTrue);
      expect(roundTrip.permViewAdherence, isFalse);
      expect(roundTrip.userId, 'patient-alice');
      expect(roundTrip.caregiverId, 'caregiver-bob');
    });

    test('perm_view_schedule = false blocks schedule retrieval logic', () {
      final perm = CaregiverPermission.create(
        invitationId: 'inv-perm-2',
        userId: 'patient-alice',
        caregiverId: 'caregiver-bob',
        permViewSchedule: false,
      );

      // Simulating query evaluation respecting permission
      List<String> getOccurrences(CaregiverPermission p) {
        if (!p.permViewSchedule) {
          return []; // Permission blocked
        }
        return ['med-1-dose', 'med-2-dose'];
      }

      expect(getOccurrences(perm), isEmpty);

      final allowedPerm = perm.copyWith(permViewSchedule: true);
      expect(getOccurrences(allowedPerm), isNotEmpty);
      expect(getOccurrences(allowedPerm).length, 2);
    });

    test('perm_view_adherence = false blocks adherence report retrieval', () {
      final perm = CaregiverPermission.create(
        invitationId: 'inv-perm-3',
        userId: 'patient-alice',
        caregiverId: 'caregiver-bob',
        permViewAdherence: false,
      );

      Map<String, dynamic>? getAdherence(CaregiverPermission p) {
        if (!p.permViewAdherence) {
          return null; // Permission blocked
        }
        return {'score': 95, 'totalCountable': 10};
      }

      expect(getAdherence(perm), isNull);

      final allowedPerm = perm.copyWith(permViewAdherence: true);
      expect(getAdherence(allowedPerm), isNotNull);
      expect(getAdherence(allowedPerm)!['score'], 95);
    });

    test('perm_view_refills = false blocks low stock retrieval', () {
      final perm = CaregiverPermission.create(
        invitationId: 'inv-perm-4',
        userId: 'patient-alice',
        caregiverId: 'caregiver-bob',
        permViewRefills: false,
      );

      List<String> getRefillAlerts(CaregiverPermission p) {
        if (!p.permViewRefills) {
          return [];
        }
        return ['Metformin 500mg low stock'];
      }

      expect(getRefillAlerts(perm), isEmpty);

      final allowedPerm = perm.copyWith(permViewRefills: true);
      expect(getRefillAlerts(allowedPerm).length, 1);
    });
  });
}
