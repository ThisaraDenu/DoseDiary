import 'package:dose_diary/features/settings/settings_detail_screens.dart';
import 'package:dose_diary/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('data and sync shows real local summary and export access',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    final preferences = await SharedPreferences.getInstance();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(preferences),
          settingsDataSummaryProvider.overrideWith(
            (ref) async => const SettingsDataSummary(medications: 4, doses: 28),
          ),
        ],
        child: const MaterialApp(home: DataSyncSettingsScreen()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Data & Sync'), findsOneWidget);
    expect(find.text('Local device only'), findsOneWidget);
    expect(find.text('4'), findsOneWidget);
    expect(find.text('28'), findsOneWidget);
    expect(find.text('Download medication history'), findsOneWidget);
  });

  testWidgets('security page exposes privacy, permissions and safe reset',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    final preferences = await SharedPreferences.getInstance();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(preferences),
        ],
        child: const MaterialApp(home: SecuritySettingsScreen()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Security & Permissions'), findsOneWidget);
    expect(find.text('Private notification previews'), findsOneWidget);
    expect(find.text('App permissions'), findsOneWidget);
    expect(find.text('Reset app preferences'), findsOneWidget);
  });
}
