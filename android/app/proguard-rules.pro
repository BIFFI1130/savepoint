# image_cropperが内部で使うuCropが任意依存として参照するOkHttp（リモートURLの
# ダウンロード機能用）。本アプリはローカル画像のクロップにしか使わずOkHttpを
# 依存関係に含めていないため、R8のクラス欠落エラーを警告扱いに留める。
-dontwarn okhttp3.**
