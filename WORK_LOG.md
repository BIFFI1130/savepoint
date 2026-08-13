# 作業メモ

対応内容・バグ修正を都度ここに追記していく。コンテキストが失われても、このファイルを見れば
状況を復元しやすくするためのログ。新しいものを上に追記する。

---

## 2026-08-13

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
