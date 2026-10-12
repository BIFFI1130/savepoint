import 'dart:convert';
import 'dart:io';

import 'package:shared_preferences/shared_preferences.dart';

import '../config/app_links.dart';

/// ストア上の最新バージョン情報。
class StoreVersionInfo {
  const StoreVersionInfo({
    required this.version,
    this.releaseNotes,
    required this.storeUrl,
  });

  final String version;
  final String? releaseNotes;
  final String storeUrl;
}

typedef StoreVersionFetcher = Future<StoreVersionInfo?> Function();

/// App Storeの公開情報（iTunes Lookup API、認証不要）から最新バージョンを取得する。
/// 取得できなかった場合（オフライン・審査中でまだ反映されていない等）はnull。
/// 反映はリリースから数時間遅れることがある。
Future<StoreVersionInfo?> fetchAppStoreVersion({
  Duration timeout = const Duration(seconds: 5),
}) async {
  final client = HttpClient()..connectionTimeout = timeout;
  try {
    final request = await client
        .getUrl(Uri.parse(AppLinks.appStoreLookupUrl))
        .timeout(timeout);
    final response = await request.close().timeout(timeout);
    if (response.statusCode != 200) return null;
    final body = await response.transform(utf8.decoder).join().timeout(timeout);
    final results = (jsonDecode(body) as Map<String, dynamic>)['results'];
    if (results is! List || results.isEmpty) return null;
    final first = results.first as Map<String, dynamic>;
    final version = first['version'] as String?;
    if (version == null) return null;
    return StoreVersionInfo(
      version: version,
      releaseNotes: first['releaseNotes'] as String?,
      storeUrl: AppLinks.appStoreUrl,
    );
  } catch (_) {
    return null;
  } finally {
    client.close(force: true);
  }
}

/// `1.0.10`のようなドット区切りの数値バージョンを比較し、[latest]が[current]より新しいか返す。
/// 数値として解釈できない場合は、誤ってお知らせを出さないよう false にする。
bool isNewerVersion(String latest, String current) {
  List<int>? parse(String v) {
    final parts = v.trim().split('.');
    final numbers = parts.map(int.tryParse).toList();
    return numbers.contains(null) ? null : numbers.cast<int>();
  }

  final l = parse(latest);
  final c = parse(current);
  if (l == null || c == null) return false;
  final length = l.length > c.length ? l.length : c.length;
  for (var i = 0; i < length; i++) {
    final lv = i < l.length ? l[i] : 0;
    final cv = i < c.length ? c[i] : 0;
    if (lv != cv) return lv > cv;
  }
  return false;
}

/// 新しいバージョンのお知らせを出すかどうかの判定と、「あとで」の記憶を担う。
/// 強制アップデート（[UpdateGateController]）とは別の、押し付けない通知用。
class AppUpdateNotice {
  AppUpdateNotice({
    required this.currentVersion,
    StoreVersionFetcher? fetcher,
    DateTime Function()? now,
  }) : _fetcher = fetcher ?? fetchAppStoreVersion,
       _now = now ?? DateTime.now;

  final String currentVersion;
  final StoreVersionFetcher _fetcher;
  final DateTime Function() _now;

  static const _dismissedKey = 'app_update_dismissed_version';
  static const _lastCheckKey = 'app_update_last_check_ms';
  static const checkInterval = Duration(hours: 12);

  /// お知らせを出すべき新バージョンがあればその情報を返す。
  /// 直近[checkInterval]以内に確認済み、または同じバージョンを「あとで」にした場合はnull。
  Future<StoreVersionInfo?> versionToAnnounce() async {
    final prefs = await SharedPreferences.getInstance();
    final nowMs = _now().millisecondsSinceEpoch;
    final lastCheck = prefs.getInt(_lastCheckKey);
    if (lastCheck != null &&
        nowMs - lastCheck < checkInterval.inMilliseconds) {
      return null;
    }
    final info = await _fetcher();
    // 取得に失敗した場合は確認済みにせず、次回の起動で再試行する。
    if (info == null) return null;
    await prefs.setInt(_lastCheckKey, nowMs);
    if (!isNewerVersion(info.version, currentVersion)) return null;
    if (prefs.getString(_dismissedKey) == info.version) return null;
    return info;
  }

  /// このバージョンのお知らせを以後出さない（次の新バージョンが出るまで）。
  Future<void> dismiss(String version) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_dismissedKey, version);
  }
}
