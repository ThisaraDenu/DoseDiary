import 'package:dose_diary/core/router/route_names.dart';
import 'package:dose_diary/features/auth/complete_profile/complete_google_profile_screen.dart';
import 'package:dose_diary/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late SharedPreferences prefs;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
  });

  testWidgets('saves Google profile details and opens app permissions',
      (tester) async {
    Map<String, dynamic>? savedProfile;
    final router = GoRouter(
      initialLocation: '/complete-profile-test',
      routes: [
        GoRoute(
          path: '/complete-profile-test',
          builder: (context, state) => CompleteGoogleProfileScreen(
            profileLoader: () async => {
              'email': 'patient@gmail.com',
              'full_name': 'Google User',
              'date_of_birth': '1995-04-12',
              'gender': 'Prefer not to say',
              'phone_number': '+94771234567',
            },
            profileSaver: (updates) async {
              savedProfile = Map<String, dynamic>.from(updates);
            },
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
    await tester.pumpAndSettle();

    expect(find.text('Complete your profile'), findsOneWidget);
    expect(find.text('patient@gmail.com'), findsOneWidget);
    expect(find.text('Full name'), findsOneWidget);
    expect(find.text('Phone number'), findsOneWidget);
    expect(find.text('Birthday'), findsOneWidget);
    expect(find.text('Gender'), findsOneWidget);

    final continueButton = find.text('Save & Continue');
    await tester.ensureVisible(continueButton);
    await tester.tap(continueButton);
    await tester.pumpAndSettle();

    expect(savedProfile, isNotNull);
    expect(savedProfile!['full_name'], 'Google User');
    expect(savedProfile!['date_of_birth'], '1995-04-12');
    expect(savedProfile!['gender'], 'Prefer not to say');
    expect(savedProfile!['phone_number'], '+94 771234567');
    expect(prefs.getBool('onboarding_complete'), isTrue);
    expect(find.text('Permissions destination'), findsOneWidget);
  });

  testWidgets('requires all profile details before continuing', (tester) async {
    var saveCalls = 0;

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
        ],
        child: MaterialApp(
          home: CompleteGoogleProfileScreen(
            profileLoader: () async => null,
            profileSaver: (updates) async => saveCalls++,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final continueButton = find.text('Save & Continue');
    await tester.ensureVisible(continueButton);
    await tester.tap(continueButton);
    await tester.pump();

    expect(saveCalls, 0);
    expect(find.text('Full name is required'), findsOneWidget);
    expect(find.text('Birthday is required'), findsOneWidget);
    expect(find.text('Gender is required'), findsOneWidget);
  });
}
