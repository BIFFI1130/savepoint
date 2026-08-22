import 'dart:io';

/// アプリの環境変数。
///
/// `--dart-define-from-file=env/dev.json` で起動時に注入する。
/// 値は env/dev.json（gitignore対象）で管理し、リポジトリには含めない。
class Env {
  static const supabaseUrl = String.fromEnvironment('SUPABASE_URL');
  static const supabaseAnonKey = String.fromEnvironment('SUPABASE_ANON_KEY');

  // AdMobのApp ID／広告ユニットIDは機密情報ではない（配布物を解析すれば誰でも見える値）ため、
  // Supabaseの鍵と違い、未設定時はGoogle公式のテストIDにフォールバックする。
  // 本番の実IDに差し替える場合のみ、Codemagicの環境変数（ADMOB_BANNER_AD_UNIT_ID）を設定する。
  static const _testBannerAdUnitIdAndroid = 'ca-app-pub-3940256099942544/9214589741';
  static const _testBannerAdUnitIdIOS = 'ca-app-pub-3940256099942544/2435281174';

  static String get admobBannerAdUnitId {
    const configured = String.fromEnvironment('ADMOB_BANNER_AD_UNIT_ID');
    if (configured.isNotEmpty) return configured;
    return Platform.isIOS ? _testBannerAdUnitIdIOS : _testBannerAdUnitIdAndroid;
  }

  static const _testNativeAdUnitIdAndroid = 'ca-app-pub-3940256099942544/2247696110';
  static const _testNativeAdUnitIdIOS = 'ca-app-pub-3940256099942544/3986624511';

  static String get admobNativeAdUnitId {
    const configured = String.fromEnvironment('ADMOB_NATIVE_AD_UNIT_ID');
    if (configured.isNotEmpty) return configured;
    return Platform.isIOS ? _testNativeAdUnitIdIOS : _testNativeAdUnitIdAndroid;
  }

  static const _testInterstitialAdUnitIdAndroid = 'ca-app-pub-3940256099942544/1033173712';
  static const _testInterstitialAdUnitIdIOS = 'ca-app-pub-3940256099942544/4411468910';

  static String get admobInterstitialAdUnitId {
    const configured = String.fromEnvironment('ADMOB_INTERSTITIAL_AD_UNIT_ID');
    if (configured.isNotEmpty) return configured;
    return Platform.isIOS
        ? _testInterstitialAdUnitIdIOS
        : _testInterstitialAdUnitIdAndroid;
  }

  // GoogleサインインのクライアントID（iOS用・ウェブ用）も非機密情報（Google Cloud
  // Consoleで公開されるOAuthクライアントIDのため）。未設定時はmain.dartで
  // GoogleSignIn.instance.initialize自体をスキップし、Googleサインインボタンの
  // 動作は無効のままアプリは通常通り起動する。
  static String get googleIosClientId =>
      const String.fromEnvironment('GOOGLE_IOS_CLIENT_ID');
  static String get googleWebClientId =>
      const String.fromEnvironment('GOOGLE_WEB_CLIENT_ID');

  // RevenueCatの公開SDKキーもAdMobの広告ユニットIDと同じく非機密情報だが、
  // AdMobと違い「未設定でも動くGoogle公式テストID」に相当するものが無いため、
  // フォールバックはしない。空文字のままならSubscriptionService側でconfigure自体を
  // スキップし、課金機能全体を「準備中」として無効化する。
  static String get revenueCatIosApiKey =>
      const String.fromEnvironment('REVENUECAT_IOS_API_KEY');
  static String get revenueCatAndroidApiKey =>
      const String.fromEnvironment('REVENUECAT_ANDROID_API_KEY');

  static void assertConfigured() {
    if (supabaseUrl.isEmpty || supabaseAnonKey.isEmpty) {
      throw StateError(
        'SUPABASE_URL / SUPABASE_ANON_KEY が設定されていません。\n'
        'env/dev.json を用意し、--dart-define-from-file=env/dev.json を付けて起動してください。',
      );
    }
  }
}
