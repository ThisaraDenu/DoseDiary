import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:dose_diary/core/router/route_names.dart';
import 'package:dose_diary/features/auth/verify_email/email_verification_screen.dart';
import 'package:dose_diary/main.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late SharedPreferences prefs;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
  });

  group('EmailVerificationScreen Widget Tests', () {
    testWidgets('renders email verification UI with 6 pin boxes and user email',
        (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            sharedPreferencesProvider.overrideWithValue(prefs),
          ],
          child: const MaterialApp(
            home: EmailVerificationScreen(
              email: 'patient@example.com',
            ),
          ),
        ),
      );

      await tester.pump();

      expect(find.text('Verify your email'), findsOneWidget);
      expect(find.text('patient@example.com'), findsOneWidget);
      expect(find.text('Verify & Continue'), findsOneWidget);
      expect(find.text('Resend Code'), findsOneWidget);
      expect(find.text('(45s)'), findsOneWidget);

      expect(find.byType(TextField), findsNWidgets(6));
      expect(find.text('Tap to fill'), findsNothing);
    });

    testWidgets('valid provider code triggers success animation',
        (tester) async {
      final router = GoRouter(
        initialLocation: '/verify-test',
        routes: [
          GoRoute(
            path: '/verify-test',
            builder: (context, state) => EmailVerificationScreen(
              email: 'patient@example.com',
              verifyCode: (email, code) async => code == '654321',
            ),
          ),
          GoRoute(
            path: RouteNames.permissions,
            builder: (context, state) =>
                const Scaffold(body: Text('Permissions destination')),
          ),
        ],
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            sharedPreferencesProvider.overrideWithValue(prefs),
          ],
          child: MaterialApp.router(routerConfig: router),
        ),
      );

      await tester.pump();

      final textFields = find.byType(TextField);
      const code = '654321';
      for (int i = 0; i < code.length; i++) {
        await tester.enterText(textFields.at(i), code[i]);
        await tester.pump();
      }
      await tester.pump(const Duration(milliseconds: 300));

      // After auto-fill and validation, Code Correct! animation badge should appear
      expect(find.text('Code Correct!'), findsOneWidget);
      expect(find.text('Opening app permissions...'), findsOneWidget);
      expect(find.text('Verified ✓'), findsOneWidget);

      // SharedPreferences should have onboarding_complete = true
      expect(prefs.getBool('onboarding_complete'), isTrue);

      // Advance through auto-navigation timer
      await tester.pump(const Duration(milliseconds: 1200));
      await tester.pumpAndSettle();
      expect(find.text('Permissions destination'), findsOneWidget);
    });

    testWidgets('entering wrong code displays error message', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            sharedPreferencesProvider.overrideWithValue(prefs),
          ],
          child: MaterialApp(
            home: EmailVerificationScreen(
              email: 'patient@example.com',
              verifyCode: (email, code) async => false,
            ),
          ),
        ),
      );

      await tester.pump();

      // Enter wrong code "11111" across textfields
      final textFields = find.byType(TextField);
      for (int i = 0; i < 6; i++) {
        await tester.enterText(textFields.at(i), '1');
        await tester.pump();
      }

      final verifyButton = find.text('Verify & Continue');
      await tester.tap(verifyButton, warnIfMissed: false);
      await tester.pumpAndSettle();

      expect(
          find.text('Incorrect code. Please check your email and try again.'),
          findsOneWidget);
      expect(find.text('Code Correct!'), findsNothing);
    });
  });
}
