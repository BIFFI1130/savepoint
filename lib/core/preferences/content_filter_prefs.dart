import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _includeAdultKey = 'content_filter_include_adult';
const _includeIndieKey = 'content_filter_include_indie';

/// main()で読み込み済みの[SharedPreferences]を受け取るためのプロバイダー。
/// main()側で`overrideWithValue`する前提のため、初期値は未実装例外にしている。
final sharedPreferencesProvider = Provider<SharedPreferences>((ref) {
  throw UnimplementedError('main()でoverrideWithValueしてください');
});

/// 「成人向け作品を表示しない」「インディー作品を表示しない」の設定値。
/// アプリ全体で共有する単一の設定のため、画面ごとのローカルstateではなく
/// このプロバイダー経由でSharedPreferencesに永続化する（アプリ再起動後も保持）。
class ContentFilterPrefs {
  ContentFilterPrefs(this._prefs);

  final SharedPreferences _prefs;

  /// デフォルトfalse＝成人向け作品は表示しない。
  bool get includeAdult => _prefs.getBool(_includeAdultKey) ?? false;

  /// デフォルトtrue＝インディー作品は表示する。
  bool get includeIndie => _prefs.getBool(_includeIndieKey) ?? true;

  Future<void> setIncludeAdult(bool value) =>
      _prefs.setBool(_includeAdultKey, value);

  Future<void> setIncludeIndie(bool value) =>
      _prefs.setBool(_includeIndieKey, value);
}

final contentFilterPrefsProvider = Provider<ContentFilterPrefs>((ref) {
  return ContentFilterPrefs(ref.watch(sharedPreferencesProvider));
});
