import 'package:dose_diary/core/router/route_names.dart';
import 'package:dose_diary/core/services/permission_service.dart';
import 'package:dose_diary/features/auth/login/login_screen.dart';
import 'package:dose_diary/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('regular Log In uses email sign-in and opens home',
      (tester) async {
    SharedPreferences.setMockInitialValues({
      PermissionService.keyPermissionsPrompted: true,
    });
    final prefs = await SharedPreferences.getInstance();
    String? receivedEmail;
    String? receivedPassword;

    final router = GoRouter(
      initialLocation: RouteNames.login,
      routes: [
        GoRoute(
          path: RouteNames.login,
          builder: (context, state) => LoginScreen(
            emailPasswordSignIn: ({required email, required password}) async {
              receivedEmail = email;
              receivedPassword = password;
            },
          ),
        ),
        GoRoute(
          path: RouteNames.home,
          builder: (context, state) =>
              const Scaffold(body: Text('Home destination')),
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
        overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await tester.pumpAndSettle();

    await tester.enterText(
      find.widgetWithText(TextFormField, 'you@example.com'),
      ' Patient@Example.com ',
    );
    await tester.enterText(find.byType(TextFormField).at(1), 'password123');
    await tester.tap(find.widgetWithText(ElevatedButton, 'Log In'));
    await tester.pumpAndSettle();

    expect(receivedEmail, 'patient@example.com');
    expect(receivedPassword, 'password123');
    expect(find.text('Home destination'), findsOneWidget);
  });
}
