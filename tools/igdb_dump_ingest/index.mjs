// IGDB Data Dumps (games/covers/platforms/genres/game_localizations/regions) を
// Supabase Postgresのステージングテーブルへ取り込み、igdb_apply_staged_dump()で
// gamesテーブルへアトミックにマージする。
//
// ステージングテーブルへの大量INSERTは`supabase db query --linked -f <file>`
// （Supabase CLIがManagement API経由で認証する）を使う。理由: DBパスワードを
// 持たせずに済むため。ただし最後の1回だけ実行する`igdb_apply_staged_dump()`は
// 数十万行規模のUPSERTで数十秒〜数分かかり、Management API側の短いクエリ
// タイムアウトに引っかかって完了できないことが実測で分かった（集合演算ベースに
// 最適化した後でも106秒かかった）。そのため、この最後のマージ処理だけは
// 生のPostgres直接接続（pg、タイムアウト無制限）で行う。
//
// 認証情報の受け渡し:
//   TWITCH_CLIENT_ID     — 非機密。環境変数または --client-id で直接渡してよい。
//   TWITCH_CLIENT_SECRET — 環境変数、または --secret-file で指定したファイル
//   IGDB_INGEST_DB_URL   — 環境変数、または --db-url-file で指定したファイル
//     （Supabaseの Direct connection 接続文字列。マージ処理でのみ使用。
//     Session poolerは原因不明の認証エラーが再現したため、Direct connectionを使う）
//
// 実行例:
//   node index.mjs --client-id=xxxx --secret-file=/path/to/.env.twitch_secret \
//     --db-url-file=/path/to/.env.igdb_ingest
//
// マージだけをやり直したい場合（ステージング済みデータが残っている場合）は
// apply_only.mjs を使う。
//
// 設計上の注意（署名付きURLの5分制限）:
//   /v4/dumps/{endpoint} で取得するS3署名付きURLは発行から5分しか有効でない。
//   そのため「1エンドポイント取得したら即ダウンロード」を守り、全URLを先に
//   まとめて集めることはしない。

import { readFileSync, writeFileSync, mkdtempSync, rmSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { execFileSync } from 'node:child_process';
import { Readable } from 'node:stream';
import { parse } from 'csv-parse';
import pg from 'pg';

const IGDB_BASE_URL = 'https://api.igdb.com/v4';
const TWITCH_TOKEN_URL = 'https://id.twitch.tv/oauth2/token';
const BATCH_SIZE = 2000;

function parseArgs(argv) {
  const args = {};
  for (const raw of argv.slice(2)) {
    const m = raw.match(/^--([a-zA-Z0-9_-]+)=(.*)$/);
    if (m) args[m[1]] = m[2];
  }
  return args;
}

function readSecret(envName, fileArg, args) {
  if (process.env[envName]) return process.env[envName].trim();
  const filePath = args[fileArg];
  if (filePath) return readFileSync(filePath, 'utf8').trim();
  throw new Error(`${envName} is not set. Provide it via env var or --${fileArg}=<path>`);
}

async function getTwitchToken(clientId, clientSecret) {
  const url = new URL(TWITCH_TOKEN_URL);
  url.searchParams.set('client_id', clientId);
  url.searchParams.set('client_secret', clientSecret);
  url.searchParams.set('grant_type', 'client_credentials');
  const res = await fetch(url, { method: 'POST' });
  if (!res.ok) {
    throw new Error(`Twitch token request failed: ${res.status} ${await res.text()}`);
  }
  return (await res.json()).access_token;
}

async function fetchDumpMeta(endpoint, clientId, token) {
  const res = await fetch(`${IGDB_BASE_URL}/dumps/${endpoint}`, {
    headers: { 'Client-ID': clientId, Authorization: `Bearer ${token}` },
  });
  if (!res.ok) {
    throw new Error(`GET /v4/dumps/${endpoint} failed: ${res.status} ${await res.text()}`);
  }
  return res.json();
}

// ---- SQLリテラル整形 ----
// 取り込み元はIGDBの信頼できるダンプではあるが、テキストフィールド（summary等）に
// 任意の文字（シングルクォート含む）が入りうるため、必ずエスケープする。

function sqlStr(v) {
  if (v === null || v === undefined || v === '') return 'NULL';
  const nulChar = String.fromCharCode(0);
  const cleaned = String(v).split(nulChar).join('');
  return `'${cleaned.replace(/'/g, "''")}'`;
}

function sqlNum(v) {
  if (v === null || v === undefined || v === '') return 'NULL';
  return String(v);
}

// CSV上は既にPostgresの配列リテラル文字列（例: "{1,2,3}"）なので、
// クォートしてキャストするだけでよい。
function sqlBigIntArray(v) {
  if (v === null || v === undefined || v === '') return "'{}'::bigint[]";
  return `'${String(v).replace(/'/g, "''")}'::bigint[]`;
}

function sqlTimestamp(v) {
  if (v === null || v === undefined || v === '') return 'NULL';
  return `'${String(v).replace(/'/g, "''")}'::timestamp`;
}

// ---- supabase CLI経由でのSQL実行 ----

const scratchDir = mkdtempSync(join(tmpdir(), 'igdb-ingest-'));
let sqlFileCounter = 0;

function runSql(sqlText) {
  sqlFileCounter += 1;
  const filePath = join(scratchDir, `q${sqlFileCounter}.sql`);
  writeFileSync(filePath, sqlText, 'utf8');
  const stdout = execFileSync(
    'supabase',
    ['db', 'query', '--linked', '-f', filePath],
    { encoding: 'utf8', maxBuffer: 1024 * 1024 * 64 },
  );
  rmSync(filePath, { force: true });
  const parsed = JSON.parse(stdout);
  if (parsed._tag === 'Error') {
    throw new Error(`SQL failed: ${JSON.stringify(parsed.error)}`);
  }
  return parsed.rows;
}

function buildInsertSql(table, columns, rows) {
  const values = rows.map((r) => `(${r.join(',')})`).join(',\n');
  return `insert into ${table} (${columns.join(', ')}) values\n${values};\n`;
}

async function streamCsv(url, onRecord) {
  const res = await fetch(url);
  if (!res.ok) throw new Error(`download failed: ${res.status} ${res.statusText}`);
  const nodeStream = Readable.fromWeb(res.body);
  const parser = nodeStream.pipe(
    parse({ columns: true, relax_column_count: true, skip_empty_lines: true }),
  );
  let count = 0;
  for await (const record of parser) {
    await onRecord(record);
    count += 1;
  }
  return count;
}

async function ingestLookup(endpoint, clientId, token, table) {
  const meta = await fetchDumpMeta(endpoint, clientId, token);
  console.log(`[${endpoint}] size_bytes=${meta.size_bytes}, downloading...`);
  let batch = [];
  let total = 0;
  const flush = () => {
    if (batch.length === 0) return;
    runSql(buildInsertSql(table, ['id', 'name'], batch));
    total += batch.length;
    batch = [];
  };
  await streamCsv(meta.s3_url, async (r) => {
    batch.push([sqlNum(r.id), sqlStr(r.name)]);
    if (batch.length >= BATCH_SIZE) flush();
  });
  flush();
  console.log(`[${endpoint}] ingested ${total} rows into ${table}`);
  return total;
}

async function ingestCovers(clientId, token) {
  const meta = await fetchDumpMeta('covers', clientId, token);
  console.log(`[covers] size_bytes=${meta.size_bytes}, downloading...`);
  const cols = ['id', 'image_id', 'game'];
  let batch = [];
  let total = 0;
  const flush = () => {
    if (batch.length === 0) return;
    runSql(buildInsertSql('igdb_stage_covers', cols, batch));
    total += batch.length;
    batch = [];
  };
  await streamCsv(meta.s3_url, async (r) => {
    batch.push([sqlNum(r.id), sqlStr(r.image_id), sqlNum(r.game)]);
    if (batch.length >= BATCH_SIZE) flush();
  });
  flush();
  console.log(`[covers] ingested ${total} rows`);
  return total;
}

async function ingestGameLocalizations(clientId, token) {
  const meta = await fetchDumpMeta('game_localizations', clientId, token);
  console.log(`[game_localizations] size_bytes=${meta.size_bytes}, downloading...`);
  const cols = ['id', 'name', 'game', 'region'];
  let batch = [];
  let total = 0;
  const flush = () => {
    if (batch.length === 0) return;
    runSql(buildInsertSql('igdb_stage_game_localizations', cols, batch));
    total += batch.length;
    batch = [];
  };
  await streamCsv(meta.s3_url, async (r) => {
    batch.push([sqlNum(r.id), sqlStr(r.name), sqlNum(r.game), sqlNum(r.region)]);
    if (batch.length >= BATCH_SIZE) flush();
  });
  flush();
  console.log(`[game_localizations] ingested ${total} rows`);
  return total;
}

async function ingestGames(clientId, token) {
  const meta = await fetchDumpMeta('games', clientId, token);
  console.log(`[games] size_bytes=${meta.size_bytes}, downloading...`);
  const cols = [
    'id', 'name', 'summary', 'url', 'cover', 'platforms', 'genres', 'themes',
    'keywords', 'game_type', 'version_parent', 'first_release_date', 'rating',
    'rating_count', 'total_rating_count',
  ];
  let batch = [];
  let total = 0;
  const flush = () => {
    if (batch.length === 0) return;
    runSql(buildInsertSql('igdb_stage_games', cols, batch));
    total += batch.length;
    if (total % (BATCH_SIZE * 10) === 0) console.log(`[games] ...${total} rows so far`);
    batch = [];
  };
  await streamCsv(meta.s3_url, async (r) => {
    batch.push([
      sqlNum(r.id), sqlStr(r.name), sqlStr(r.summary), sqlStr(r.url), sqlNum(r.cover),
      sqlBigIntArray(r.platforms), sqlBigIntArray(r.genres), sqlBigIntArray(r.themes),
      sqlBigIntArray(r.keywords), sqlNum(r.game_type), sqlNum(r.version_parent),
      sqlTimestamp(r.first_release_date), sqlNum(r.rating), sqlNum(r.rating_count),
      sqlNum(r.total_rating_count),
    ]);
    if (batch.length >= BATCH_SIZE) flush();
  });
  flush();
  console.log(`[games] ingested ${total} rows`);
  return total;
}

async function applyStagedDumpViaDirectConnection(dbUrl, stagedGamesCount) {
  const client = new pg.Client({ connectionString: dbUrl, ssl: { rejectUnauthorized: false } });
  await client.connect();
  await client.query("set timezone = 'UTC'");
  await client.query('set statement_timeout = 0');

  const runRows = await client.query(
    "insert into igdb_dump_runs (endpoint, status) values ('games', 'running') returning id",
  );
  const runId = runRows.rows[0].id;

  try {
    console.log('Applying staged dump (igdb_apply_staged_dump, direct connection)...');
    const t0 = Date.now();
    const { rows } = await client.query('select * from igdb_apply_staged_dump()');
    const elapsedSec = ((Date.now() - t0) / 1000).toFixed(1);
    const { staged_count: stagedCount, rows_affected: rowsAffected } = rows[0];
    await client.query(
      "update igdb_dump_runs set status = 'success', finished_at = now(), row_count = $1 where id = $2",
      [stagedCount, runId],
    );
    console.log(
      `Done in ${elapsedSec}s. staged_count=${stagedCount} (script counted ${stagedGamesCount}), rows_affected=${rowsAffected}`,
    );
  } catch (err) {
    await client.query(
      "update igdb_dump_runs set status = 'failed', finished_at = now(), error = $1 where id = $2",
      [String(err.message || err), runId],
    );
    throw err;
  } finally {
    await client.end();
  }
}

async function main() {
  const args = parseArgs(process.argv);
  const clientId = process.env.TWITCH_CLIENT_ID || args['client-id'];
  if (!clientId) throw new Error('TWITCH_CLIENT_ID is required (env or --client-id=)');
  const clientSecret = readSecret('TWITCH_CLIENT_SECRET', 'secret-file', args);
  const dbUrl = readSecret('IGDB_INGEST_DB_URL', 'db-url-file', args);

  console.log('Fetching Twitch access token...');
  const token = await getTwitchToken(clientId, clientSecret);
  console.log('Got token.');

  console.log('Truncating staging/lookup tables...');
  runSql(
    'truncate table igdb_platforms, igdb_genres, igdb_regions, ' +
      'igdb_stage_covers, igdb_stage_game_localizations, igdb_stage_games;',
  );

  try {
    await ingestLookup('platforms', clientId, token, 'igdb_platforms');
    await ingestLookup('genres', clientId, token, 'igdb_genres');
    await ingestLookup('regions', clientId, token, 'igdb_regions');
    await ingestCovers(clientId, token);
    await ingestGameLocalizations(clientId, token);
    const stagedGamesCount = await ingestGames(clientId, token);

    await applyStagedDumpViaDirectConnection(dbUrl, stagedGamesCount);
  } finally {
    rmSync(scratchDir, { recursive: true, force: true });
  }
}

main().catch((err) => {
  console.error('Ingestion failed:', err);
  process.exitCode = 1;
});
