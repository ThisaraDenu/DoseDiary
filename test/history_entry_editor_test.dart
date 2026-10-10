import 'package:dose_diary/data/local/database_provider.dart';
import 'package:dose_diary/data/local/models/app_models.dart';
import 'package:dose_diary/data/local/models/dose_status.dart';
import 'package:dose_diary/data/repositories/app_repositories.dart';
import 'package:dose_diary/features/history/history_entry_editor.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';

void main() {
  final yesterday =
      DateUtils.dateOnly(DateTime.now()).subtract(const Duration(days: 1));
  final medication = Medication(
    id: 'med-1',
    userId: 'guest-user',
    name: 'Aspirin',
    strength: 75,
    strengthUnit: 'mg',
    amountPerDose: 1,
    doseUnit: 'tablet',
    isActive: true,
    quantityOnHand: 10,
    quantityUnit: 'tablets',
    createdAt: yesterday,
    updatedAt: yesterday,
  );

  Future<void> openEditor(WidgetTester tester, _RecordingRepository repo,
      {DoseOccurrence? occurrence, DoseEvent? event}) async {
    await tester.pumpWidget(ProviderScope(
      overrides: [doseRepositoryProvider.overrideWithValue(repo)],
      child: MaterialApp(
          home: Builder(
              builder: (context) => Scaffold(
                    body: TextButton(
                        onPressed: () => showDialog<DateTime>(
                              context: context,
                              builder: (_) => HistoryEntryEditor(
                                medications: [medication],
                                initialDate: yesterday,
                                occurrence: occurrence,
                                event: event,
                              ),
                            ),
                        child: const Text('Open')),
                  ))),
    ));
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
  }

  testWidgets(
      'adds a past skipped dose with its reason and selected medication',
      (tester) async {
    final repo = _RecordingRepository();
    await openEditor(tester, repo);
    await tester.tap(find.byKey(const ValueKey('history-status')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Skipped').last);
    await tester.pumpAndSettle();
    await tester.enterText(
        find.byKey(const ValueKey('history-skip-reason')), 'Felt unwell');
    await tester.tap(find.byKey(const ValueKey('save-history-entry')));
    await tester.pumpAndSettle();
    expect(repo.medicationId, 'med-1');
    expect(repo.status, DoseStatus.skipped);
    expect(repo.skipReason, 'Felt unwell');
    expect(repo.occurrenceId, isNull);
    expect(DateUtils.isSameDay(repo.doseTime, yesterday), isTrue);
    expect(find.text('Add past dose'), findsNothing);
  });

  testWidgets('edits an existing entry and preserves its recorded time',
      (tester) async {
    final repo = _RecordingRepository();
    final takenAt = yesterday.add(const Duration(hours: 9, minutes: 15));
    final occurrence = DoseOccurrence(
      id: 'dose-1',
      scheduleId: 'schedule-1',
      medicationId: medication.id,
      userId: medication.userId,
      scheduledAt: yesterday.add(const Duration(hours: 8)),
      localDate: DateFormat('yyyy-MM-dd').format(yesterday),
      occurrenceKey: 'dose-1',
      status: DoseStatus.taken,
      createdAt: yesterday,
    );
    final event = DoseEvent(
      id: 'event-1',
      occurrenceId: occurrence.id,
      userId: medication.userId,
      action: 'taken',
      recordedAt: takenAt,
      clientId: 'event-1',
      createdAt: yesterday,
    );
    await openEditor(tester, repo, occurrence: occurrence, event: event);
    expect(find.text('9:15 AM'), findsOneWidget);
    final picker = tester.widget<DropdownButtonFormField<String>>(
        find.byKey(const ValueKey('history-medication')));
    expect(picker.onChanged, isNull);
    await tester.tap(find.byKey(const ValueKey('history-status')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Missed').last);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('save-history-entry')));
    await tester.pumpAndSettle();
    expect(repo.occurrenceId, 'dose-1');
    expect(repo.status, DoseStatus.missed);
    expect(repo.doseTime, takenAt);
  });

  testWidgets('cancel does not save and failed saves allow retry',
      (tester) async {
    final repo = _RecordingRepository();
    await openEditor(tester, repo);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(repo.calls, 0);
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    repo.fail = true;
    await tester.tap(find.byKey(const ValueKey('save-history-entry')));
    await tester.pumpAndSettle();
    expect(find.text('Could not save history. Try again.'), findsOneWidget);
    repo.fail = false;
    await tester.tap(find.byKey(const ValueKey('save-history-entry')));
    await tester.pumpAndSettle();
    expect(repo.calls, 2);
    expect(find.text('Add past dose'), findsNothing);
  });

  test('repository rejects future doses and unrecorded statuses', () async {
    final repo = DoseRepository(AppDatabase.instance);
    await expectLater(
        repo.saveHistoryEntry(
          medicationId: medication.id,
          doseTime: DateTime.now().add(const Duration(days: 1)),
          status: DoseStatus.taken,
        ),
        throwsArgumentError);
    await expectLater(
        repo.saveHistoryEntry(
          medicationId: medication.id,
          doseTime: yesterday,
          status: DoseStatus.pending,
        ),
        throwsArgumentError);
  });
}

class _RecordingRepository extends DoseRepository {
  _RecordingRepository() : super(AppDatabase.instance);
  String? medicationId;
  String? occurrenceId;
  String? skipReason;
  DateTime? doseTime;
  DoseStatus? status;
  int calls = 0;
  bool fail = false;

  @override
  Future<void> saveHistoryEntry(
      {required String medicationId,
      required DateTime doseTime,
      required DoseStatus status,
      String? occurrenceId,
      String? skipReason}) async {
    calls++;
    if (fail) throw StateError('Save failed');
    this.medicationId = medicationId;
    this.doseTime = doseTime;
    this.status = status;
    this.occurrenceId = occurrenceId;
    this.skipReason = skipReason;
  }
}
