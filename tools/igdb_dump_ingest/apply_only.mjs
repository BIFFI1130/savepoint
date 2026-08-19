// ステージング済みデータ(既にigdb_stage_*テーブルに投入済み)に対して、
// igdb_apply_staged_dump()だけを実行する一回限りの補助スクリプト。
// Management API経由のCLI(`supabase db query`)は短いstatement timeoutを
// 強制するため使えない(大きなUPSERTが完了できない)。生のPostgres直接接続
// (Direct connection)なら`SET statement_timeout = 0`で無制限にできるため、
// こちらを使う。

import { readFileSync } from 'node:fs';
import pg from 'pg';

const args = {};
for (const raw of process.argv.slice(2)) {
  const m = raw.match(/^--([a-zA-Z0-9_-]+)=(.*)$/);
  if (m) args[m[1]] = m[2];
}

function readSecret(envName, fileArg) {
  if (process.env[envName]) return process.env[envName].trim();
  const filePath = args[fileArg];
  if (filePath) return readFileSync(filePath, 'utf8').trim();
  throw new Error(`${envName} is not set. Provide it via env var or --${fileArg}=<path>`);
}

async function main() {
  const dbUrl = readSecret('IGDB_INGEST_DB_URL', 'db-url-file');
  const client = new pg.Client({ connectionString: dbUrl, ssl: { rejectUnauthorized: false } });
  console.log('Connecting...');
  await client.connect();
  console.log('Connected.');
  await client.query("set timezone = 'UTC'");
  await client.query('set statement_timeout = 0');

  const runRows = await client.query(
    "insert into igdb_dump_runs (endpoint, status) values ('games', 'running') returning id",
  );
  const runId = runRows.rows[0].id;
  console.log(`Started run id=${runId}`);

  try {
    console.log('Applying staged dump (this may take a while)...');
    const t0 = Date.now();
    const { rows } = await client.query('select * from igdb_apply_staged_dump()');
    const elapsedSec = ((Date.now() - t0) / 1000).toFixed(1);
    const { staged_count: stagedCount, rows_affected: rowsAffected } = rows[0];
    await client.query(
      "update igdb_dump_runs set status = 'success', finished_at = now(), row_count = $1 where id = $2",
      [stagedCount, runId],
    );
    console.log(`Done in ${elapsedSec}s. staged_count=${stagedCount}, rows_affected=${rowsAffected}`);
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

main().catch((err) => {
  console.error('Failed:', err);
  process.exitCode = 1;
});
