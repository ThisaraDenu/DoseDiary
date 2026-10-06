import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';
import 'package:dose_diary/data/local/models/app_models.dart';
import 'package:dose_diary/data/local/models/dose_status.dart';
import 'package:dose_diary/features/caregivers/caregiver_management_screen.dart';
import 'package:dose_diary/features/home/home_dashboard_screen.dart';

void main() {
  group('HomeDashboardScreen Widget Tests', () {
    testWidgets('renders clean empty states with zero mock data when database has no records', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            todayOccurrencesProvider.overrideWith((ref) => []),
            todayMedicationsProvider.overrideWith((ref) => []),
            todayAdherenceProvider.overrideWith((ref) => const AdherenceSummary(taken: 0, total: 0, countable: 0)),
            lowStockProvider.overrideWith((ref) => []),
            caregiversProvider.overrideWith((ref) => []),
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
      final expectedDateStr = DateFormat('EEEE, d MMMM yyyy').format(DateTime.now());
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
      expect(find.text('No doses today'), findsOneWidget);
      expect(find.text('Refills'), findsOneWidget);
      expect(find.text('0 Low'), findsOneWidget);
      expect(find.text('All supplies in stock'), findsOneWidget);

      // Caregiver card: shows clean unlinked state, NOT mock "Nimal Perera (Son)"
      expect(find.text('No Caregiver Connected'), findsOneWidget);
      expect(find.text('Nimal Perera (Son)'), findsNothing);
    });

    testWidgets('renders real data when medications, occurrences, and caregivers exist in database', (tester) async {
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

      final caregiver = CaregiverInvitation(
        id: 'cg-1',
        email: 'son@example.com',
        relationship: 'Son',
        status: 'active',
        createdAt: now,
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            todayOccurrencesProvider.overrideWith((ref) => [occ1, occ2]),
            todayMedicationsProvider.overrideWith((ref) => [med1, med2]),
            todayAdherenceProvider.overrideWith((ref) => const AdherenceSummary(taken: 1, total: 2, countable: 2)),
            lowStockProvider.overrideWith((ref) => [med1]),
            caregiversProvider.overrideWith((ref) => [caregiver]),
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
      expect(find.text('500 mg • 1 tablet(s)'), findsOneWidget);
      expect(find.text('Take with food'), findsOneWidget);
      expect(find.text('Log Dose'), findsOneWidget);

      // Today's schedule: Displays both real occurrences
      expect(find.text("Today's Schedule"), findsOneWidget);
      expect(find.text('Metformin'), findsWidgets);
      expect(find.text('Lisinopril'), findsWidgets);
      expect(find.text('Upcoming'), findsOneWidget);
      expect(find.text('Taken'), findsWidgets);

      // Stats Grid: Real adherence & refills
      expect(find.text('50%'), findsOneWidget);
      expect(find.text('1 of 2 taken today'), findsOneWidget);
      expect(find.text('1 Low'), findsOneWidget);
      expect(find.text('Metformin'), findsWidgets);

      // Caregiver card: Displays real caregiver information
      expect(find.text('Caregiver Connected'), findsOneWidget);
      expect(find.text('son@example.com (Son)'), findsOneWidget);
      expect(find.text('Status'), findsOneWidget);
    });

    testWidgets('renders gracefully when medications exist but no occurrences scheduled for today', (tester) async {
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
            todayAdherenceProvider.overrideWith((ref) => const AdherenceSummary(taken: 0, total: 0, countable: 0)),
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

    testWidgets('displays only the first part of the user name when overridden', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            userNameProvider.overrideWith((ref) => 'Thisara'),
            todayOccurrencesProvider.overrideWith((ref) => []),
            todayMedicationsProvider.overrideWith((ref) => []),
            todayAdherenceProvider.overrideWith((ref) => const AdherenceSummary(taken: 0, total: 0, countable: 0)),
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

    testWidgets('switches to Caregiver Mode and displays all real caregiver records and interactivity', (tester) async {
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
        userId: 'user-1',
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
        userId: 'user-1',
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
        userId: 'user-1',
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
        userId: 'user-1',
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
        userId: 'user-1',
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
        userId: 'user-1',
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
            todayMedicationsProvider.overrideWith((ref) => [medVitD, medAmox, medAsp]),
            todayAdherenceProvider.overrideWith((ref) => const AdherenceSummary(taken: 1, total: 3, countable: 2)),
            lowStockProvider.overrideWith((ref) => [medAmox]),
            weeklyAdherenceProvider.overrideWith((ref) => weeklyReport),
            lowestStockMedicationProvider.overrideWith((ref) => medAmox),
            caregiversProvider.overrideWith((ref) => []),
            allocatedPatientsProvider.overrideWith((ref) => [
              AllocatedPatient(
                id: 'sample-patient-ishara',
                caregiverId: 'user-1',
                fullName: 'Ishara Perera',
                relationship: 'Mother',
                location: 'Colombo Home',
                lastActive: 'Active 12m ago',
                phoneBattery: 84,
                batteryStatus: 'Balanced',
                smartHubStatus: 'Synced 2m ago',
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

      // 1. Patient Quick Telemetry & Status Card (shows real allocated patient details)
      expect(find.text('Ishara Perera'), findsOneWidget);
      expect(find.textContaining('Active 12m ago'), findsOneWidget);
      expect(find.text('Phone Battery'), findsOneWidget);
      expect(find.text('84% • Balanced'), findsOneWidget);
      expect(find.text('Smart Hub & Band'), findsOneWidget);
      expect(find.text('Synced 2m ago'), findsOneWidget);

      // 2. Urgent Reminder Banner Card (Real Next Dose: Amoxicillin 500mg)
      expect(find.text('NEXT MEDICATION SOON'), findsOneWidget);
      expect(find.text('Amoxicillin 500 mg'), findsNWidgets(2));
      expect(find.text('Send Gentle Ping'), findsOneWidget);
      expect(find.text('Later'), findsOneWidget);

      // 3. Today's Regimen Section
      expect(find.text("Today's Regimen"), findsOneWidget);
      expect(find.text('Vitamin D 1000 IU'), findsOneWidget);
      expect(find.text('Aspirin 75 mg'), findsOneWidget);
      expect(find.text('Mark as Taken'), findsOneWidget);
      expect(find.text('Prompt Ishara'), findsOneWidget);

      // 4. Caregiver Adherence Card
      expect(find.text('Weekly Adherence'), findsOneWidget);
      expect(find.text('94% On Track'), findsOneWidget);
      expect(find.text('Amoxicillin (10 Days Left)'), findsOneWidget);
      expect(find.text('Refill'), findsOneWidget);

      // 5. Care Actions Grid
      expect(find.text('Care Actions'), findsOneWidget);
      expect(find.text('Log In-Person'), findsOneWidget);
      expect(find.text('Dr. Angela Chen'), findsOneWidget);
      expect(find.text('Share Log'), findsOneWidget);
      expect(find.text('Permissions'), findsOneWidget);

      // Test Interactivity: Tap 'Send Gentle Ping' triggers toast
      await tester.ensureVisible(find.text('Send Gentle Ping'));
      await tester.tap(find.text('Send Gentle Ping'));
      await tester.pump();
      expect(find.text("Gentle chime sent to Ishara's phone & smart speaker."), findsOneWidget);

      // Tap 'Prompt Ishara' triggers prompt toast
      await tester.ensureVisible(find.text('Prompt Ishara'));
      await tester.tap(find.text('Prompt Ishara'));
      await tester.pump();
      expect(find.text('Audio alert sent to Ishara for Amoxicillin 500 mg.'), findsOneWidget);

      // Scroll back up and tap 'Patient Mode' to switch back
      await tester.drag(find.byType(CustomScrollView), const Offset(0, 800));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Patient Mode'));
      await tester.pumpAndSettle();
      expect(find.text('Ishara (Patient)'), findsOneWidget);
      expect(find.text('Ishara Perera'), findsNothing);
    });

    testWidgets('in Caregiver Mode, renders clean empty state when database has zero records', (tester) async {
      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            userNameProvider.overrideWith((ref) => 'Ishara'),
            todayOccurrencesProvider.overrideWith((ref) => []),
            todayMedicationsProvider.overrideWith((ref) => []),
            todayAdherenceProvider.overrideWith((ref) => const AdherenceSummary(taken: 0, total: 0, countable: 0)),
            lowStockProvider.overrideWith((ref) => []),
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

      // Urgent reminder is NOT shown because there is no pending medication in database
      expect(find.text('NEXT MEDICATION SOON'), findsNothing);

      // Regimen shows clean empty state
      expect(find.text('No Regimen Scheduled for Today'), findsOneWidget);
      expect(find.text('Add Medication'), findsOneWidget);
      expect(find.text('Load Sample Regimen'), findsNothing);

      // Refill strip shows all well stocked
      expect(find.text('All Prescriptions Well Stocked'), findsOneWidget);
    });
  });
}
