import Flutter
import FirebaseMessaging
import GoogleMobileAds
import UIKit
import firebase_messaging
import google_mobile_ads

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    // UIScene（FlutterImplicitEngineDelegate）方式ではFlutterプラグインの登録が
    // didInitializeImplicitFlutterEngine（このメソッドの後）まで遅延される。しかしAppleは
    // UNUserNotificationCenter.delegateをdidFinishLaunchingWithOptions内で（returnする前に）
    // 設定することを要求するため、firebase_messaging側の自動セットアップでは間に合わず、
    // APNsトークンが永久に取得できない不具合になる
    // （https://github.com/firebase/flutterfire/pull/18501）。そのため明示的に先に呼んでおく。
    FLTFirebaseMessagingPlugin.configureNotificationCenterDelegate()
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  override func application(
    _ application: UIApplication,
    didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data
  ) {
    // 上記と同じUIScene移行の既知の不具合により、firebase_messagingの自動スウィズリングが
    // このコールバックをMessaging.messaging().apnsTokenへ正しく橋渡しできず、Dart側の
    // getAPNSToken()が永久にnullのままタイムアウトする事象を実機で確認した
    // （https://github.com/firebase/flutterfire/issues/18204）。明示的に設定して回避する。
    Messaging.messaging().apnsToken = deviceToken
    super.application(application, didRegisterForRemoteNotificationsWithDeviceToken: deviceToken)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)

    // ホーム画面のゲームカバー一覧に紛れ込ませるネイティブ広告のファクトリを登録する。
    FLTGoogleMobileAdsPlugin.registerNativeAdFactory(
      engineBridge.pluginRegistry,
      factoryId: "gameCard",
      nativeAdFactory: GameCardNativeAdFactory()
    )
  }
}
