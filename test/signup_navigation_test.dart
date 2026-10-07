import 'package:dose_diary/core/router/route_names.dart';
import 'package:dose_diary/features/auth/signup/signup_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

void main() {
  testWidgets('Log In opens the login page from a direct signup visit',
      (tester) async {
    final router = GoRouter(
      initialLocation: RouteNames.signup,
      routes: [
        GoRoute(
          path: RouteNames.signup,
          builder: (context, state) => const SignUpScreen(),
        ),
        GoRoute(
          path: RouteNames.login,
          builder: (context, state) =>
              const Scaffold(body: Text('Login destination')),
        ),
      ],
    );

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await tester.pumpAndSettle();

    final loginButton = find.text('Log In');
    await tester.ensureVisible(loginButton);
    await tester.tap(loginButton);
    await tester.pumpAndSettle();

    expect(find.text('Login destination'), findsOneWidget);
  });
}
