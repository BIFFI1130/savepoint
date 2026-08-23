import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

import '../config/env.dart';

/// 適応バナー広告。読み込み中・失敗時は何も表示しない
/// （レイアウト崩れやエラー表示でユーザー体験を損なわないため）。
///
/// サイズは画面全体の幅ではなく、自身が配置された場所で実際に使える幅
/// （[LayoutBuilder]の制約）を基準に決める。ホーム画面下部のような全幅の
/// 配置だけでなく、左右にパディングのあるコンテンツ内に埋め込んでも
/// 横にはみ出さない。
class BannerAdWidget extends StatefulWidget {
  const BannerAdWidget({super.key});

  @override
  State<BannerAdWidget> createState() => _BannerAdWidgetState();
}

class _BannerAdWidgetState extends State<BannerAdWidget> {
  BannerAd? _bannerAd;
  bool _isLoading = false;

  Future<void> _loadAd(double width) async {
    final size = await AdSize.getLargeAnchoredAdaptiveBannerAdSize(
      width.truncate(),
    );
    if (size == null) return;

    final ad = BannerAd(
      adUnitId: Env.admobBannerAdUnitId,
      size: size,
      request: const AdRequest(),
      listener: BannerAdListener(
        onAdLoaded: (loadedAd) {
          if (!mounted) {
            loadedAd.dispose();
            return;
          }
          setState(() => _bannerAd = loadedAd as BannerAd);
        },
        onAdFailedToLoad: (failedAd, error) {
          failedAd.dispose();
        },
      ),
    );
    await ad.load();
  }

  @override
  void dispose() {
    _bannerAd?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ad = _bannerAd;
    if (ad != null) {
      // 直下に必ずNavigationBar（自身で下端のセーフエリアを確保する）が続く配置
      // では、ここでSafeAreaを重ねると余計な空白ができてしまうため付けていない。
      return SizedBox(
        width: ad.size.width.toDouble(),
        height: ad.size.height.toDouble(),
        child: AdWidget(ad: ad),
      );
    }
    return LayoutBuilder(
      builder: (context, constraints) {
        if (!_isLoading) {
          _isLoading = true;
          final width = constraints.maxWidth;
          WidgetsBinding.instance.addPostFrameCallback((_) => _loadAd(width));
        }
        return const SizedBox.shrink();
      },
    );
  }
}
