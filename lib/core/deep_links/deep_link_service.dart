import 'package:app_links/app_links.dart';
import 'package:flutter/foundation.dart';

/// カスタムURLスキーム（`savepoint://`）経由のディープリンクを受け取る。
/// 現状はパスワード再設定メールのリンク（`savepoint://reset-password`）のみを扱う。
class DeepLinkService {
  DeepLinkService(this._onLink);

  final void Function(Uri uri) _onLink;
  final _appLinks = AppLinks();

  /// コールド起動時にリンク経由で開かれた場合と、起動中にリンクを開いた場合の
  /// 両方をハンドルする。失敗してもアプリの起動自体はブロックしない。
  Future<void> init() async {
    try {
      final initialUri = await _appLinks.getInitialLink();
      if (initialUri != null) _onLink(initialUri);
    } catch (error, stackTrace) {
      debugPrint('DeepLinkService.getInitialLink failed: $error\n$stackTrace');
    }
    _appLinks.uriLinkStream.listen(
      _onLink,
      onError: (error, stackTrace) {
        debugPrint('DeepLinkService.uriLinkStream error: $error\n$stackTrace');
      },
    );
  }
}
