import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

import '../config/env.dart';

/// ホーム画面のゲームカバー横スクロール一覧に、ゲームカードと同じ寸法で
/// 紛れ込ませるネイティブ広告カード。実際の見た目（画像・見出し・「広告」表記）は
/// ネイティブ側（Android: NativeAdFactory / iOS: FLTNativeAdFactory）で組み立てる。
/// 読み込み中・失敗時も同じ幅を確保し、横スクロール一覧のレイアウトが
/// ガタつかないようにする。
class NativeAdCard extends StatefulWidget {
  // 幅はAdMobのMediaViewの最小サイズ要件（動画クリエイティブの場合120x120dp以上）を
  // 満たすため、隣接するゲームカバー（110dp）よりわずかに広くしている。
  const NativeAdCard({super.key, this.width = 120, this.height = 160});

  final double width;
  final double height;

  static const _factoryId = 'gameCard';

  @override
  State<NativeAdCard> createState() => _NativeAdCardState();
}

class _NativeAdCardState extends State<NativeAdCard> {
  NativeAd? _nativeAd;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadAd();
  }

  void _loadAd() {
    if (_isLoading) return;
    _isLoading = true;
    final ad = NativeAd(
      adUnitId: Env.admobNativeAdUnitId,
      factoryId: NativeAdCard._factoryId,
      request: const AdRequest(),
      listener: NativeAdListener(
        onAdLoaded: (loadedAd) {
          if (!mounted) {
            loadedAd.dispose();
            return;
          }
          setState(() => _nativeAd = loadedAd as NativeAd);
        },
        onAdFailedToLoad: (failedAd, error) {
          failedAd.dispose();
        },
      ),
    );
    ad.load();
  }

  @override
  void dispose() {
    _nativeAd?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ad = _nativeAd;
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: SizedBox(
        width: widget.width,
        height: widget.height,
        child: ad == null ? null : AdWidget(ad: ad),
      ),
    );
  }
}
