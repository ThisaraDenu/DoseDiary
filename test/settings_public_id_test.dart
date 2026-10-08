import 'package:dose_diary/features/settings/settings_screen.dart';
import 'package:dose_diary/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('shows the unique DoseDiary ID above settings sections',
      (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(
            await _preferences(),
          ),
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
          sharedPreferencesProvider.overrideWithValue(
            await _preferences(),
          ),
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

  testWidgets('shows all complete settings sections and current preferences',
      (tester) async {
    tester.view.physicalSize = const Size(420, 5000);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    final preferences = await _preferences({
      'settings.guest.language': 'ta',
      'settings.guest.notif_reminders': false,
      'settings.guest.privacy_previews': false,
    });

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(preferences),
          userPublicIdProvider.overrideWith((ref) async => '#04217'),
        ],
        child: const MaterialApp(home: SettingsScreen()),
      ),
    );
    await tester.pumpAndSettle();

    for (final section in [
      'MEDICATION & TRACKING',
      'CARE NETWORK',
      'PREFERENCES',
      'DATA & SECURITY',
      'HELP & INFORMATION',
      'SESSION',
    ]) {
      expect(find.text(section), findsOneWidget);
    }
    expect(find.text('Medication history'), findsOneWidget);
    expect(find.text('Tamil'), findsOneWidget);
    expect(find.text('Data & sync'), findsOneWidget);
    expect(find.text('Security & permissions'), findsOneWidget);
    expect(find.text('Detailed'), findsOneWidget);
    expect(find.text('About DoseDiary'), findsOneWidget);
  });
}

Future<SharedPreferences> _preferences([
  Map<String, Object> values = const {},
]) async {
  SharedPreferences.setMockInitialValues(values);
  return SharedPreferences.getInstance();
}
