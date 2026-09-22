import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dose_diary/core/widgets/dd_button.dart';
import 'package:dose_diary/core/widgets/dd_google_button.dart';
import 'package:dose_diary/core/widgets/dd_status_badge.dart';
import 'package:dose_diary/core/widgets/dd_card.dart';
import 'package:dose_diary/core/widgets/dd_empty_state.dart';
import 'package:dose_diary/data/local/models/dose_status.dart';

void main() {
  group('Core Widgets Tests', () {
    testWidgets('DdButton renders label and fires callback on tap', (tester) async {
      bool tapped = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: DdButton(
              label: 'Take Medication',
              onPressed: () => tapped = true,
            ),
          ),
        ),
      );

      expect(find.text('Take Medication'), findsOneWidget);
      await tester.tap(find.text('Take Medication'));
      await tester.pump();
      expect(tapped, isTrue);
    });

    testWidgets('DdButton shows spinner when isLoading is true', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: DdButton(
              label: 'Saving',
              isLoading: true,
              onPressed: () {},
            ),
          ),
        ),
      );

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.text('Saving'), findsNothing);
    });

    testWidgets('DdStatusBadge renders appropriate text and style for statuses', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Column(
              children: [
                DdStatusBadge(status: DoseStatus.taken),
                DdStatusBadge(status: DoseStatus.missed),
                DdStatusBadge(status: DoseStatus.skipped),
                DdStatusBadge(status: DoseStatus.pending),
              ],
            ),
          ),
        ),
      );

      expect(find.text('Taken'), findsOneWidget);
      expect(find.text('Missed'), findsOneWidget);
      expect(find.text('Skipped'), findsOneWidget);
      expect(find.text('Pending'), findsOneWidget);
    });

    testWidgets('DdCard displays child content and handles tap if provided', (tester) async {
      bool tapped = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: DdCard(
              onTap: () => tapped = true,
              child: const Text('Metformin 500mg'),
            ),
          ),
        ),
      );

      expect(find.text('Metformin 500mg'), findsOneWidget);
      await tester.tap(find.text('Metformin 500mg'));
      await tester.pump();
      expect(tapped, isTrue);
    });

    testWidgets('DdEmptyState renders title and subtitle', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: DdEmptyState(
              icon: Icons.medication_outlined,
              title: 'No Medications',
              subtitle: 'Tap the button to add your first prescription.',
            ),
          ),
        ),
      );

      expect(find.text('No Medications'), findsOneWidget);
      expect(find.text('Tap the button to add your first prescription.'), findsOneWidget);
      expect(find.byIcon(Icons.medication_outlined), findsOneWidget);
    });

    testWidgets('DdGoogleButton renders label, logo, and fires tap callback', (tester) async {
      bool tapped = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: DdGoogleButton(
              onPressed: () => tapped = true,
            ),
          ),
        ),
      );

      expect(find.text('Continue with Google'), findsOneWidget);
      expect(find.byType(GoogleLogo), findsOneWidget);
      await tester.tap(find.text('Continue with Google'));
      await tester.pump();
      expect(tapped, isTrue);
    });
  });
}
