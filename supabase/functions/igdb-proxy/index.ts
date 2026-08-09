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
// 'details' は 'search' より重いフィールド（企業情報・関連作品・日本語翻訳概要）まで
// 取得してキャッシュする。'search' は一覧表示に必要な軽いフィールドのみを都度
// upsertするため、既存のキャッシュ済み詳細情報（developers/publishers/similar_games/
// summary_ja）を空値で上書きしてしまわないよう、あえてこれらのキーをペイロードに
// 含めていない（Postgrestのupsertはペイロードに含まれる列だけをUPDATEする）。
//
// 必要な環境変数（`supabase secrets set` で設定する）:
//   TWITCH_CLIENT_ID, TWITCH_CLIENT_SECRET
// 以下はSupabaseが自動的に注入する:
//   SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY

import { createClient } from 'jsr:@supabase/supabase-js@2';

const IGDB_BASE_URL = 'https://api.igdb.com/v4';
const TWITCH_TOKEN_URL = 'https://id.twitch.tv/oauth2/token';
const MYMEMORY_URL = 'https://api.mymemory.translated.net/get';
const TRANSLATE_CHUNK_MAX_LEN = 450;

const SEARCH_FIELDS = 'id,name,cover.url,first_release_date,platforms.name,summary,url';
const SEARCH_PAGE_SIZE = 24;

/** カテゴリ探索（タイトル検索なし）時の並び替え。キーはFlutter側と合わせている。 */
const SORT_CLAUSES: Record<string, string> = {
  popularity: 'sort total_rating_count desc',
  name: 'sort name asc',
  release_date: 'sort first_release_date desc',
};
const DETAILS_FIELDS = `${SEARCH_FIELDS},` +
  'involved_companies.company.name,involved_companies.developer,involved_companies.publisher,' +
  'similar_games.name,similar_games.cover.url,similar_games.first_release_date';

interface InvolvedCompany {
  company?: { name?: string };
  developer?: boolean;
  publisher?: boolean;
}

interface SimilarGameRaw {
  id: number;
  name?: string;
  cover?: { url?: string };
}

interface RawIgdbGame {
  id: number;
  name?: string;
  cover?: { url?: string };
  first_release_date?: number; // unix seconds
  platforms?: { name: string }[];
  summary?: string;
  url?: string; // このゲームのIGDB上のページURL（帰属表示のリンク先として使う）
  involved_companies?: InvolvedCompany[];
  similar_games?: SimilarGameRaw[];
}

interface SimilarGameSummary {
  id: number;
  name: string;
  cover_url: string | null;
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

/** 一覧表示に必要な軽いフィールドのみの行。search結果のキャッシュに使う。 */
function toSearchRow(raw: RawIgdbGame) {
  return {
    id: raw.id,
    name: raw.name ?? '(タイトル不明)',
    cover_url: toBigCoverUrl(raw.cover?.url),
    first_release_date: toIsoDate(raw.first_release_date),
    platforms: (raw.platforms ?? []).map((p) => p.name),
    summary: raw.summary ?? null,
    igdb_url: raw.url ?? null,
    raw_igdb_json: raw,
    cached_at: new Date().toISOString(),
  };
}

/** 詳細表示用に、企業情報・関連作品まで含めた行。details取得時のみ使う。 */
function toDetailRow(raw: RawIgdbGame) {
  const involved = raw.involved_companies ?? [];
  const developers = involved
    .filter((c) => c.developer && c.company?.name)
    .map((c) => c.company!.name!);
  const publishers = involved
    .filter((c) => c.publisher && c.company?.name)
    .map((c) => c.company!.name!);
  const similarGames: SimilarGameSummary[] = (raw.similar_games ?? []).map((g) => ({
    id: g.id,
    name: g.name ?? '(タイトル不明)',
    cover_url: toBigCoverUrl(g.cover?.url),
  }));

  return {
    ...toSearchRow(raw),
    developers,
    publishers,
    similar_games: similarGames,
  };
}

/** 英語の長文を文単位でMyMemory APIの1リクエスト上限に収まるよう分割する。 */
function chunkText(text: string, maxLen: number): string[] {
  const sentences = text.split(/(?<=[.!?])\s+/);
  const chunks: string[] = [];
  let current = '';
  for (const sentence of sentences) {
    const candidate = current ? `${current} ${sentence}` : sentence;
    if (candidate.length > maxLen && current) {
      chunks.push(current.trim());
      current = sentence;
    } else {
      current = candidate;
    }
  }
  if (current) chunks.push(current.trim());
  return chunks.length > 0 ? chunks : [text.slice(0, maxLen)];
}

/**
 * MyMemory Translation API（無料・登録不要）で英語→日本語に翻訳する。
 * 失敗した場合はnullを返し、呼び出し側は英語の概要をそのまま表示する。
 */
async function translateToJapanese(text: string): Promise<string | null> {
  const chunks = chunkText(text, TRANSLATE_CHUNK_MAX_LEN);
  const translated: string[] = [];
  for (const chunk of chunks) {
    try {
      const url = `${MYMEMORY_URL}?q=${encodeURIComponent(chunk)}&langpair=en|ja`;
      const res = await fetch(url);
      if (!res.ok) break;
      const json = await res.json();
      const piece = json?.responseData?.translatedText;
      if (!piece) break;
      translated.push(piece);
    } catch {
      break;
    }
  }
  return translated.length > 0 ? translated.join('') : null;
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
  return await queryIgdbEndpoint(accessToken, 'games', apicalypseQuery);
}

async function queryIgdbEndpoint<T>(
  accessToken: string,
  endpoint: string,
  apicalypseQuery: string,
): Promise<T[]> {
  const response = await fetch(`${IGDB_BASE_URL}/${endpoint}`, {
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

/**
 * 開発元名から会社IDを解決する。
 *
 * games側で `involved_companies.company.name` のような2階層のネストしたフィールドを
 * where句で直接絞り込もうとするとIGDB側でタイムアウトする（実測で確認済み）。
 * そのため /companies エンドポイントで先に名前からIDを引き、
 * gamesの絞り込みは1階層の `involved_companies.company = (id...)` に留める。
 */
async function resolveCompanyIds(
  accessToken: string,
  name: string,
): Promise<number[]> {
  const escaped = name.replace(/"/g, '\\"');

  // 完全一致を優先する。あいまい一致だけだと「Nintendo」で検索したときに
  // 本家(id=70)より先に子会社（Nintendo R&D4 等）がヒットしてしまい、
  // 期待した開発元のタイトルが絞り込みから漏れることがあるため。
  const exact = await queryIgdbEndpoint<{ id: number }>(
    accessToken,
    'companies',
    `fields id; where name = "${escaped}"; limit 1;`,
  );
  if (exact.length > 0) return exact.map((c) => c.id);

  const fuzzy = await queryIgdbEndpoint<{ id: number }>(
    accessToken,
    'companies',
    `fields id; where name ~ *"${escaped}"*; limit 10;`,
  );
  return fuzzy.map((c) => c.id);
}

Deno.serve(async (req) => {
  if (req.method !== 'POST') {
    return new Response('Method Not Allowed', { status: 405 });
  }

  try {
    const { action, query, id, platform, developer, genre, offset, sort } = await req.json();
    const db = serviceRoleClient();
    const accessToken = await getTwitchAccessToken(db);

    if (action === 'search') {
      const hasQuery = typeof query === 'string' && query.trim().length > 0;

      const filters: string[] = [];
      if (typeof platform === 'string' && platform.trim()) {
        const p = platform.trim().replace(/"/g, '\\"');
        filters.push(`platforms.name ~ *"${p}"*`);
      }
      if (typeof genre === 'string' && genre.trim()) {
        const g = genre.trim().replace(/"/g, '\\"');
        filters.push(`genres.name = "${g}"`);
      }
      if (typeof developer === 'string' && developer.trim()) {
        const companyIds = await resolveCompanyIds(accessToken, developer.trim());
        if (companyIds.length === 0) {
          // 該当する開発元が見つからない場合は、無条件に0件を返す。
          return new Response(JSON.stringify([]), {
            headers: { 'Content-Type': 'application/json' },
          });
        }
        filters.push(
          `involved_companies.company = (${companyIds.join(',')}) & involved_companies.developer = true`,
        );
      }

      if (!hasQuery && filters.length === 0) {
        return new Response(
          JSON.stringify({ error: 'query, or at least one filter, is required' }),
          { status: 400, headers: { 'Content-Type': 'application/json' } },
        );
      }

      const clauses = [`fields ${SEARCH_FIELDS}`];
      if (hasQuery) {
        const escaped = (query as string).replace(/"/g, '\\"');
        clauses.unshift(`search "${escaped}"`);
      }
      if (filters.length > 0) clauses.push(`where ${filters.join(' & ')}`);
      // IGDBは search と sort を同時に使えない（sortは関連度順を上書きしてしまうため
      // 406エラーになる）。タイトル検索が無い場合のみ、指定された並び順を適用する。
      // 未指定時は人気順（評価数が多い順）をデフォルトにする。
      if (!hasQuery) {
        const sortClause = SORT_CLAUSES[sort as string] ?? SORT_CLAUSES.popularity;
        clauses.push(sortClause);
      }
      const pageOffset = typeof offset === 'number' && offset > 0 ? offset : 0;
      clauses.push(`limit ${SEARCH_PAGE_SIZE}`);
      if (pageOffset > 0) clauses.push(`offset ${pageOffset}`);

      const raws = await queryIgdb(accessToken, `${clauses.join('; ')};`);
      const rows = raws.map(toSearchRow);
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
        `where id = ${id}; fields ${DETAILS_FIELDS}; limit 1;`,
      );
      if (raws.length === 0) {
        return new Response(JSON.stringify(null), {
          headers: { 'Content-Type': 'application/json' },
        });
      }
      const row = toDetailRow(raws[0]);

      // 既に翻訳済みならAPIを呼ばずに使い回す（無料枠の節約とレスポンス短縮のため）。
      const { data: existing } = await db
        .from('games')
        .select('summary_ja')
        .eq('id', row.id)
        .maybeSingle();
      const summaryJa = existing?.summary_ja ??
        (row.summary ? await translateToJapanese(row.summary) : null);

      const fullRow = { ...row, summary_ja: summaryJa };
      const { error: upsertError } = await db.from('games').upsert(fullRow);
      if (upsertError) {
        throw new Error(`games upsert failed: ${upsertError.message}`);
      }
      return new Response(JSON.stringify(fullRow), {
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
