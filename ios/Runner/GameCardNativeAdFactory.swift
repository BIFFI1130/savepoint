import Foundation
import GoogleMobileAds
import UIKit

/// ホームのゲームカバー横スクロール一覧に紛れ込ませるネイティブ広告カードを、
/// プログラムから組み立てるファクトリ（Androidの native_ad_card.xml + GameCardNativeAdFactory.kt
/// に相当。iOS側はXIBを使わずコードでビューを構築している）。
class GameCardNativeAdFactory: NSObject, FLTNativeAdFactory {
  func createNativeAd(
    _ nativeAd: GADNativeAd,
    customOptions: [AnyHashable: Any]? = nil
  ) -> GADNativeAdView? {
    let adView = GADNativeAdView()
    adView.translatesAutoresizingMaskIntoConstraints = false

    let mediaView = GADMediaView()
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
    headlineLabel.numberOfLines = 2
    headlineLabel.font = UIFont.boldSystemFont(ofSize: 12)
    headlineLabel.textColor = .white
    headlineLabel.text = nativeAd.headline
    adView.addSubview(headlineLabel)
    adView.headlineView = headlineLabel
    NSLayoutConstraint.activate([
      headlineLabel.leadingAnchor.constraint(equalTo: adView.leadingAnchor, constant: 8),
      headlineLabel.trailingAnchor.constraint(equalTo: adView.trailingAnchor, constant: -8),
      headlineLabel.bottomAnchor.constraint(equalTo: adView.bottomAnchor, constant: -8),
    ])

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

    adView.nativeAd = nativeAd

    return adView
  }
}
