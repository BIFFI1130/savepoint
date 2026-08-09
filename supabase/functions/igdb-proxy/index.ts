// igdb-proxy
//
// Flutterクライアントの代わりにIGDB(Internet Game Database)へ問い合わせるEdge Function。
// IGDBはTwitchのOAuthクライアント資格情報を必要とするが、そのシークレットは
// このサーバー側関数だけが保持し、クライアントには一切渡さない。
//
// 使い方（Flutter側）:
//   supabase.functions.invoke('igdb-proxy', body: {action: 'search', query: '...'})
//   supabase.functions.invoke('igdb-proxy', body: {action: 'details', id: 1234})
//
// 必要な環境変数（`supabase secrets set` で設定する）:
//   TWITCH_CLIENT_ID, TWITCH_CLIENT_SECRET
// 以下はSupabaseが自動的に注入する:
//   SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY

import { createClient } from 'jsr:@supabase/supabase-js@2';

const IGDB_BASE_URL = 'https://api.igdb.com/v4';
const TWITCH_TOKEN_URL = 'https://id.twitch.tv/oauth2/token';

const GAME_FIELDS =
  'id,name,cover.url,first_release_date,platforms.name,summary';

interface RawIgdbGame {
  id: number;
  name?: string;
  cover?: { url?: string };
  first_release_date?: number; // unix seconds
  platforms?: { name: string }[];
  summary?: string;
}

interface GameRow {
  id: number;
  name: string;
  cover_url: string | null;
  first_release_date: string | null;
  platforms: string[];
  summary: string | null;
  raw_igdb_json: RawIgdbGame;
  cached_at: string;
}

function serviceRoleClient() {
  return createClient(
    Deno.env.get('SUPABASE_URL')!,
    Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!,
  );
}

function toBigCoverUrl(url: string | undefined): string | null {
  if (!url) return null;
  const withScheme = url.startsWith('//') ? `https:${url}` : url;
  return withScheme.replace('t_thumb', 't_cover_big');
}

function toIsoDate(unixSeconds: number | undefined): string | null {
  if (!unixSeconds) return null;
  return new Date(unixSeconds * 1000).toISOString().slice(0, 10);
}

function toGameRow(raw: RawIgdbGame): GameRow {
  return {
    id: raw.id,
    name: raw.name ?? '(タイトル不明)',
    cover_url: toBigCoverUrl(raw.cover?.url),
    first_release_date: toIsoDate(raw.first_release_date),
    platforms: (raw.platforms ?? []).map((p) => p.name),
    summary: raw.summary ?? null,
    raw_igdb_json: raw,
    cached_at: new Date().toISOString(),
  };
}

/** igdb_tokens テーブルから有効なTwitchトークンを取得し、なければ新規取得して保存する。 */
async function getTwitchAccessToken(
  db: ReturnType<typeof serviceRoleClient>,
): Promise<string> {
  const { data: cached, error: selectError } = await db
    .from('igdb_tokens')
    .select('access_token, expires_at')
    .eq('id', 1)
    .maybeSingle();
  if (selectError) {
    throw new Error(`igdb_tokens select failed: ${selectError.message}`);
  }

  const isValid =
    cached && new Date(cached.expires_at).getTime() > Date.now() + 60_000;
  if (isValid) {
    return cached!.access_token as string;
  }

  const clientId = Deno.env.get('TWITCH_CLIENT_ID')!;
  const clientSecret = Deno.env.get('TWITCH_CLIENT_SECRET')!;

  const tokenResponse = await fetch(
    `${TWITCH_TOKEN_URL}?client_id=${clientId}&client_secret=${clientSecret}&grant_type=client_credentials`,
    { method: 'POST' },
  );
  if (!tokenResponse.ok) {
    throw new Error(`Twitchトークン取得に失敗しました: ${tokenResponse.status}`);
  }
  const tokenJson = await tokenResponse.json();
  const accessToken = tokenJson.access_token as string;
  const expiresAt = new Date(Date.now() + tokenJson.expires_in * 1000);

  const { error: tokenUpsertError } = await db.from('igdb_tokens').upsert({
    id: 1,
    access_token: accessToken,
    expires_at: expiresAt.toISOString(),
  });
  if (tokenUpsertError) {
    throw new Error(`igdb_tokens upsert failed: ${tokenUpsertError.message}`);
  }

  return accessToken;
}

async function queryIgdb(
  accessToken: string,
  apicalypseQuery: string,
): Promise<RawIgdbGame[]> {
  const response = await fetch(`${IGDB_BASE_URL}/games`, {
    method: 'POST',
    headers: {
      'Client-ID': Deno.env.get('TWITCH_CLIENT_ID')!,
      'Authorization': `Bearer ${accessToken}`,
      'Content-Type': 'text/plain',
    },
    body: apicalypseQuery,
  });
  if (!response.ok) {
    throw new Error(`IGDBへの問い合わせに失敗しました: ${response.status}`);
  }
  return await response.json();
}

Deno.serve(async (req) => {
  if (req.method !== 'POST') {
    return new Response('Method Not Allowed', { status: 405 });
  }

  try {
    const { action, query, id } = await req.json();
    const db = serviceRoleClient();
    const accessToken = await getTwitchAccessToken(db);

    if (action === 'search') {
      if (!query || typeof query !== 'string') {
        return new Response(
          JSON.stringify({ error: 'query is required' }),
          { status: 400, headers: { 'Content-Type': 'application/json' } },
        );
      }
      const escaped = query.replace(/"/g, '\\"');
      const raws = await queryIgdb(
        accessToken,
        `search "${escaped}"; fields ${GAME_FIELDS}; limit 20;`,
      );
      const rows = raws.map(toGameRow);
      if (rows.length > 0) {
        const { error: upsertError } = await db.from('games').upsert(rows);
        if (upsertError) {
          throw new Error(`games upsert failed: ${upsertError.message}`);
        }
      }
      return new Response(JSON.stringify(rows), {
        headers: { 'Content-Type': 'application/json' },
      });
    }

    if (action === 'details') {
      if (typeof id !== 'number') {
        return new Response(
          JSON.stringify({ error: 'id is required' }),
          { status: 400, headers: { 'Content-Type': 'application/json' } },
        );
      }
      const raws = await queryIgdb(
        accessToken,
        `where id = ${id}; fields ${GAME_FIELDS}; limit 1;`,
      );
      if (raws.length === 0) {
        return new Response(JSON.stringify(null), {
          headers: { 'Content-Type': 'application/json' },
        });
      }
      const row = toGameRow(raws[0]);
      const { error: upsertError } = await db.from('games').upsert(row);
      if (upsertError) {
        throw new Error(`games upsert failed: ${upsertError.message}`);
      }
      return new Response(JSON.stringify(row), {
        headers: { 'Content-Type': 'application/json' },
      });
    }

    return new Response(
      JSON.stringify({ error: 'unknown action' }),
      { status: 400, headers: { 'Content-Type': 'application/json' } },
    );
  } catch (error) {
    console.error(error);
    return new Response(
      JSON.stringify({ error: (error as Error).message }),
      { status: 500, headers: { 'Content-Type': 'application/json' } },
    );
  }
});
