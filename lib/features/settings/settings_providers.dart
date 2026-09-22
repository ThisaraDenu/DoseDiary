import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../main.dart';

// ── Settings state ────────────────────────────────────────────────────────────

class AppSettings {
  const AppSettings({
    this.textScaleFactor = 1.0,
    this.simpleWording = false,
    this.locale = const Locale('en'),
    this.notificationRemindersEnabled = true,
    this.notificationSound = true,
    this.notificationVibration = true,
    this.privacySafePreviews = true,
    this.retryCount = 2,
    this.gracePeriodMinutes = 30,
  });

  final double textScaleFactor;
  final bool simpleWording;
  final Locale locale;
  final bool notificationRemindersEnabled;
  final bool notificationSound;
  final bool notificationVibration;
  final bool privacySafePreviews;
  final int retryCount;
  final int gracePeriodMinutes;

  AppSettings copyWith({
    double? textScaleFactor,
    bool? simpleWording,
    Locale? locale,
    bool? notificationRemindersEnabled,
    bool? notificationSound,
    bool? notificationVibration,
    bool? privacySafePreviews,
    int? retryCount,
    int? gracePeriodMinutes,
  }) =>
      AppSettings(
        textScaleFactor: textScaleFactor ?? this.textScaleFactor,
        simpleWording: simpleWording ?? this.simpleWording,
        locale: locale ?? this.locale,
        notificationRemindersEnabled:
            notificationRemindersEnabled ?? this.notificationRemindersEnabled,
        notificationSound: notificationSound ?? this.notificationSound,
        notificationVibration: notificationVibration ?? this.notificationVibration,
        privacySafePreviews: privacySafePreviews ?? this.privacySafePreviews,
        retryCount: retryCount ?? this.retryCount,
        gracePeriodMinutes: gracePeriodMinutes ?? this.gracePeriodMinutes,
      );
}

// ── Notifier ──────────────────────────────────────────────────────────────────

class SettingsNotifier extends StateNotifier<AppSettings> {
  SettingsNotifier(this._prefs) : super(_load(_prefs));

  final SharedPreferences _prefs;

  static AppSettings _load(SharedPreferences prefs) {
    final langCode = prefs.getString('language') ?? 'en';
    return AppSettings(
      textScaleFactor: prefs.getDouble('text_scale') ?? 1.0,
      simpleWording: prefs.getBool('simple_wording') ?? false,
      locale: Locale(langCode),
      notificationRemindersEnabled: prefs.getBool('notif_reminders') ?? true,
      notificationSound: prefs.getBool('notif_sound') ?? true,
      notificationVibration: prefs.getBool('notif_vibration') ?? true,
      privacySafePreviews: prefs.getBool('privacy_previews') ?? true,
      retryCount: prefs.getInt('retry_count') ?? 2,
      gracePeriodMinutes: prefs.getInt('grace_period') ?? 30,
    );
  }

  Future<void> setTextScale(double scale) async {
    await _prefs.setDouble('text_scale', scale);
    state = state.copyWith(textScaleFactor: scale);
  }

  Future<void> setSimpleWording(bool value) async {
    await _prefs.setBool('simple_wording', value);
    state = state.copyWith(simpleWording: value);
  }

  Future<void> setLanguage(String langCode) async {
    await _prefs.setString('language', langCode);
    state = state.copyWith(locale: Locale(langCode));
  }

  Future<void> setNotificationReminders(bool value) async {
    await _prefs.setBool('notif_reminders', value);
    state = state.copyWith(notificationRemindersEnabled: value);
  }

  Future<void> setNotificationSound(bool value) async {
    await _prefs.setBool('notif_sound', value);
    state = state.copyWith(notificationSound: value);
  }

  Future<void> setNotificationVibration(bool value) async {
    await _prefs.setBool('notif_vibration', value);
    state = state.copyWith(notificationVibration: value);
  }

  Future<void> setPrivacySafePreviews(bool value) async {
    await _prefs.setBool('privacy_previews', value);
    state = state.copyWith(privacySafePreviews: value);
  }

  Future<void> setRetryCount(int value) async {
    await _prefs.setInt('retry_count', value);
    state = state.copyWith(retryCount: value);
  }

  Future<void> setGracePeriod(int minutes) async {
    await _prefs.setInt('grace_period', minutes);
    state = state.copyWith(gracePeriodMinutes: minutes);
  }
}

// ── Provider ──────────────────────────────────────────────────────────────────

final settingsProvider = StateNotifierProvider<SettingsNotifier, AppSettings>((ref) {
  final prefs = ref.watch(sharedPreferencesProvider);
  return SettingsNotifier(prefs);
});
