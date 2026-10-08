import 'package:dose_diary/features/medications/add_medication_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('fits dose controls and exposes image choices on a narrow screen',
      (tester) async {
    tester.view.physicalSize = const Size(340, 700);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(home: AddMedicationScreen()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Amount per dose'), findsOneWidget);
    expect(find.text('Add medication image'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.tap(find.text('Add medication image'));
    await tester.pumpAndSettle();

    expect(find.text('Take a photo'), findsOneWidget);
    expect(find.text('Choose from gallery'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('action buttons can be scrolled above the bottom clearance',
      (tester) async {
    tester.view.physicalSize = const Size(340, 700);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(home: AddMedicationScreen()),
      ),
    );

    final saveButton = find.text('Save Medication');
    await tester.scrollUntilVisible(
      saveButton,
      400,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();

    expect(find.text('Cancel'), findsOneWidget);
    expect(saveButton, findsOneWidget);
    expect(tester.getBottomRight(saveButton).dy, lessThan(700 - 72));
    expect(tester.takeException(), isNull);
  });
}
