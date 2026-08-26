import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

import '../../features/game_log/domain/game_log.dart';

const _enabledKey = 'memories_reminder_enabled';
const _notificationId = 1005;

/// 過去の同じ月日に記録した「遊んだ」ログがあれば、「○年前の今日、あなたは
/// 『{ゲーム名}』を記録していました」とローカル通知で振り返りを促す。
/// 既存の記録データだけで完結し、サーバー往復は不要。
class MemoriesReminderService {
  MemoriesReminderService();

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

  /// 今日の月日と一致する過去の「遊んだ」ログがあれば、今日20:00に単発通知を
  /// 積む（毎日アプリ起動時に呼び、当日分を上書き更新する）。無ければ解除する。
  Future<void> syncSchedule(List<GameLogWithGame> logs) async {
    if (!await isEnabled()) return;
    await _ensureInitialized();

    final now = DateTime.now();
    final pastMemories = logs
        .where((e) => e.log.status == GameLogStatus.played)
        .where((e) =>
            e.log.createdAt.month == now.month &&
            e.log.createdAt.day == now.day &&
            e.log.createdAt.year < now.year)
        .toList()
      ..sort((a, b) => a.log.createdAt.compareTo(b.log.createdAt));

    if (pastMemories.isEmpty) {
      await _plugin.cancel(id: _notificationId);
      return;
    }

    final oldest = pastMemories.first;
    final yearsAgo = now.year - oldest.log.createdAt.year;

    final tzNow = tz.TZDateTime.now(tz.local);
    var scheduled = tz.TZDateTime(tz.local, tzNow.year, tzNow.month, tzNow.day, 20);
    if (scheduled.isBefore(tzNow)) return;

    await _plugin.zonedSchedule(
      id: _notificationId,
      title: '今日は思い出の日です',
      body: '$yearsAgo年前の今日、『${oldest.game.displayName}』を記録していました。',
      scheduledDate: scheduled,
      notificationDetails: const NotificationDetails(
        android: AndroidNotificationDetails(
          'memories_reminder',
          '振り返り通知',
          channelDescription: '過去の同じ日に記録した作品をお知らせします',
          importance: Importance.defaultImportance,
        ),
        iOS: DarwinNotificationDetails(),
      ),
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
    );
  }
}

final memoriesReminderServiceProvider = Provider<MemoriesReminderService>((ref) {
  return MemoriesReminderService();
});

/// プロフィール画面のトグル表示用。有効・無効を切り替えたら
/// `ref.invalidate(memoriesReminderEnabledProvider)` で再取得する。
final memoriesReminderEnabledProvider = FutureProvider<bool>((ref) async {
  return ref.watch(memoriesReminderServiceProvider).isEnabled();
});
