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
//   TWITCH_CLIENT_ID, TWITCH_CLIENT_SECRET, GOOGLE_TRANSLATE_API_KEY
// 以下はSupabaseが自動的に注入する:
//   SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY

import { createClient } from 'jsr:@supabase/supabase-js@2';

const IGDB_BASE_URL = 'https://api.igdb.com/v4';
const TWITCH_TOKEN_URL = 'https://id.twitch.tv/oauth2/token';
const GOOGLE_TRANSLATE_URL = 'https://translation.googleapis.com/language/translate/v2';

const SEARCH_FIELDS = 'id,name,cover.url,first_release_date,platforms.name,summary,url,themes.name';
/** IGDBのthemes名。この名前が付いている作品は成人向けとして扱う。 */
const ADULT_THEME_NAME = 'Erotic';
/**
 * ↑のIGDB上でのtheme ID（IGDBの/themesエンドポイントで確認済み、固定値）。
 * to-many関係の除外は `themes.name != "..."` のようなドット区切りの比較では機能しない
 * （「配列内にErotic以外の要素が1つでもあれば真」という判定になり、事実上素通りしてしまう）。
 * IGDBの仕様通り `themes != (id...)` というID直指定の除外構文を使う必要がある。
 */
const ADULT_THEME_ID = 42;
const SEARCH_PAGE_SIZE = 24;
/**
 * IGDBのcategory値のうち、MOD・ROMハック等の非公式派生作品を示すもの
 * （5=mod, 12=fork）。一覧・週間新作の両方でこれらを除外する。
 */
const UNOFFICIAL_CATEGORY_IDS = [5, 12];

/**
 * 「MonsterHunter」のようにスペースなしで詰めて入力された検索語に、
 * 単語境界と思われる位置（小文字/数字→大文字の切り替わり）でスペースを挿入する。
 * 挿入の必要がない（既にスペースを含む、境界が見つからない）場合はnullを返す。
 */
function insertWordBoundarySpaces(text: string): string | null {
  if (/\s/.test(text)) return null;
  const spaced = text.replace(/([a-z0-9])([A-Z])/g, '$1 $2');
  return spaced !== text ? spaced : null;
}

/** カテゴリ探索（タイトル検索なし）時の並び替え。キーはFlutter側と合わせている。 */
const SORT_CLAUSES: Record<string, string> = {
  popularity: 'sort total_rating_count desc',
  name: 'sort name asc',
  release_date: 'sort first_release_date desc',
};
const DETAILS_FIELDS = `${SEARCH_FIELDS},` +
  'involved_companies.company.name,involved_companies.company.country,' +
  'involved_companies.developer,involved_companies.publisher,' +
  'similar_games.name,similar_games.cover.url,similar_games.first_release_date,' +
  'websites.url,websites.type';

/** ISO 3166-1数値コードの日本（IGDBのcompanies.countryはこの体系。実データで確認済み）。 */
const JAPAN_COUNTRY_CODE = 392;

/** IGDBのwebsites.typeの値（/website_typesエンドポイントで確認済み）。公式サイトのみ使う。 */
const OFFICIAL_WEBSITE_TYPE = 1;

/**
 * 公式サイトのURLに日本語ページらしさが感じられるかどうかの簡易判定。
 * IGDBのwebsitesには言語情報が無いため、ドメイン/パスに日本を示す文字列があるかで代用する。
 */
const JAPANESE_URL_HINT_REGEX = /(^|\.)jp(\.|\/|$)|\/ja([-/]|$)|japan/i;

interface InvolvedCompany {
  company?: { name?: string; country?: number };
  developer?: boolean;
  publisher?: boolean;
}

interface SimilarGameRaw {
  id: number;
  name?: string;
  cover?: { url?: string };
}

interface WebsiteRaw {
  url: string;
  type?: number;
}

interface RawIgdbGame {
  id: number;
  name?: string;
  cover?: { url?: string };
  first_release_date?: number; // unix seconds
  platforms?: { name: string }[];
  summary?: string;
  url?: string; // このゲームのIGDB上のページURL（帰属表示のリンク先として使う）
  themes?: { name: string }[];
  involved_companies?: InvolvedCompany[];
  similar_games?: SimilarGameRaw[];
  websites?: WebsiteRaw[];
}

/** 公式サイトのURLを選ぶ。日本語ページらしいものがあればそれを優先する。 */
function pickOfficialWebsiteUrl(websites: WebsiteRaw[] | undefined): string | null {
  const officials = (websites ?? []).filter((w) => w.type === OFFICIAL_WEBSITE_TYPE);
  if (officials.length === 0) return null;
  const japanese = officials.find((w) => JAPANESE_URL_HINT_REGEX.test(w.url));
  return (japanese ?? officials[0]).url;
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
    is_adult: (raw.themes ?? []).some((t) => t.name === ADULT_THEME_NAME),
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
  const isJapaneseDeveloper = involved.some(
    (c) => c.developer && c.company?.country === JAPAN_COUNTRY_CODE,
  );
  const similarGames: SimilarGameSummary[] = (raw.similar_games ?? []).map((g) => ({
    id: g.id,
    name: g.name ?? '(タイトル不明)',
    cover_url: toBigCoverUrl(g.cover?.url),
  }));

  return {
    ...toSearchRow(raw),
    developers,
    publishers,
    is_japanese_developer: isJapaneseDeveloper,
    similar_games: similarGames,
    official_url: pickOfficialWebsiteUrl(raw.websites),
  };
}

/**
 * Google Cloud Translation API（Basic/v2）で1件テキストを翻訳する共通処理。
 * Google側の1リクエストあたりの上限（3万文字程度）はゲームの概要文なら十分収まるため、
 * MyMemory時代のような文単位でのチャンク分割は不要。
 */
async function translateText(
  text: string,
  source: 'en' | 'ja',
  target: 'en' | 'ja',
): Promise<string | null> {
  try {
    const res = await fetch(
      `${GOOGLE_TRANSLATE_URL}?key=${Deno.env.get('GOOGLE_TRANSLATE_API_KEY')}`,
      {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ q: text, source, target, format: 'text' }),
      },
    );
    if (!res.ok) return null;
    const json = await res.json();
    const translated = json?.data?.translations?.[0]?.translatedText;
    return typeof translated === 'string' && translated ? translated : null;
  } catch {
    return null;
  }
}

/**
 * Google Cloud Translation APIで英語→日本語に翻訳する。
 * 失敗した場合はnullを返し、呼び出し側は英語の概要をそのまま表示する。
 */
async function translateToJapanese(text: string): Promise<string | null> {
  return await translateText(text, 'en', 'ja');
}

const JAPANESE_CHARS_REGEX = /[぀-ヿ一-鿿]/;

/**
 * 検索語に日本語が含まれる場合、IGDB検索（英語タイトルが中心）でヒットするよう
 * 英語に翻訳してから検索する。日本語を含まない場合はそのまま返す。
 */
async function translateQueryToEnglish(text: string): Promise<string> {
  if (!JAPANESE_CHARS_REGEX.test(text)) return text;
  const translated = await translateText(text, 'ja', 'en');
  return translated?.trim() ? translated : text;
}

/** 今週（月曜0:00〜翌週月曜0:00、UTC基準）のunixタイムスタンプ範囲を返す。 */
function currentWeekRangeUnix(): { start: number; end: number } {
  const now = new Date();
  const day = now.getUTCDay(); // 0=日曜, 1=月曜, ...
  const diffToMonday = day === 0 ? 6 : day - 1;
  const monday = new Date(Date.UTC(
    now.getUTCFullYear(),
    now.getUTCMonth(),
    now.getUTCDate() - diffToMonday,
  ));
  const nextMonday = new Date(monday);
  nextMonday.setUTCDate(monday.getUTCDate() + 7);
  return {
    start: Math.floor(monday.getTime() / 1000),
    end: Math.floor(nextMonday.getTime() / 1000),
  };
}

/**
 * 既にキャッシュ済みの日本語タイトル（name_ja）・開発元が日本の会社かどうか
 * （is_japanese_developer）を行にマージして返す。search/weekly_releasesは
 * 軽量化のため新規翻訳・企業情報取得は行わず、既にdetails取得済みのものだけを再利用する。
 */
async function mergeCachedNameJa<T extends { id: number; name: string }>(
  db: ReturnType<typeof serviceRoleClient>,
  rows: T[],
): Promise<(T & { name_ja?: string | null; is_japanese_developer?: boolean })[]> {
  if (rows.length === 0) return rows;
  const { data } = await db
    .from('games')
    .select('id, name_ja, is_japanese_developer')
    .in('id', rows.map((r) => r.id));
  const cachedById = new Map((data ?? []).map((r) => [r.id, r]));
  return rows.map((row) => {
    const cached = cachedById.get(row.id);
    return {
      ...row,
      name_ja: normalizeTranslatedName(row.name, cached?.name_ja ?? null),
      is_japanese_developer: cached?.is_japanese_developer ?? false,
    };
  });
}

/**
 * タイトル翻訳結果の後処理。MyMemoryは "Control（コントロール）" のように、
 * 原題をそのままカタカナ読みで括弧書きしただけの実質的に無意味な「翻訳」を返すことがある。
 * こうした場合は英語のままの方が自然なため、翻訳結果が原題から始まっている（＝原題に
 * 何かを付け足しただけ）ときは原題をそのまま採用する。
 */
function normalizeTranslatedName(original: string, translated: string | null): string | null {
  if (!translated) return translated;
  const normalizedOriginal = original.trim().toLowerCase();
  const normalizedTranslated = translated.trim().toLowerCase();
  if (normalizedTranslated.startsWith(normalizedOriginal)) return original;
  return translated;
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
    const {
      action, query, id, platform, platforms, developer, genre, genres,
      offset, sort, includeUpcoming, includeAdult,
    } = await req.json();
    const db = serviceRoleClient();
    const accessToken = await getTwitchAccessToken(db);

    if (action === 'search') {
      const hasQuery = typeof query === 'string' && query.trim().length > 0;

      // 複数選択時はOR条件（選択されたうちどれか1つでも当てはまれば表示）。
      const platformList: string[] = Array.isArray(platforms)
        ? platforms.filter((p): p is string => typeof p === 'string' && p.trim().length > 0)
        : typeof platform === 'string' && platform.trim()
        ? [platform]
        : [];
      const genreList: string[] = Array.isArray(genres)
        ? genres.filter((g): g is string => typeof g === 'string' && g.trim().length > 0)
        : typeof genre === 'string' && genre.trim()
        ? [genre]
        : [];

      const filters: string[] = [];
      if (platformList.length > 0) {
        const clause = platformList
          .map((p) => `platforms.name ~ *"${p.trim().replace(/"/g, '\\"')}"*`)
          .join(' | ');
        filters.push(platformList.length > 1 ? `(${clause})` : clause);
      }
      if (genreList.length > 0) {
        const clause = genreList
          .map((g) => `genres.name = "${g.trim().replace(/"/g, '\\"')}"`)
          .join(' | ');
        filters.push(genreList.length > 1 ? `(${clause})` : clause);
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

      const sortKey = typeof sort === 'string' && SORT_CLAUSES[sort] ? sort : 'popularity';

      // 発売時期順は、デフォルトでは未発売（未来の発売日）の作品を除外する。
      // includeUpcomingがtrueの場合のみ、発売予定作品も含めて一覧表示する。
      if (!hasQuery && sortKey === 'release_date' && includeUpcoming !== true) {
        const nowUnix = Math.floor(Date.now() / 1000);
        filters.push(`first_release_date <= ${nowUnix}`);
      }

      // デフォルトでは成人向け（Eroticテーマ）の作品を除外する。
      if (includeAdult !== true) {
        filters.push(`themes != (${ADULT_THEME_ID})`);
      }

      // 「～Collector's Edition」「～Bundle」等、既存タイトルの別バージョンとして
      // IGDBがversion_parentで紐付けている作品は一覧から除外し、本編のみを表示する。
      filters.push('version_parent = null');

      // DLC・アップデート・追加エピソード等、既存タイトルにparent_gameで
      // 紐付けられている作品も除外する（例: 「Monster Hunter Rise: Title Update 3」は
      // 「Monster Hunter Rise」に、「Honkai: Star Rail - ○○」も本編にまとめる）。
      // 起動する本体（ROM）が変わらない追加コンテンツは本編の記録に一本化する方針。
      filters.push('parent_game = null');

      // MOD・ROMハック・同人プラットフォーマー等の非公式作品を除外する。
      // IGDBのcategoryは 5=mod, 12=fork（既存タイトルを改変・派生させた非公式作品に
      // 使われる分類）で、ROMハックや同人フリーゲームの多くもこれに分類されている。
      // categoryが未設定（null）の作品も多いため、「category != (...)」単体だと
      // IGDB側でnullとの比較がfalse扱いになりcategory未設定の正規タイトルまで
      // 一覧から消えてしまう。nullは許可した上でmod/forkだけを除外する。
      filters.push(
        `(category = null | category != (${UNOFFICIAL_CATEGORY_IDS.join(',')}))`,
      );

      const clauses = [`fields ${SEARCH_FIELDS}`];
      let translatedQuery = '';
      if (hasQuery) {
        translatedQuery = await translateQueryToEnglish((query as string).trim());
        const escaped = translatedQuery.replace(/"/g, '\\"');
        clauses.unshift(`search "${escaped}"`);
      }
      if (filters.length > 0) clauses.push(`where ${filters.join(' & ')}`);
      // IGDBは search と sort を同時に使えない（sortは関連度順を上書きしてしまうため
      // 406エラーになる）。タイトル検索が無い場合のみ、指定された並び順を適用する。
      if (!hasQuery) {
        clauses.push(SORT_CLAUSES[sortKey]);
      }
      const pageOffset = typeof offset === 'number' && offset > 0 ? offset : 0;
      clauses.push(`limit ${SEARCH_PAGE_SIZE}`);
      if (pageOffset > 0) clauses.push(`offset ${pageOffset}`);

      let raws = await queryIgdb(accessToken, `${clauses.join('; ')};`);

      // 「MonsterHunter」のようにスペースなしで詰めて検索して0件だった場合、
      // 単語境界にスペースを挿入した表記（「Monster Hunter」）で再検索する。
      if (raws.length === 0 && hasQuery) {
        const spaced = insertWordBoundarySpaces(translatedQuery);
        if (spaced) {
          const retryClauses = [...clauses];
          retryClauses[0] = `search "${spaced.replace(/"/g, '\\"')}"`;
          raws = await queryIgdb(accessToken, `${retryClauses.join('; ')};`);
        }
      }

      const rows = raws.map(toSearchRow);
      if (rows.length > 0) {
        const { error: upsertError } = await db.from('games').upsert(rows);
        if (upsertError) {
          throw new Error(`games upsert failed: ${upsertError.message}`);
        }
      }
      const rowsWithNameJa = await mergeCachedNameJa(db, rows);
      return new Response(JSON.stringify(rowsWithNameJa), {
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

      // 既に翻訳済みならAPIを呼ばずに使い回す（翻訳コストの節約とレスポンス短縮のため）。
      const { data: existing } = await db
        .from('games')
        .select('summary_ja, name_ja')
        .eq('id', row.id)
        .maybeSingle();
      const summaryJa = existing?.summary_ja ??
        (row.summary ? await translateToJapanese(row.summary) : null);
      const nameJa = normalizeTranslatedName(
        row.name,
        existing?.name_ja ?? await translateToJapanese(row.name),
      );

      // 関連作品のタイトルも日本語優先で表示する。既にキャッシュ済みならそれを使い、
      // 無ければ翻訳して軽量な行（id/name/name_ja）だけgamesにキャッシュしておく
      // （次回以降その作品が関連作品や検索結果に出た際に再利用できるようにするため）。
      const similarWithNameJa = await mergeCachedNameJa(db, row.similar_games);
      const untranslatedSimilar = similarWithNameJa.filter((g) => !g.name_ja);
      for (const similar of untranslatedSimilar) {
        similar.name_ja = normalizeTranslatedName(
          similar.name,
          await translateToJapanese(similar.name),
        );
      }
      if (untranslatedSimilar.length > 0) {
        const { error: similarUpsertError } = await db.from('games').upsert(
          untranslatedSimilar.map((g) => ({
            id: g.id,
            name: g.name,
            cover_url: g.cover_url,
            name_ja: g.name_ja,
          })),
        );
        if (similarUpsertError) {
          throw new Error(`games upsert failed (similar_games): ${similarUpsertError.message}`);
        }
      }

      const fullRow = {
        ...row,
        summary_ja: summaryJa,
        name_ja: nameJa,
        similar_games: similarWithNameJa,
      };
      const { error: upsertError } = await db.from('games').upsert(fullRow);
      if (upsertError) {
        throw new Error(`games upsert failed: ${upsertError.message}`);
      }
      return new Response(JSON.stringify(fullRow), {
        headers: { 'Content-Type': 'application/json' },
      });
    }

    if (action === 'weekly_releases') {
      const { start, end } = currentWeekRangeUnix();
      const weeklyFilters = [
        `first_release_date >= ${start}`,
        `first_release_date < ${end}`,
      ];
      if (typeof platform === 'string' && platform.trim()) {
        const p = platform.trim().replace(/"/g, '\\"');
        weeklyFilters.push(`platforms.name ~ *"${p}"*`);
      }
      if (includeAdult !== true) {
        weeklyFilters.push(`themes != (${ADULT_THEME_ID})`);
      }
      weeklyFilters.push('version_parent = null');
      // DLC・アップデート等、既存タイトルの追加コンテンツは新作一覧に出さない。
      weeklyFilters.push('parent_game = null');
      // categoryが未設定（null）の正規タイトルまで消えないよう、search側と同じく
      // nullは許可した上でmod/forkだけを除外する。
      weeklyFilters.push(
        `(category = null | category != (${UNOFFICIAL_CATEGORY_IDS.join(',')}))`,
      );
      const raws = await queryIgdb(
        accessToken,
        `fields ${SEARCH_FIELDS}; where ${weeklyFilters.join(' & ')}; sort total_rating_count desc; limit 30;`,
      );
      const rows = raws.map(toSearchRow);
      if (rows.length > 0) {
        const { error: upsertError } = await db.from('games').upsert(rows);
        if (upsertError) {
          throw new Error(`games upsert failed: ${upsertError.message}`);
        }
      }
      const rowsWithNameJa = await mergeCachedNameJa(db, rows);
      return new Response(JSON.stringify(rowsWithNameJa), {
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
