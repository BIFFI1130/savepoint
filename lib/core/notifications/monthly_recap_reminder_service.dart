import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

const _enabledKey = 'monthly_recap_enabled';
const _notificationId = 1004;

/// 月末に「今月の振り返りができました」とローカル通知で知らせ、まとめ画面
/// （プレイ傾向診断のシェア導線）への再訪を促す。ローカル通知は本文をスケジュール
/// 時点で固定する必要があるため、具体的な件数などは含めず汎用的な文言にする
/// （月末時点の正確な集計値を事前に予測して埋め込むことはできないため）。
class MonthlyRecapReminderService {
  MonthlyRecapReminderService();

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

  /// 有効な場合、次回の月末通知が確実に積まれているようにする
  /// （すでに過ぎていれば翌月末に繰り越す）。アプリ起動のたびに呼んでよい。
  Future<void> ensureScheduled() async {
    if (!await isEnabled()) return;
    await _ensureInitialized();
    await _schedule();
  }

  Future<void> _schedule() async {
    final now = tz.TZDateTime.now(tz.local);
    var lastDay = tz.TZDateTime(tz.local, now.year, now.month + 1, 0, 21);
    if (lastDay.isBefore(now)) {
      lastDay = tz.TZDateTime(tz.local, now.year, now.month + 2, 0, 21);
    }

    await _plugin.zonedSchedule(
      id: _notificationId,
      title: '今月の記録、できました',
      body: '今月の振り返りを見てみましょう。あなたのゲーマータイプは変わったかも？',
      scheduledDate: lastDay,
      notificationDetails: const NotificationDetails(
        android: AndroidNotificationDetails(
          'monthly_recap',
          '月末ふりかえり',
          channelDescription: '月末に今月の記録の振り返りをお知らせします',
          importance: Importance.defaultImportance,
        ),
        iOS: DarwinNotificationDetails(),
      ),
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
    );
  }
}

final monthlyRecapReminderServiceProvider =
    Provider<MonthlyRecapReminderService>((ref) {
  return MonthlyRecapReminderService();
});

/// プロフィール画面のトグル表示用。有効・無効を切り替えたら
/// `ref.invalidate(monthlyRecapEnabledProvider)` で再取得する。
final monthlyRecapEnabledProvider = FutureProvider<bool>((ref) async {
  return ref.watch(monthlyRecapReminderServiceProvider).isEnabled();
});
