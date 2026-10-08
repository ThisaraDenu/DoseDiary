import 'package:dose_diary/features/settings/settings_providers.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test('settings are stored separately for each account', () async {
    SharedPreferences.setMockInitialValues({});
    final preferences = await SharedPreferences.getInstance();
    final firstAccount = SettingsNotifier(preferences, 'user-one');
    final secondAccount = SettingsNotifier(preferences, 'user-two');

    await firstAccount.setLanguage('ta');
    await firstAccount.setNotificationReminders(false);

    expect(firstAccount.state.locale.languageCode, 'ta');
    expect(firstAccount.state.notificationRemindersEnabled, isFalse);
    expect(secondAccount.state.locale.languageCode, 'en');
    expect(secondAccount.state.notificationRemindersEnabled, isTrue);

    final reloadedFirst = SettingsNotifier(preferences, 'user-one');
    expect(reloadedFirst.state.locale.languageCode, 'ta');
    expect(reloadedFirst.state.notificationRemindersEnabled, isFalse);
  });

  test('reset restores defaults without touching another account', () async {
    SharedPreferences.setMockInitialValues({
      'settings.user-one.text_scale': 1.5,
      'settings.user-one.privacy_previews': false,
      'settings.user-two.text_scale': 1.2,
    });
    final preferences = await SharedPreferences.getInstance();
    final firstAccount = SettingsNotifier(preferences, 'user-one');

    await firstAccount.resetToDefaults();

    expect(firstAccount.state.textScaleFactor, 1.0);
    expect(firstAccount.state.privacySafePreviews, isTrue);
    expect(preferences.getDouble('settings.user-two.text_scale'), 1.2);
  });
}
