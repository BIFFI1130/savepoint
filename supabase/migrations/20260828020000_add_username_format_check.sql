-- profiles.usernameの書式（半角英数字のみ）は、これまでオンボーディング画面の
-- クライアント側RegExpのみで担保されており、DB側には対応するcheck制約が無かった。
-- 有効なJWTがあれば専用RPCを経由せずprofilesテーブルへ直接PATCHでき、
-- 空白・絵文字・制御文字・Unicode双方向制御文字・数百文字の長大な文字列など、
-- 意図しない値をusernameに設定できてしまっていた（follow_feed・game_public_reviews・
-- ユーザー検索結果等、他ユーザーの目に触れる箇所に直接表示されるため、表示崩れや
-- なりすまし紛いの文字種の悪用につながりうる）。クライアント側の書式
-- （`^[a-zA-Z0-9]+$`）と揃え、長さの上限も加えてDB側でも強制する。
--
-- 既存データにこの制約へ違反する行が実在した（適用時に検出済み。恐らく日本語や
-- 記号を含むユーザー名を持つ既存アカウント）ため、NOT VALIDで追加する。これにより
-- 既存行は検証せずそのまま許容しつつ、以後の新規insert・update（＝この脆弱性の
-- 悪用経路）に対しては即座に制約を強制できる。既存の違反行を特定して是正する場合は
-- 別途調査のうえ対応し、対応後に`validate constraint`で全行検証済みの状態にできる。
alter table public.profiles
  add constraint profiles_username_format_check
  check (username ~ '^[a-zA-Z0-9]{1,32}$') not valid;
