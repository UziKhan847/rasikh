import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

/// The optional daily reminder (Settings → Learning): one local notification
/// a day at the time the learner picks. Nothing is sent anywhere — the
/// operating system shows it from the schedule kept on the device.
class DailyReminder {
  DailyReminder._();

  static const _id = 1;
  static final _plugin = FlutterLocalNotificationsPlugin();
  static bool _ready = false;

  /// Phones and macOS can schedule; the other desktops and the web cannot,
  /// so Settings hides the switch there.
  static bool get supported =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS ||
          defaultTargetPlatform == TargetPlatform.macOS);

  static Future<void> _init() async {
    if (_ready) return;
    tzdata.initializeTimeZones();
    try {
      final zone = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(zone.identifier));
    } catch (_) {
      // Unknown zone: stay on UTC; the reminder still fires daily.
    }
    await _plugin.initialize(
      settings: const InitializationSettings(
        android: AndroidInitializationSettings('ic_launcher_monochrome'),
        iOS: DarwinInitializationSettings(
          requestAlertPermission: false,
          requestBadgePermission: false,
          requestSoundPermission: false,
        ),
        macOS: DarwinInitializationSettings(
          requestAlertPermission: false,
          requestBadgePermission: false,
          requestSoundPermission: false,
        ),
      ),
    );
    _ready = true;
  }

  /// Asks for permission and schedules the reminder at [minutesOfDay] (local
  /// time). Returns false when it could not be scheduled (permission refused,
  /// or an unsupported platform).
  static Future<bool> enable(
      {required int minutesOfDay,
      required String title,
      required String body}) async {
    if (!supported) return false;
    try {
      await _init();
      bool? granted = true;
      if (defaultTargetPlatform == TargetPlatform.android) {
        granted = await _plugin
            .resolvePlatformSpecificImplementation<
                AndroidFlutterLocalNotificationsPlugin>()
            ?.requestNotificationsPermission();
      } else if (defaultTargetPlatform == TargetPlatform.iOS) {
        granted = await _plugin
            .resolvePlatformSpecificImplementation<
                IOSFlutterLocalNotificationsPlugin>()
            ?.requestPermissions(alert: true, sound: true);
      } else if (defaultTargetPlatform == TargetPlatform.macOS) {
        granted = await _plugin
            .resolvePlatformSpecificImplementation<
                MacOSFlutterLocalNotificationsPlugin>()
            ?.requestPermissions(alert: true, sound: true);
      }
      if (granted == false) return false;
      await _plugin.cancel(id: _id);
      final now = tz.TZDateTime.now(tz.local);
      var at = tz.TZDateTime(tz.local, now.year, now.month, now.day,
          minutesOfDay ~/ 60, minutesOfDay % 60);
      if (!at.isAfter(now)) at = at.add(const Duration(days: 1));
      await _plugin.zonedSchedule(
        id: _id,
        title: title,
        body: body,
        scheduledDate: at,
        notificationDetails: const NotificationDetails(
          android: AndroidNotificationDetails(
            'daily_reminder',
            'Daily reminder',
            channelDescription: 'A gentle daily reminder to read or learn.',
            importance: Importance.defaultImportance,
            priority: Priority.defaultPriority,
          ),
          iOS: DarwinNotificationDetails(),
          macOS: DarwinNotificationDetails(),
        ),
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        matchDateTimeComponents: DateTimeComponents.time,
      );
      return true;
    } catch (e, st) {
      debugPrint('[DailyReminder] $e\n$st');
      return false;
    }
  }

  static Future<void> disable() async {
    if (!supported) return;
    try {
      await _init();
      await _plugin.cancel(id: _id);
    } catch (_) {}
  }
}
