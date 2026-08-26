import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

import '../../features/game_log/domain/game_log.dart';
import '../../features/game_log/domain/weekly_streak.dart';

const _enabledKey = 'streak_reminder_enabled';
const _weekdayKey = 'streak_reminder_weekday';
const _hourKey = 'streak_reminder_hour';
const _minuteKey = 'streak_reminder_minute';
const _notificationId = 1002;

/// 週間記録ストリークが途切れそうな時に、ローカル通知でリマインドする。
/// `backlog_reminder_service.dart`と異なり、判定材料（今週すでに記録したか）は
/// 常に端末内にある`myLogsProvider`のデータのみで完結するため、
/// スケジュールのたびに本文を動的に組み立ててもサーバー往復は発生しない。
class StreakReminderService {
  StreakReminderService();

  final _plugin = FlutterLocalNotificationsPlugin();
  bool _initialized = false;

  Future<void> _ensureInitialized() async {
    if (_initialized) return;
    tz_data.initializeTimeZones();
    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings();
    await _plugin.initialize(
      settings: const InitializationSettings(
        android: androidSettings,
        iOS: iosSettings,
      ),
    );
    _initialized = true;
  }

  /// 明示的にOFFにされていない限りtrue（初期値はON）。
  Future<bool> isEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_enabledKey) ?? true;
  }

  /// リマインダーを有効化する。通知許可が得られなかった場合はfalseを返し、
  /// 設定側の状態も有効にしない。
  Future<bool> enable() async {
    await _ensureInitialized();

    final androidPlugin = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    final iosPlugin = _plugin.resolvePlatformSpecificImplementation<
        IOSFlutterLocalNotificationsPlugin>();

    final androidGranted =
        await androidPlugin?.requestNotificationsPermission() ?? true;
    final iosGranted = await iosPlugin?.requestPermissions(
          alert: true,
          badge: true,
          sound: true,
        ) ??
        true;

    if (!androidGranted || !iosGranted) return false;

    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_enabledKey, true);
    return true;
  }

  Future<void> disable() async {
    await _ensureInitialized();
    await _plugin.cancel(id: _notificationId);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_enabledKey, false);
  }

  /// 通知の曜日（`DateTime.monday`〜`DateTime.sunday`）と時刻。未設定時は
  /// 日曜20:00。
  Future<({int weekday, int hour, int minute})> getSchedule() async {
    final prefs = await SharedPreferences.getInstance();
    return (
      weekday: prefs.getInt(_weekdayKey) ?? DateTime.sunday,
      hour: prefs.getInt(_hourKey) ?? 20,
      minute: prefs.getInt(_minuteKey) ?? 0,
    );
  }

  Future<void> setSchedule({
    required int weekday,
    required int hour,
    required int minute,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_weekdayKey, weekday);
    await prefs.setInt(_hourKey, hour);
    await prefs.setInt(_minuteKey, minute);
  }

  /// 現在のログの状態から、今週分のリマインダーを再スケジュール（または解除）する。
  /// 無効化されている場合は何もしない。
  Future<void> syncSchedule(List<GameLogWithGame> logs) async {
    if (!await isEnabled()) return;
    await _ensureInitialized();

    final streak = currentWeeklyStreak(logs);
    final now = tz.TZDateTime.now(tz.local);
    final weekStart = now.subtract(Duration(days: now.weekday - 1));
    final hasLoggedThisWeek = logs.any(
      (e) =>
          e.log.status == GameLogStatus.played &&
          !e.log.createdAt.isBefore(
            DateTime(weekStart.year, weekStart.month, weekStart.day),
          ),
    );

    if (hasLoggedThisWeek) {
      await _plugin.cancel(id: _notificationId);
      return;
    }

    final schedule = await getSchedule();
    var scheduled = tz.TZDateTime(
      tz.local,
      now.year,
      now.month,
      now.day,
      schedule.hour,
      schedule.minute,
    );
    while (scheduled.weekday != schedule.weekday || scheduled.isBefore(now)) {
      scheduled = scheduled.add(const Duration(days: 1));
    }

    final body = streak > 0
        ? 'このままだと$streak週連続の記録が途切れてしまいます。今週はまだ「遊んだ」の記録がありません。'
        : '今週の記録をつけて、ストリークを始めましょう。';

    await _plugin.zonedSchedule(
      id: _notificationId,
      title: '記録ストリークが途切れそうです',
      body: body,
      scheduledDate: scheduled,
      notificationDetails: const NotificationDetails(
        android: AndroidNotificationDetails(
          'streak_reminder',
          '記録ストリークリマインダー',
          channelDescription: '週間記録ストリークが途切れそうな時にお知らせします',
          importance: Importance.defaultImportance,
        ),
        iOS: DarwinNotificationDetails(),
      ),
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
    );
  }
}

final streakReminderServiceProvider = Provider<StreakReminderService>((ref) {
  return StreakReminderService();
});

/// プロフィール画面のトグル表示用。有効・無効を切り替えたら
/// `ref.invalidate(streakReminderEnabledProvider)` で再取得する。
final streakReminderEnabledProvider = FutureProvider<bool>((ref) async {
  return ref.watch(streakReminderServiceProvider).isEnabled();
});
