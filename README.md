# SavePoint

遊んだゲームを記録・評価・レビューできるアプリ（ゲーム版Filmarksを目指すプロジェクト）。

- フロントエンド: Flutter（Riverpod / go_router）
- バックエンド: Supabase（Postgres / Auth / Edge Functions）
- ゲームデータ: IGDB（Twitch OAuth経由、Edge Function経由でアクセス）

---

## 現在の状態（2026-09-07更新）

Flutter画面一式・Supabase本番/開発環境・IGDB連携Edge Function・Firebase・AdMob・RevenueCatはすべて実装・設定済みで、
Apple Developer Program / Supabase / Twitch Developer / Google Playの各アカウント登録もすべて完了しています。
iOS/AndroidともCodemagic CIは使わず、このMacBook上でのローカルビルド・署名・ストア提出に一本化しています
（詳細は各種セットアップ手順を参照。以下の「あなたがやること」節・Codemagic関連の記述は初期構築時のもので、現在は運用していません）。

### 残っている主なブロッカー

1. **iOS: 有料アプリ契約（Paid Applications Agreement）がApple側のバグで未締結** — Legal Entity住所編集画面の不具合により署名できない状態。Apple Developer Supportへ報告済み（Case-ID 22046905）、回答待ち。解決するまでRevenueCatの購読機能は無効化（`REVENUECAT_IOS_API_KEY`を空文字にしたビルド）でストア提出している。
2. **Android: Google Play製品版（本番）は未申請** — ストア掲載情報の審査は完了しているが、製品版アクセスの申請には「12人以上のテスターがクローズドテストにオプトインし、14日間以上継続」という条件が必要（現在0人）。参加リンク: `https://play.google.com/apps/testing/com.biffi.savepoint`
3. **Twitch/IGDBパートナーシップ契約** — BIFFI本人は署名済みだが、Twitch側からの締結完了の返信が未着で停止中。広告収益化を伴うストア正式配信はこの返信待ち。

---

## ローカル開発環境（セットアップ済み）

このMacBookには以下がインストール・設定済みです。

| ツール | 備考 |
|---|---|
| Flutter SDK | `flutter --version` で確認可能 |
| Xcode | Apple ID（yuichirobiffi@icloud.com）でサインイン済み。iOSビルド・署名・App Store Connectへの直接アップロードに使用 |
| Android SDK / JDK 17 | Homebrew経由でインストール済み（`openjdk@17` `android-commandlinetools`） |
| Supabase CLI | `supabase --version` で確認可能 |

`flutter` `supabase` コマンドはそのまま使えます。

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

### 5. dev/prod環境の分離

開発・動作確認は上記の`env/dev.json`（devプロジェクト）を使い、自由にテストアカウントを作ったりデータを触ったりしてよい。本番用に別途「savepoint-prod」Supabaseプロジェクトを用意しており、マイグレーション・Edge Function（`igdb-proxy`・`delete-account`）・Storageバケット構成はdevと同一内容を反映済み。

- 本番プロジェクトの接続情報は`env/prod.json`（git管理対象外、`env/prod.example.json`が雛形）に保存する
- Codemagic CI（TestFlight・Firebase配信）は、ダッシュボード側の`SUPABASE_VARIABLES`変数グループが本番プロジェクトのURL/anon key/service_role keyを指すように設定する（このリポジトリのyamlにはURL/キー自体は含まれない）
- 本番プロジェクトに対してマイグレーションを追加する場合は、`supabase db push --project-ref <prod-project-ref> --password <prod-db-password>`のように`--project-ref`を明示して実行し、ローカルの`supabase link`状態（dev向け）を変更しないようにする
- 本番プロジェクトのDBパスワード・Edge Functionシークレット（TWITCH_CLIENT_ID/SECRET・GOOGLE_TRANSLATE_API_KEY）はパスワードマネージャー等で別途保管すること（Supabase側は書き込み専用のため、後から値を読み出すことはできない）

---

## Apple Developer側の設定（Sign in with Apple用）

1. Identifiers → App IDs でbundle ID `com.biffi.savepoint` を登録し、「Sign in with Apple」capabilityを有効化
2. Identifiers → Services IDs を新規作成し、Return URLに `https://<project-ref>.supabase.co/auth/v1/callback` を設定
3. Keys → 「Sign in with Apple」を有効にした新規Keyを作成し、`.p8` ファイルをダウンロード（再ダウンロード不可、保管必須）
4. 上記のServices ID・Team ID・Key ID・`.p8` の中身をSupabase Dashboard → Authentication → Providers → Appleに入力

---

## iPhoneでの実行（ローカルビルド）

このMacBook上のXcodeでビルド・署名し、App Store Connectへ直接アップロードします（Codemagicは使用していません）。

```bash
flutter build ipa --release --export-options-plist=<path> --build-number=<N> --dart-define-from-file=env/prod.json
```

`exportOptionsPlist`の`destination`を`upload`にすると、Xcodeの既にサインイン済みのセッションを使ってApp Store Connectへ直接アップロードできます（パスワード・APIキーの追加入力不要）。TestFlightまたはApp Review提出後、実機にインストールできます。

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

## 通報の確認方法（運営向け）

ユーザーからの通報は`reports`テーブルに保存されるが、一般ユーザー（anon/authenticated）には
一切公開されない（insertのみ許可）。運営は以下のいずれかの方法で確認する。

- Supabase Dashboard → Table Editor → `reports_with_details`（通報者・被通報者のユーザー名を
  結合した確認用ビュー。未対応`open`のものが上に並ぶ）
- 同ダッシュボードのSQL Editorから直接クエリしてもよい:
  ```sql
  select * from public.reports_with_details where status = 'open';
  ```

対応したら、`reports`テーブルの該当行を直接編集して`status`を`resolved`（対応済み）または
`dismissed`（対応不要と判断）に変更し、`resolved_at`・`resolved_note`に対応内容を記録する。
アプリ側に管理画面は用意していない（通報件数が少ない前提でダッシュボード運用としている）。
