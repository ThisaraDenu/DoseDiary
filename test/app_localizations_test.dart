import 'package:dose_diary/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Sinhala localizes navigation, accessibility, and home labels', () {
    const localizations = AppLocalizations(Locale('si'));

    expect(localizations.home, 'මුල් පිටුව');
    expect(localizations.settings, 'සැකසුම්');
    expect(localizations.tr('Accessibility'), 'ප්‍රවේශ්‍යතාව');
    expect(localizations.tr('Patient Mode'), 'රෝගී ප්‍රකාරය');
  });

  test('Tamil localizes navigation, accessibility, and caregiver labels', () {
    const localizations = AppLocalizations(Locale('ta'));

    expect(localizations.medications, 'மருந்துகள்');
    expect(localizations.history, 'வரலாறு');
    expect(localizations.tr('App Colour'), 'செயலி நிறம்');
    expect(localizations.tr('Caregiver Mode'), 'பராமரிப்பாளர் முறை');
  });

  test('English and unknown labels safely use their source text', () {
    const localizations = AppLocalizations(Locale('en'));

    expect(localizations.home, 'Home');
    expect(localizations.tr('Medicine name entered by user'),
        'Medicine name entered by user');
  });
}
