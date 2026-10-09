import 'package:dose_diary/data/local/models/app_models.dart';
import 'package:dose_diary/data/local/models/dose_status.dart';
import 'package:dose_diary/features/history/history_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';

void main() {
  testWidgets(
    'renders the reference-style history UI using only supplied database data',
    (tester) async {
      tester.view.physicalSize = const Size(390, 1200);
      tester.view.devicePixelRatio = 1;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final today = DateUtils.dateOnly(DateTime.now());
      final yesterday = today.subtract(const Duration(days: 1));
      final createdAt = today.subtract(const Duration(days: 10));
      final amoxicillin = Medication(
        id: 'med-amoxicillin-history',
        userId: 'patient-1',
        name: 'Amoxicillin',
        strength: 500,
        strengthUnit: 'mg',
        amountPerDose: 1,
        doseUnit: 'capsule',
        instructions: 'Take with food',
        isActive: true,
        quantityOnHand: 20,
        quantityUnit: 'capsules',
        createdAt: createdAt,
        updatedAt: createdAt,
      );
      final aspirin = Medication(
        id: 'med-aspirin-history',
        userId: 'patient-1',
        name: 'Aspirin',
        strength: 75,
        strengthUnit: 'mg',
        amountPerDose: 1,
        doseUnit: 'tablet',
        isActive: true,
        quantityOnHand: 15,
        quantityUnit: 'tablets',
        createdAt: createdAt,
        updatedAt: createdAt,
      );

      DoseOccurrence occurrence({
        required String id,
        required Medication medication,
        required DateTime day,
        required int hour,
        required DoseStatus status,
      }) {
        final localDate = DateFormat('yyyy-MM-dd').format(day);
        return DoseOccurrence(
          id: id,
          scheduleId: 'schedule-${medication.id}',
          medicationId: medication.id,
          userId: medication.userId,
          scheduledAt: DateTime(day.year, day.month, day.day, hour),
          localDate: localDate,
          occurrenceKey: '$id-$localDate',
          status: status,
          createdAt: createdAt,
        );
      }

      final takenToday = occurrence(
        id: 'taken-today',
        medication: amoxicillin,
        day: today,
        hour: 8,
        status: DoseStatus.taken,
      );
      final skippedToday = occurrence(
        id: 'skipped-today',
        medication: aspirin,
        day: today,
        hour: 13,
        status: DoseStatus.skipped,
      );
      final pendingToday = occurrence(
        id: 'pending-today',
        medication: amoxicillin,
        day: today,
        hour: 20,
        status: DoseStatus.pending,
      );
      final takenYesterday = occurrence(
        id: 'taken-yesterday',
        medication: aspirin,
        day: yesterday,
        hour: 8,
        status: DoseStatus.taken,
      );
      final missedYesterday = occurrence(
        id: 'missed-yesterday',
        medication: amoxicillin,
        day: yesterday,
        hour: 20,
        status: DoseStatus.missed,
      );

      final data = HistoryData(
        occurrences: [
          takenToday,
          skippedToday,
          pendingToday,
          takenYesterday,
          missedYesterday,
        ],
        medications: {
          amoxicillin.id: amoxicillin,
          aspirin.id: aspirin,
        },
        latestEvents: {
          takenToday.id: DoseEvent(
            id: 'event-taken',
            occurrenceId: takenToday.id,
            userId: 'patient-1',
            action: 'taken',
            recordedAt: DateTime(
              today.year,
              today.month,
              today.day,
              8,
              10,
            ),
            clientId: 'event-taken-client',
            createdAt: createdAt,
          ),
          skippedToday.id: DoseEvent(
            id: 'event-skipped',
            occurrenceId: skippedToday.id,
            userId: 'patient-1',
            action: 'skipped',
            recordedAt: DateTime(
              today.year,
              today.month,
              today.day,
              13,
            ),
            skipReason: 'Felt unwell',
            clientId: 'event-skipped-client',
            createdAt: createdAt,
          ),
        },
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            historySelectedDateProvider.overrideWith((ref) => today),
            historyViewModeProvider.overrideWith((ref) => HistoryViewMode.day),
            historyDataProvider.overrideWith((ref, date) => data),
          ],
          child: const MaterialApp(home: HistoryScreen()),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Medication History'), findsOneWidget);
      expect(find.text('Day'), findsOneWidget);
      expect(find.text('Week'), findsOneWidget);
      expect(find.text('Weekly Adherence'), findsOneWidget);
      expect(find.text('2 of 5 scheduled'), findsOneWidget);
      expect(find.textContaining('Today,'), findsWidgets);
      expect(find.textContaining('Yesterday,'), findsOneWidget);
      expect(find.text('Felt unwell'), findsOneWidget);
      expect(find.text('Vitamin D'), findsNothing);

      await tester.tap(find.byKey(const ValueKey('weekly-adherence-review')));
      await tester.pumpAndSettle();
      expect(find.text('Weekly Adherence Charts'), findsOneWidget);
      expect(find.text('Daily adherence'), findsOneWidget);
      expect(find.text('Dose status breakdown'), findsOneWidget);
      expect(find.text('5 doses scheduled this week'), findsOneWidget);
      await tester.tap(find.byTooltip('Close charts'));
      await tester.pumpAndSettle();

      await tester.tap(find.byTooltip('Download history PDF'));
      await tester.pumpAndSettle();
      expect(find.text('Get history as PDF'), findsOneWidget);
      expect(find.text('Download daily history PDF'), findsOneWidget);
      expect(find.text('Download weekly history PDF'), findsOneWidget);
      await tester.tapAt(const Offset(20, 20));
      await tester.pumpAndSettle();

      await tester.scrollUntilVisible(
        find.text('Status Key Reference'),
        300,
      );
      expect(find.text('Status Key Reference'), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('history-tab-week')));
      await tester.pumpAndSettle();
      expect(find.text('Weekly Dose Summary'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}
