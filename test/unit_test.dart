import 'package:flutter_test/flutter_test.dart';
import 'package:dose_diary/data/local/models/app_models.dart';
import 'package:dose_diary/data/local/models/dose_status.dart';
import 'package:dose_diary/data/repositories/app_repositories.dart';

void main() {
  group('DoseStatus tests', () {
    test('DoseStatus parsing from string and toDbString', () {
      expect(DoseStatus.fromString('taken'), DoseStatus.taken);
      expect(DoseStatus.fromString('missed'), DoseStatus.missed);
      expect(DoseStatus.fromString('skipped'), DoseStatus.skipped);
      expect(DoseStatus.fromString('overdue'), DoseStatus.overdue);
      expect(DoseStatus.fromString('snoozed'), DoseStatus.snoozed);
      expect(DoseStatus.fromString('pending'), DoseStatus.pending);
      expect(DoseStatus.fromString('anything_else'), DoseStatus.pending);

      expect(DoseStatus.taken.toDbString(), 'taken');
      expect(DoseStatus.missed.toDbString(), 'missed');
    });

    test('DoseStatus isTerminal and isActionable check', () {
      expect(DoseStatus.taken.isTerminal, isTrue);
      expect(DoseStatus.missed.isTerminal, isTrue);
      expect(DoseStatus.skipped.isTerminal, isTrue);
      expect(DoseStatus.pending.isTerminal, isFalse);
      expect(DoseStatus.snoozed.isTerminal, isFalse);

      expect(DoseStatus.pending.isActionable, isTrue);
      expect(DoseStatus.snoozed.isActionable, isTrue);
      expect(DoseStatus.taken.isActionable, isFalse);
    });
  });

  group('Medication Model tests', () {
    final testMed = Medication(
      id: 'med-001',
      userId: 'user-001',
      name: 'Amoxicillin',
      strength: 500,
      strengthUnit: 'mg',
      amountPerDose: 1,
      doseUnit: 'capsule(s)',
      instructions: 'Take after food',
      isActive: true,
      isAsNeeded: false,
      quantityOnHand: 4,
      quantityUnit: 'capsule(s)',
      refillReminderEnabled: true,
      refillThresholdQty: 7,
      createdAt: DateTime.utc(2026, 1, 1),
      updatedAt: DateTime.utc(2026, 1, 1),
    );

    test('displayStrength formats correctly', () {
      expect(testMed.displayStrength, '500 mg');
    });

    test('isLowStock calculates accurately based on threshold', () {
      expect(testMed.isLowStock, isTrue);

      final highStockMed = testMed.copyWith(quantityOnHand: 30);
      expect(highStockMed.isLowStock, isFalse);
    });

    test('serialization round trip', () {
      final map = testMed.toMap();
      final restored = Medication.fromMap(map);

      expect(restored.id, testMed.id);
      expect(restored.name, testMed.name);
      expect(restored.strength, testMed.strength);
      expect(restored.isLowStock, testMed.isLowStock);
      expect(restored.quantityOnHand, testMed.quantityOnHand);
    });
  });

  group('AdherenceSummary tests', () {
    test('calculates percentage accurately', () {
      const summary1 = AdherenceSummary(taken: 3, total: 4, countable: 4);
      expect(summary1.percentage, 75.0);
      expect(summary1.percentageStr, '75%');

      const summaryZero = AdherenceSummary(taken: 0, total: 0, countable: 0);
      expect(summaryZero.percentage, 0.0);
      expect(summaryZero.percentageStr, '0%');

      const summaryAll = AdherenceSummary(taken: 5, total: 5, countable: 5);
      expect(summaryAll.percentage, 100.0);
      expect(summaryAll.percentageStr, '100%');
    });
  });
}
