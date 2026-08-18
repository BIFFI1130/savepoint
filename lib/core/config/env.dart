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

  static void assertConfigured() {
    if (supabaseUrl.isEmpty || supabaseAnonKey.isEmpty) {
      throw StateError(
        'SUPABASE_URL / SUPABASE_ANON_KEY が設定されていません。\n'
        'env/dev.json を用意し、--dart-define-from-file=env/dev.json を付けて起動してください。',
      );
    }
  }
}
