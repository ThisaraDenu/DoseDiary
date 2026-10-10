import 'package:dose_diary/data/local/models/app_models.dart';
import 'package:dose_diary/data/local/models/dose_status.dart';
import 'package:dose_diary/data/repositories/app_repositories.dart';
import 'package:dose_diary/features/medications/medication_schedule_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets(
    'shows one detailed card per medication with every scheduled dose',
    (tester) async {
      tester.view.physicalSize = const Size(390, 1800);
      tester.view.devicePixelRatio = 1;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final date = DateTime(2026, 10, 8);
      final now = DateTime(2026, 10, 1);
      final amoxicillin = Medication(
        id: 'med-amoxicillin',
        userId: 'patient-1',
        name: 'Amoxicillin',
        strength: 500,
        strengthUnit: 'mg',
        amountPerDose: 1,
        doseUnit: 'capsule',
        instructions: 'Take after food',
        isActive: true,
        quantityOnHand: 18,
        quantityUnit: 'capsules',
        refillReminderEnabled: true,
        refillThresholdQty: 6,
        createdAt: now,
        updatedAt: now,
      );
      final aspirin = Medication(
        id: 'med-aspirin',
        userId: 'patient-1',
        name: 'Aspirin',
        strength: 75,
        strengthUnit: 'mg',
        amountPerDose: 1,
        doseUnit: 'tablet',
        isActive: true,
        quantityOnHand: 30,
        quantityUnit: 'tablets',
        createdAt: now,
        updatedAt: now,
      );

      DoseOccurrence occurrence(
        String id,
        Medication medication,
        int hour,
        DoseStatus status,
      ) {
        return DoseOccurrence(
          id: id,
          scheduleId: 'schedule-${medication.id}',
          medicationId: medication.id,
          userId: medication.userId,
          scheduledAt: DateTime(date.year, date.month, date.day, hour),
          localDate: '2026-10-08',
          occurrenceKey: '$id-2026-10-08',
          status: status,
          createdAt: now,
        );
      }

      final occurrences = [
        occurrence('amox-morning', amoxicillin, 8, DoseStatus.taken),
        occurrence('amox-afternoon', amoxicillin, 14, DoseStatus.pending),
        occurrence('amox-evening', amoxicillin, 20, DoseStatus.pending),
        occurrence('aspirin-evening', aspirin, 21, DoseStatus.pending),
      ];

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            selectedScheduleDateProvider.overrideWith((ref) => date),
            scheduleOccurrencesProvider
                .overrideWith((ref, selectedDate) => occurrences),
            allActiveMedsProvider.overrideWith((ref) => [amoxicillin, aspirin]),
          ],
          child: const MaterialApp(home: MedicationScheduleScreen()),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(FloatingActionButton), findsNothing);
      expect(find.byTooltip('Add Medication'), findsOneWidget);
      expect(find.text('Amoxicillin'), findsOneWidget);
      expect(find.text('Aspirin'), findsOneWidget);
      expect(
        find.byKey(
          const ValueKey('medication-frequency-med-amoxicillin'),
        ),
        findsOneWidget,
      );
      expect(find.text('3 times on this day'), findsNWidgets(2));
      expect(find.text('1 time on this day'), findsNWidgets(2));
      expect(find.text('8:00 AM'), findsOneWidget);
      expect(find.text('2:00 PM'), findsOneWidget);
      expect(find.text('8:00 PM'), findsOneWidget);
      expect(find.text('9:00 PM'), findsOneWidget);
      expect(find.text('Take after food'), findsOneWidget);
      expect(find.text('18 capsules'), findsOneWidget);
      expect(find.text('At 6 capsules'), findsOneWidget);
      expect(
        find.byKey(const ValueKey('medication-card-image')),
        findsNWidgets(2),
      );
      expect(tester.takeException(), isNull);
    },
  );
}
