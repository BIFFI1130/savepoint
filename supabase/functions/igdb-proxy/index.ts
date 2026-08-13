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

const SEARCH_FIELDS = 'id,name,cover.url,first_release_date,platforms.name,summary,url,themes.name,genres.name';
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
 * IGDBのgame_type値のうち、MOD・ROMハック等の非公式派生作品を示すもの
 * （5=mod, 12=fork）。category（旧フィールド）は未設定の作品が多く実用に
 * ならなかったため、より網羅的に値が入っているgame_typeを使う。
 * 一覧・週間新作の両方でこれらを除外する。
 */
const UNOFFICIAL_GAME_TYPE_IDS = [5, 12];

/**
 * IGDBのkeywords（タグ）IDのうち、ROMハック・ファンゲーム等の非公式作品に
 * 付与されているもの。game_type未設定でもこちらのタグが付いていることが多い
 * （例: 「Kaizo Mario World」はgame_type=mod、「NSMB: Mario vs. Luigi Online」は
 * game_type未設定だがkeywords=unofficial,fangame）。
 *   2004 = unofficial, 16696 = rom hack, 24124 = fangame
 */
const UNOFFICIAL_KEYWORD_IDS = [2004, 16696, 24124];

/**
 * IGDBのgenres上での「Indie」ジャンルのID（IGDBの/genresエンドポイントで確認済み、固定値）。
 * to-many関係の除外はthemesと同様、`genres.name != "..."`のようなドット区切りの比較では
 * 機能しないため、IDを直接指定する除外構文 `genres != (id...)` を使う。
 */
const INDIE_GENRE_ID = 32;

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

/**
 * ゲームタイトルの日本語表示は、以前はGoogle翻訳による機械翻訳を使っていたが、
 * IGDBが公式に持つ「Localized Title」（game_localizationsエンドポイント、
 * regionが"Japan"の行）に切り替えた。機械翻訳と違い実際の公式日本語タイトル
 * （ローカライズ版が存在する場合）を返せるため、こちらを優先する。
 * regions.nameの値（/regionsエンドポイントで確認済み）。
 */
const JAPAN_REGION_NAME = 'Japan';

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
  genres?: { name: string }[];
  involved_companies?: InvolvedCompany[];
  similar_games?: SimilarGameRaw[];
  websites?: WebsiteRaw[];
  rating?: number; // ユーザー評価の平均（0〜100）。top100の加重評価計算にのみ使う。
  rating_count?: number; // ユーザー評価の件数。同上。
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
  name_ja: string | null;
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

/**
 * 一覧表示に必要な軽いフィールドのみの行。search結果のキャッシュに使う。
 * nameJaはIGDBのLocalized Title（Japan）から取得した値。無ければnullを渡し、
 * クライアント側でoriginalタイトル（name）にフォールバックする。
 */
function toSearchRow(raw: RawIgdbGame, nameJa: string | null) {
  return {
    id: raw.id,
    name: raw.name ?? '(タイトル不明)',
    name_ja: nameJa,
    cover_url: toBigCoverUrl(raw.cover?.url),
    first_release_date: toIsoDate(raw.first_release_date),
    platforms: (raw.platforms ?? []).map((p) => p.name),
    summary: raw.summary ?? null,
    igdb_url: raw.url ?? null,
    genres: (raw.genres ?? []).map((g) => g.name),
    is_adult: (raw.themes ?? []).some((t) => t.name === ADULT_THEME_NAME),
    raw_igdb_json: raw,
    cached_at: new Date().toISOString(),
  };
}

/**
 * 詳細表示用に、企業情報・関連作品まで含めた行。details取得時のみ使う。
 * jaNamesは対象ゲーム自身と関連作品（similar_games）分のIDをキーにした
 * Localized Title（Japan）のマップ。
 */
function toDetailRow(raw: RawIgdbGame, jaNames: Map<number, string>) {
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
    name_ja: jaNames.get(g.id) ?? null,
    cover_url: toBigCoverUrl(g.cover?.url),
  }));

  return {
    ...toSearchRow(raw, jaNames.get(raw.id) ?? null),
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

/** 今月（1日0:00〜翌月1日0:00、UTC基準）のunixタイムスタンプ範囲を返す。 */
function currentMonthRangeUnix(): { start: number; end: number } {
  const now = new Date();
  return monthRangeUnix(now.getUTCFullYear(), now.getUTCMonth() + 1);
}

/** 指定した年月（1〜12）の1日0:00〜翌月1日0:00（UTC基準）のunixタイムスタンプ範囲を返す。 */
function monthRangeUnix(year: number, month: number): { start: number; end: number } {
  const start = new Date(Date.UTC(year, month - 1, 1));
  const end = new Date(Date.UTC(year, month, 1));
  return {
    start: Math.floor(start.getTime() / 1000),
    end: Math.floor(end.getTime() / 1000),
  };
}

/**
 * 既にキャッシュ済みの「開発元が日本の会社かどうか」（is_japanese_developer）を
 * 行にマージして返す。search/weekly_releasesは軽量化のため企業情報の再取得は行わず、
 * 既にdetails取得済みのものだけを再利用する。
 */
async function mergeCachedIsJapaneseDeveloper<T extends { id: number }>(
  db: ReturnType<typeof serviceRoleClient>,
  rows: T[],
): Promise<(T & { is_japanese_developer?: boolean })[]> {
  if (rows.length === 0) return rows;
  const { data } = await db
    .from('games')
    .select('id, is_japanese_developer')
    .in('id', rows.map((r) => r.id));
  const cachedById = new Map((data ?? []).map((r) => [r.id, r]));
  return rows.map((row) => ({
    ...row,
    is_japanese_developer: cachedById.get(row.id)?.is_japanese_developer ?? false,
  }));
}

/**
 * 対象ゲームIDのうち、IGDBのLocalized Title（regionが"Japan"）が設定されている
 * ものだけをid→タイトルのマップにして返す。1ゲームに複数行あった場合は最初の
 * 非空文字列を採用する。該当が無いゲームはマップに含まれない
 * （＝呼び出し側はoriginalタイトルにフォールバックする）。
 */
async function fetchJapaneseLocalizedNames(
  accessToken: string,
  gameIds: number[],
): Promise<Map<number, string>> {
  const uniqueIds = [...new Set(gameIds)];
  const map = new Map<number, string>();
  if (uniqueIds.length === 0) return map;

  const rows = await queryIgdbEndpoint<{ game: number; name?: string }>(
    accessToken,
    'game_localizations',
    `fields game,name; where game = (${uniqueIds.join(',')}) & region.name = "${JAPAN_REGION_NAME}"; limit 500;`,
  );
  for (const row of rows) {
    const name = row.name?.trim();
    if (name && !map.has(row.game)) {
      map.set(row.game, name);
    }
  }
  return map;
}

/**
 * 日本語クエリを英語に翻訳してのIGDB検索が0件だった場合のフォールバック。
 * 「ストッカーの中の死体っていくら？」（原題"How Much for the Body in the
 * Freezer"）のように、機械翻訳では原題から意味的にずれてしまい検索がヒットしない
 * ケースがあるため、IGDBのLocalized Title（Japan）自体をあいまい一致で検索し、
 * 該当ゲームIDを返す。
 */
async function fetchGameIdsByJapaneseLocalizedTitle(
  accessToken: string,
  query: string,
): Promise<number[]> {
  const escaped = query.replace(/"/g, '\\"');
  const rows = await queryIgdbEndpoint<{ game: number }>(
    accessToken,
    'game_localizations',
    `fields game; where name ~ *"${escaped}"* & region.name = "${JAPAN_REGION_NAME}"; limit 50;`,
  );
  return [...new Set(rows.map((r) => r.game))];
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
 * プラットフォーム名の配列からIGDBのwhere句断片を作る（OR条件）。複数選択時は
 * 選択されたうちどれか1つでも当てはまれば一覧に含める。空配列ならnullを返す。
 */
function buildPlatformFilter(platformList: string[]): string | null {
  if (platformList.length === 0) return null;
  const clause = platformList
    .map((p) => `platforms.name ~ *"${p.trim().replace(/"/g, '\\"')}"*`)
    .join(' | ');
  return platformList.length > 1 ? `(${clause})` : clause;
}

/**
 * ジャンル名の配列からIGDBのwhere句断片を作る（OR条件）。複数選択時は
 * 選択されたうちどれか1つでも当てはまれば一覧に含める。空配列ならnullを返す。
 */
function buildGenreFilter(genreList: string[]): string | null {
  if (genreList.length === 0) return null;
  const clause = genreList
    .map((g) => `genres.name = "${g.trim().replace(/"/g, '\\"')}"`)
    .join(' | ');
  return genreList.length > 1 ? `(${clause})` : clause;
}

/**
 * プラットフォーム・ジャンルのリクエストパラメータを文字列配列に正規化する。
 * 複数選択用の配列（[arrValue]）を優先し、無ければ単数値（[singularValue]、
 * 後方互換のため）を1件だけの配列として扱う。
 */
function parseStringListParam(arrValue: unknown, singularValue: unknown): string[] {
  if (Array.isArray(arrValue)) {
    return arrValue.filter((v): v is string => typeof v === 'string' && v.trim().length > 0);
  }
  if (typeof singularValue === 'string' && singularValue.trim()) return [singularValue];
  return [];
}

/**
 * 一覧系アクション（search/weekly_releases/monthly_releases/top100）で共通して
 * 適用する除外フィルタ（成人向け・インディー・別バージョン・DLC・非公式作品）。
 * [excludeIndie] はジャンルフィルタで明示的に「インディー」が選ばれている場合など、
 * 呼び出し側でインディー除外を無効化したい場合にfalseを渡す。
 */
function commonExclusionFilters(
  includeAdult: boolean,
  includeIndie: boolean,
  excludeIndie = true,
): string[] {
  const filters: string[] = [];
  if (includeAdult !== true) {
    filters.push(`themes != (${ADULT_THEME_ID})`);
  }
  if (includeIndie !== true && excludeIndie) {
    filters.push(`genres != (${INDIE_GENRE_ID})`);
  }
  filters.push('version_parent = null');
  filters.push('parent_game = null');
  filters.push(
    `(game_type = null | game_type != (${UNOFFICIAL_GAME_TYPE_IDS.join(',')}))`,
  );
  filters.push(`keywords != (${UNOFFICIAL_KEYWORD_IDS.join(',')})`);
  return filters;
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
      offset, sort, includeUpcoming, includeAdult, includeIndie, year, month,
    } = await req.json();
    const db = serviceRoleClient();
    const accessToken = await getTwitchAccessToken(db);

    if (action === 'search') {
      const hasQuery = typeof query === 'string' && query.trim().length > 0;

      // 複数選択時はOR条件（選択されたうちどれか1つでも当てはまれば表示）。
      const platformList = parseStringListParam(platforms, platform);
      const genreList = parseStringListParam(genres, genre);

      const filters: string[] = [];
      const searchPlatformFilter = buildPlatformFilter(platformList);
      if (searchPlatformFilter) filters.push(searchPlatformFilter);
      const searchGenreFilter = buildGenreFilter(genreList);
      if (searchGenreFilter) filters.push(searchGenreFilter);
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

      // 「～Collector's Edition」「～Bundle」等、既存タイトルの別バージョンとして
      // IGDBがversion_parentで紐付けている作品は常に一覧から除外し、本編のみを表示する。
      filters.push('version_parent = null');

      // DLC・アップデート・追加エピソード等、既存タイトルにparent_gameで
      // 紐付けられている作品も常に除外する（例: 「Monster Hunter Rise: Title Update 3」は
      // 「Monster Hunter Rise」に、「Honkai: Star Rail - ○○」も本編にまとめる）。
      // 起動する本体（ROM）が変わらない追加コンテンツは本編の記録に一本化する方針。
      // タイトル検索時にこれを外すと、DLC/アップデートが本編と別の検索結果として
      // 再び表示されてしまう不具合が過去に発生したため、hasQueryの有無に関わらず
      // 常時適用する。
      filters.push('parent_game = null');

      // タイトル検索（hasQuery）時は、以下の独自キュレーションフィルタを一切適用せず、
      // IGDBの`search`結果をそのまま返す。カテゴリ探索（ジャンル・ハード等での一覧）
      // では引き続き適用する。
      //
      // これらのフィルタ（インディー除外・非公式作品除外・成人向け除外）は
      // 「一覧をきれいに見せる」ためのキュレーションであり、タイトルを直接検索している
      // ときに適用すると、本来ヒットすべき作品（インディー作品・IGDB側のgame_type
      // タグ付けが実態と異なる作品など）が検索結果から消えてしまい、「検索しても
      // ヒットしない＝検索精度が悪い」という体感につながっていた。
      // ただし version_parent/parent_game（別バージョン・DLC/アップデートの除外）は
      // 「起動する本体が変わらない付随作品を本編に一本化する」という別の目的のフィルタ
      // であり、検索精度とは無関係のため、上記の通り常に適用する。
      if (!hasQuery) {
        // デフォルトでは成人向け（Eroticテーマ）の作品を除外する。
        if (includeAdult !== true) {
          filters.push(`themes != (${ADULT_THEME_ID})`);
        }

        // デフォルトではインディー作品を除外する。ただし、ジャンルフィルタで
        // 明示的に「インディー」が選択されている場合は除外しない。
        if (includeIndie !== true && !genreList.includes('Indie')) {
          filters.push(`genres != (${INDIE_GENRE_ID})`);
        }

        // MOD・ROMハック・ファンゲーム等の非公式作品を除外する。
        // game_typeが未設定の作品も一部あるため、「game_type != (...)」単体だと
        // IGDB側でnullとの比較がfalse扱いになりgame_type未設定の正規タイトルまで
        // 一覧から消えてしまう。nullは許可した上でmod/forkだけを除外する。
        filters.push(
          `(game_type = null | game_type != (${UNOFFICIAL_GAME_TYPE_IDS.join(',')}))`,
        );
        // game_typeが未設定のままROMハック・ファンゲームとして扱われている作品も
        // あるため、keywordsタグでも二重に除外する（to-many型フィールドへの
        // 「!= (idリスト)」は要素が1件もその値と一致しなければtrueになる仕様）。
        filters.push(`keywords != (${UNOFFICIAL_KEYWORD_IDS.join(',')})`);
      }

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

      // 日本語クエリの場合、機械翻訳した英語での検索は「0件」だけが問題とは限らない。
      // 翻訳がニュアンスから外れている場合、探している作品とは無関係な作品が
      // それなりの件数ヒットしてしまうことがあり（例:「素晴らしき日々」の翻訳結果に
      // 別の無関係な作品が一致してしまう）、その場合raws.length !== 0となるため
      // 従来は0件判定のこの分岐が発動せず、本来ヒットすべき作品が検索結果に
      // 出てこなかった。そのため0件かどうかに関わらず常に、IGDBのLocalized Title
      // （Japan）自体をあいまい一致で検索し、原題への直接一致を優先して結果の
      // 先頭に差し込む（IDが重複するものは除去する）。
      //
      // pageOffset > 0（「もっと見る」による追加読み込み）のときはこの分岐を実行しない。
      // ここで見つかる作品はoffsetに関わらず毎回同じ集合になるため、もし追加読み込み時にも
      // 実行すると、同じ作品が先頭に何度も再挿入されてしまい、スクロールするたびに同じ
      // タイトルが繰り返し出てくる（無限ループしているように見える）不具合になる。
      if (pageOffset === 0 && hasQuery && JAPANESE_CHARS_REGEX.test((query as string).trim())) {
        const gameIds = await fetchGameIdsByJapaneseLocalizedTitle(
          accessToken,
          (query as string).trim(),
        );
        if (gameIds.length > 0) {
          const idFilters = [...filters, `id = (${gameIds.join(',')})`];
          const localizedRaws = await queryIgdb(
            accessToken,
            `fields ${SEARCH_FIELDS}; where ${idFilters.join(' & ')}; limit ${SEARCH_PAGE_SIZE};`,
          );
          const localizedIds = new Set(localizedRaws.map((r) => r.id));
          raws = [
            ...localizedRaws,
            ...raws.filter((r) => !localizedIds.has(r.id)),
          ].slice(0, SEARCH_PAGE_SIZE);
        }
      }

      const jaNames = await fetchJapaneseLocalizedNames(accessToken, raws.map((r) => r.id));
      const rows = raws.map((raw) => toSearchRow(raw, jaNames.get(raw.id) ?? null));
      if (rows.length > 0) {
        const { error: upsertError } = await db.from('games').upsert(rows);
        if (upsertError) {
          throw new Error(`games upsert failed: ${upsertError.message}`);
        }
      }
      const rowsWithDevFlag = await mergeCachedIsJapaneseDeveloper(db, rows);
      return new Response(JSON.stringify(rowsWithDevFlag), {
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
      const raw = raws[0];
      const similarIds = (raw.similar_games ?? []).map((g) => g.id);
      const jaNames = await fetchJapaneseLocalizedNames(accessToken, [raw.id, ...similarIds]);
      const row = toDetailRow(raw, jaNames);

      // 概要の翻訳は既に翻訳済みならAPIを呼ばずに使い回す（翻訳コストの節約とレスポンス短縮のため）。
      // タイトル（name_ja）はIGDBのLocalized Titleを毎回そのまま使うため、キャッシュ再利用は不要。
      const { data: existing } = await db
        .from('games')
        .select('summary_ja')
        .eq('id', row.id)
        .maybeSingle();
      const summaryJa = existing?.summary_ja ??
        (row.summary ? await translateToJapanese(row.summary) : null);

      const fullRow = {
        ...row,
        summary_ja: summaryJa,
      };
      const { error: upsertError } = await db.from('games').upsert(fullRow);
      if (upsertError) {
        throw new Error(`games upsert failed: ${upsertError.message}`);
      }
      return new Response(JSON.stringify(fullRow), {
        headers: { 'Content-Type': 'application/json' },
      });
    }

    // weekly_releases/monthly_releases/top100は共通して複数プラットフォーム選択・
    // 複数ジャンル選択（いずれもOR条件）とインディー作品フィルタに対応する。
    const releasePlatformList = parseStringListParam(platforms, platform);
    const releaseGenreList = parseStringListParam(genres, genre);
    const releaseExcludeIndie = !releaseGenreList.includes('Indie');

    if (action === 'weekly_releases') {
      const { start, end } = currentWeekRangeUnix();
      const weeklyFilters = [
        `first_release_date >= ${start}`,
        `first_release_date < ${end}`,
      ];
      const platformFilter = buildPlatformFilter(releasePlatformList);
      if (platformFilter) weeklyFilters.push(platformFilter);
      const genreFilter = buildGenreFilter(releaseGenreList);
      if (genreFilter) weeklyFilters.push(genreFilter);
      weeklyFilters.push(
        ...commonExclusionFilters(includeAdult, includeIndie, releaseExcludeIndie),
      );
      const raws = await queryIgdb(
        accessToken,
        `fields ${SEARCH_FIELDS}; where ${weeklyFilters.join(' & ')}; sort total_rating_count desc; limit 30;`,
      );
      const jaNames = await fetchJapaneseLocalizedNames(accessToken, raws.map((r) => r.id));
      const rows = raws.map((raw) => toSearchRow(raw, jaNames.get(raw.id) ?? null));
      if (rows.length > 0) {
        const { error: upsertError } = await db.from('games').upsert(rows);
        if (upsertError) {
          throw new Error(`games upsert failed: ${upsertError.message}`);
        }
      }
      const rowsWithDevFlag = await mergeCachedIsJapaneseDeveloper(db, rows);
      return new Response(JSON.stringify(rowsWithDevFlag), {
        headers: { 'Content-Type': 'application/json' },
      });
    }

    if (action === 'monthly_releases') {
      const { start, end } = currentMonthRangeUnix();
      const monthlyFilters = [
        `first_release_date >= ${start}`,
        `first_release_date < ${end}`,
      ];
      const platformFilter = buildPlatformFilter(releasePlatformList);
      if (platformFilter) monthlyFilters.push(platformFilter);
      const genreFilter = buildGenreFilter(releaseGenreList);
      if (genreFilter) monthlyFilters.push(genreFilter);
      monthlyFilters.push(
        ...commonExclusionFilters(includeAdult, includeIndie, releaseExcludeIndie),
      );
      const raws = await queryIgdb(
        accessToken,
        `fields ${SEARCH_FIELDS}; where ${monthlyFilters.join(' & ')}; sort total_rating_count desc; limit 60;`,
      );
      const jaNames = await fetchJapaneseLocalizedNames(accessToken, raws.map((r) => r.id));
      const rows = raws.map((raw) => toSearchRow(raw, jaNames.get(raw.id) ?? null));
      if (rows.length > 0) {
        const { error: upsertError } = await db.from('games').upsert(rows);
        if (upsertError) {
          throw new Error(`games upsert failed: ${upsertError.message}`);
        }
      }
      const rowsWithDevFlag = await mergeCachedIsJapaneseDeveloper(db, rows);
      return new Response(JSON.stringify(rowsWithDevFlag), {
        headers: { 'Content-Type': 'application/json' },
      });
    }

    // IGDB公式のTop 100（https://www.igdb.com/top-100/games）と同じ考え方の加重評価順トップ100。
    // 単純にtotal_rating_count（評価数）順にすると「評価数は多いが評価の質は普通」な作品
    // （例: 大型オープンワールド作品など）が上位に来てしまい、公式の並びと大きくずれる。
    // 公式サイトも「average ratingだけでなく件数も加味した加重評価（weighted rating）を使う」
    // と明言しているため、IMDb方式のベイズ平均で近似する:
    //   WR = (v / (v+m)) * R + (m / (v+m)) * C
    //   R = そのゲームのユーザー評価平均, v = 評価件数,
    //   m = 候補入りに必要な最低評価件数（円滑化定数）, C = 候補プール全体の平均評価
    if (action === 'top100') {
      const TOP100_MIN_RATING_COUNT = 200;
      const top100Filters: string[] = [
        'rating != null',
        `rating_count >= ${TOP100_MIN_RATING_COUNT}`,
      ];
      const platformFilter = buildPlatformFilter(releasePlatformList);
      if (platformFilter) top100Filters.push(platformFilter);
      const genreFilter = buildGenreFilter(releaseGenreList);
      if (genreFilter) top100Filters.push(genreFilter);
      top100Filters.push(
        ...commonExclusionFilters(includeAdult, includeIndie, releaseExcludeIndie),
      );

      // IGDBは1クエリ最大500件までしか返さないため、評価件数が多い順に候補プールを取得する
      // （加重評価の性質上、上位に来る作品はほぼ評価件数も多いため、この絞り込みで実用上十分）。
      const raws = await queryIgdbEndpoint<RawIgdbGame>(
        accessToken,
        'games',
        `fields ${SEARCH_FIELDS},rating,rating_count; where ${top100Filters.join(' & ')}; sort rating_count desc; limit 500;`,
      );

      const meanRating = raws.length > 0
        ? raws.reduce((sum, r) => sum + (r.rating ?? 0), 0) / raws.length
        : 0;
      const ranked = raws
        .map((raw) => {
          const v = raw.rating_count ?? 0;
          const weighted =
            (v / (v + TOP100_MIN_RATING_COUNT)) * (raw.rating ?? 0) +
            (TOP100_MIN_RATING_COUNT / (v + TOP100_MIN_RATING_COUNT)) * meanRating;
          return { raw, weighted };
        })
        .sort((a, b) => b.weighted - a.weighted)
        .slice(0, 100)
        .map((entry) => entry.raw);

      const jaNames = await fetchJapaneseLocalizedNames(accessToken, ranked.map((r) => r.id));
      const rows = ranked.map((raw) => toSearchRow(raw, jaNames.get(raw.id) ?? null));
      if (rows.length > 0) {
        const { error: upsertError } = await db.from('games').upsert(rows);
        if (upsertError) {
          throw new Error(`games upsert failed: ${upsertError.message}`);
        }
      }
      const rowsWithDevFlag = await mergeCachedIsJapaneseDeveloper(db, rows);
      return new Response(JSON.stringify(rowsWithDevFlag), {
        headers: { 'Content-Type': 'application/json' },
      });
    }

    // カレンダー表示用: 指定した年月に発売予定・発売済みのゲーム一覧（発売日昇順）。
    // weekly/monthly_releasesと違い任意の年月を指定できる（前月・翌月へのナビゲーション用）。
    if (action === 'calendar_releases') {
      const now = new Date();
      const yearNum = typeof year === 'number' ? year : now.getUTCFullYear();
      const monthNum = typeof month === 'number' ? month : now.getUTCMonth() + 1;
      const { start, end } = monthRangeUnix(yearNum, monthNum);
      const calendarFilters = [
        `first_release_date >= ${start}`,
        `first_release_date < ${end}`,
      ];
      const platformFilter = buildPlatformFilter(releasePlatformList);
      if (platformFilter) calendarFilters.push(platformFilter);
      const genreFilter = buildGenreFilter(releaseGenreList);
      if (genreFilter) calendarFilters.push(genreFilter);
      calendarFilters.push(
        ...commonExclusionFilters(includeAdult, includeIndie, releaseExcludeIndie),
      );
      const raws = await queryIgdb(
        accessToken,
        `fields ${SEARCH_FIELDS}; where ${calendarFilters.join(' & ')}; sort first_release_date asc; limit 500;`,
      );
      const jaNames = await fetchJapaneseLocalizedNames(accessToken, raws.map((r) => r.id));
      const rows = raws.map((raw) => toSearchRow(raw, jaNames.get(raw.id) ?? null));
      if (rows.length > 0) {
        const { error: upsertError } = await db.from('games').upsert(rows);
        if (upsertError) {
          throw new Error(`games upsert failed: ${upsertError.message}`);
        }
      }
      const rowsWithDevFlag = await mergeCachedIsJapaneseDeveloper(db, rows);
      return new Response(JSON.stringify(rowsWithDevFlag), {
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
