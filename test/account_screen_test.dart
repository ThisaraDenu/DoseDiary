import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dose_diary/features/settings/account_screen.dart';

void main() {
  group('AccountScreen Widget Tests', () {
    testWidgets('renders profile editing form, avatar, and account info', (tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: AccountScreen(),
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      // AppBar title
      expect(find.text('Profile & Account'), findsOneWidget);

      // Avatar camera button
      expect(find.byIcon(Icons.camera_alt_rounded), findsOneWidget);

      // Name field and button
      expect(find.text('Personal Info'), findsOneWidget);
      expect(find.text('Full Name'), findsOneWidget);
      expect(find.text('Save Profile Changes'), findsOneWidget);

      // Account & Security section
      expect(find.text('Account & Security'), findsOneWidget);
      expect(find.text('Email Address'), findsOneWidget);
      expect(find.text('Supabase User ID'), findsOneWidget);
    });

    testWidgets('shows change photo bottom sheet on camera button tap', (tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: AccountScreen(),
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      final cameraIcon = find.byIcon(Icons.camera_alt_rounded);
      expect(cameraIcon, findsOneWidget);

      await tester.tap(cameraIcon);
      await tester.pumpAndSettle();

      expect(find.text('Change Profile Photo'), findsOneWidget);
      expect(find.text('Take a photo'), findsOneWidget);
      expect(find.text('Choose from gallery'), findsOneWidget);
    });
  });
}
