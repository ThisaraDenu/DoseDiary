import 'package:dose_diary/core/theme/app_dimensions.dart';
import 'package:dose_diary/data/local/models/app_models.dart';
import 'package:dose_diary/features/medications/edit_medication_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets(
    'shows every editable medication detail and keeps actions above navigation',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final createdAt = DateTime(2026, 10, 1);
      final medication = Medication(
        id: 'med-edit',
        userId: 'patient-1',
        name: 'Amoxicillin',
        strength: 500,
        strengthUnit: 'mg',
        amountPerDose: 1,
        doseUnit: 'capsule(s)',
        imageUrl:
            'data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk+A8AAQUBAScY42YAAAAASUVORK5CYII=',
        instructions: 'Take after food',
        isActive: true,
        quantityOnHand: 18,
        quantityUnit: 'capsule(s)',
        refillReminderEnabled: true,
        refillThresholdQty: 6,
        createdAt: createdAt,
        updatedAt: createdAt,
      );
      final schedule = MedicationSchedule(
        id: 'schedule-edit',
        medicationId: medication.id,
        userId: medication.userId,
        timesOfDay: const ['08:00', '20:00'],
        frequencyType: 'daily',
        startDate: createdAt,
        timezone: 'Asia/Colombo',
        createdAt: createdAt,
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            editMedicationProvider
                .overrideWith((ref, medicationId) => medication),
            editMedicationScheduleProvider
                .overrideWith((ref, medicationId) => schedule),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: EditMedicationScreen(
                medicationId: 'med-edit',
              ),
              bottomNavigationBar: SizedBox(
                key: ValueKey('test-bottom-navigation'),
                height: AppDimensions.navBarHeight,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Medicine name *'), findsOneWidget);
      expect(find.text('Strength'), findsOneWidget);
      expect(find.text('Amount per dose'), findsOneWidget);
      expect(find.text('Instructions'), findsOneWidget);
      expect(find.text('Schedule'), findsOneWidget);
      expect(find.text('Frequency'), findsOneWidget);
      expect(find.text('Reminder times'), findsOneWidget);
      expect(find.text('8:00 AM'), findsOneWidget);
      expect(find.text('8:00 PM'), findsOneWidget);
      expect(find.text('Stock & Refills'), findsOneWidget);
      expect(find.text('Current quantity'), findsOneWidget);
      expect(find.text('Refill reminder'), findsOneWidget);
      expect(find.text('Low-stock threshold (units)'), findsOneWidget);
      expect(find.text('Tap to change medication image'), findsOneWidget);

      await tester.ensureVisible(find.text('Save Changes'));
      await tester.pumpAndSettle();

      final navigationTop = tester
          .getTopLeft(find.byKey(const ValueKey('test-bottom-navigation')))
          .dy;
      expect(tester.getBottomRight(find.text('Cancel')).dy,
          lessThan(navigationTop));
      expect(
        tester.getBottomRight(find.text('Save Changes')).dy,
        lessThan(navigationTop),
      );
      expect(tester.takeException(), isNull);
    },
  );
}
