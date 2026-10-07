import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:dose_diary/core/services/permission_service.dart';
import 'package:dose_diary/features/permissions/permissions_screen.dart';
import 'package:dose_diary/main.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late SharedPreferences prefs;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
  });

  group('PermissionsScreen Widget Tests', () {
    testWidgets('renders App permissions header, recommended and optional items', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            sharedPreferencesProvider.overrideWithValue(prefs),
            permissionsControllerProvider.overrideWith(
              (ref) => PermissionsController({
                AppPermissionType.notification: false,
                AppPermissionType.contacts: false,
                AppPermissionType.camera: false,
                AppPermissionType.microphone: false,
              }),
            ),
          ],
          child: const MaterialApp(
            home: PermissionsScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Header and title
      expect(find.text('App permissions'), findsOneWidget);
      expect(find.textContaining('Helpful reminders'), findsOneWidget);

      // Recommended Notifications Card
      expect(find.text('Notifications'), findsOneWidget);
      expect(find.text('Recommended'), findsOneWidget);

      // Optional items
      expect(find.text('Contacts'), findsOneWidget);
      expect(find.text('Camera'), findsOneWidget);
      expect(find.text('Microphone'), findsOneWidget);

      // Action buttons
      expect(find.text('Enable notifications'), findsOneWidget);
      expect(find.text('Not now'), findsOneWidget);
    });

    testWidgets('marks permissions_prompted as true in SharedPreferences when "Not now" is tapped', (tester) async {
      expect(PermissionService.hasPrompted(prefs), isFalse);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            sharedPreferencesProvider.overrideWithValue(prefs),
            permissionsControllerProvider.overrideWith(
              (ref) => PermissionsController({
                AppPermissionType.notification: false,
                AppPermissionType.contacts: false,
                AppPermissionType.camera: false,
                AppPermissionType.microphone: false,
              }),
            ),
          ],
          child: const MaterialApp(
            home: PermissionsScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      final notNowButton = find.text('Not now');
      expect(notNowButton, findsOneWidget);

      await tester.ensureVisible(notNowButton);
      await tester.tap(notNowButton);
      await tester.pumpAndSettle();

      expect(PermissionService.hasPrompted(prefs), isTrue);
    });

    testWidgets('shows Continue to DoseDiary when notification is already granted', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            sharedPreferencesProvider.overrideWithValue(prefs),
            permissionsControllerProvider.overrideWith(
              (ref) => PermissionsController({
                AppPermissionType.notification: true,
                AppPermissionType.contacts: true,
                AppPermissionType.camera: true,
                AppPermissionType.microphone: true,
              }),
            ),
          ],
          child: const MaterialApp(
            home: PermissionsScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Continue to DoseDiary'), findsOneWidget);
      expect(find.text('Enable notifications'), findsNothing);
    });
  });
}
