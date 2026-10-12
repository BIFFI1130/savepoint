// steam-importの純粋関数（入力の解釈・クエリ生成・結果の整形）。
// Deno.serveを含むindex.tsから切り離し、単体テスト（steam_test.ts）できるようにしている。

export type SteamTarget = { steamId: string } | { vanity: string };

/**
 * ユーザーが入力した文字列から、SteamID64かバニティURL（カスタムURLの名前）を取り出す。
 * 受け付ける形式: 17桁のSteamID64 / steamcommunity.comのプロフィールURL
 * （/profiles/<SteamID64> または /id/<名前>）/ カスタムURLの名前だけ。
 */
export function parseSteamInput(raw: string): SteamTarget | null {
  const input = raw.trim();
  if (!input) return null;
  if (/^\d{17}$/.test(input)) return { steamId: input };

  if (/^https?:\/\//i.test(input) || /^steamcommunity\.com\//i.test(input)) {
    let url: URL;
    try {
      url = new URL(/^https?:\/\//i.test(input) ? input : `https://${input}`);
    } catch {
      return null;
    }
    if (url.hostname !== 'steamcommunity.com' && url.hostname !== 'www.steamcommunity.com') {
      return null;
    }
    const profiles = url.pathname.match(/^\/profiles\/(\d{17})(?:\/|$)/);
    if (profiles) return { steamId: profiles[1] };
    const vanity = url.pathname.match(/^\/id\/([A-Za-z0-9_-]{2,32})(?:\/|$)/);
    if (vanity) return { vanity: vanity[1] };
    return null;
  }

  if (/^[A-Za-z0-9_-]{2,32}$/.test(input)) return { vanity: input };
  return null;
}

export interface OwnedGame {
  appid: number;
  name?: string;
  /** 累計プレイ時間（分）。 */
  playtime_forever?: number;
}

/** IGDBのgame_type。DLC・バンドル・Mod・エピソード・シーズン・パック・アップデートは取り込み対象外。 */
export const EXCLUDED_GAME_TYPES = new Set([1, 3, 5, 6, 7, 13, 14]);

export function chunk<T>(items: T[], size: number): T[][] {
  const out: T[][] = [];
  for (let i = 0; i < items.length; i += size) out.push(items.slice(i, i + size));
  return out;
}

/**
 * SteamのappidをIGDBのゲームIDに対応づけるexternal_gamesのクエリ。
 * IGDBは`category`（Steam=1）を廃止予定として`external_game_source`に移行中のため、
 * どちらの項目でも組み立てられるようにしている。
 */
export function buildExternalGamesQuery(appIds: number[], useSourceField: boolean): string {
  const uids = appIds.map((id) => `"${id}"`).join(',');
  const filter = useSourceField ? 'external_game_source = 1' : 'category = 1';
  return `fields game,uid; where ${filter} & uid = (${uids}); limit 500;`;
}

export interface MatchedGame {
  game_id: number;
  name: string;
  cover_url: string | null;
  playtime_minutes: number;
}

export interface GameRow {
  id: number;
  name: string;
  name_ja: string | null;
  cover_url: string | null;
  game_type_id: number | null;
}

/**
 * Steamの所有ゲームとIGDBの対応・gamesテーブルの行から、取り込み候補の一覧を作る。
 * - gamesテーブルに行が無いもの（外部キーを満たせない）と、DLC等は除外する。
 * - 同じIGDBゲームに複数のappidが対応する場合は、プレイ時間が長い方を残す。
 * - プレイ時間の長い順（未プレイは末尾、その中ではタイトル順）に並べる。
 */
export function buildMatches(
  owned: OwnedGame[],
  appIdToGameId: Map<number, number>,
  gamesById: Map<number, GameRow>,
): { matched: MatchedGame[]; unmatchedCount: number } {
  const byGame = new Map<number, MatchedGame>();
  let unmatched = 0;
  for (const item of owned) {
    const gameId = appIdToGameId.get(item.appid);
    const row = gameId === undefined ? undefined : gamesById.get(gameId);
    if (!row || (row.game_type_id !== null && EXCLUDED_GAME_TYPES.has(row.game_type_id))) {
      unmatched++;
      continue;
    }
    const minutes = item.playtime_forever ?? 0;
    const existing = byGame.get(row.id);
    if (existing) {
      existing.playtime_minutes = Math.max(existing.playtime_minutes, minutes);
      continue;
    }
    byGame.set(row.id, {
      game_id: row.id,
      name: row.name_ja ?? row.name,
      cover_url: row.cover_url,
      playtime_minutes: minutes,
    });
  }
  const matched = [...byGame.values()].sort((a, b) => {
    if (a.playtime_minutes !== b.playtime_minutes) return b.playtime_minutes - a.playtime_minutes;
    return a.name.localeCompare(b.name, 'ja');
  });
  return { matched, unmatchedCount: unmatched };
}
