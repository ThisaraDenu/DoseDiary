import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';
import 'package:dose_diary/data/local/models/app_models.dart';
import 'package:dose_diary/data/local/models/dose_status.dart';
import 'package:dose_diary/features/home/home_dashboard_screen.dart';

void main() {
  group('HomeDashboardScreen Widget Tests', () {
    testWidgets(
        'renders clean empty states with zero mock data when database has no records',
        (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            todayOccurrencesProvider.overrideWith((ref) => []),
            todayMedicationsProvider.overrideWith((ref) => []),
            todayAdherenceProvider.overrideWith((ref) =>
                const AdherenceSummary(taken: 0, total: 0, countable: 0)),
            lowStockProvider.overrideWith((ref) => []),
            caregiversProvider.overrideWith((ref) => []),
            patientCaregiversListProvider
                .overrideWith((ref) => Future.value([])),
          ],
          child: const MaterialApp(
            home: HomeDashboardScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Header: has medical services icon and notification button
      expect(find.text('Home'), findsOneWidget);
      expect(find.byIcon(Icons.medical_services_rounded), findsOneWidget);
      expect(find.byIcon(Icons.notifications_none_rounded), findsOneWidget);

      // Current Date pill
      final expectedDateStr =
          DateFormat('EEEE, d MMMM yyyy').format(DateTime.now());
      expect(find.text(expectedDateStr), findsOneWidget);

      // Greeting
      expect(find.textContaining('Ishara!'), findsOneWidget);

      // Active View Switcher
      expect(find.text('ACTIVE VIEW'), findsOneWidget);
      expect(find.text('Patient Mode'), findsOneWidget);
      expect(find.text('Caregiver Mode'), findsOneWidget);

      // Next Medication Card: should show empty state, NOT mock "Amoxicillin"
      expect(find.text('No Medications Added Yet'), findsOneWidget);
      expect(find.text('Add Your First Medication'), findsOneWidget);
      expect(find.text('NEXT MEDICATION'), findsNothing);
      expect(find.text('Amoxicillin'), findsNothing);

      // Today's schedule: should show empty state, NOT mock "Vitamin D" or "Aspirin"
      expect(find.text("Today's Schedule"), findsOneWidget);
      expect(find.text('No medications scheduled for today'), findsOneWidget);
      expect(find.text('Vitamin D'), findsNothing);
      expect(find.text('Aspirin'), findsNothing);

      // Stats Grid: Adherence and Refills reflect empty data
      expect(find.text('Adherence'), findsOneWidget);
      expect(find.text('No data'), findsOneWidget);
      expect(find.text('No doses today'), findsOneWidget);
      expect(find.text('Refills'), findsOneWidget);
      expect(find.text('0 Low'), findsOneWidget);
      expect(find.text('All supplies in stock'), findsOneWidget);

      // Caregiver card: shows clean unlinked state, NOT mock "Nimal Perera (Son)"
      expect(find.text('No Caregivers Added'), findsOneWidget);
      expect(find.text('Nimal Perera (Son)'), findsNothing);
    });

    testWidgets(
        'renders real data when medications, occurrences, and caregivers exist in database',
        (tester) async {
      final now = DateTime.now();
      final localDate = DateFormat('yyyy-MM-dd').format(now);

      final med1 = Medication(
        id: 'med-1',
        userId: 'user-1',
        name: 'Metformin',
        strength: 500,
        strengthUnit: 'mg',
        amountPerDose: 1,
        doseUnit: 'tablet(s)',
        instructions: 'Take with food',
        imageUrl:
            'data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk+A8AAQUBAScY42YAAAAASUVORK5CYII=',
        isActive: true,
        quantityOnHand: 2,
        quantityUnit: 'tablet(s)',
        refillThresholdQty: 5,
        createdAt: now,
        updatedAt: now,
      );

      final med2 = Medication(
        id: 'med-2',
        userId: 'user-1',
        name: 'Lisinopril',
        strength: 10,
        strengthUnit: 'mg',
        amountPerDose: 1,
        doseUnit: 'tablet(s)',
        instructions: 'Take in the morning',
        isActive: true,
        quantityOnHand: 30,
        quantityUnit: 'tablet(s)',
        createdAt: now,
        updatedAt: now,
      );

      final occ1 = DoseOccurrence(
        id: 'occ-1',
        scheduleId: 'sched-1',
        medicationId: 'med-1',
        userId: 'user-1',
        scheduledAt: now.add(const Duration(minutes: 30)),
        localDate: localDate,
        occurrenceKey: 'sched-1-$localDate-1200',
        status: DoseStatus.pending,
        createdAt: now,
      );

      final occ2 = DoseOccurrence(
        id: 'occ-2',
        scheduleId: 'sched-2',
        medicationId: 'med-2',
        userId: 'user-1',
        scheduledAt: now.subtract(const Duration(hours: 2)),
        localDate: localDate,
        occurrenceKey: 'sched-2-$localDate-0800',
        status: DoseStatus.taken,
        createdAt: now,
      );

      final caregiver = AllocatedCaregiver(
        id: 'cg-1',
        patientId: 'user-1',
        fullName: 'Nimal Perera',
        relationship: 'Son',
        location: 'Colombo Home',
        phoneBattery: 85,
        batteryStatus: 'Balanced',
        smartHubStatus: 'Synced 2m ago',
        phoneNumber: '+94 77 123 4567',
        email: 'nimal@example.com',
        lastActive: 'Active 5m ago',
        createdAt: now,
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            todayOccurrencesProvider.overrideWith((ref) => [occ1, occ2]),
            todayMedicationsProvider.overrideWith((ref) => [med1, med2]),
            todayAdherenceProvider.overrideWith((ref) =>
                const AdherenceSummary(taken: 1, total: 2, countable: 2)),
            lowStockProvider.overrideWith((ref) => [med1]),
            caregiversProvider.overrideWith((ref) => []),
            patientCaregiversListProvider
                .overrideWith((ref) => Future.value([caregiver])),
          ],
          child: const MaterialApp(
            home: HomeDashboardScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Next Medication Card: Displays real Metformin card
      expect(find.text('NEXT MEDICATION'), findsOneWidget);
      expect(find.text('Metformin'), findsWidgets);
      expect(find.textContaining('500 mg'), findsWidgets);
      expect(find.textContaining('1 tablet(s)'), findsWidgets);
      expect(find.text('Take with food'), findsOneWidget);
      expect(
        find.byKey(const ValueKey('next-medication-image')),
        findsOneWidget,
      );
      expect(find.text('Log Dose'), findsNothing);

      // Today's schedule: only active upcoming/snoozed doses remain visible.
      expect(find.text("Today's Schedule"), findsOneWidget);
      expect(find.text('Metformin'), findsWidgets);
      expect(find.text('Lisinopril'), findsNothing);
      expect(find.text('Upcoming'), findsOneWidget);
      expect(find.text('Taken'), findsNothing);

      // Stats Grid: Real adherence & refills
      expect(find.text('50%'), findsOneWidget);
      expect(find.text('1 of 2 taken today'), findsOneWidget);
      expect(find.text('1 Low'), findsOneWidget);
      expect(find.text('Metformin'), findsWidgets);

      // Caregiver card: Displays real caregiver information
      expect(find.text('My Caregivers'), findsOneWidget);
      expect(find.text('Nimal Perera'), findsOneWidget);
      expect(find.textContaining('Active 5m ago'), findsOneWidget);
      expect(find.text('Caregiver account'), findsOneWidget);
      expect(find.text('Relationship'), findsOneWidget);
      expect(find.text('Son'), findsOneWidget);
      expect(find.text('nimal@example.com'), findsOneWidget);
      expect(find.text('+94 77 123 4567'), findsOneWidget);
      expect(find.text('Phone Battery'), findsNothing);
      expect(find.text('Smart Hub & Band'), findsNothing);
    });

    testWidgets(
        'renders gracefully when medications exist but no occurrences scheduled for today',
        (tester) async {
      final now = DateTime.now();
      final med = Medication(
        id: 'med-1',
        userId: 'user-1',
        name: 'Metformin',
        strength: 500,
        strengthUnit: 'mg',
        amountPerDose: 1,
        doseUnit: 'tablet(s)',
        isActive: true,
        quantityOnHand: 20,
        quantityUnit: 'tablet(s)',
        createdAt: now,
        updatedAt: now,
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            todayOccurrencesProvider.overrideWith((ref) => []),
            todayMedicationsProvider.overrideWith((ref) => [med]),
            todayAdherenceProvider.overrideWith((ref) =>
                const AdherenceSummary(taken: 0, total: 0, countable: 0)),
            lowStockProvider.overrideWith((ref) => []),
            caregiversProvider.overrideWith((ref) => []),
          ],
          child: const MaterialApp(
            home: HomeDashboardScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Next Medication Card: Displays 'No Doses Scheduled for Today' without crashing
      expect(find.text('No Doses Scheduled for Today'), findsOneWidget);
      expect(find.text('View Medications'), findsOneWidget);
    });

    testWidgets('displays only the first part of the user name when overridden',
        (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            userNameProvider.overrideWith((ref) => 'Thisara'),
            todayOccurrencesProvider.overrideWith((ref) => []),
            todayMedicationsProvider.overrideWith((ref) => []),
            todayAdherenceProvider.overrideWith((ref) =>
                const AdherenceSummary(taken: 0, total: 0, countable: 0)),
            lowStockProvider.overrideWith((ref) => []),
            caregiversProvider.overrideWith((ref) => []),
          ],
          child: const MaterialApp(
            home: HomeDashboardScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();
      expect(find.textContaining('Thisara!'), findsOneWidget);
      expect(find.textContaining('Denuwan'), findsNothing);
    });

    testWidgets(
        'switches to Caregiver Mode and displays all real caregiver records and interactivity',
        (tester) async {
      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final now = DateTime.now();
      final todayStr = DateFormat('yyyy-MM-dd').format(now);

      final medVitD = Medication(
        id: 'med-vit-d',
        userId: 'patient-1',
        name: 'Vitamin D',
        strength: 1000,
        strengthUnit: 'IU',
        amountPerDose: 1,
        doseUnit: 'Softgel',
        instructions: 'Take with morning breakfast',
        isActive: true,
        quantityOnHand: 45,
        quantityUnit: 'softgels',
        createdAt: now,
        updatedAt: now,
      );

      final medAmox = Medication(
        id: 'med-amox',
        userId: 'patient-1',
        name: 'Amoxicillin',
        strength: 500,
        strengthUnit: 'mg',
        amountPerDose: 1,
        doseUnit: 'Capsule',
        instructions: 'with food or lunch',
        isActive: true,
        quantityOnHand: 10,
        quantityUnit: 'capsules',
        refillReminderEnabled: true,
        refillThresholdQty: 12,
        createdAt: now,
        updatedAt: now,
      );

      final medAsp = Medication(
        id: 'med-asp',
        userId: 'patient-1',
        name: 'Aspirin',
        strength: 75,
        strengthUnit: 'mg',
        amountPerDose: 1,
        doseUnit: 'Tablet',
        instructions: 'Cardioprotective low dose at bedtime',
        isActive: true,
        quantityOnHand: 60,
        quantityUnit: 'tablets',
        createdAt: now,
        updatedAt: now,
      );

      final occ1 = DoseOccurrence(
        id: 'occ-1',
        scheduleId: 'sched-1',
        medicationId: medVitD.id,
        userId: 'patient-1',
        scheduledAt: DateTime(now.year, now.month, now.day, 8, 0),
        localDate: todayStr,
        occurrenceKey: 'sched-1-$todayStr-08:00',
        status: DoseStatus.taken,
        createdAt: now,
      );

      final occ2 = DoseOccurrence(
        id: 'occ-2',
        scheduleId: 'sched-2',
        medicationId: medAmox.id,
        userId: 'patient-1',
        scheduledAt: DateTime(now.year, now.month, now.day, 12, 30),
        localDate: todayStr,
        occurrenceKey: 'sched-2-$todayStr-12:30',
        status: DoseStatus.pending,
        createdAt: now,
      );

      final occ3 = DoseOccurrence(
        id: 'occ-3',
        scheduleId: 'sched-3',
        medicationId: medAsp.id,
        userId: 'patient-1',
        scheduledAt: DateTime(now.year, now.month, now.day, 20, 0),
        localDate: todayStr,
        occurrenceKey: 'sched-3-$todayStr-20:00',
        status: DoseStatus.pending,
        createdAt: now,
      );

      const weeklyReport = WeeklyAdherenceReport(
        overallPercentage: 94.0,
        totalCountable: 18,
        totalTaken: 17,
        totalMissed: 0,
        dailyPips: [
          DailyAdherencePip(dayLabel: 'Wed', percentage: 100, hasDoses: true),
          DailyAdherencePip(dayLabel: 'Thu', percentage: 100, hasDoses: true),
          DailyAdherencePip(dayLabel: 'Fri', percentage: 100, hasDoses: true),
          DailyAdherencePip(dayLabel: 'Sat', percentage: 100, hasDoses: true),
          DailyAdherencePip(dayLabel: 'Sun', percentage: 100, hasDoses: true),
          DailyAdherencePip(dayLabel: 'Mon', percentage: 88, hasDoses: true),
          DailyAdherencePip(dayLabel: 'Today', percentage: 100, hasDoses: true),
        ],
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            userNameProvider.overrideWith((ref) => 'Ishara'),
            todayOccurrencesProvider.overrideWith((ref) => [occ1, occ2, occ3]),
            todayMedicationsProvider
                .overrideWith((ref) => [medVitD, medAmox, medAsp]),
            todayAdherenceProvider.overrideWith((ref) =>
                const AdherenceSummary(taken: 1, total: 3, countable: 2)),
            lowStockProvider.overrideWith((ref) => [medAmox]),
            weeklyAdherenceProvider.overrideWith((ref) => weeklyReport),
            lowestStockMedicationProvider.overrideWith((ref) => medAmox),
            caregiverPatientOccurrencesProvider
                .overrideWith((ref, patientId) => [occ1, occ2, occ3]),
            caregiverPatientMedicationsProvider
                .overrideWith((ref, patientId) => [medVitD, medAmox, medAsp]),
            caregiverPatientWeeklyAdherenceProvider
                .overrideWith((ref, patientId) => weeklyReport),
            caregiverPatientLowStockProvider
                .overrideWith((ref, patientId) => [medAmox]),
            caregiverPatientLowestStockMedicationProvider
                .overrideWith((ref, patientId) => medAmox),
            patientPermissionsProvider.overrideWith((ref, patientId) => null),
            caregiversProvider.overrideWith((ref) => []),
            allocatedPatientsProvider.overrideWith((ref) => [
                  AllocatedPatient(
                    id: 'sample-patient-ishara',
                    caregiverId: 'user-1',
                    patientUserId: 'patient-1',
                    fullName: 'Ishara Perera',
                    relationship: 'Mother',
                    location: 'Colombo Home',
                    lastActive: 'Active 12m ago',
                    phoneBattery: 84,
                    batteryStatus: 'Balanced',
                    smartHubStatus: 'Synced 2m ago',
                    phoneNumber: '+94 71 987 6543',
                    patientEmail: 'ishara@example.com',
                    gender: 'male',
                    createdAt: now,
                  ),
                ]),
          ],
          child: const MaterialApp(
            home: HomeDashboardScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Tap Caregiver Mode button
      await tester.tap(find.text('Caregiver Mode'));
      await tester.pumpAndSettle();

      // Active View pill updates
      expect(find.text('Ishara (Caregiver)'), findsOneWidget);
      expect(find.text('Incoming Invitations'), findsNothing);

      // 1. Patient account card (shows real allocated patient details)
      expect(find.text('Ishara Perera'), findsOneWidget);
      expect(find.textContaining('Active 12m ago'), findsOneWidget);
      expect(find.text('Patient account'), findsOneWidget);
      expect(find.text('Relationship'), findsOneWidget);
      expect(find.text('Mother'), findsOneWidget);
      expect(find.text('Email'), findsOneWidget);
      expect(find.text('ishara@example.com'), findsOneWidget);
      expect(find.text('Gender'), findsOneWidget);
      expect(find.text('Male'), findsOneWidget);
      expect(find.text('+94 71 987 6543'), findsOneWidget);
      expect(find.text('Phone Battery'), findsNothing);
      expect(find.text('Smart Hub & Band'), findsNothing);

      // Patient account details are read-only; only removal is available.
      await tester.tap(find.byIcon(Icons.more_vert_rounded).first);
      await tester.pumpAndSettle();
      expect(find.text('Edit Patient Details'), findsNothing);
      expect(find.text('Remove Patient'), findsOneWidget);
      await tester.tap(find.text('Remove Patient'));
      await tester.pumpAndSettle();
      expect(
        find.textContaining('removed from both your app and the patient’s app'),
        findsOneWidget,
      );
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      // 2. Medication details and today's doses share one read-only section.
      expect(find.text('Medication & Today’s Schedule'), findsOneWidget);
      expect(find.text('Active medications'), findsOneWidget);
      expect(find.text('Today’s doses'), findsOneWidget);
      expect(find.text('Patient Medications'), findsNothing);
      expect(find.text('View only'), findsOneWidget);
      expect(
        find.textContaining('Medication details and today’s doses for Ishara'),
        findsOneWidget,
      );
      expect(find.text('Edit Medication'), findsNothing);
      expect(find.text('Delete Medication'), findsNothing);

      final medicationCard =
          find.byKey(const ValueKey('caregiver-medication-med-vit-d'));
      await tester.ensureVisible(medicationCard);
      await tester.tap(medicationCard);
      await tester.pumpAndSettle();
      expect(find.text('Medication details'), findsOneWidget);
      expect(find.textContaining('Read-only access'), findsOneWidget);
      expect(find.text('Edit Medication'), findsNothing);
      expect(find.text('Delete Medication'), findsNothing);
      await tester.tap(find.text('Close'));
      await tester.pumpAndSettle();

      // 3. Urgent Reminder Banner Card (Real Next Dose: Amoxicillin 500mg)
      expect(find.text('NEXT MEDICATION SOON'), findsOneWidget);
      expect(find.text('Amoxicillin 500 mg'), findsNWidgets(2));
      expect(find.text('Send Gentle Ping'), findsOneWidget);
      expect(find.text('Later'), findsOneWidget);

      // The previous standalone regimen section was merged above.
      expect(find.text("Today's Regimen"), findsNothing);
      expect(find.text('Vitamin D 1000 IU'), findsOneWidget);
      expect(find.text('Aspirin 75 mg'), findsOneWidget);
      expect(find.text('Mark as Taken'), findsOneWidget);
      expect(find.text('Prompt Ishara'), findsOneWidget);

      // 5. Patient-scoped weekly adherence card
      expect(find.text('Weekly Adherence'), findsOneWidget);
      expect(find.text('Ishara • Last 7 days'), findsOneWidget);
      expect(find.text('94% On Track'), findsOneWidget);
      expect(find.text('Amoxicillin (10 Days Left)'), findsOneWidget);
      expect(find.text('Refill'), findsOneWidget);

      // The legacy Care Actions grid is not shown in Caregiver Mode.
      expect(find.text('Care Actions'), findsNothing);
      expect(find.text('Log In-Person'), findsNothing);
      expect(find.text('Emergency Contact'), findsNothing);
      expect(find.text('Share Log'), findsNothing);

      // Test Interactivity: Tap 'Send Gentle Ping' triggers toast
      await tester.ensureVisible(find.text('Send Gentle Ping'));
      await tester.tap(find.text('Send Gentle Ping'));
      await tester.pump();
      expect(
          find.text("Gentle reminder sent to Ishara's phone."), findsOneWidget);

      // Tap 'Prompt Ishara' triggers prompt toast
      await tester.ensureVisible(find.text('Prompt Ishara'));
      await tester.tap(find.text('Prompt Ishara'));
      await tester.pump();
      expect(
          find.text(
              'Medication reminder sent to Ishara for Amoxicillin 500 mg.'),
          findsOneWidget);

      // Scroll back up and tap 'Patient Mode' to switch back
      await tester.drag(find.byType(CustomScrollView), const Offset(0, 2500));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Patient Mode'));
      await tester.tap(find.text('Patient Mode'));
      await tester.pumpAndSettle();
      expect(find.text('Ishara (Patient)'), findsOneWidget);
      expect(find.text('Ishara Perera'), findsNothing);
    });

    testWidgets(
        'Today schedule keeps snoozed medication and hides skipped medication',
        (tester) async {
      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final now = DateTime.now();
      final localDate = DateFormat('yyyy-MM-dd').format(now);
      final snoozedMedication = Medication(
        id: 'med-snoozed',
        userId: 'user-1',
        name: 'Snoozed Metformin',
        strength: 500,
        strengthUnit: 'mg',
        amountPerDose: 1,
        doseUnit: 'tablet(s)',
        imageUrl:
            'data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk+A8AAQUBAScY42YAAAAASUVORK5CYII=',
        isActive: true,
        quantityOnHand: 10,
        quantityUnit: 'tablet(s)',
        createdAt: now,
        updatedAt: now,
      );
      final skippedMedication = Medication(
        id: 'med-skipped',
        userId: 'user-1',
        name: 'Skipped Aspirin',
        strength: 75,
        strengthUnit: 'mg',
        amountPerDose: 1,
        doseUnit: 'tablet(s)',
        isActive: true,
        quantityOnHand: 10,
        quantityUnit: 'tablet(s)',
        createdAt: now,
        updatedAt: now,
      );
      final snoozeUntil = now.add(const Duration(minutes: 30));
      final occurrences = [
        DoseOccurrence(
          id: 'occ-snoozed',
          scheduleId: 'schedule-snoozed',
          medicationId: snoozedMedication.id,
          userId: 'user-1',
          scheduledAt: now.subtract(const Duration(minutes: 5)),
          localDate: localDate,
          occurrenceKey: 'schedule-snoozed-$localDate-0800',
          status: DoseStatus.snoozed,
          snoozeUntil: snoozeUntil,
          createdAt: now,
        ),
        DoseOccurrence(
          id: 'occ-skipped',
          scheduleId: 'schedule-skipped',
          medicationId: skippedMedication.id,
          userId: 'user-1',
          scheduledAt: now.add(const Duration(hours: 1)),
          localDate: localDate,
          occurrenceKey: 'schedule-skipped-$localDate-0900',
          status: DoseStatus.skipped,
          createdAt: now,
        ),
      ];

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            userNameProvider.overrideWith((ref) => 'Ishara'),
            todayOccurrencesProvider.overrideWith((ref) => occurrences),
            todayMedicationsProvider.overrideWith(
              (ref) => [snoozedMedication, skippedMedication],
            ),
            todayAdherenceProvider.overrideWith(
              (ref) => const AdherenceSummary(
                taken: 0,
                total: 2,
                countable: 2,
              ),
            ),
            lowStockProvider.overrideWith((ref) => []),
            caregiversProvider.overrideWith((ref) => []),
          ],
          child: const MaterialApp(home: HomeDashboardScreen()),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Snoozed Metformin'), findsWidgets);
      expect(find.text('Snoozed'), findsOneWidget);
      expect(find.textContaining('Snoozed until'), findsOneWidget);
      expect(
        find.byKey(const ValueKey('schedule-medication-image')),
        findsOneWidget,
      );
      expect(find.text('Skipped Aspirin'), findsNothing);
      expect(find.text('Skipped'), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets(
        'Caregiver Mode hides personal medication data when no patient is linked',
        (tester) async {
      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final now = DateTime.now();
      final todayStr = DateFormat('yyyy-MM-dd').format(now);
      final caregiverOwnMedication = Medication(
        id: 'caregiver-own-med',
        userId: 'caregiver-1',
        name: 'Caregiver Personal Medicine',
        strength: 20,
        strengthUnit: 'mg',
        amountPerDose: 1,
        doseUnit: 'Tablet',
        isActive: true,
        quantityOnHand: 2,
        quantityUnit: 'tablets',
        refillReminderEnabled: true,
        refillThresholdQty: 5,
        createdAt: now,
        updatedAt: now,
      );
      final caregiverOwnOccurrence = DoseOccurrence(
        id: 'caregiver-own-occurrence',
        scheduleId: 'caregiver-own-schedule',
        medicationId: caregiverOwnMedication.id,
        userId: 'caregiver-1',
        scheduledAt: now.add(const Duration(minutes: 30)),
        localDate: todayStr,
        occurrenceKey: 'caregiver-own-schedule-$todayStr',
        status: DoseStatus.pending,
        createdAt: now,
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            userNameProvider.overrideWith((ref) => 'Ishara'),
            todayOccurrencesProvider
                .overrideWith((ref) => [caregiverOwnOccurrence]),
            todayMedicationsProvider
                .overrideWith((ref) => [caregiverOwnMedication]),
            todayAdherenceProvider.overrideWith((ref) =>
                const AdherenceSummary(taken: 0, total: 1, countable: 0)),
            lowStockProvider.overrideWith((ref) => [caregiverOwnMedication]),
            lowestStockMedicationProvider
                .overrideWith((ref) => caregiverOwnMedication),
            caregiversProvider.overrideWith((ref) => []),
            allocatedPatientsProvider.overrideWith((ref) => []),
          ],
          child: const MaterialApp(
            home: HomeDashboardScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Tap Caregiver Mode button
      await tester.tap(find.text('Caregiver Mode'));
      await tester.pumpAndSettle();

      // Top status card shows 'No Patient Allocated' and 'Add Patient' with NO mock telemetry
      expect(find.text('Phone Battery'), findsNothing);
      expect(find.text('Smart Hub & Band'), findsNothing);
      expect(find.text('84% • Balanced'), findsNothing);
      expect(find.text('Synced 2m ago'), findsNothing);
      expect(find.text('Ishara Perera'), findsNothing);

      // The caregiver's own pending medication must not leak into this mode.
      expect(find.text('NEXT MEDICATION SOON'), findsNothing);
      expect(find.text('Caregiver Personal Medicine'), findsNothing);
      expect(find.text('No Regimen Scheduled for Today'), findsNothing);
      expect(find.text('Weekly Adherence'), findsNothing);
      expect(find.text('All Prescriptions Well Stocked'), findsNothing);
      expect(find.text('Add Patient'), findsOneWidget);
      expect(find.text('Add Medication'), findsNothing);
      expect(find.text('Load Sample Regimen'), findsNothing);
    });
  });
}
