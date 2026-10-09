import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/timezone.dart' as tz;

import '../data/remote/auth_service.dart';

class NotificationLaunch {
  const NotificationLaunch(this.payload, {this.actionId});

  final String payload;
  final String? actionId;
}

class NotificationService {
  static final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();
  static final StreamController<NotificationLaunch> _launchController =
      StreamController<NotificationLaunch>.broadcast();

  // Channel settings are immutable on Android. The new ID upgrades existing
  // installations from a normal reminder to a full medication alarm.
  static const _alarmChannelId = 'dose_diary_alarms_v2';
  static const _alarmChannelName = 'Medication alarms';
  static const _alarmChannelDesc =
      'Full-screen alarms when a medication dose is due';
  static const _generalChannelId = 'dose_diary_notifications';
  static const _generalChannelName = 'DoseDiary notifications';
  static const _generalChannelDesc = 'DoseDiary updates and health reminders';

  static NotificationLaunch? _initialLaunch;

  static Stream<NotificationLaunch> get launches => _launchController.stream;

  static NotificationLaunch? takeInitialLaunch() {
    final launch = _initialLaunch;
    _initialLaunch = null;
    return launch;
  }

  static Future<void> initialize() async {
    const androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    final iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
      notificationCategories: <DarwinNotificationCategory>[
        DarwinNotificationCategory(
          'dose_alarm',
          actions: <DarwinNotificationAction>[
            DarwinNotificationAction.plain(
              'taken',
              'Taken',
              options: <DarwinNotificationActionOption>{
                DarwinNotificationActionOption.foreground,
              },
            ),
            DarwinNotificationAction.plain(
              'snooze',
              'Remind in 5 min',
              options: <DarwinNotificationActionOption>{
                DarwinNotificationActionOption.foreground,
              },
            ),
            DarwinNotificationAction.plain(
              'skip',
              'Skip',
              options: <DarwinNotificationActionOption>{
                DarwinNotificationActionOption.foreground,
                DarwinNotificationActionOption.destructive,
              },
            ),
          ],
        ),
      ],
    );

    await _plugin.initialize(
      InitializationSettings(android: androidSettings, iOS: iosSettings),
      onDidReceiveNotificationResponse: _onNotificationResponse,
    );

    final launchDetails = await _plugin.getNotificationAppLaunchDetails();
    final response = launchDetails?.notificationResponse;
    if ((launchDetails?.didNotificationLaunchApp ?? false) &&
        response?.payload != null) {
      _initialLaunch = NotificationLaunch(
        response!.payload!,
        actionId: response.actionId,
      );
    }

    await _plugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.requestNotificationsPermission();
  }

  /// Requests Android's special alarm capabilities from the user. On older
  /// Android releases these methods simply return without showing UI.
  static Future<void> requestAlarmPermissions() async {
    final android = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    await android?.requestNotificationsPermission();
    await android?.requestExactAlarmsPermission();
    await android?.requestFullScreenIntentPermission();
  }

  static void _onNotificationResponse(NotificationResponse response) {
    final payload = response.payload;
    if (payload == null || payload.isEmpty) return;
    _launchController.add(
      NotificationLaunch(payload, actionId: response.actionId),
    );
  }

  static int notificationIdForDose(String occurrenceId) {
    var hash = 17;
    for (final unit in occurrenceId.codeUnits) {
      hash = (hash * 37 + unit) & 0x7fffffff;
    }
    return hash;
  }

  static Future<void> scheduleDoseAlarm({
    required String occurrenceId,
    required String medicationName,
    required String doseDescription,
    required DateTime scheduledAt,
  }) {
    return scheduleReminder(
      notificationId: notificationIdForDose(occurrenceId),
      title: 'Time for $medicationName',
      body: doseDescription,
      scheduledAt: scheduledAt,
      payload: 'dose:$occurrenceId',
    );
  }

  static Future<void> scheduleReminder({
    required int notificationId,
    required String title,
    required String body,
    required DateTime scheduledAt,
    String? payload,
    bool? safePreviews,
  }) async {
    if (!scheduledAt.isAfter(DateTime.now())) return;

    final preferences = await SharedPreferences.getInstance();
    final owner = AuthService.currentUser?.id ?? 'guest';
    T setting<T>(String name, T fallback) =>
        preferences.get('settings.$owner.$name') as T? ??
        preferences.get(name) as T? ??
        fallback;
    final remindersEnabled = setting<bool>('notif_reminders', true);
    if (!remindersEnabled) return;
    final useSafePreviews =
        safePreviews ?? setting<bool>('privacy_previews', true);
    final playSound = setting<bool>('notif_sound', true);
    final vibrate = setting<bool>('notif_vibration', true);
    final tz.TZDateTime tzTime = tz.TZDateTime.from(scheduledAt, tz.local);

    final displayTitle = useSafePreviews ? 'Medication alarm' : title;
    final displayBody = useSafePreviews
        ? 'It is time to take your scheduled medication.'
        : body;

    await _plugin.zonedSchedule(
      notificationId,
      displayTitle,
      displayBody,
      tzTime,
      NotificationDetails(
        android: AndroidNotificationDetails(
          _alarmChannelId,
          _alarmChannelName,
          channelDescription: _alarmChannelDesc,
          importance: Importance.max,
          priority: Priority.max,
          category: AndroidNotificationCategory.alarm,
          audioAttributesUsage: AudioAttributesUsage.alarm,
          fullScreenIntent: true,
          ongoing: true,
          autoCancel: false,
          timeoutAfter: 15 * 60 * 1000,
          additionalFlags: playSound ? Int32List.fromList(const [4]) : null,
          playSound: playSound,
          enableVibration: vibrate,
          vibrationPattern: vibrate
              ? Int64List.fromList(const [0, 800, 350, 800, 350, 1200])
              : null,
          visibility: useSafePreviews
              ? NotificationVisibility.private
              : NotificationVisibility.public,
          styleInformation: BigTextStyleInformation(displayBody),
          actions: const <AndroidNotificationAction>[
            AndroidNotificationAction(
              'taken',
              'Taken',
              showsUserInterface: true,
            ),
            AndroidNotificationAction(
              'snooze',
              'Remind in 5 min',
              showsUserInterface: true,
            ),
            AndroidNotificationAction(
              'skip',
              'Skip',
              showsUserInterface: true,
            ),
          ],
        ),
        iOS: DarwinNotificationDetails(
          categoryIdentifier: 'dose_alarm',
          interruptionLevel: InterruptionLevel.timeSensitive,
          presentAlert: true,
          presentBadge: true,
          presentSound: playSound,
        ),
      ),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      payload: payload,
    );
  }

  static Future<void> cancelDoseAlarm(String occurrenceId) =>
      cancelReminder(notificationIdForDose(occurrenceId));

  static Future<void> cancelReminder(int notificationId) async {
    await _plugin.cancel(notificationId);
  }

  static Future<void> cancelAll() async {
    await _plugin.cancelAll();
  }

  static Future<void> showImmediateNotification({
    required int id,
    required String title,
    required String body,
    String? payload,
  }) async {
    final preferences = await SharedPreferences.getInstance();
    final owner = AuthService.currentUser?.id ?? 'guest';
    T setting<T>(String name, T fallback) =>
        preferences.get('settings.$owner.$name') as T? ??
        preferences.get(name) as T? ??
        fallback;
    if (!setting<bool>('notif_reminders', true)) return;
    final safePreviews = setting<bool>('privacy_previews', true);
    final playSound = setting<bool>('notif_sound', true);
    final vibrate = setting<bool>('notif_vibration', true);

    await _plugin.show(
      id,
      safePreviews ? 'DoseDiary' : title,
      safePreviews ? 'You have a new health reminder' : body,
      NotificationDetails(
        android: AndroidNotificationDetails(
          _generalChannelId,
          _generalChannelName,
          channelDescription: _generalChannelDesc,
          importance: Importance.high,
          priority: Priority.high,
          playSound: playSound,
          enableVibration: vibrate,
          visibility: safePreviews
              ? NotificationVisibility.private
              : NotificationVisibility.public,
        ),
        iOS: DarwinNotificationDetails(
          presentSound: playSound,
          interruptionLevel: InterruptionLevel.timeSensitive,
        ),
      ),
      payload: payload,
    );
  }
}
