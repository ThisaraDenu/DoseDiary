import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dose_diary/core/widgets/dd_phone_input.dart';

void main() {
  group('CountryRegion Tests', () {
    test('defaultRegion is Sri Lanka (+94)', () {
      expect(CountryRegion.defaultRegion.code, 'LK');
      expect(CountryRegion.defaultRegion.dialCode, '+94');
      expect(CountryRegion.defaultRegion.flag, '🇱🇰');
    });

    test('matches searches name, code, or dialCode', () {
      const lk = CountryRegion.defaultRegion;
      expect(lk.matches('sri'), isTrue);
      expect(lk.matches('LK'), isTrue);
      expect(lk.matches('+94'), isTrue);
      expect(lk.matches('94'), isTrue);
      expect(lk.matches('usa'), isFalse);
    });

    test('parse extracts dialCode and national number', () {
      final parsedSriLanka = CountryRegion.parse('+94 771234567');
      expect(parsedSriLanka.region.code, 'LK');
      expect(parsedSriLanka.nationalNumber, '771234567');

      final parsedUS = CountryRegion.parse('+1 4155552671');
      expect(parsedUS.region.dialCode, '+1');
      expect(parsedUS.nationalNumber, '4155552671');
    });

    test('formatFullNumber produces clean international format', () {
      final formatted = DdPhoneInput.formatFullNumber(
        CountryRegion.defaultRegion,
        '77 123 4567',
      );
      expect(formatted, '+94 771234567');
    });
  });

  group('DdPhoneInput Widget Tests', () {
    testWidgets('renders phone label, region selector pill, and input field', (tester) async {
      final controller = TextEditingController();
      CountryRegion currentRegion = CountryRegion.defaultRegion;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: DdPhoneInput(
              controller: controller,
              selectedRegion: currentRegion,
              onRegionChanged: (reg) => currentRegion = reg,
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Phone Number'), findsOneWidget);
      expect(find.text('🇱🇰'), findsOneWidget);
      expect(find.text('+94'), findsOneWidget);
      expect(find.byType(TextFormField), findsOneWidget);
    });
  });
}
