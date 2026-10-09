import 'dart:convert';

import 'package:dose_diary/data/local/models/app_models.dart';
import 'package:dose_diary/data/local/models/dose_status.dart';
import 'package:dose_diary/features/history/history_pdf_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';

void main() {
  test('builds valid day and week PDFs from supplied medication history',
      () async {
    final selectedDate = DateTime(2026, 10, 8);
    final medication = Medication(
      id: 'med-1',
      userId: 'user-1',
      name: 'Amoxicillin',
      strength: 500,
      strengthUnit: 'mg',
      amountPerDose: 1,
      doseUnit: 'capsule',
      instructions: 'Take with food',
      isActive: true,
      quantityOnHand: 12,
      quantityUnit: 'capsules',
      createdAt: selectedDate,
      updatedAt: selectedDate,
    );
    final occurrence = DoseOccurrence(
      id: 'occurrence-1',
      scheduleId: 'schedule-1',
      medicationId: medication.id,
      userId: medication.userId,
      scheduledAt: DateTime(2026, 10, 8, 8),
      localDate: DateFormat('yyyy-MM-dd').format(selectedDate),
      occurrenceKey: 'schedule-1-2026-10-08-08:00',
      status: DoseStatus.taken,
      createdAt: selectedDate,
    );
    final event = DoseEvent(
      id: 'event-1',
      occurrenceId: occurrence.id,
      userId: medication.userId,
      action: 'taken',
      recordedAt: DateTime(2026, 10, 8, 8, 5),
      clientId: 'client-1',
      createdAt: selectedDate,
    );

    for (final period in HistoryPdfPeriod.values) {
      final bytes = await HistoryPdfService.build(
        period: period,
        selectedDate: selectedDate,
        occurrences: [occurrence],
        medications: {medication.id: medication},
        latestEvents: {occurrence.id: event},
      );

      expect(bytes.length, greaterThan(1000));
      expect(ascii.decode(bytes.take(4).toList()), '%PDF');
    }
  });
}
