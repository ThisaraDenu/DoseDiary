import 'package:dose_diary/data/local/models/app_models.dart';
import 'package:dose_diary/data/local/models/dose_status.dart';
import 'package:dose_diary/features/reminders/reminder_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('shows medication image, name, dose details, and actions',
      (tester) async {
    tester.view.physicalSize = const Size(340, 760);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final now = DateTime.now();
    final medication = Medication(
      id: 'med-image',
      userId: 'user-1',
      name: 'Metformin',
      strength: 500,
      strengthUnit: 'mg',
      amountPerDose: 1,
      doseUnit: 'tablet(s)',
      imageUrl:
          'data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk+A8AAQUBAScY42YAAAAASUVORK5CYII=',
      instructions: 'Take with food',
      isActive: true,
      quantityOnHand: 20,
      quantityUnit: 'tablet(s)',
      createdAt: now,
      updatedAt: now,
    );
    final occurrence = DoseOccurrence(
      id: 'occ-image',
      scheduleId: 'schedule-1',
      medicationId: medication.id,
      userId: medication.userId,
      scheduledAt: now.add(const Duration(hours: 1)),
      localDate: '2026-10-08',
      occurrenceKey: 'schedule-1-2026-10-08-1200',
      status: DoseStatus.pending,
      createdAt: now,
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          reminderOccurrenceProvider.overrideWith(
            (ref, id) async => occurrence,
          ),
          reminderMedicationProvider.overrideWith(
            (ref, id) async => medication,
          ),
        ],
        child: const MaterialApp(
          home: ReminderScreen(occurrenceId: 'occ-image'),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('medication-image')), findsOneWidget);
    expect(find.text('Metformin'), findsOneWidget);
    expect(find.text('500 mg'), findsOneWidget);
    expect(find.text('1 tablet(s)'), findsOneWidget);
    expect(find.text('Take with food'), findsOneWidget);
    expect(find.text('Mark as taken'), findsOneWidget);
    expect(find.text('Snooze'), findsOneWidget);
    expect(find.text('Skip dose'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('uses a polished medication fallback when no image was added',
      (tester) async {
    final now = DateTime.now();
    final medication = Medication(
      id: 'med-no-image',
      userId: 'user-1',
      name: 'Vitamin D',
      strength: 1000,
      strengthUnit: 'IU',
      amountPerDose: 1,
      doseUnit: 'tablet(s)',
      isActive: true,
      quantityOnHand: 10,
      quantityUnit: 'tablet(s)',
      createdAt: now,
      updatedAt: now,
    );
    final occurrence = DoseOccurrence(
      id: 'occ-no-image',
      scheduleId: 'schedule-2',
      medicationId: medication.id,
      userId: medication.userId,
      scheduledAt: now.add(const Duration(hours: 2)),
      localDate: '2026-10-08',
      occurrenceKey: 'schedule-2-2026-10-08-1400',
      status: DoseStatus.pending,
      createdAt: now,
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          reminderOccurrenceProvider.overrideWith(
            (ref, id) async => occurrence,
          ),
          reminderMedicationProvider.overrideWith(
            (ref, id) async => medication,
          ),
        ],
        child: const MaterialApp(
          home: ReminderScreen(occurrenceId: 'occ-no-image'),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('medication-image-fallback')),
      findsOneWidget,
    );
    expect(find.text('Vitamin D'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
