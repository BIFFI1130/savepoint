package com.biffi.savepoint

import android.content.Context
import android.view.LayoutInflater
import android.widget.TextView
import com.google.android.gms.ads.nativead.MediaView
import com.google.android.gms.ads.nativead.NativeAd
import com.google.android.gms.ads.nativead.NativeAdView
import io.flutter.plugins.googlemobileads.NativeAdFactory

/**
 * ホームのゲームカバー横スクロール一覧に紛れ込ませるネイティブ広告カード
 * （res/layout/native_ad_card.xml）を組み立てるファクトリ。factoryId "gameCard" として
 * MainActivity.kt から登録する。
 */
class GameCardNativeAdFactory(private val context: Context) : NativeAdFactory {

    override fun createNativeAd(
        nativeAd: NativeAd,
        customOptions: MutableMap<String, Any>?,
    ): NativeAdView {
        val adView = LayoutInflater.from(context)
            .inflate(R.layout.native_ad_card, null) as NativeAdView

        val mediaView = adView.findViewById<MediaView>(R.id.ad_media)
        adView.mediaView = mediaView
        mediaView.mediaContent = nativeAd.mediaContent

        val headlineView = adView.findViewById<TextView>(R.id.ad_headline)
        headlineView.text = nativeAd.headline
        adView.headlineView = headlineView

        adView.setNativeAd(nativeAd)
        return adView
    }
}
