import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

/// 「遊びたい」に登録した未発売ゲームの発売日当日にローカル通知でお知らせする。
/// 通知IDにはIGDBのgame_id（int）をそのまま使うため、ゲーム1件につき通知は1件に
/// 保たれ、再度スケジュールすれば上書き、[cancelForGame]で解除できる。
/// 積みゲーリマインダー（[BacklogReminderService]）と同様、完全に端末内で完結する
/// ローカル通知であり、サーバー側のプッシュ通知基盤（FCM/APNs）は必要ない。
class ReleaseReminderService {
  ReleaseReminderService();

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

  Future<bool> _requestPermission() async {
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
    return androidGranted && iosGranted;
  }

  /// [releaseDate]が未来の場合のみ、その日の9:00に発売お知らせ通知を予約する。
  /// 発売日が既に過ぎている・当日9:00を過ぎている場合は何もしない
  /// （呼び出し側で「未発売の遊びたいゲーム」だけに絞って呼ぶ想定）。
  Future<void> scheduleForGame({
    required int gameId,
    required String title,
    required DateTime releaseDate,
  }) async {
    await _ensureInitialized();

    final now = tz.TZDateTime.now(tz.local);
    final scheduled = tz.TZDateTime(
      tz.local,
      releaseDate.year,
      releaseDate.month,
      releaseDate.day,
      9,
    );
    if (!scheduled.isAfter(now)) return;

    final granted = await _requestPermission();
    if (!granted) return;

    await _plugin.zonedSchedule(
      id: gameId,
      title: '本日発売です',
      body: '「遊びたい」に登録した「$title」が本日発売されました。',
      scheduledDate: scheduled,
      notificationDetails: const NotificationDetails(
        android: AndroidNotificationDetails(
          'release_reminder',
          '発売日お知らせ',
          channelDescription: '「遊びたい」に登録した作品の発売日をお知らせします',
          importance: Importance.defaultImportance,
        ),
        iOS: DarwinNotificationDetails(),
      ),
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
    );
  }

  Future<void> cancelForGame(int gameId) async {
    await _ensureInitialized();
    await _plugin.cancel(id: gameId);
  }
}

final releaseReminderServiceProvider = Provider<ReleaseReminderService>((ref) {
  return ReleaseReminderService();
});
