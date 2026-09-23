import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';
import 'package:dose_diary/data/local/models/app_models.dart';
import 'package:dose_diary/data/local/models/dose_status.dart';
import 'package:dose_diary/data/repositories/app_repositories.dart';
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
  });
}
