import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _countKey = 'app_open_streak_count';
const _lastDateKey = 'app_open_last_date';

String _dateKey(DateTime date) =>
    '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

/// 「記録ストリーク」（週間記録ストリーク、対象は"遊んだ"を記録した週）とは別の、
/// 単純に「アプリを開いた日」の連続日数を数える指標。記録の有無を問わないぶん
/// ハードルが低く、混同を避けるため表示上も別のアイコン・文言を使う。
class AppOpenStreakService {
  AppOpenStreakService();

  /// 今日分の起動を記録し、直近の連続起動日数を返す。1日1回だけ呼んでも、
  /// 何度呼んでも安全（同じ日の呼び出しはカウントに影響しない）。
  Future<int> ensureTodayCounted() async {
    final prefs = await SharedPreferences.getInstance();
    final today = DateTime.now();
    final todayKey = _dateKey(today);
    final lastDateKey = prefs.getString(_lastDateKey);

    if (lastDateKey == todayKey) {
      return prefs.getInt(_countKey) ?? 1;
    }

    final yesterdayKey = _dateKey(today.subtract(const Duration(days: 1)));
    final currentCount = prefs.getInt(_countKey) ?? 0;
    final newCount = (lastDateKey == yesterdayKey) ? currentCount + 1 : 1;

    await prefs.setString(_lastDateKey, todayKey);
    await prefs.setInt(_countKey, newCount);
    return newCount;
  }

  Future<int> currentStreak() async {
    final prefs = await SharedPreferences.getInstance();
    final today = DateTime.now();
    final todayKey = _dateKey(today);
    final yesterdayKey = _dateKey(today.subtract(const Duration(days: 1)));
    final lastDateKey = prefs.getString(_lastDateKey);
    if (lastDateKey != todayKey && lastDateKey != yesterdayKey) return 0;
    return prefs.getInt(_countKey) ?? 0;
  }
}

final appOpenStreakServiceProvider = Provider<AppOpenStreakService>((ref) {
  return AppOpenStreakService();
});

/// マイログ画面のバッジ表示用。
final appOpenStreakProvider = FutureProvider<int>((ref) async {
  return ref.watch(appOpenStreakServiceProvider).currentStreak();
});
