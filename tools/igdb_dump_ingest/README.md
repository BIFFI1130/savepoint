# igdb_dump_ingest

IGDB Data Dumps（Data Partner限定機能。全エンドポイントを日次CSVで一括取得できる）を
Supabaseのステージングテーブルへ取り込み、`igdb_apply_staged_dump()`で`games`テーブルへ
アトミックにマージするツール。ホーム（今週/今月発売・TOP100）・発売日カレンダーを、
IGDBへのライブAPI呼び出し無しで返せるようにするためのバックエンド。

対応するスキーマ・RPC関数は`supabase/migrations/20260820*.sql`を参照。

## 認証情報

| 変数名 | 内容 | 機密性 |
|---|---|---|
| `TWITCH_CLIENT_ID` | Data Dumps機能が有効化されたTwitch Client ID | 非機密 |
| `TWITCH_CLIENT_SECRET` | 同Client Secret | 機密 |
| `IGDB_INGEST_DB_URL` | SupabaseのDirect connection接続文字列 | 機密 |

いずれも環境変数、または`--client-id=`・`--secret-file=`・`--db-url-file=`（ファイルの中身をそのまま読む）で渡せる。

**注意**: `IGDB_INGEST_DB_URL`は**Direct connection**（`db.<project-ref>.supabase.co:5432`）を
使うこと。Session pooler（`aws-0-*.pooler.supabase.com:5432`）は原因不明の
`password authentication failed`が繰り返し再現したため、動作確認できていない。

## なぜDBへの書き込み方法が2種類に分かれているか

- ステージングテーブルへの大量INSERT: `supabase db query --linked -f <file>`
  （Supabase CLIがManagement API経由で認証する）を使う。DBパスワードを持たせずに済む。
- 最後の1回だけ実行する`igdb_apply_staged_dump()`: 生のPostgres直接接続（`pg`パッケージ、
  `statement_timeout=0`）を使う。数十万行規模のUPSERTで実測100秒前後かかり、
  Management API側の短いクエリタイムアウトに引っかかって完了できないことが分かったため。

## 使い方

```bash
npm install

node index.mjs \
  --client-id=<Twitch Client ID> \
  --secret-file=/path/to/twitch_secret.txt \
  --db-url-file=/path/to/db_url.txt
```

途中でダウンロード済みのステージングデータが残っている状態から、マージ処理だけを
やり直したい場合（Management API側のタイムアウトで失敗した場合など）:

```bash
node apply_only.mjs --db-url-file=/path/to/db_url.txt
```

## GitHub Actionsでのスケジュール化について

未実施（2026-08-20時点）。IGDB側の正式契約（DocuSign署名）完了後に着手する予定。
`.github/workflows/igdb-dump-ingest.yml`として、`schedule`（日次）＋手動実行用の
`workflow_dispatch`で追加する想定。
