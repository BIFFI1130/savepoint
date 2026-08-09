# SavePoint

遊んだゲームを記録・評価・レビューできるアプリ（ゲーム版Filmarksを目指すプロジェクト）。

- フロントエンド: Flutter（Riverpod / go_router）
- バックエンド: Supabase（Postgres / Auth / Edge Functions）
- ゲームデータ: IGDB（Twitch OAuth経由、Edge Function経由でアクセス）

---

## 現在の状態

コード側の雛形（Flutter画面一式・Supabase SQLマイグレーション・IGDB連携Edge Function）は実装済みです。
まだ**BIFFI自身が行う必要のあるアカウント作成・キー取得**が残っています。それが終わり次第、実際に動かせます。

### あなたがやること（未着手）

1. **Apple Developer Program登録**（https://developer.apple.com/programs/enroll/ 、年間$99、承認に24〜48時間以上）
2. **Supabaseプロジェクト作成**（https://supabase.com）→ Project URL・anon public key・service_role keyを控える
3. **Twitch Developer登録**（https://dev.twitch.tv/console/apps）→ IGDB用のClient ID / Client Secretを発行
4. **Codemagicアカウント作成**（https://codemagic.io）→ このGitHubリポジトリと連携（iOSビルド・TestFlight配信用）

これらが揃ったら、URLやキーを教えてください。以下のセットアップ手順に反映します。

---

## ローカル開発環境（セットアップ済み）

このマシンには以下がインストール・設定済みです。

| ツール | 場所 | 備考 |
|---|---|---|
| Flutter SDK | `C:\src\flutter` | ユーザーPATHに追加済み。`flutter --version` で確認可能 |
| Node.js (LTS) | 標準インストール先 | winget経由でインストール |
| Supabase CLI | `C:\src\supabase-cli` | ユーザーPATHに追加済み。`supabase --version` で確認可能 |

新しいターミナルを開けば `flutter` `supabase` コマンドがそのまま使えます（PATHはユーザー環境変数に永続化済み）。

Android SDK（Android Studio）は未導入です。今回はiOS優先のため必須ではありませんが、Androidでも動作確認したくなったら
[Android Studio](https://developer.android.com/studio) をインストールしてください。

---

## セットアップ手順（キーが揃ってから）

### 1. Supabase側

```bash
supabase login
supabase link --project-ref <あなたのproject-ref>
supabase db push
```

`supabase db push` で `supabase/migrations/20260809000000_init_schema.sql` が適用され、
`profiles` / `games` / `game_logs` / `igdb_tokens` テーブルとRLSポリシーが作成されます。

Supabase Dashboardでの設定:
- Authentication → Providers → Email: 有効化（開発中はメール確認を無効化すると楽）
- Authentication → Providers → Apple: Services ID / Team ID / Key ID / `.p8`キーの内容を入力
  （Apple Developer側での準備手順は [Apple Developer側の設定](#apple-developer側の設定) 参照）

### 2. igdb-proxy Edge Functionのデプロイ

```bash
supabase secrets set TWITCH_CLIENT_ID=<Twitchで発行したClient ID>
supabase secrets set TWITCH_CLIENT_SECRET=<Twitchで発行したClient Secret>
supabase functions deploy igdb-proxy
```

### 3. Flutterアプリの環境変数

`env/dev.example.json` をコピーして `env/dev.json` を作成し、Supabaseの値を入れてください（`env/dev.json` はgit管理対象外）。

```bash
cp env/dev.example.json env/dev.json
```

```json
{
  "SUPABASE_URL": "https://<project-ref>.supabase.co",
  "SUPABASE_ANON_KEY": "<anon public key>"
}
```

### 4. アプリを起動する

```bash
flutter pub get
flutter run --dart-define-from-file=env/dev.json
```

Windows上ではChrome（Web）やWindowsデスクトップ向けにまず起動確認ができます。iPhone実機での確認はCodemagic経由になります（下記）。

---

## Apple Developer側の設定（Sign in with Apple用）

1. Identifiers → App IDs でbundle ID `com.biffi.savepoint` を登録し、「Sign in with Apple」capabilityを有効化
2. Identifiers → Services IDs を新規作成し、Return URLに `https://<project-ref>.supabase.co/auth/v1/callback` を設定
3. Keys → 「Sign in with Apple」を有効にした新規Keyを作成し、`.p8` ファイルをダウンロード（再ダウンロード不可、保管必須）
4. 上記のServices ID・Team ID・Key ID・`.p8` の中身をSupabase Dashboard → Authentication → Providers → Appleに入力

---

## iPhoneでの実行（Codemagic経由）

Windows環境ではiOSのビルド（Xcode / `pod install`）ができないため、Codemagic（クラウドMac CI）を使います。

1. Codemagicで本リポジトリを連携
2. iOSワークフローを作成し、App Store Connect APIキーで自動署名を設定
3. `ios/Runner.xcodeproj` のbundle identifierをApple DeveloperのApp IDと一致させる（Codemagic上、またはXcodeで設定）
4. ビルド実行 → TestFlightへ配信 → BIFFIのiPhone 17にTestFlightアプリ経由でインストール

---

## ディレクトリ構成

```
lib/
  main.dart / app.dart           # エントリーポイント、MaterialApp.router
  core/
    config/env.dart              # --dart-defineで渡す環境変数
    supabase/supabase_client.dart
    router/app_router.dart       # go_router設定・認証リダイレクト
    theme/app_theme.dart
    widgets/                     # 共通ウィジェット（星評価・カバー画像・ローディング等）
  features/
    auth/                        # サインイン・サインアップ
    game_search/                 # IGDB検索・ゲーム詳細
    game_log/                    # 評価・レビュー投稿・マイログ一覧

supabase/
  migrations/                    # DBスキーマ（profiles/games/game_logs/igdb_tokens, RLS）
  functions/igdb-proxy/          # IGDB連携Edge Function（Twitchシークレットはここだけが保持）
```

## 動作確認（E2E）

1. `flutter analyze` で静的チェック（現時点でエラーなし）
2. Supabase Dashboardでテーブル・RLSポリシー・トリガーが作成されているか確認
3. `supabase functions invoke igdb-proxy --data '{"action":"search","query":"zelda"}'` などで疎通確認
4. サインアップ → Sign in with Apple → ゲーム検索 → 詳細表示 → 記録・評価・レビュー投稿 → マイログ一覧に反映されることを実機で確認
