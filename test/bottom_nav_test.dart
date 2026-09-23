import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dose_diary/core/widgets/dd_bottom_nav.dart';

void main() {
  group('DdBottomNav Tests', () {
    testWidgets('renders active item label and triggers onTap on tapping inactive item', (tester) async {
      int tappedIndex = -1;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            bottomNavigationBar: DdBottomNav(
              currentIndex: 0,
              onTap: (index) => tappedIndex = index,
            ),
          ),
        ),
      );

      // Verify active label for Home
      expect(find.text('Home'), findsOneWidget);

      // Tap on Medications (index 1)
      final medsSemantics = find.byWidgetPredicate(
        (widget) => widget is Semantics && widget.properties.label == 'Medications',
      );
      expect(medsSemantics, findsOneWidget);
      await tester.tap(medsSemantics);
      await tester.pump();

      expect(tappedIndex, 1);
    });

    testWidgets('smoothly animates active indicator when currentIndex changes', (tester) async {
      int currentIndex = 0;

      await tester.pumpWidget(
        StatefulBuilder(
          builder: (context, setState) {
            return MaterialApp(
              home: Scaffold(
                bottomNavigationBar: DdBottomNav(
                  currentIndex: currentIndex,
                  onTap: (index) {
                    setState(() => currentIndex = index);
                  },
                ),
              ),
            );
          },
        ),
      );

      expect(find.text('Home'), findsOneWidget);

      // Tap on Settings (index 3)
      final settingsSemantics = find.byWidgetPredicate(
        (widget) => widget is Semantics && widget.properties.label == 'Settings',
      );
      await tester.tap(settingsSemantics);
      await tester.pump();

      // Midway through animation
      await tester.pump(const Duration(milliseconds: 160));

      // Complete the animation
      await tester.pumpAndSettle();

      // Verify active label is now Settings
      expect(find.text('Settings'), findsOneWidget);
    });
  });
}
