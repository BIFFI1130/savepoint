import Flutter
import FirebaseCrashlytics
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
    let result = super.application(application, didFinishLaunchingWithOptions: launchOptions)
    // requestPermission()経由でも登録が保証されないことが実機で確認されたため
    // （didRegisterForRemoteNotificationsWithDeviceToken/didFailToRegisterForRemoteNotificationsWithError
    // のいずれもCrashlyticsに一度も記録されなかった＝そもそもregisterForRemoteNotifications()が
    // 呼ばれていなかった）、起動時に無条件で直接呼ぶ。通知許可の有無に関わらず安全に呼び出せる
    // （未許可の場合もAPNsトークン自体は取得できる。実際にアラート等が表示されるかは
    // 別途UNUserNotificationCenterの許可状態に従う）。
    application.registerForRemoteNotifications()
    return result
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
    // このコールバック自体が実際に呼ばれているかどうかをCrashlyticsで確認できるようにする
    // （Dart側の20秒タイムアウトだけでは、そもそも呼ばれていないのか／呼ばれても
    // Dart側に伝わっていないのかを切り分けられないため）。
    Crashlytics.crashlytics().log(
      "didRegisterForRemoteNotificationsWithDeviceToken fired (\(deviceToken.count) bytes)")
    super.application(application, didRegisterForRemoteNotificationsWithDeviceToken: deviceToken)
  }

  override func application(
    _ application: UIApplication,
    didFailToRegisterForRemoteNotificationsWithError error: Error
  ) {
    // APNsへの登録がOS側で明示的に失敗した場合、これまでのDart側「20秒タイムアウト」の
    // ログだけでは分からなかった実際の失敗理由（NSError）をCrashlyticsに記録する。
    Crashlytics.crashlytics().record(error: error)
    super.application(application, didFailToRegisterForRemoteNotificationsWithError: error)
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
