import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../supabase/supabase_client.dart';

/// TestFlight・Firebase App Distributionのように、ストア経由の自動更新チェックが
/// 効かない配布経路向けに、アプリ自身のビルド番号と`app_versions`テーブルの
/// `latest_build`を比較し、古いビルドを起動した場合にアップデート画面への強制
/// リダイレクトが必要かどうかをrouterに伝える。`app_versions`はCI
/// （codemagic.yaml）がビルド・パブリッシュ成功直後にservice roleで更新する。
class UpdateGateController extends ChangeNotifier {
  UpdateGateController() {
    _refresh();
  }

  /// null=判定中（まだ問い合わせ中）、true=アップデート画面への誘導が必要、
  /// false=不要（最新、またはチェックできなかった場合は誤ってブロックしないためfalse扱い）。
  bool? needsUpdate;

  /// アップデート画面から開くリンク（TestFlightアプリ／Firebase App Distributionの
  /// テスター向けページ）。取得できなかった場合はnull。
  String? updateUrl;

  Future<void> _refresh() async {
    try {
      final platform = Platform.isIOS ? 'ios' : 'android';
      final rowFuture = supabase
          .from('app_versions')
          .select('latest_build, update_url')
          .eq('platform', platform)
          .maybeSingle();
      final packageInfoFuture = PackageInfo.fromPlatform();
      final row = await rowFuture;
      final packageInfo = await packageInfoFuture;

      if (row == null) {
        needsUpdate = false;
        notifyListeners();
        return;
      }
      final latestBuild = row['latest_build'] as int;
      final currentBuild = int.tryParse(packageInfo.buildNumber) ?? latestBuild;
      updateUrl = row['update_url'] as String?;
      needsUpdate = currentBuild < latestBuild;
      notifyListeners();
    } catch (_) {
      // 更新チェック自体の失敗（オフライン等）でアプリの利用をブロックしないよう、
      // falseのまま（＝ブロックしない）にする。
      needsUpdate = false;
      notifyListeners();
    }
  }
}

final updateGateProvider = Provider<UpdateGateController>((ref) {
  return UpdateGateController();
});
