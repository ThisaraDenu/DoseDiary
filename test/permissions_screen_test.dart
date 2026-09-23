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
    testWidgets('renders all 5 requested permission items and header', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            sharedPreferencesProvider.overrideWithValue(prefs),
            permissionsControllerProvider.overrideWith(
              (ref) => PermissionsController({
                AppPermissionType.contacts: false,
                AppPermissionType.location: false,
                AppPermissionType.media: false,
                AppPermissionType.camera: false,
                AppPermissionType.calendar: false,
              }),
            ),
          ],
          child: const MaterialApp(
            home: PermissionsScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Header and description
      expect(find.text('Enable App Permissions'), findsOneWidget);
      expect(find.textContaining('To give you the safest, most personalized health tracking experience'), findsOneWidget);

      // 1. Contacts
      expect(find.text('Emergency Contacts & Caregivers'), findsOneWidget);
      expect(find.byIcon(Icons.contacts_rounded), findsOneWidget);

      // 2. Location
      expect(find.text('Nearby Medical & Pharmacies'), findsOneWidget);
      expect(find.byIcon(Icons.location_on_rounded), findsOneWidget);

      // 3. Media
      expect(find.text('Prescriptions & Photos'), findsOneWidget);
      expect(find.byIcon(Icons.perm_media_rounded), findsOneWidget);

      // 4. Camera
      expect(find.text('Camera & Barcode Scanner'), findsOneWidget);
      expect(find.byIcon(Icons.camera_alt_rounded), findsOneWidget);

      // 5. Calendar
      expect(find.text('Device Calendar Sync'), findsOneWidget);
      expect(find.byIcon(Icons.calendar_month_rounded), findsOneWidget);

      // Action buttons
      expect(find.text('Skip for now'), findsOneWidget);
      expect(find.text('Allow All Permissions'), findsOneWidget);
    });

    testWidgets('marks permissions_prompted as true in SharedPreferences when skip is tapped', (tester) async {
      expect(PermissionService.hasPrompted(prefs), isFalse);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            sharedPreferencesProvider.overrideWithValue(prefs),
            permissionsControllerProvider.overrideWith(
              (ref) => PermissionsController({
                AppPermissionType.contacts: false,
                AppPermissionType.location: false,
                AppPermissionType.media: false,
                AppPermissionType.camera: false,
                AppPermissionType.calendar: false,
              }),
            ),
          ],
          child: const MaterialApp(
            home: PermissionsScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      final skipButton = find.text('Skip for now');
      expect(skipButton, findsOneWidget);

      await tester.tap(skipButton);
      await tester.pumpAndSettle();

      expect(PermissionService.hasPrompted(prefs), isTrue);
    });

    testWidgets('shows Granted badge when all permissions are already granted', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            sharedPreferencesProvider.overrideWithValue(prefs),
            permissionsControllerProvider.overrideWith(
              (ref) => PermissionsController({
                AppPermissionType.contacts: true,
                AppPermissionType.location: true,
                AppPermissionType.media: true,
                AppPermissionType.camera: true,
                AppPermissionType.calendar: true,
              }),
            ),
          ],
          child: const MaterialApp(
            home: PermissionsScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // All 5 should have 'Granted' pills
      expect(find.text('Granted'), findsNWidgets(5));
      expect(find.text('Continue to DoseDiary'), findsOneWidget);
      expect(find.text('Allow All Permissions'), findsNothing);
    });
  });
}
