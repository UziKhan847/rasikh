import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:rasikh/core/reminder.dart';

/// The daily reminder schedules one local notification at the chosen time,
/// repeating daily, and cancels it again — with the notification plugin
/// answered by a fake platform channel.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('dexterous.com/flutter/local_notifications');
  final calls = <MethodCall>[];
  bool permission = true;

  setUp(() {
    calls.clear();
    permission = true;
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    // What the generated plugin registrant does when the app starts.
    AndroidFlutterLocalNotificationsPlugin.registerWith();
    final m = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    m.setMockMethodCallHandler(channel, (call) async {
      calls.add(call);
      return switch (call.method) {
        'initialize' => true,
        'requestNotificationsPermission' => permission,
        _ => null,
      };
    });
    m.setMockMethodCallHandler(
      const MethodChannel('flutter_timezone'),
      (call) async => 'UTC',
    );
  });

  tearDown(() => debugDefaultTargetPlatformOverride = null);

  test('enabling schedules a daily notification at the chosen time', () async {
    final ok = await DailyReminder.enable(
      minutesOfDay: 7 * 60 + 15,
      title: 'Qiraah',
      body: 'Time to read',
    );
    expect(ok, isTrue);
    final methods = calls.map((c) => c.method).toList();
    expect(methods, contains('requestNotificationsPermission'));
    final sched = calls.lastWhere((c) => c.method == 'zonedSchedule');
    final args = Map<String, Object?>.from(sched.arguments as Map);
    expect(args['id'], 1);
    expect(args['title'], 'Qiraah');
    expect(args['body'], 'Time to read');
    // Repeats every day at the same time of day.
    expect(args['matchDateTimeComponents'], isNotNull);
    expect('${args['scheduledDateTime']}', contains('07:15'));
  });

  test('a refused permission schedules nothing', () async {
    permission = false;
    final ok = await DailyReminder.enable(
      minutesOfDay: 20 * 60,
      title: 'Qiraah',
      body: 'Time to read',
    );
    expect(ok, isFalse);
    expect(calls.where((c) => c.method == 'zonedSchedule'), isEmpty);
  });

  test('disabling cancels it', () async {
    await DailyReminder.disable();
    final cancel = calls.lastWhere((c) => c.method == 'cancel');
    expect(Map<String, Object?>.from(cancel.arguments as Map)['id'], 1);
  });
}
