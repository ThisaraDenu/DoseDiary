import 'package:dose_diary/features/settings/settings_providers.dart';
import 'package:dose_diary/core/theme/app_colors.dart';
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
    await firstAccount.setThemeColor(AppThemeColor.oceanBlue);

    expect(firstAccount.state.locale.languageCode, 'ta');
    expect(firstAccount.state.notificationRemindersEnabled, isFalse);
    expect(firstAccount.state.themeColor, AppThemeColor.oceanBlue);
    expect(secondAccount.state.locale.languageCode, 'en');
    expect(secondAccount.state.notificationRemindersEnabled, isTrue);
    expect(secondAccount.state.themeColor, AppThemeColor.crimson);

    final reloadedFirst = SettingsNotifier(preferences, 'user-one');
    expect(reloadedFirst.state.locale.languageCode, 'ta');
    expect(reloadedFirst.state.notificationRemindersEnabled, isFalse);
    expect(reloadedFirst.state.themeColor, AppThemeColor.oceanBlue);
  });

  test('reset restores defaults without touching another account', () async {
    SharedPreferences.setMockInitialValues({
      'settings.user-one.text_scale': 1.5,
      'settings.user-one.privacy_previews': false,
      'settings.user-one.theme_color': 'teal',
      'settings.user-two.text_scale': 1.2,
    });
    final preferences = await SharedPreferences.getInstance();
    final firstAccount = SettingsNotifier(preferences, 'user-one');

    await firstAccount.resetToDefaults();

    expect(firstAccount.state.textScaleFactor, 1.0);
    expect(firstAccount.state.privacySafePreviews, isTrue);
    expect(firstAccount.state.themeColor, AppThemeColor.crimson);
    expect(preferences.getString('settings.user-one.theme_color'), isNull);
    expect(preferences.getDouble('settings.user-two.text_scale'), 1.2);
  });
}
