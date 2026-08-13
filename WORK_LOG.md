# 作業メモ

対応内容・バグ修正を都度ここに追記していく。コンテキストが失われても、このファイルを見れば
状況を復元しやすくするためのログ。新しいものを上に追記する。

---

## 2026-08-13（続き）

### 対応済み: CodemagicのCIビルド時間短縮（ビルド5分・パブリッシュ1分30秒だった）

- ユーザーがCodemagicのビルドログ・パブリッシュログを共有し、短縮できないか相談。
- **ログから判明したボトルネック**: Androidの`Gradle assembleRelease`が298秒
  （ビルド全体5分の大半）。原因は以下の2つ:
  1. `codemagic.yaml`に`cache:`設定が一切なく、`Android SDK Platform 36`を毎回
     ゼロからダウンロード・インストールしていた（ログの
     `"Install Android SDK Platform 36 (revision 2)" complete`部分）。Gradleの
     依存解決・ビルドキャッシュもビルド間で永続化されていなかった。
  2. `flutter build apk --release`がarm64・armv7・x86_64の全アーキテクチャ向け
     ネイティブライブラリを1つのAPKに同梱しており、余分なビルド・パッケージング
     コストがかかっていた。
- **対応**:
  - `codemagic.yaml`の`release`ワークフローに`cache.cache_paths`を追加
     （`$HOME/.gradle/caches`・`$HOME/.gradle/wrapper`・`$HOME/.pub-cache`・
     `$CM_BUILD_DIR/.dart_tool`・`$CM_BUILD_DIR/android/.gradle`・
     `$HOME/Library/Caches/CocoaPods`・`/usr/local/share/android-sdk`）。
     2回目以降のビルドでSDK再ダウンロードとGradle依存解決の待ち時間が大きく減る見込み。
  - `android/gradle.properties`に`org.gradle.caching=true`・`org.gradle.parallel=true`を追加。
  - `codemagic.yaml`のAndroidビルドコマンドに`--target-platform=android-arm64`を追加し、
    ビルド対象をarm64のみに限定（Firebase App Distributionのテスターは全員arm64実機という
    前提で、ユーザーに確認の上「arm64のみに絞る」を選択）。armv7・x86_64向けの
    ビルド・パッケージング処理を省略できる。publish側が参照するファイル名
    （`build/app/outputs/flutter-apk/app-release.apk`）は単一ターゲットビルドでも
    変わらないため、パブリッシュ処理の変更は不要だった。
  - パブリッシュ側（1分30秒）はiOSのaltoolアップロード自体は0.239秒で完了しており、
    大半はApp Store Connect APIやfirebase-tools（Node起動＋Google認証）の
    固定オーバーヘッドと考えられる。ログにステップ単位のタイムスタンプがなく
    これ以上の内訳特定ができなかったため、今回は手を付けていない。
- **未検証**: Codemagic実機での次回ビルドでの時間短縮効果は、ローカル環境では検証できない
  （Codemagic CI環境固有の設定のため）。次回のCIビルドで実際の短縮幅を確認してもらう必要がある。
  1回目のビルドはキャッシュが空の状態から始まるため、効果が出るのは2回目以降。

---

## 2026-08-13

### 対応済み: テスト用の強制毎回オンボーディングを撤廃、正式な「一度も設定していない場合のみ強制」に変更

- ユーザー要望: 「ユーザーIDを正規シーケンスで一度も設定したことないユーザーは起動時に
  強制してください。」→ 前回実装した`kForceUsernameOnboardingForTesting`（設定済みでも
  常に起動時にオンボーディング画面を強制する一時フラグ）はもう不要とのことなので撤廃。
- `lib/core/onboarding/username_gate.dart`: `kForceUsernameOnboardingForTesting`定数と
  それを参照していたロジックを削除。`needsOnboarding`は単純に
  `profiles.username`が未設定（null/空文字）かどうかだけで判定するようにした
  （＝一度も正規のユーザーID入力画面を通っていないユーザーだけが対象。一度設定した
  ユーザーは以降起動時に強制されない）。
- `username_onboarding_screen.dart`のクラスdocコメントからテスト限定フラグへの言及を削除。
- **検証**: `flutter analyze`クリア。既にユーザーID（`test1`）を設定済みの状態でアプリを
  完全再起動（`am force-stop`→`am start`）→オンボーディング画面を経由せず直接ホーム画面が
  表示されることをスクリーンショットで確認。

### 対応済み: 表示名の鉛筆アイコン編集・ユーザーID（半角英数字限定・一意・変更不可）・起動時オンボーディング

- ユーザー要望:
  1. 表示名は、アイコン画像下の表示名の右肩上に小さい鉛筆アイコンをタップして編集できるようにする。
  2. ユーザー名を「ユーザーID（半角英数字）」に改め、半角英数字以外は入力不可にする。
     一度決めたら変更不可・重複禁止。
  3. ユーザーIDが空ならアプリ起動時に必ずユーザーID入力画面（シーケンス）を経由させる。
  4. テスト段階では特別に、ユーザーIDが空でなくとも起動のたびにこの画面を経由させ、
     変更できるようにする。

- **DB**: `profiles.username`には元から`unique`制約が既に存在しており（初期スキーマ）、
  重複禁止はDB側で担保済み。「一度決めたら変更不可」はDBのハード制約にはせず、
  UI側でのみ強制する設計にした（テスト段階の「起動のたびに変更可能」という特例を
  素直に実現するため。DBトリガーで不変にすると特例が実装しにくくなる）。マイグレーション
  追加は無し。

- **新規**: `lib/core/onboarding/username_gate.dart`
  - `kForceUsernameOnboardingForTesting`（`const bool`、現在`true`）: テスト段階限定の
    フラグ。本番リリース前に`false`にすること、という警告コメント付き。
  - `UsernameGateController`（`ChangeNotifier`）: ログイン中ユーザーの`profiles.username`を
    監視し、未設定（またはテストフラグがtrueの間は設定済みでも常に）なら
    `needsOnboarding = true`にする。`markCompleted()`でその場のセッション内のみ解除。
  - `usernameGateProvider`: 上記コントローラーのシングルトンインスタンスを提供する
    Riverpod Provider。

- **新規**: `lib/features/social/presentation/screens/username_onboarding_screen.dart`
  - `PopScope(canPop: false)`でシステムのバックボタンによる離脱をブロックする、
    強制シーケンス画面。
  - `TextField`に`FilteringTextInputFormatter.allow(RegExp('[a-zA-Z0-9]'))`を設定し、
    半角英数字以外は入力自体をブロック。送信前にも正規表現で二重チェック。
  - 送信は`SocialRepository.setUsername()`を呼び、成功したら
    `usernameGateProvider`の`markCompleted()`を呼んで`context.go('/home')`。
    重複エラー（DBのunique制約違反）はメッセージを「そのユーザーIDは既に使われています」に
    変換して表示。

- **`lib/core/router/app_router.dart`の変更**:
  - `refreshListenable`を`Listenable.merge([refreshStream, usernameGate])`に変更し、
    ユーザーID取得の非同期完了時にもredirectが再評価されるようにした。
  - `redirect`内で、ログイン中かつ`usernameGate.needsOnboarding == true`かつ
    オンボーディング画面上でなければ`/onboarding/username`へ強制リダイレクト。
    `needsOnboarding == false`でオンボーディング画面上にいる場合は`/home`へ戻す
    （`null`＝判定中の間はどちらのリダイレクトも発生させず、現在のルートをそのまま
    表示する。これにより初回起動時に一瞬ホームが見えてからオンボーディングへ
    切り替わる僅かなちらつきが発生するが許容範囲と判断）。

- **`lib/features/social/data/social_repository.dart`の変更**:
  - `updateMyProfile()`から`username`・`displayName`パラメータを削除し、
    `isPublic`・`gameHistory`・`favoriteGenres`のみを扱う（プロフィール確認ページの
    「保存する」ボタン用）。
  - `updateDisplayName(String? displayName)`を新設（表示名だけを更新、鉛筆アイコンから
    呼ばれる）。
  - `setUsername(String username)`を新設（ユーザーID入力画面からのみ呼ばれる想定）。

- **`lib/features/social/presentation/screens/my_profile_screen.dart`の変更**:
  - ユーザー名・表示名のTextField（常時表示の編集フォーム）を削除。
  - 表示名は`Text`表示のみにし、その右上（Row内でクロスアクション start寄せ、
    テキストの右に小さい`Icons.edit`を配置）に鉛筆アイコンを追加。タップで
    `AlertDialog`（表示名編集専用）を開き、保存すると`updateDisplayName()`を呼ぶ。
  - ユーザーIDは`@test1`のような読み取り専用の`Text`表示のみ（編集UIなし）。
  - 「保存する」ボタンは公開設定・ゲーム歴・好きなジャンルのみを保存するように変更。

- **バグ修正（実機検証中に発見）**: 表示名編集ダイアログで、`showDialog`の外側で
  `TextEditingController`を生成し`Navigator.pop`直後に手動で`controller.dispose()`する
  実装にしたところ、ダイアログの閉じるアニメーション中にTextFieldがまだ
  controllerを参照している状態でdisposeされ、
  `'_dependents.isEmpty': is not true`という assertion で赤画面クラッシュした。
  ダイアログの中身を専用の`StatefulWidget`（`_DisplayNameEditDialog`）に切り出し、
  `TextEditingController`をその`State`が自分の`initState`相当（`late final`初期化）で
  生成し`dispose()`で破棄するよう変更して解消。showDialogに渡すcontrollerは
  呼び出し側で管理せず、必ずダイアログ自身のStateに持たせるのが安全という教訓。

- **検証**（エミュレータ、テストフラグ`true`の状態）:
  - 既存ユーザー（ユーザーID未設定）でアプリ起動→ユーザーID入力画面が強制表示されることを
    確認。
  - システムのバックボタンでは閉じられない（画面が変わらない）ことを確認。
  - 半角英数字のみ通ることを確認（IMEの都合で日本語混じりの入力は直接検証できなかったが、
    ローマ字コンポジション中の文字列がフォーマッタを通過し、最終的にDBへ保存された値
    `test1`が英数字のみであったことから、フォーマッタが機能していることを間接的に確認）。
  - 送信後`/home`へ遷移し、DB（`profiles.username`）に正しく保存されることを
    `supabase db query`で確認。
  - アプリを完全に再起動（`am force-stop`→`am start`）→ユーザーID設定済み（`test1`）でも
    テストフラグにより再度オンボーディング画面が表示され、既存値がプリフィルされることを
    確認（要望4の動作）。
  - プロフィール画面で表示名の鉛筆アイコンをタップ→編集ダイアログが開く→
    保存ボタンを押してもクラッシュしないことを確認（上記バグ修正後）。
  - `@test1`が編集不可の読み取り専用表示になっていることを確認。
  - `flutter analyze`はクリア（既存の無関係な1件のみ）。

### 対応済み: プロフィール設定（ユーザー名・表示名・公開設定）を人アイコンのページに統合、歯車アイコンを削除

- ユーザー要望: 「プロフィール設定の名前設定をここからできるようにしてください。今のところ、
  歯車アイコンには特に機能は入らない想定です。」
- 旧`profile_settings_screen.dart`（ユーザー名・表示名・公開設定のみを扱う画面、歯車アイコンから
  遷移）の内容をすべて`my_profile_screen.dart`（人アイコンから遷移するプロフィール確認・編集
  ページ）に統合した。歯車アイコンには今後も機能を割り当てない前提のため、
  `my_logs_screen.dart`のAppBar actionsから歯車IconButtonごと削除し、
  `/social/profile-settings`ルートと`profile_settings_screen.dart`ファイル自体も削除した
  （不要になったコードを残さない方針）。
- `social_repository.dart`: `updateMyProfile()`と`updateMyBio()`の2つに分かれていた更新処理を
  1つの`updateMyProfile({username, displayName, isPublic, gameHistory, favoriteGenres})`に統合。
  画面側の保存ボタンも1つにまとめ、アバター画像アップロードのみ独立した即時保存のまま
  （画像選択＝即アップロードの体験を優先し、他フィールドの保存ボタン押下を待たせないため）。
- `my_profile_screen.dart`: アバター画像の下に「名前未設定」ラベル、その下にユーザー名・
  表示名のTextField、公開設定のSwitchListTileを追加（元profile_settings_screen.dartと同じ
  文言・重複ユーザー名エラーハンドリングを踏襲）。その下に既存のゲーム歴・好きなジャンル・
  「保存する」ボタン・オレの推しゲー、という構成。
- **検証**: `flutter analyze`はクリア（既存の無関係な1件のみ）。エミュレータで
  マイログ画面から歯車アイコンが消えたこと、人アイコンのみが表示されることを確認。
  プロフィール画面で公開設定をON・ジャンル選択・ユーザー名欄を操作し保存→
  `supabase db query`で`profiles.is_public = true`・`favorite_genres`が正しく反映されることを
  確認済み。ユーザー名のテキスト入力そのものはエミュレータのIME（Gboard日本語かな入力）が
  ローマ字→かな変換してしまい`adb shell input text`での英数字入力検証ができなかったため、
  空欄のまま保存されることのみ確認した（TextField自体は旧profile_settings_screen.dartと
  完全に同じ実装パターンを使い回しており、機能的なリスクは低いと判断）。

### 対応済み: マイログ「歯車」の左隣に人アイコン→プロフィール確認・編集ページを新規実装

- ユーザー要望: 「マイログの歯車の左隣に人アイコンを配置し、これをプロフィール確認ページと
  したいです。また、そのページでプロフィールの編集も行うことができるようになります。
  プロフィールは、プロフィール画像とゲーム歴、好きなジャンル設定、オレの推しゲー。を
  設定できるようにしたいです。」
- **DB変更**（`supabase/migrations/20260813210000_add_profile_bio_and_avatar_storage.sql`、
  `supabase db push --linked`で適用済み）:
  - `profiles`に`game_history text`（ゲーム歴、自由記述）・
    `favorite_genres text[] not null default '{}'`（好きなジャンル、複数選択）を追加。
  - Supabase Storageに`avatars`バケットを新規作成（`public: true`）。
    `storage.objects`に4つのRLSポリシーを追加：公開read、本人のフォルダ
    （`{auth.uid()}/...`という命名規約）への insert/update/delete のみ許可。
- **Dart側**:
  - `lib/features/social/domain/social_profile.dart`: `gameHistory`・`favoriteGenres`
    フィールドを追加。
  - `lib/features/social/data/social_repository.dart`: `updateMyBio()`
    （ゲーム歴・好きなジャンルの保存）と`uploadAvatar()`
    （`avatars`バケットへのアップロード＋`profiles.avatar_url`更新、
    キャッシュ回避のため公開URLに`?t=timestamp`を付与）を追加。
  - `pubspec.yaml`に`image_picker: ^1.1.2`を追加（ギャラリーから画像選択、Android側は
    photo pickerを使うため追加のマニフェスト権限は不要）。
  - `lib/features/social/presentation/screens/my_profile_screen.dart`（新規）:
    アバター画像（タップでギャラリーから選択→アップロード）・ゲーム歴のテキストフィールド・
    `GenreBadgeSelector`での好きなジャンル選択・「オレの推しゲー」一覧（既存の
    `myFavoritesProvider`/`FavoriteGamesList`を再利用、「編集する」から`/favorites/edit`へ）
    を1画面にまとめた。ゲーム歴・好きなジャンルは「保存する」ボタンで`updateMyBio()`を
    呼んで保存する（ユーザー名・表示名・公開設定は従来通り歯車アイコンの
    `profile-settings`画面で編集する棲み分けのまま変更していない）。
  - `lib/core/router/app_router.dart`: `/social/my-profile`ルートを追加。
  - `lib/features/game_log/presentation/screens/my_logs_screen.dart`: AppBar actionsの
    歯車アイコンの左に`Icons.person_outline`の新規IconButtonを追加、
    `/social/my-profile`へ遷移。
- **検証**: `flutter analyze`はクリア（既存の無関係な1件のみ）。エミュレータで
  マイログ→人アイコン→プロフィール画面遷移を確認。ジャンルバッジ（RPG・シューティング）を
  選択し保存ボタンを押下→`supabase db query`で`profiles.favorite_genres`に
  `["Role-playing (RPG)", "Shooter"]`等が正しく反映されることを確認済み。
  アバター画像アップロードは実機でのギャラリー選択UIを伴うため自動タップでの検証は行っておらず、
  実装コードの確認に留めている（ユーザーに実機確認を依頼）。

**adb手動操作時の注意（今回ハマったポイント）**: スクリーンショットはRead toolが
`900x2000`に縮小表示するが、実機解像度は`1080x2400`。displayed座標をそのまま
`adb shell input tap`に渡すと1.2倍分ズレて隣の要素（今回は「レース」ジャンルバッジ）を
誤タップしてしまう。displayed座標は必ず1.2倍してからadb tapに渡すこと。

### 解決済み: DLC・アップデートがゲーム一覧に再表示される問題

- ユーザー報告: 「以前対応したはずの、一つのゲームタイトルのDLC・アップデートが表示されて
  しまっているのが復活しています。再度修正対応してください。」
- **原因**: `supabase/functions/igdb-proxy/index.ts`に既存の`version_parent = null` /
  `parent_game = null`によるDLC/アップデート除外フィルタが存在していたが、未コミットの
  変更（検索精度向上のための別対応）で「タイトル検索（`hasQuery`が true）のときは
  キュレーションフィルタを一切適用しない」という`if (!hasQuery) { ... }`ブロックの中に
  `version_parent`/`parent_game`フィルタも巻き込まれてしまっていた。結果、タイトル検索時に
  DLC/アップデート（例:「Monster Hunter Rise: Title Update 3」）が本編と別の検索結果として
  再び表示されるようになっていた。
- **修正**: `supabase/functions/igdb-proxy/index.ts`の602-645行目付近。
  `version_parent = null` と `parent_game = null` の2つのフィルタを`if (!hasQuery)`ブロックの
  外に出し、タイトル検索時・カテゴリ探索時のどちらでも常に適用されるようにした。
  一方、成人向け/インディー/MOD・ROMハック除外フィルタは、意図通りタイトル検索時は
  スキップしたままにしている（これらは検索精度とのトレードオフのための意図的な変更であり、
  DLCの件とは別目的のフィルタのため）。
- **デプロイ**: `npx supabase functions deploy igdb-proxy` で本番反映済み。
- **検証**:
  - curlで直接APIを叩き確認: `{"action":"search","query":"Monster Hunter Rise"}` →
    「Monster Hunter Rise + Sunbreak」「Monster Hunter Rise」の2件のみ（Title Update等は
    含まれない）。
  - `{"action":"search","query":"Honkai Star Rail"}` → 本編1件のみ。
  - エミュレータの検索画面で「Monster Hunter Rise」と検索し、「モンスターハンターライズ ＋
    サンブレイクセット」「モンスターハンターライズ」の2件のみ表示されることを確認
    （スクリーンショットで確認済み、DLC/アップデートは出ない）。
- コミットはまだしていない（ユーザーの指示があれば実施）。

### 対応中: トレンド画面のジャンルフィルタ動作確認

- `flutter run -d emulator-5554 --debug --dart-define-from-file=env/dev.json` でビルド・起動成功。
- トレンド画面「みんなが遊びたい」タブの初期状態（フィルタなし）をスクリーンショットで確認、
  10件表示（セキロ、Cyberpunk 2077、ドンキーコング バナンザ、ウィッチャー3、Tokyo 7th
  シスターズ、ペルソナ5、エルデンリング、Link! Like! ラブライブ!、Lovers、Ark: Survival
  Evolved）。
  → この後、フィルタアイコンからジャンルを選択して絞り込みが実際に効くか検証予定。

---

### 対応済み: マイログ画面のフィルタアイコン位置変更

- ユーザー要望: 「マイログのフィルターアイコンは、リスト・グリッド切り替えアイコンの左隣に
  配置してください。」
- 変更前: フィルタアイコンはAppBarのactions（歯車アイコンの左）に配置、グリッド/リスト
  切り替えアイコンはソート行（body内、`並び替え：`ドロップダウンと同じ行）の右端に配置されて
  おり、離れた位置にあった。
- 変更後: `lib/features/game_log/presentation/screens/my_logs_screen.dart`
  - AppBarのactionsからフィルタIconButtonを削除し、歯車アイコン（プロフィール設定）のみに。
  - ソート行の`Spacer()`の後、グリッド/リスト切り替えIconButtonの直前にフィルタIconButtonを
    追加（`_hasActiveFilter`で色が変わる仕様はそのまま維持）。
- `flutter analyze`で該当ファイルを確認、問題なし。
- エミュレータで再ビルド後、マイログ画面「遊んだ」タブでフィルタアイコンがグリッド切り替え
  アイコンの左隣に表示されていることをスクリーンショットで確認済み。

## 未解決・保留事項

- セール中ゲーム機能（IsThereAnyDeal API連携）: ユーザーの意向により保留中
  （「セール情報の表示はもう少し考えます」）。
- DLC・アップデート再表示バグ: 調査中、原因の当たりはついているが未修正（上記参照）。
