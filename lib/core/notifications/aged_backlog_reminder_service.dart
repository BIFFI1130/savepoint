import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

import '../../features/game_log/domain/game_log.dart';

const _enabledKey = 'aged_backlog_reminder_enabled';
const _notificationId = 1003;
const _agedThresholdDays = 90;

/// 「遊びたい」に長期間（90日以上）放置されている作品を、ローカル通知で
/// 個別に知らせる。毎週固定文言で送る`backlog_reminder_service.dart`とは異なり、
/// こちらは対象が90日以上経過した最古の1件に絞られた時だけ、その作品名を
/// 含めた単発通知を送る（役割が重複しないよう別枠にしている）。
class AgedBacklogReminderService {
  AgedBacklogReminderService();

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

  Future<bool> isEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_enabledKey) ?? false;
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

  /// 現在のログの状態から、経年放置作品の通知を再スケジュール（または解除）する。
  /// 無効化されている場合は何もしない。
  Future<void> syncSchedule(List<GameLogWithGame> logs) async {
    if (!await isEnabled()) return;
    await _ensureInitialized();

    final now = DateTime.now();
    final agedWantToPlay = logs
        .where((e) => e.log.status == GameLogStatus.wantToPlay)
        .where((e) => now.difference(e.log.createdAt).inDays >= _agedThresholdDays)
        .toList()
      ..sort((a, b) => a.log.createdAt.compareTo(b.log.createdAt));

    if (agedWantToPlay.isEmpty) {
      await _plugin.cancel(id: _notificationId);
      return;
    }

    final oldest = agedWantToPlay.first;
    final tzNow = tz.TZDateTime.now(tz.local);
    var scheduled =
        tz.TZDateTime(tz.local, tzNow.year, tzNow.month, tzNow.day, 19);
    if (scheduled.isBefore(tzNow)) {
      scheduled = scheduled.add(const Duration(days: 1));
    }

    await _plugin.zonedSchedule(
      id: _notificationId,
      title: '積みゲーはいかがですか？',
      body: '『${oldest.game.displayName}』を登録してから3ヶ月以上経ちました。そろそろ遊んでみませんか？',
      scheduledDate: scheduled,
      notificationDetails: const NotificationDetails(
        android: AndroidNotificationDetails(
          'aged_backlog_reminder',
          '積みゲー経年アラート',
          channelDescription: '長期間手つかずの「遊びたい」作品をお知らせします',
          importance: Importance.defaultImportance,
        ),
        iOS: DarwinNotificationDetails(),
      ),
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
    );
  }
}

final agedBacklogReminderServiceProvider =
    Provider<AgedBacklogReminderService>((ref) {
  return AgedBacklogReminderService();
});

/// プロフィール画面のトグル表示用。有効・無効を切り替えたら
/// `ref.invalidate(agedBacklogReminderEnabledProvider)` で再取得する。
final agedBacklogReminderEnabledProvider = FutureProvider<bool>((ref) async {
  return ref.watch(agedBacklogReminderServiceProvider).isEnabled();
});
