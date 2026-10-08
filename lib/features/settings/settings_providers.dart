import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../main.dart';
import '../../data/local/database_provider.dart';
import '../../data/remote/auth_service.dart';

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
        notificationVibration:
            notificationVibration ?? this.notificationVibration,
        privacySafePreviews: privacySafePreviews ?? this.privacySafePreviews,
        retryCount: retryCount ?? this.retryCount,
        gracePeriodMinutes: gracePeriodMinutes ?? this.gracePeriodMinutes,
      );
}

// ── Notifier ──────────────────────────────────────────────────────────────────

class SettingsNotifier extends StateNotifier<AppSettings> {
  SettingsNotifier(this._prefs, this._ownerKey)
      : super(_load(_prefs, _ownerKey));

  final SharedPreferences _prefs;
  final String _ownerKey;

  static const _preferenceKeys = <String>[
    'text_scale',
    'simple_wording',
    'language',
    'notif_reminders',
    'notif_sound',
    'notif_vibration',
    'privacy_previews',
    'retry_count',
    'grace_period',
  ];

  String _key(String name) => 'settings.$_ownerKey.$name';

  static AppSettings _load(SharedPreferences prefs, String ownerKey) {
    String key(String name) => 'settings.$ownerKey.$name';
    T? value<T>(String name) =>
        prefs.get(key(name)) as T? ?? prefs.get(name) as T?;
    final langCode = value<String>('language') ?? 'en';
    return AppSettings(
      textScaleFactor: value<double>('text_scale') ?? 1.0,
      simpleWording: value<bool>('simple_wording') ?? false,
      locale: Locale(langCode),
      notificationRemindersEnabled: value<bool>('notif_reminders') ?? true,
      notificationSound: value<bool>('notif_sound') ?? true,
      notificationVibration: value<bool>('notif_vibration') ?? true,
      privacySafePreviews: value<bool>('privacy_previews') ?? true,
      retryCount: value<int>('retry_count') ?? 2,
      gracePeriodMinutes: value<int>('grace_period') ?? 30,
    );
  }

  Future<void> setTextScale(double scale) async {
    await _prefs.setDouble(_key('text_scale'), scale);
    state = state.copyWith(textScaleFactor: scale);
  }

  Future<void> setSimpleWording(bool value) async {
    await _prefs.setBool(_key('simple_wording'), value);
    state = state.copyWith(simpleWording: value);
  }

  Future<void> setLanguage(String langCode) async {
    await _prefs.setString(_key('language'), langCode);
    state = state.copyWith(locale: Locale(langCode));
  }

  Future<void> setNotificationReminders(bool value) async {
    await _prefs.setBool(_key('notif_reminders'), value);
    state = state.copyWith(notificationRemindersEnabled: value);
  }

  Future<void> setNotificationSound(bool value) async {
    await _prefs.setBool(_key('notif_sound'), value);
    state = state.copyWith(notificationSound: value);
  }

  Future<void> setNotificationVibration(bool value) async {
    await _prefs.setBool(_key('notif_vibration'), value);
    state = state.copyWith(notificationVibration: value);
  }

  Future<void> setPrivacySafePreviews(bool value) async {
    await _prefs.setBool(_key('privacy_previews'), value);
    state = state.copyWith(privacySafePreviews: value);
  }

  Future<void> setRetryCount(int value) async {
    await _prefs.setInt(_key('retry_count'), value);
    state = state.copyWith(retryCount: value);
  }

  Future<void> setGracePeriod(int minutes) async {
    await _prefs.setInt(_key('grace_period'), minutes);
    state = state.copyWith(gracePeriodMinutes: minutes);
  }

  Future<void> resetToDefaults() async {
    for (final name in _preferenceKeys) {
      await _prefs.remove(_key(name));
    }
    state = const AppSettings();
  }
}

// ── Provider ──────────────────────────────────────────────────────────────────

final settingsProvider =
    StateNotifierProvider<SettingsNotifier, AppSettings>((ref) {
  ref.watch(accountSessionEpochProvider);
  final prefs = ref.watch(sharedPreferencesProvider);
  final ownerKey = AuthService.currentUser?.id ?? 'guest';
  return SettingsNotifier(prefs, ownerKey);
});
