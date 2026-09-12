import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../supabase/supabase_client.dart';

/// アプリ自身のビルド番号と`app_versions`テーブルの`latest_build`（＝実際には
/// 「これ未満は強制アップデート対象」という下限値）を比較し、古いビルドを起動した
/// 場合にアップデート画面への強制リダイレクトが必要かどうかをrouterに伝える。
/// App Store／TestFlight／Firebase App Distributionのどの配布経路にも同じ仕組みで
/// 対応できる（Apple自身の自動更新チェックとは独立した、アプリ内の強制ブロック）。
///
/// `app_versions`の値は自動更新ではなく、**重篤な不具合修正・破壊的変更を含む
/// リリースの直後にのみ手動で更新する**運用にしている（通常のアップデートは
/// Appleの自動更新に任せ、毎回強制するとUXを損なうため）。更新方法は
/// [[project_release_checklist]]のメモリ、またはリポジトリの運用手順を参照。
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
