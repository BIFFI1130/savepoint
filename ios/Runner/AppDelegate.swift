import Flutter
import GoogleMobileAds
import UIKit
import google_mobile_ads

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)

    // ホーム画面のゲームカバー一覧に紛れ込ませるネイティブ広告のファクトリを登録する。
    let registrar = engineBridge.pluginRegistry.registrar(forPlugin: "GameCardNativeAdFactory")
    FLTGoogleMobileAdsPlugin.registerNativeAdFactory(
      registrar,
      factoryId: "gameCard",
      nativeAdFactory: GameCardNativeAdFactory()
    )
  }
}
