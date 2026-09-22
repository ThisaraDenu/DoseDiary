import 'package:flutter/material.dart';

/// Stub AppLocalizations class.
/// Replace with flutter_gen or arb-based implementation for production.
class AppLocalizations {
  AppLocalizations(this.locale);
  final Locale locale;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations) ??
        AppLocalizations(const Locale('en'));
  }

  static const delegate = _AppLocalizationsDelegate();

  String get appTitle => 'DoseDiary';
  String get home => 'Home';
  String get medications => 'Medications';
  String get history => 'History';
  String get settings => 'Settings';
  String get taken => 'Taken';
  String get missed => 'Missed';
  String get skipped => 'Skipped';
  String get pending => 'Pending';
  String get overdue => 'Overdue';
  String get snoozed => 'Snoozed';
  String get logDose => "I've Taken It";
  String get snooze => 'Snooze Reminder';
  String get skip => 'Skip This Dose';
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  bool isSupported(Locale locale) =>
      ['en', 'si', 'ta'].contains(locale.languageCode);

  @override
  Future<AppLocalizations> load(Locale locale) async =>
      AppLocalizations(locale);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}
