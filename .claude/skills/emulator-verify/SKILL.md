---
name: emulator-verify
description: Androidエミュレータ上でSavePointアプリをビルド・起動し、adb/uiautomatorでUI操作・検証・スクリーンショット取得を行う標準手順。「エミュレータで確認して」「実機で動かして」等のUI検証依頼で使う。
---

# emulator-verify

SavePointアプリの変更をAndroidエミュレータ上で実際に操作して検証するための標準手順。UIや画面遷移の変更後は、コード上の確認だけでなく必ずこの手順で実機動作を確認する。

## 前提

- スクラッチパスディレクトリ（Windows形式パス）を使う。`/tmp/...`はネイティブWindowsバイナリ（adb.exe等）から解決できないため使わない。
- `window_dump.xml`等の一時ファイルは`.gitignore`済みだが、作業後に残さないよう心がける。

## 手順

1. エミュレータが起動しているか確認: `adb devices`。起動していなければ既存のAVDを起動する。

2. アプリをビルドしてインストールする。エミュレータのアーキテクチャに合わせる（x86_64エミュレータなら`--target-platform=android-x64`を明示しないとABIミスマッチで`UnsatisfiedLinkError`が起きる):
   ```
   flutter build apk --debug --target-platform=android-x64
   adb install -r build/app/outputs/flutter-apk/app-debug.apk
   ```
   もしくは`flutter run`でホットリロード込みの対話的検証でもよい。

3. アプリを起動: `adb shell monkey -p com.biffi.savepoint -c android.intent.category.LAUNCHER 1`

4. UI状態を確認する際は毎回:
   ```
   adb shell uiautomator dump /sdcard/window_dump.xml
   adb pull /sdcard/window_dump.xml <scratchpad>/window_dump.xml
   ```
   をRead/Grepし、対象要素の`bounds="[x1,y1][x2,y2]"`を正確に読み取ってから`adb shell input tap <cx> <cy>`（bounds中心座標）でタップする。座標を目視・推測でタップしない。

5. スクリーンショットが必要な場合:
   ```
   adb shell screencap -p /sdcard/window_screenshot.png
   adb pull /sdcard/window_screenshot.png <scratchpad>/...
   ```

6. クラッシュ・エラー確認: `adb logcat -d | grep -i -E "AndroidRuntime|savepoint"` 等で異常がないか確認する。

7. 検証完了後、確認した操作フロー・結果を簡潔にユーザーに報告する。スクリーンショットが視覚的に重要な場合はSendUserFileで送る。

## 注意

- テキスト入力はJapanese IMEの制約を受ける場合があるため、`adb shell input text`はASCII限定。日本語入力が必要な場面ではUI操作を避け、デモデータはAPI経由（Supabase REST等）で投入する方が確実。
- 生成された一時ファイル（`window_dump.xml`、`window_screenshot.png`等）はリポジトリにコミットしない（`.gitignore`済み）。
