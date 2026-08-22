import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

import '../config/env.dart';

/// 全画面インタースティシャル広告の読み込み・表示をまとめて扱うサービス。
///
/// バナー/ネイティブ広告と違い、表示直前ではなく事前に読み込んでおく必要があるため
/// （読み込みに数秒かかることがある）、呼び出し側は使いそうなタイミングで[preload]を
/// 呼んでおき、実際に見せたいタイミングで[show]を呼ぶ、という2段階の使い方をする。
/// 広告が読み込めていない場合（通信失敗・タイミングが早すぎた等）は[show]が何もせず
/// 即座に完了するため、呼び出し側の本来の処理（保存など）を広告の成否でブロックしない。
class InterstitialAdService {
  InterstitialAd? _ad;
  bool _isLoading = false;

  void preload() {
    if (_ad != null || _isLoading) return;
    _isLoading = true;
    InterstitialAd.load(
      adUnitId: Env.admobInterstitialAdUnitId,
      request: const AdRequest(),
      adLoadCallback: InterstitialAdLoadCallback(
        onAdLoaded: (ad) {
          _ad = ad;
          _isLoading = false;
        },
        onAdFailedToLoad: (error) {
          _isLoading = false;
          debugPrint('InterstitialAd failed to load: $error');
        },
      ),
    );
  }

  /// 読み込み済みの広告を表示し、閉じられる（または表示自体に失敗する）まで待つ。
  /// 未読み込みの場合は何もせずすぐに返る。表示後は次回に備えて自動的に再読み込みする。
  Future<void> show() async {
    final ad = _ad;
    if (ad == null) return;
    _ad = null;

    final completer = Completer<void>();
    ad.fullScreenContentCallback = FullScreenContentCallback(
      onAdDismissedFullScreenContent: (ad) {
        ad.dispose();
        if (!completer.isCompleted) completer.complete();
        preload();
      },
      onAdFailedToShowFullScreenContent: (ad, error) {
        ad.dispose();
        if (!completer.isCompleted) completer.complete();
        preload();
      },
    );
    await ad.show();
    return completer.future;
  }
}
