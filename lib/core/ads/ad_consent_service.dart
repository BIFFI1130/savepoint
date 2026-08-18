import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

/// EEA/UK圏のユーザーに対する広告配信同意（UMP: User Messaging Platform）を取得し、
/// 完了後にAdMob SDKを初期化する。日本のユーザーには通常同意フォームは表示されない
/// （SDKが位置情報から自動判定する）が、AdMobの規約上すべてのパブリッシャーに実装が
/// 求められているため対応する。同意情報の取得に失敗した場合（オフライン等）も、
/// アプリの起動自体はブロックしない。
class AdConsentService {
  const AdConsentService();

  Future<void> requestConsentAndInitialize() async {
    final completer = Completer<void>();

    ConsentInformation.instance.requestConsentInfoUpdate(
      ConsentRequestParameters(),
      () {
        ConsentForm.loadAndShowConsentFormIfRequired((formError) async {
          if (formError != null) {
            debugPrint('UMP consent form error: ${formError.message}');
          }
          await _initializeIfAllowed();
          if (!completer.isCompleted) completer.complete();
        });
      },
      (FormError error) async {
        debugPrint('UMP consent info update error: ${error.message}');
        await _initializeIfAllowed();
        if (!completer.isCompleted) completer.complete();
      },
    );

    return completer.future;
  }

  Future<void> _initializeIfAllowed() async {
    final canRequestAds = await ConsentInformation.instance.canRequestAds();
    if (canRequestAds) {
      await MobileAds.instance.initialize();
    }
  }
}
