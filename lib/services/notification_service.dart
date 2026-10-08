import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/timezone.dart' as tz;

import '../data/remote/auth_service.dart';

class NotificationService {
  static final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  static const _channelId = 'dose_diary_reminders';
  static const _channelName = 'Dose Reminders';
  static const _channelDesc = 'Medication dose reminder notifications';

  static Future<void> initialize() async {
    const androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    await _plugin.initialize(
      const InitializationSettings(android: androidSettings, iOS: iosSettings),
      onDidReceiveNotificationResponse: _onNotificationTap,
    );

    // Request Android 13+ notification permission
    await _plugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.requestNotificationsPermission();
  }

  static void _onNotificationTap(NotificationResponse response) {
    // Navigate to reminder screen using the payload (occurrence ID)
    // In a full app this would use the navigator key or router
    // ignore: avoid_print
    print('[NotificationService] Notification tapped: ${response.payload}');
  }

  static Future<void> scheduleReminder({
    required int notificationId,
    required String title,
    required String body,
    required DateTime scheduledAt,
    String? payload,
    bool? safePreviews,
  }) async {
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

    final displayTitle = useSafePreviews ? 'DoseDiary' : title;
    final displayBody = useSafePreviews ? 'Time to take your medication' : body;

    await _plugin.zonedSchedule(
      notificationId,
      displayTitle,
      displayBody,
      tzTime,
      NotificationDetails(
        android: AndroidNotificationDetails(
          _channelId,
          _channelName,
          channelDescription: _channelDesc,
          importance: Importance.high,
          priority: Priority.high,
          category: AndroidNotificationCategory.reminder,
          playSound: playSound,
          enableVibration: vibrate,
          visibility: useSafePreviews
              ? NotificationVisibility.private
              : NotificationVisibility.public,
        ),
        iOS: DarwinNotificationDetails(
          categoryIdentifier: 'dose_reminder',
          interruptionLevel: InterruptionLevel.timeSensitive,
          presentSound: playSound,
        ),
      ),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      payload: payload,
    );
  }

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
    await _plugin.show(
      id,
      title,
      body,
      const NotificationDetails(
        android: AndroidNotificationDetails(
          _channelId,
          _channelName,
          channelDescription: _channelDesc,
          importance: Importance.high,
          priority: Priority.high,
        ),
      ),
      payload: payload,
    );
  }
}
