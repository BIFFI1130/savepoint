package com.biffi.savepoint

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugins.googlemobileads.GoogleMobileAdsPlugin

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        // ホーム画面のゲームカバー一覧に紛れ込ませるネイティブ広告のファクトリを登録する。
        GoogleMobileAdsPlugin.registerNativeAdFactory(
            flutterEngine,
            "gameCard",
            GameCardNativeAdFactory(this),
        )
    }

    override fun cleanUpFlutterEngine(flutterEngine: FlutterEngine) {
        GoogleMobileAdsPlugin.unregisterNativeAdFactory(flutterEngine, "gameCard")
        super.cleanUpFlutterEngine(flutterEngine)
    }
}
