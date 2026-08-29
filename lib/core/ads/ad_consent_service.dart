import 'dart:async';
import 'dart:io';

import 'package:app_tracking_transparency/app_tracking_transparency.dart';
import 'package:flutter/foundation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

/// EEA/UK圏のユーザーに対する広告配信同意（UMP: User Messaging Platform）を取得し、
/// 完了後にAdMob SDKを初期化する。日本のユーザーには通常同意フォームは表示されない
/// （SDKが位置情報から自動判定する）が、AdMobの規約上すべてのパブリッシャーに実装が
/// 求められているため対応する。同意情報の取得に失敗した場合（オフライン等）も、
/// アプリの起動自体はブロックしない。
///
/// iOSでは併せてApp Tracking Transparency（ATT）の許諾ダイアログも表示する。UMPは
/// EEA/UK向けの同意管理、ATTは（EEA/UK含む）全地域でiOS 14.5以降パーソナライズ広告に
/// トラッキングを使う場合に必須のOS標準ダイアログで、役割が異なるため両方が必要。
/// AdMob初期化より前に呼ぶことが推奨されているため、UMP同意解決後・AdMob初期化前に行う。
class AdConsentService {
  const AdConsentService();

  // 本番の広告ユニットIDでもテスト広告が表示されるようにする実機の端末ID一覧。
  // 「invalid traffic」（自己クリック等による無効なトラフィック）と判定されAdMob
  // アカウントが停止されるリスクを避けるため、動作確認に使う実機は必ずここに登録する。
  // 各IDはGMA SDKが初回広告リクエスト時にLogcat（Androidタグ"Ads"）へ
  // 「Use RequestConfiguration.Builder().setTestDeviceIds(...)」として出力するもの。
  static const _testDeviceIds = [
    '02796F0FFB3695C59C194221C8CCFCDE', // ZY22HLN9KX（動作確認用Android実機）
  ];

  Future<void> requestConsentAndInitialize() async {
    final completer = Completer<void>();

    ConsentInformation.instance.requestConsentInfoUpdate(
      ConsentRequestParameters(),
      () {
        ConsentForm.loadAndShowConsentFormIfRequired((formError) async {
          if (formError != null) {
            debugPrint('UMP consent form error: ${formError.message}');
          }
          await _requestTrackingAuthorizationIfNeeded();
          await _initializeIfAllowed();
          if (!completer.isCompleted) completer.complete();
        });
      },
      (FormError error) async {
        debugPrint('UMP consent info update error: ${error.message}');
        await _requestTrackingAuthorizationIfNeeded();
        await _initializeIfAllowed();
        if (!completer.isCompleted) completer.complete();
      },
    );

    return completer.future;
  }

  Future<void> _requestTrackingAuthorizationIfNeeded() async {
    if (!Platform.isIOS) return;
    try {
      await AppTrackingTransparency.requestTrackingAuthorization();
    } catch (error, stackTrace) {
      debugPrint('ATT request failed: $error\n$stackTrace');
    }
  }

  Future<void> _initializeIfAllowed() async {
    final canRequestAds = await ConsentInformation.instance.canRequestAds();
    if (canRequestAds) {
      await MobileAds.instance.initialize();
      await MobileAds.instance.updateRequestConfiguration(
        RequestConfiguration(testDeviceIds: _testDeviceIds),
      );
    }
  }
}
