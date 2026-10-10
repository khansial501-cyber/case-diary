import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;
import '../core/providers.dart';
import '../core/utils.dart';

/// Low-level wrapper around flutter_local_notifications (initialised in main()).
class NotificationService {
  NotificationService._();
  static final NotificationService instance = NotificationService._();
  final FlutterLocalNotificationsPlugin plugin = FlutterLocalNotificationsPlugin();
  bool ready = false;

  Future<void> init() async {
    try {
      tzdata.initializeTimeZones();
      final name = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(name));
    } catch (_) {
      tz.setLocalLocation(tz.getLocation('Asia/Karachi'));
    }
    await plugin.initialize(const InitializationSettings(android: AndroidInitializationSettings('@mipmap/ic_launcher')));
    final a = plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
    await a?.createNotificationChannel(const AndroidNotificationChannel('reminders', 'Case reminders',
        importance: Importance.high, description: 'Reminders you set on a case'));
    await a?.createNotificationChannel(const AndroidNotificationChannel('digest', 'Hearing digest',
        importance: Importance.high, description: 'Daily summary of tomorrow\'s hearings'));
    ready = true;
  }

  NotificationDetails details(String channel, {String? bigText}) => NotificationDetails(
        android: AndroidNotificationDetails(
          channel,
          channel == 'digest' ? 'Hearing digest' : 'Case reminders',
          importance: Importance.high,
          priority: Priority.high,
          styleInformation: bigText == null ? null : BigTextStyleInformation(bigText),
        ),
      );

  Future<void> schedule(int id, String title, String body, DateTime when, String channel,
      {DateTimeComponents? repeat}) async {
    if (!ready) return;
    final t = tz.TZDateTime.from(when, tz.local);
    Future<void> go(AndroidScheduleMode mode) => plugin.zonedSchedule(
          id, title, body, t, details(channel, bigText: body),
          androidScheduleMode: mode,
          uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
          matchDateTimeComponents: repeat,
        );
    try {
      await go(AndroidScheduleMode.exactAllowWhileIdle);
    } catch (_) {
      try {
        await go(AndroidScheduleMode.inexactAllowWhileIdle);
      } catch (e) {
        debugPrint('schedule failed: $e');
      }
    }
  }

  Future<void> cancel(int id) async => ready ? plugin.cancel(id) : null;
}

/// Friendly permission flow (Android 13+ notifications, Android 12+ exact alarms).
Future<bool> ensureNotificationPermissions() async {
  var n = await Permission.notification.status;
  if (!n.isGranted) n = await Permission.notification.request();
  final ex = await Permission.scheduleExactAlarm.status;
  if (!ex.isGranted) await Permission.scheduleExactAlarm.request();
  return n.isGranted;
}

const _eveningBase = 900000, _morningBase = 900050, _weeklyBackupId = 990001;

class NotificationController {
  final Ref ref;
  NotificationController(this.ref);
  NotificationService get _n => NotificationService.instance;

  Future<void> scheduleCaseReminder({required String caseId, required DateTime when, required String message}) async {
    await ensureNotificationPermissions();
    final id = await ref.read(repoProvider).addReminder(caseId, when, message);
    if (when.isAfter(DateTime.now())) {
      await _n.schedule(id, ref.read(settingsProvider).firmName.isEmpty ? 'Case Diary' : ref.read(settingsProvider).firmName,
          message, when, 'reminders');
    }
  }

  Future<void> cancelReminder(int notificationId) => _n.cancel(notificationId);

  Future<void> cancelCaseReminders(String caseId) async {
    final repo = ref.read(repoProvider);
    for (final r in await repo.reminders(caseId: caseId)) {
      await _n.cancel(r.notificationId);
      await repo.setReminderDone(r.id, true);
    }
  }

  /// Rebuilds the next 14 days of digests with up-to-date counts. Called after every data change.
  Future<void> rebuildDigests() async {
    if (!_n.ready) return;
    final s = ref.read(settingsProvider);
    for (var i = 0; i < 14; i++) {
      await _n.cancel(_eveningBase + i);
      await _n.cancel(_morningBase + i);
    }
    final repo = ref.read(repoProvider);
    final l = ref.read(l10nProvider);
    final now = DateTime.now();
    final td = today();
    final eveH = int.tryParse(s.get('digestHour', '20')) ?? 20, eveM = int.tryParse(s.get('digestMinute', '0')) ?? 0;
    final morH = int.tryParse(s.get('morningHour', '8')) ?? 8, morM = int.tryParse(s.get('morningMinute', '0')) ?? 0;
    final eveningOn = s.flag('digestEnabled', true), morningOn = s.flag('morningDigest', false);
    for (var i = 0; i < 14; i++) {
      final day = td.add(Duration(days: i));
      if (eveningOn) {
        final at = DateTime(day.year, day.month, day.day, eveH, eveM);
        if (at.isAfter(now)) {
          final hearing = await repo.casesOn(ymd(day.add(const Duration(days: 1))));
          if (hearing.isNotEmpty) {
            await _n.schedule(_eveningBase + i, l.f('digestTitleTomorrow', {'n': '${hearing.length}'}), _list(hearing.map((e) => e.title).toList(), l), at, 'digest');
          }
        }
      }
      if (morningOn) {
        final at = DateTime(day.year, day.month, day.day, morH, morM);
        if (at.isAfter(now)) {
          final hearing = await repo.casesOn(ymd(day));
          if (hearing.isNotEmpty) {
            await _n.schedule(_morningBase + i, l.f('digestTitleToday', {'n': '${hearing.length}'}), _list(hearing.map((e) => e.title).toList(), l), at, 'digest');
          }
        }
      }
    }
  }

  String _list(List<String> t, L10n l) {
    final shown = t.take(6).join('\n');
    return t.length > 6 ? '$shown\n+${t.length - 6}' : shown;
  }

  /// After restoring a backup / first launch: re-create every pending reminder + digests + backup nudge.
  Future<void> rescheduleAll() async {
    final repo = ref.read(repoProvider);
    final s = ref.read(settingsProvider);
    for (final r in await repo.reminders(upcomingOnly: true)) {
      await _n.schedule(r.notificationId, s.firmName.isEmpty ? 'Case Diary' : s.firmName, r.message, r.when, 'reminders');
    }
    await rebuildDigests();
    await scheduleWeeklyBackupReminder();
  }

  Future<void> scheduleWeeklyBackupReminder() async {
    await _n.cancel(_weeklyBackupId);
    final s = ref.read(settingsProvider);
    if (!s.flag('backupReminder', true) || !_n.ready) return;
    final l = ref.read(l10nProvider);
    var d = DateTime.now();
    d = DateTime(d.year, d.month, d.day, 10);
    while (d.weekday != DateTime.sunday || d.isBefore(DateTime.now())) {
      d = d.add(const Duration(days: 1));
    }
    await _n.schedule(_weeklyBackupId, l('backupReminderTitle'), l('backupReminderBody'), d, 'reminders',
        repeat: DateTimeComponents.dayOfWeekAndTime);
  }
}

final notificationServiceProvider = Provider<NotificationController>((ref) => NotificationController(ref));
