import 'package:dose_diary/features/settings/settings_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('shows the unique DoseDiary ID above settings sections',
      (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          userPublicIdProvider.overrideWith((ref) async => '#04217'),
        ],
        child: const MaterialApp(home: SettingsScreen()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Your DoseDiary ID'), findsOneWidget);
    expect(find.text('#04217'), findsOneWidget);
    expect(find.byIcon(Icons.copy_rounded), findsOneWidget);
  });

  testWidgets('allows an unavailable public ID to be requested again',
      (tester) async {
    var requestCount = 0;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          userPublicIdProvider.overrideWith((ref) async {
            requestCount++;
            return null;
          }),
        ],
        child: const MaterialApp(home: SettingsScreen()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('ID unavailable'), findsOneWidget);
    expect(find.byTooltip('Retry ID'), findsOneWidget);

    await tester.tap(find.byTooltip('Retry ID'));
    await tester.pumpAndSettle();

    expect(requestCount, 2);
  });
}
