import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

const _enabledKey = 'backlog_reminder_enabled';
const _notificationId = 1001;

/// 「遊びたい」に積み上がったゲームを消化するよう、週1回ローカル通知でリマインドする。
/// サーバー側のプッシュ通知（新しいフォロワーなど）とは異なり、
/// このリマインダーは完全に端末内で完結する（FCM/APNsのサーバー連携は不要）ため、
/// 追加のバックエンド実装や外部コンソールでの設定なしに導入できる。
///
/// 通知本文は端末側で固定文言を表示するのみで、送信のたびにサーバーから
/// 「実際に積みゲーがあるか」を取得するような動的な内容にはしていない
/// （バックグラウンド処理の複雑化を避けるため）。
class BacklogReminderService {
  BacklogReminderService();

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

    await _schedule();

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

  Future<void> _schedule() async {
    final now = tz.TZDateTime.now(tz.local);
    // 毎週日曜19:00（既に過ぎていれば来週の同時刻から開始）。
    var scheduled = tz.TZDateTime(
      tz.local,
      now.year,
      now.month,
      now.day,
      19,
    );
    while (scheduled.weekday != DateTime.sunday || scheduled.isBefore(now)) {
      scheduled = scheduled.add(const Duration(days: 1));
    }

    await _plugin.zonedSchedule(
      id: _notificationId,
      title: '積みゲーはいかがですか？',
      body: '「遊びたい」に登録した作品を、今週は1本消化してみませんか。',
      scheduledDate: scheduled,
      notificationDetails: const NotificationDetails(
        android: AndroidNotificationDetails(
          'backlog_reminder',
          '積みゲーリマインダー',
          channelDescription: '「遊びたい」の消化を週1回リマインドします',
          importance: Importance.defaultImportance,
        ),
        iOS: DarwinNotificationDetails(),
      ),
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      matchDateTimeComponents: DateTimeComponents.dayOfWeekAndTime,
    );
  }
}

final backlogReminderServiceProvider = Provider<BacklogReminderService>((ref) {
  return BacklogReminderService();
});

/// プロフィール画面のトグル表示用。有効・無効を切り替えたら
/// `ref.invalidate(backlogReminderEnabledProvider)` で再取得する。
final backlogReminderEnabledProvider = FutureProvider<bool>((ref) async {
  return ref.watch(backlogReminderServiceProvider).isEnabled();
});
