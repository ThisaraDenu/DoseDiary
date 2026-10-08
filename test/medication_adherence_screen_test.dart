import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dose_diary/data/local/models/app_models.dart';
import 'package:dose_diary/features/adherence/medication_adherence_screen.dart';
import 'package:dose_diary/features/home/home_dashboard_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('MedicationAdherenceScreen Widget Tests', () {
    testWidgets('renders clean empty state with 0 / 0 when no data in database',
        (tester) async {
      final emptyReport =
          ComprehensiveAdherenceReport.empty(AdherencePeriod.thisWeek);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            comprehensiveAdherenceProvider
                .overrideWith((ref) async => emptyReport),
            userNameProvider.overrideWith((ref) async => 'Ishara'),
          ],
          child: const MaterialApp(
            home: MedicationAdherenceScreen(),
          ),
        ),
      );

      await tester.pump();
      await tester.pumpAndSettle();

      // Header checks
      expect(find.text('PATIENT HEALTH RECORDS'), findsOneWidget);
      expect(find.text('Medication\nAdherence'), findsOneWidget);
      expect(find.text('Doctor'), findsOneWidget);
      expect(find.text('PDF'), findsOneWidget);

      // Period tabs
      expect(find.text('This Week'), findsOneWidget);
      expect(find.text('Monthly'), findsOneWidget);
      expect(find.text('All Time'), findsOneWidget);

      // Status & Score
      expect(find.text('• No Data'), findsOneWidget);
      expect(find.text('No Data Recorded'), findsOneWidget);
      expect(find.text('—%'), findsOneWidget);
      expect(find.text('Score'), findsOneWidget);

      // 4 Stats
      expect(find.text('0 / 0'), findsOneWidget);
      expect(find.text('0'), findsWidgets); // Streak 0, Missed 0, Delayed 0
      expect(find.text('0 doses'), findsOneWidget);
      expect(find.text('0 on time'), findsOneWidget);

      // Breakdown title & legend
      expect(find.text('7-Day Dose Breakdown'), findsOneWidget);
      expect(find.text('Tap day to inspect'), findsOneWidget);
      expect(find.text('Taken (100%)'), findsOneWidget);
      expect(find.text('Missed dose'), findsOneWidget);
      expect(find.text('Taken late'), findsOneWidget);

      // Empty individual medications card
      expect(find.text('No Prescriptions in Database'), findsOneWidget);
      expect(find.text('Add Medication'), findsOneWidget);
      expect(find.text('0 Active Prescriptions'), findsOneWidget);
    });

    testWidgets('renders real medications, streak, and adherence scores from database',
        (tester) async {
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final amox = Medication.create(
        userId: 'test-user',
        name: 'Amoxicillin',
        strength: 500,
        strengthUnit: 'mg',
        amountPerDose: 1,
        doseUnit: 'capsule(s)',
        instructions: 'Antibiotic • 3 times daily with food',
        quantityOnHand: 14,
      );
      final vitD = Medication.create(
        userId: 'test-user',
        name: 'Vitamin D3',
        strength: 1000,
        strengthUnit: 'IU',
        amountPerDose: 1,
        doseUnit: 'tablet(s)',
        instructions: 'Bone & Immunity • Once every morning',
        quantityOnHand: 30,
      );

      final breakdown = <AdherenceDayBreakdown>[
        for (int i = 6; i >= 0; i--)
          AdherenceDayBreakdown(
            date: today.subtract(Duration(days: i)),
            dayLabel: i == 0 ? 'Today' : 'Day',
            dayNumber: today.subtract(Duration(days: i)).day,
            isToday: i == 0,
            countable: 4,
            taken: 4,
            missed: 0,
            delayed: 0,
            status: DayAdherenceStatus.taken100,
            percentage: 100.0,
          ),
      ];

      final populatedReport = ComprehensiveAdherenceReport(
        period: AdherencePeriod.thisWeek,
        startDate: today.subtract(const Duration(days: 6)),
        endDate: now,
        totalCountable: 28,
        totalTaken: 26,
        totalMissed: 1,
        totalDelayed: 1,
        scorePercentage: 92,
        hasData: true,
        currentStreakDays: 14,
        mostRecentMissedDate: DateTime(2026, 8, 17),
        averageDelayMinutes: 45,
        dailyBreakdown: breakdown,
        medicationAdherences: [
          MedicationAdherenceItem(
            medication: amox,
            countable: 20,
            taken: 19,
            missed: 1,
            delayed: 0,
            adherencePercentage: 95,
            daysSupplyLeft: 2,
            nextDoseTime: 'Next dose: 2:00 PM',
            subtitle: 'Antibiotic • 3 times daily with food',
          ),
          MedicationAdherenceItem(
            medication: vitD,
            countable: 7,
            taken: 7,
            missed: 0,
            delayed: 0,
            adherencePercentage: 100,
            daysSupplyLeft: 30,
            lastTakenTime: 'Taken 8:15 AM today',
            subtitle: 'Bone & Immunity • Once every morning',
          ),
        ],
        activePrescriptionsCount: 2,
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            comprehensiveAdherenceProvider
                .overrideWith((ref) async => populatedReport),
            userNameProvider.overrideWith((ref) async => 'Ishara'),
          ],
          child: const MaterialApp(
            home: MedicationAdherenceScreen(),
          ),
        ),
      );

      await tester.pump();
      await tester.pumpAndSettle();

      // Top summary card checks
      expect(find.text('92%'), findsOneWidget);
      expect(find.text('• On Track'), findsOneWidget);
      expect(find.text('Excellent Adherence'), findsOneWidget);
      expect(find.text('26 / 28'), findsOneWidget);
      expect(find.text('14'), findsOneWidget);
      expect(find.text('1 dose (Aug 17)'), findsOneWidget);
      expect(find.text('1 +45m'), findsOneWidget);

      // Active prescriptions
      expect(find.text('2 Active Prescriptions'), findsOneWidget);
      expect(find.text('Amoxicillin 500 mg'), findsOneWidget);
      expect(find.text('Vitamin D3 1000 IU'), findsOneWidget);
      expect(find.text('95% adherence rate'), findsOneWidget);
      expect(find.text('100% adherence rate'), findsOneWidget);
      expect(find.text('Perfect 100%'), findsOneWidget);
      expect(find.text('Next dose: 2:00 PM'), findsOneWidget);
    });

    testWidgets('tapping Doctor PDF opens the bottom sheet modal with summary',
        (tester) async {
      final emptyReport =
          ComprehensiveAdherenceReport.empty(AdherencePeriod.thisWeek);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            comprehensiveAdherenceProvider
                .overrideWith((ref) async => emptyReport),
            userNameProvider.overrideWith((ref) async => 'Ishara'),
          ],
          child: const MaterialApp(
            home: MedicationAdherenceScreen(),
          ),
        ),
      );

      await tester.pump();
      await tester.pumpAndSettle();

      final pdfButton = find.text('Doctor');
      expect(pdfButton, findsOneWidget);
      await tester.tap(pdfButton);
      await tester.pumpAndSettle();

      // Check modal content
      expect(find.text('Doctor Adherence Report'), findsOneWidget);
      expect(find.text('Patient Name'), findsOneWidget);
      expect(find.text('Ishara'), findsOneWidget);
      expect(find.text('Export & Share Report'), findsOneWidget);
    });
  });
}
