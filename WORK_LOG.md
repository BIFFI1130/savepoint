# 作業メモ

対応内容・バグ修正を都度ここに追記していく。コンテキストが失われても、このファイルを見れば
状況を復元しやすくするためのログ。新しいものを上に追記する。

---

## 2026-08-14（続き4）

### 対応済み: 通報の運営側確認手段を整備（製品版リリース準備 #6）

`reports`テーブルは以前から存在し「一般ユーザーはinsertのみ、運営はSupabase
ダッシュボード（service role）から確認する」設計だったが、(1)対応状況を
追跡する手段がなく、(2)reporter_id/reported_user_idが生のUUIDのままで
ダッシュボードで見ても誰が誰を通報したのか分からない、という2点が未整備だった。

- マイグレーション`20260814010000_add_report_status_and_admin_view.sql`:
  `reports`に`status`（open/resolved/dismissed）・`resolved_at`・`resolved_note`
  を追加し、`reports_with_details`ビュー（reporter/reportedのusername・
  display_nameを結合、未対応が上に来るソート）を新設。
- マイグレーション`20260814020000_grant_service_role_reports_view.sql`:
  このプロジェクトはservice_roleへのGRANTが自動では付かない設計（既存の
  games/igdb_tokensのGRANT漏れと同じ理由）のため、`reports`のselect/update
  と`reports_with_details`のselectをservice_roleに明示的に付与。
- 両マイグレーションをdev（lsitiazbafrgeyklcckc）・prod（hjqgeewbuwuxwyorceog）
  両方に適用。
- README「通報の確認方法（運営向け）」を新設し、Table Editor / SQL Editorでの
  確認手順と、対応後のstatus更新方法を記載。アプリ内に管理画面は作らず、
  ダッシュボード運用とする方針を明記。

検証: devプロジェクトに実際に残っていた過去のテスト通報2件がservice_role経由で
`reports_with_details`から正しく（ユーザー名付きで）取得できること、PATCHで
status更新ができ、ビューの並び順が意図通り変わることを確認。確認後、テストで
書き換えたstatusは`open`に戻した。

---

## 2026-08-14（続き3）

### 対応済み: クラッシュレポート（Firebase Crashlytics）導入（製品版リリース準備 #5）

製品版リリース準備の punch list 項目5。既存のFirebaseプロジェクト`savepoint-505117`
（これまでAndroidのFirebase App Distribution配信専用に使っていたもの）にiOSアプリを
新規登録し、Flutter側にCrashlyticsを組み込んだ。

- `flutterfire configure`でiOS/Android両方のFirebaseアプリを登録し`lib/firebase_options.dart`
  を生成。iOS用`GoogleService-Info.plist`は`flutterfire configure`が自動配置しなかったため、
  `firebase apps:sdkconfig IOS <appId>`で直接ダウンロードして`ios/Runner/`に配置した
  （Xcodeがない環境のためproject.pbxprojへのリソース登録はできていないが、Dart側の
  `Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform)`で必要な値は
  すべて渡されるため、プラグインの動作自体に支障はない）。
- `flutterfire configure`が`android/settings.gradle.kts`に古いバージョン(4.3.15)の
  google-services pluginを重複追加し、既存の`android/build.gradle.kts`側の宣言(4.5.0)と
  バージョン衝突してビルドが失敗する問題が発生。重複分を削除して解消。
- `pubspec.yaml`に`firebase_core`・`firebase_crashlytics`を追加。`lib/main.dart`で
  Supabase初期化成功後にFirebaseを初期化し、`FlutterError.onError`と
  `PlatformDispatcher.instance.onError`をCrashlyticsに接続（Dart側の同期・非同期例外を
  両方捕捉）。デバッグ実行時（`kDebugMode`）は収集を無効化し、リリースビルドのみ収集する。
- Android側は`android/build.gradle.kts`・`android/app/build.gradle.kts`にCrashlytics
  Gradle pluginと`firebase-crashlytics`/`firebase-crashlytics-ndk`依存を追加し、リリース
  ビルドで`nativeSymbolUploadEnabled = true`を設定（ネイティブ層のクラッシュもシンボリケート
  可能にする）。
- iOS側はXcodeのビルドフェーズ編集（dSYMアップロード用Run Script）をWindows環境からは
  行えないため、代わりに`codemagic.yaml`のiOSビルドステップ内で
  `firebase crashlytics:symbols:upload`をCLIから実行するようにし、`flutter build ipa`の
  直後にdSYMをアップロードする（失敗してもTestFlightへのパブリッシュ自体は継続するよう
  `|| echo ...`で握りつぶす）。

検証:
- `flutter build apk --release`が成功することを確認（Crashlytics Gradle設定のシンタックス
  エラーがないことの確認）。
- Androidエミュレータでリリースビルド（x86_64ターゲットでエミュレータのアーキテクチャに
  合わせてビルドし直したもの）を実機確認。起動時ログで`FirebaseCrashlytics`・
  `libcrashlytics`（NDK側ネイティブハンドラ）が正常に初期化されることを確認。
  `adb shell am crash com.biffi.savepoint`で強制的にクラッシュさせた後、次回起動時に
  Crashlyticsがローカルのクラッシュレポートファイル（priority-reports配下）を検出し
  アップロード処理を試みるログを確認した（Firebase Consoleダッシュボードへの反映は
  数分〜数時間のタイムラグがあるため、実際の反映は別途確認が必要）。
- `flutter analyze`は既存の無関係な警告のみでクリーン。
- iOS側は実機/シミュレータでの検証はできなかった（Windows環境のため）。次回のCodemagic
  ビルドで`firebase crashlytics:symbols:upload`ステップのログを確認し、実際に動作するか
  確認すること。

---

## 2026-08-14（続き2）

### 対応済み: アプリ内アカウント削除機能を実装（製品版リリース準備 #1）

- 背景: 製品版リリース前の抜け漏れ調査で、Apple/Google審査に必須の「アプリ内アカウント
  削除」機能が未実装だと判明（設定画面自体が無かった）。ユーザーの指示「1から順番に慎重に
  実装していってください」を受けて対応。
- 新規Edge Function `supabase/functions/delete-account/index.ts`: 呼び出し元のJWTを
  anon keyクライアントで検証して本人確認した上で、service roleで
  (1) Storage `avatars`バケット配下の本人のアバター画像を削除（ベストエフォート）、
  (2) `auth.admin.deleteUser`で`auth.users`行を削除。`public.profiles`以下、
  `game_logs`/`collections`/`collection_games`/`favorite_games`/`follows`/`blocks`/
  `reports`など本人に紐づく全テーブルは既存の`on delete cascade`FK制約で連鎖削除される
  （新規マイグレーション不要、既存スキーマの設計で完結）。
- `lib/features/auth/data/auth_repository.dart`に`deleteAccount()`を追加
  （Edge Function呼び出し→成功したら`signOut()`）。
- `lib/features/social/presentation/screens/my_profile_screen.dart`に「アカウント」
  セクションを新設。「ログアウト」（このアプリに元々無かった導線だったため合わせて追加）と
  「アカウントを削除」の2項目。削除は誤操作防止のため2段階確認
  （影響範囲の説明ダイアログ→「削除」と入力しないとボタンが有効化されない最終確認
  ダイアログ）を経てから実行する設計にした。
- 検証: Admin APIで使い捨てテストユーザーを作成し、(a) curlでEdge Functionを直接叩いて
  正常削除・cascade削除・認証ヘッダー無し/不正トークンでの401拒否を確認、
  (b) 実機（エミュレータ）でアプリ内サインイン→プロフィール画面→ログアウト→
  アカウント削除の2段階ダイアログ→サインイン画面への自動遷移までUI操作で確認、
  (c) バックエンド側で`auth.admin`から当該ユーザーが404になっている（完全削除）ことを
  再度確認。既存の`test1`等の実データには一切手を加えていない。
- 補足（作業メモ）: エミュレータの日本語Gboardは`adb shell input text`でASCII文字を
  送ると既存の入力バッファに割り込む・ローマ字未確定のまま残る等の癖があり、加えて
  漢字を含む文字列（確認ダイアログの「削除」）は`adb shell input text`自体が
  非ASCII文字でNullPointerExceptionを起こし送信不可だった。最終的に
  `uiautomator dump`で正確なウィジェット座標を都度取得してタップする方式と、
  PowerShellの`Set-Clipboard`→エミュレータの共有クリップボード経由でIMEのクリップボード
  候補チップをタップする方式で確実に操作できた。

## 2026-08-14（続き）

### 対応済み: Android配布テスターをFirebase App Distributionのグループで管理するように変更

- ユーザー要望: 「Androidユーザーへのテスト配布をデータ化したいです（今は一人のユーザーを
  決め打ち）。App Distributionのテスターをそのまま使えないでしょうか？」
- 従来`codemagic.yaml`は`firebase appdistribution:distribute`の宛先を
  `--testers "lanbian38@gmail.com"`と1人決め打ちにしていた。Firebase App Distributionには
  「テスターグループ」機能があり、グループ名を指定して配布すればグループ内の全テスターに
  自動配布される（テスターの追加・削除はFirebase側の操作だけで完結し、CIの設定変更は不要）
  ため、これに切り替えるのが要望に合致すると判断。ユーザーに実行内容を確認の上で対応。
- Firebase CLI（`firebase appdistribution:groups:create`・`firebase appdistribution:
  testers:add --group-alias`）でプロジェクト`savepoint-505117`に`testers`という
  エイリアスのグループ（表示名「テスター」）を新規作成し、既存の2人のテスター
  （`0ce38f3c2xb491k@ezweb.ne.jp`・`lanbian38@gmail.com`）をそのグループに追加した。
- `codemagic.yaml`の`firebase appdistribution:distribute`呼び出しを
  `--testers "lanbian38@gmail.com"`から`--groups "testers"`に変更。今後テスターを
  増減させたい場合は、Firebaseコンソールの「App Distribution > テスターとグループ」
  （このユーザーが最初に共有したスクリーンショットの画面）で`testers`グループに
  テスターを追加・削除するだけでよく、`codemagic.yaml`を触る必要はない。
- YAML構文はPythonの`yaml.safe_load`で確認済み。`firebase appdistribution:group:list`・
  `firebase appdistribution:testers:list testers`で2人ともグループに正しく所属している
  ことを確認済み。次回のCodemagicビルドで実際にこのグループ宛に配布されるかは
  ローカルでは検証できないため、次回のリリースビルドで確認が必要。

## 2026-08-14

まとめてユーザーから依頼のあった6件のバグ修正・新機能を対応。

### 対応済み: オレの推しゲー — 空状態メッセージの簡素化・未保存確認ダイアログ

- ユーザー要望: 「何も追加されていないとき、『まだ推しゲーが登録されていません』だけで良い」
  「戻るときに保存してなかったら確認してほしい」。
- `lib/features/favorites/presentation/screens/favorite_games_edit_screen.dart`:
  - 空状態の`EmptyView`メッセージから「右下のボタンから追加しましょう」の2行目を削除し、
    「まだ推しゲーが登録されていません」のみに変更（プロフィール画面側の表示は既に
    このメッセージのみだったので、編集画面側を合わせた）。
  - `_hydrate`で初期値（`_initialGameIds`・`_initialRanked`）を保持し、現在の状態と比較する
    `_isDirty`を追加。画面全体を`PopScope(canPop: !_isDirty)`で包み、`onPopInvokedWithResult`で
    未保存の変更がある場合のみ確認ダイアログ（「編集内容を破棄しますか？」）を出す。
    保存成功時は`_initialGameIds`/`_initialRanked`を保存後の値で更新してから`pop()`する
    （更新しないと、保存直後の自動pop自体が「未保存変更あり」と誤判定されてダイアログが
    出てしまうため）。
  - エミュレータで確認: 1件削除→戻る→確認ダイアログ表示→「編集を続ける」で画面に留まる→
    再度戻る→「破棄する」でDB上の元の内容のまま一覧に戻ることを確認。

### 対応済み: ゲーム詳細画面「遊んだ」ボタンの配色がデフォルトで選択状態に見える

- ユーザー報告: 「『遊んだ』の配色がデフォルトで押されているように見えている。『遊びたい』と
  同じでいい」。
- 原因: `_StatusAndLogSection`（`lib/features/game_search/presentation/screens/game_detail_screen.dart`）
  で「遊んだ」ボタンが常時`FilledButton.icon`だった（記録の有無に関わらず塗りつぶし＝選択中に
  見える配色）。「遊びたい」ボタンは`isWantToPlay`で`FilledButton`/`OutlinedButton`を
  切り替えていたのに、「遊んだ」だけ切り替えがなかった。
- `isPlayed`のとき`FilledButton.icon`（記録を編集する）、そうでないとき`OutlinedButton.icon`
  （遊んだ）に切り替えるよう修正。エミュレータで未記録のゲームを開き、両ボタンとも
  アウトライン表示になることを確認。

### 対応済み: igdb-proxy — 成人向け/インディーフィルタがタイトル検索で効かない・Persona 5 Royalが検索に出ない

- ユーザー報告2件: 「検索で『成人向け作品を表示する』『インディー作品を表示する』のフィルターが
  効いていない気がする」「Persona5 Royalが検索に引っかからない」。原因は両方とも
  `supabase/functions/igdb-proxy/index.ts`の`search`アクション。
- **フィルタが効かない件**: 以前のセッションで「タイトル検索時は独自キュレーションフィルタ
  （成人向け・インディー・非公式作品除外）を一切適用しない」という実装にしていた
  （検索精度を優先した意図的な変更だったが、結果としてチェックボックスがタイトル検索では
  常に無視される状態になっていた）。`hasQuery`の有無に関わらず`commonExclusionFilters()`を
  常に適用するよう統一し、検索・一覧のどちらでもチェックボックスの効果が一貫するようにした。
- **Persona 5 Royalが出ない件**: `parent_game = null`を無条件に除外条件へ入れていたのが原因。
  IGDB上「Persona 5 Royal」はgame_type=10（expanded_game）でparent_game=Persona 5と
  紐付けられており、これが「DLC/アップデート等の付随コンテンツ」除外に誤って巻き込まれていた。
  `ATTACHMENT_GAME_TYPE_IDS`（1=dlc_addon, 2=expansion, 6=episode, 14=update）を新設し、
  parent_gameが設定されていてもgame_typeがこれらに該当しない場合（expanded_game/remake/
  remaster/standalone_expansion/port等、実質的に別ROMの独立タイトル）は除外しないよう変更。
  従来のDLC重複表示バグ対策（parent_game持ちの本物のDLC除外）は維持されている。
- `search`アクション内の個別実装を`commonExclusionFilters()`呼び出しに統一し、コードの重複も
  削減。`npx supabase functions deploy igdb-proxy`でデプロイ済み。curlで動作確認:
  - `query: "Persona 5 Royal"` → id=114283「Persona 5 Royal」がヒットするようになった。
  - `query: "HuniePop"`（Erotic + Indie両方に該当）→ `includeAdult`/`includeIndie`ともに
    falseなら0件、両方trueなら1件ヒット。タイトル検索でもチェックボックスが機能することを確認。

### 対応済み: 生年月オンボーディング・18歳未満への成人向けオプション非表示

- ユーザー要望: 「生年月の登録がされていなければ、起動時に生年月の入力を求める」
  「登録された生年月が18歳を超えていなければ『成人向け作品を表示する』オプションを表示しない」。
- **DB**: `supabase/migrations/20260814000000_add_birthdate_to_profiles.sql`で
  `profiles.birth_year`・`profiles.birth_month`（年・月のみ、日は取得しない）を追加。
- **年齢判定**: `lib/core/utils/age.dart`に`isAdultBirthYearMonth(year, month)`を新設。
  日が不明なため、誕生月と同じ月の間は「まだ17歳の可能性がある」として非成人扱いにし、
  翌月になって初めて成人と判定する安全側の実装
  （`(now.year - birthYear > 18) || (now.year - birthYear == 18 && now.month > birthMonth)`）。
- **強制オンボーディング**: `lib/core/onboarding/birthdate_gate.dart`
  （`UsernameGateController`と同じ設計）と`lib/features/social/presentation/screens/
  birthdate_onboarding_screen.dart`（`PopScope(canPop: false)`、生年・生月のドロップダウン2つ）
  を新規実装。`app_router.dart`のredirectに、ユーザーID設定済みの場合のみ続けて生年月をチェック
  するロジックを追加（`/onboarding/birthdate`ルート）。
- **成人向けオプションの非表示**: `lib/features/social/presentation/providers/
  social_providers.dart`に`isAdultUserProvider`（`myProfileProvider`の生年月から算出）を追加。
  `AdvancedFiltersSection`（`lib/core/widgets/advanced_filters_section.dart`）に
  `showAdultOption`フラグを追加し、falseなら「成人向け作品を表示する」チェックボックス自体を
  描画しない。呼び出し元5箇所（検索・トレンド・カレンダー・ホームの一覧・マイログ）すべてに
  `showAdultOption: (ref.watch|ref.read)(isAdultUserProvider)`を渡した。トレンド画面のみ
  `StatefulWidget`だったため`ConsumerStatefulWidget`に変更が必要だった。
- 既存テストアカウント`test1`（birth_year=2000, birth_month=11、既に設定済みだった）を使い、
  一時的に生年月をnullにしてエミュレータで確認: ①起動時に生年月入力画面が強制表示される
  ②戻るボタンでは閉じられない ③2016年1月（18歳未満）で保存すると検索画面の「詳しい条件」に
  「成人向け作品を表示する」が表示されなくなる（「インディー作品を表示する」は表示されたまま）
  ことを確認。確認後、test1の生年月は元の値（2000年11月）に復元済み。

### 対応済み: igdb-proxy — 表示するgame_typeをホワイトリスト方式に変更

- ユーザー要望: 「Bundle, DLC, Update, Pack/Addon, Mod は表示しないようにしてください。
  （Main Game, Expansion, Remake, Expanded Gameのみ）」。
- 直前の対応で導入した`ATTACHMENT_GAME_TYPE_IDS`（除外リスト方式）と既存の
  `UNOFFICIAL_GAME_TYPE_IDS`（mod/fork除外）を統合し、`ALLOWED_GAME_TYPE_IDS = [0, 2, 8, 10]`
  （main_game/expansion/remake/expanded_game）のホワイトリスト方式に変更。
  `commonExclusionFilters()`のgame_type条件を
  `(game_type = null | game_type = (0,2,8,10))`に一本化（game_type未設定の作品は
  引き続き許可）。これによりBundle(3)・DLC/addon(1)・standalone_expansion(4)・
  episode(6)・season(7)・remaster(9)・port(11)・fork(12)・pack(13)・update(14)は
  ユーザー指定のリストに含まれないものも含めすべて除外される。
- `npx supabase functions deploy igdb-proxy`でデプロイ済み。curlで確認:
  「Persona 5 Royal」検索で本編のみ表示され「Persona 5 Royal: Persona Bundle」が
  消えたこと、「Monster Hunter Rise Title Update」で0件になったこと、
  「Cyberpunk 2077」で本編のみ表示されることを確認。

### 対応済み: 「遊びたい」ボタンをトグル化（もう一度押すと解除）

- ユーザー要望: 「『遊びたい』は押されている状態で再び押すと解除されてほしい」。
- `game_detail_screen.dart`の`_markWantToPlay`を`_toggleWantToPlay(GameLog? log)`に変更。
  現在の記録が`GameLogStatus.wantToPlay`のときは`logRepository.deleteLog(log.id)`で記録ごと
  削除して解除し、それ以外（未登録・遊んだ済み）のときは従来通り`markWantToPlay`で登録する。
  「遊びたい」記録は評価・レビューを持たない前提のため、解除＝削除で問題ない
  （もし評価・レビュー付きの「遊んだ」記録だった場合はこの分岐に入らないため消えない）。
- エミュレータで確認: 未記録タイトルで「遊びたい」→「遊びたい登録済み」（塗りつぶし）に変化→
  もう一度タップ→「遊びたい」（アウトライン）に戻り、「記録を削除する」ボタンも消えて
  記録が完全に解除されたことを確認。

### 補足: flutter analyze・全体確認

- 上記すべてのDart変更後、`flutter analyze`をプロジェクト全体に対して実行し、新規の
  warning/errorがないことを確認（既存の`onReorder`非推奨警告のみ残存、対応不要）。

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
