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
    // メディア素材の読み込みに失敗した場合や、画像を持たない広告クリエイティブの場合に
    // 背景が真っ黒になり「表示が壊れている」ように見えてしまうため、中間グレーで
    // フォールバックする（CoverImageのプレースホルダーと近いトーン）。
    mediaView.backgroundColor = UIColor(white: 0.38, alpha: 1)
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

    // 広告主アイコン。素材が提供されているのにViewが未設定だと実装不備として
    // 検証ツールに指摘されるため、右下に小さく表示する。headline/CTAより先に
    // 生成し、両ラベルのtrailing制約をこのiconImageView基準にすることで、
    // テキストの長さに関わらずアイコンの上に重ならないようにする。
    var iconImageView: UIImageView?
    if let icon = nativeAd.icon {
      let imageView = UIImageView(image: icon.image)
      imageView.translatesAutoresizingMaskIntoConstraints = false
      imageView.contentMode = .scaleAspectFit
      adView.addSubview(imageView)
      adView.iconView = imageView
      NSLayoutConstraint.activate([
        imageView.trailingAnchor.constraint(equalTo: adView.trailingAnchor, constant: -8),
        imageView.bottomAnchor.constraint(equalTo: adView.bottomAnchor, constant: -7),
        imageView.widthAnchor.constraint(equalToConstant: 20),
        imageView.heightAnchor.constraint(equalToConstant: 20),
      ])
      iconImageView = imageView
    }
    // アイコン未設定の場合のtrailing制約の基準として、アイコンと同じ位置に不可視の
    // レイアウトガイドを置く（headline/CTAのtrailing制約を常に同じ書き方にできる）。
    let iconTrailingAnchor = iconImageView?.leadingAnchor ?? adView.trailingAnchor
    let iconTrailingInset: CGFloat = iconImageView != nil ? -4 : -8

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
      // アイコン（またはadViewの端）より内側に収め、CTAテキストが長い場合でも
      // 右側の要素と重ならないようにする。
      callToActionLabel.trailingAnchor.constraint(
        lessThanOrEqualTo: iconTrailingAnchor, constant: iconTrailingInset),
      callToActionLabel.bottomAnchor.constraint(equalTo: adView.bottomAnchor, constant: -6),
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
      headlineLabel.trailingAnchor.constraint(
        lessThanOrEqualTo: iconTrailingAnchor, constant: iconTrailingInset),
      // CTAラベルの上端からの相対位置で指定する（adView.bottomからの固定値同士
      // だけに頼ると、Dynamic Type等で行の高さが伸びた際にCTAと重なってしまうため）。
      headlineLabel.bottomAnchor.constraint(equalTo: callToActionLabel.topAnchor, constant: -4),
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
