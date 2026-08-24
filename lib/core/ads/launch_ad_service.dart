import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'interstitial_ad_service.dart';

const _lastShownDateKey = 'launch_ad_last_shown_date';

/// アプリ起動時に1日1回だけ表示するインタースティシャル広告。
/// 「遊んだ／遊びたい」を記録するフローには一切関与しない、起動直後のみの広告枠。
class LaunchAdService {
  LaunchAdService(this._ad);

  final InterstitialAdService _ad;

  /// 今日まだ表示していなければ、読み込みを待ってから表示する。
  /// 広告の表示にまで至った場合のみ「今日表示済み」を記録する
  /// （読み込み失敗時は次回起動でも再度試せるようにするため）。
  Future<void> maybeShow() async {
    final prefs = await SharedPreferences.getInstance();
    final today = _todayString();
    if (prefs.getString(_lastShownDateKey) == today) return;

    final shown = await _ad.preloadAndShow();
    if (shown) {
      await prefs.setString(_lastShownDateKey, today);
    }
  }

  String _todayString() {
    final now = DateTime.now();
    return '${now.year.toString().padLeft(4, '0')}-'
        '${now.month.toString().padLeft(2, '0')}-'
        '${now.day.toString().padLeft(2, '0')}';
  }
}

final launchAdServiceProvider = Provider<LaunchAdService>((ref) {
  return LaunchAdService(InterstitialAdService());
});
