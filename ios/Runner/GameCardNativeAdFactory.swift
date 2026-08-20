import Foundation
import GoogleMobileAds
import UIKit
import google_mobile_ads

/// ホームのゲームカバー横スクロール一覧に紛れ込ませるネイティブ広告カードを、
/// プログラムから組み立てるファクトリ（Androidの native_ad_card.xml + GameCardNativeAdFactory.kt
/// に相当。iOS側はXIBを使わずコードでビューを構築している）。
class GameCardNativeAdFactory: NSObject, FLTNativeAdFactory {
  func createNativeAd(
    _ nativeAd: NativeAd,
    customOptions: [AnyHashable: Any]? = nil
  ) -> NativeAdView? {
    let adView = NativeAdView()
    adView.translatesAutoresizingMaskIntoConstraints = false

    let mediaView = MediaView()
    mediaView.translatesAutoresizingMaskIntoConstraints = false
    adView.addSubview(mediaView)
    adView.mediaView = mediaView
    NSLayoutConstraint.activate([
      mediaView.leadingAnchor.constraint(equalTo: adView.leadingAnchor),
      mediaView.trailingAnchor.constraint(equalTo: adView.trailingAnchor),
      mediaView.topAnchor.constraint(equalTo: adView.topAnchor),
      mediaView.bottomAnchor.constraint(equalTo: adView.bottomAnchor),
    ])

    let scrim = UIView()
    scrim.translatesAutoresizingMaskIntoConstraints = false
    scrim.backgroundColor = UIColor.black.withAlphaComponent(0.7)
    adView.addSubview(scrim)
    NSLayoutConstraint.activate([
      scrim.leadingAnchor.constraint(equalTo: adView.leadingAnchor),
      scrim.trailingAnchor.constraint(equalTo: adView.trailingAnchor),
      scrim.bottomAnchor.constraint(equalTo: adView.bottomAnchor),
      scrim.heightAnchor.constraint(equalToConstant: 56),
    ])

    let headlineLabel = UILabel()
    headlineLabel.translatesAutoresizingMaskIntoConstraints = false
    headlineLabel.numberOfLines = 1
    headlineLabel.font = UIFont.boldSystemFont(ofSize: 12)
    headlineLabel.textColor = .white
    headlineLabel.text = nativeAd.headline
    adView.addSubview(headlineLabel)
    adView.headlineView = headlineLabel
    NSLayoutConstraint.activate([
      headlineLabel.leadingAnchor.constraint(equalTo: adView.leadingAnchor, constant: 8),
      headlineLabel.trailingAnchor.constraint(equalTo: adView.trailingAnchor, constant: -8),
      headlineLabel.bottomAnchor.constraint(equalTo: adView.bottomAnchor, constant: -24),
    ])

    let callToActionLabel = UILabel()
    callToActionLabel.translatesAutoresizingMaskIntoConstraints = false
    callToActionLabel.numberOfLines = 1
    callToActionLabel.font = UIFont.boldSystemFont(ofSize: 10)
    callToActionLabel.textColor = .black
    callToActionLabel.backgroundColor = .white
    callToActionLabel.text = nativeAd.callToAction
    adView.addSubview(callToActionLabel)
    adView.callToActionView = callToActionLabel
    NSLayoutConstraint.activate([
      callToActionLabel.leadingAnchor.constraint(equalTo: adView.leadingAnchor, constant: 8),
      callToActionLabel.bottomAnchor.constraint(equalTo: adView.bottomAnchor, constant: -6),
    ])

    // 広告主アイコン。素材が提供されているのにViewが未設定だと実装不備として
    // 検証ツールに指摘されるため、CTAボタンの反対側に小さく表示する。
    if let icon = nativeAd.icon {
      let iconImageView = UIImageView(image: icon.image)
      iconImageView.translatesAutoresizingMaskIntoConstraints = false
      iconImageView.contentMode = .scaleAspectFit
      adView.addSubview(iconImageView)
      adView.iconView = iconImageView
      NSLayoutConstraint.activate([
        iconImageView.trailingAnchor.constraint(equalTo: adView.trailingAnchor, constant: -8),
        iconImageView.bottomAnchor.constraint(equalTo: adView.bottomAnchor, constant: -7),
        iconImageView.widthAnchor.constraint(equalToConstant: 20),
        iconImageView.heightAnchor.constraint(equalToConstant: 20),
      ])
    }

    let badgeLabel = UILabel()
    badgeLabel.translatesAutoresizingMaskIntoConstraints = false
    badgeLabel.text = "広告"
    badgeLabel.font = UIFont.systemFont(ofSize: 10)
    badgeLabel.textColor = .white
    badgeLabel.textAlignment = .center
    badgeLabel.backgroundColor = UIColor.black.withAlphaComponent(0.6)
    badgeLabel.layer.cornerRadius = 3
    badgeLabel.clipsToBounds = true
    adView.addSubview(badgeLabel)
    NSLayoutConstraint.activate([
      badgeLabel.leadingAnchor.constraint(equalTo: adView.leadingAnchor, constant: 4),
      badgeLabel.topAnchor.constraint(equalTo: adView.topAnchor, constant: 4),
      badgeLabel.widthAnchor.constraint(equalToConstant: 28),
      badgeLabel.heightAnchor.constraint(equalToConstant: 16),
    ])

    // AdMobのポリシーで表示が必須の「広告に関する選択肢」アイコン。
    // 左上の「広告」バッジと重ならないよう右上に配置する。
    let adChoicesView = AdChoicesView()
    adChoicesView.translatesAutoresizingMaskIntoConstraints = false
    adView.addSubview(adChoicesView)
    adView.adChoicesView = adChoicesView
    NSLayoutConstraint.activate([
      adChoicesView.trailingAnchor.constraint(equalTo: adView.trailingAnchor, constant: -4),
      adChoicesView.topAnchor.constraint(equalTo: adView.topAnchor, constant: 4),
    ])

    adView.nativeAd = nativeAd

    return adView
  }
}
