// steam-import
//
// Steamの所有ゲームを取得し、IGDBの作品に対応づけて、SavePointに取り込める候補の一覧を返す。
// 記録の書き込み自体はクライアントが（RLSの範囲で）行うため、この関数は読み取り専用。
//
// 流れ:
//   1. 入力（SteamID64 / プロフィールURL / カスタムURLの名前）→ SteamID64
//   2. Steam Web API GetOwnedGames（プロフィールの「ゲームの詳細」が公開されている必要がある）
//   3. IGDBのexternal_gamesでappidをIGDBのゲームIDに対応づけ
//   4. gamesテーブルに存在する作品だけに絞る（game_logsの外部キーを満たすため）。DLC等は除外
//
// リクエスト: { steam_input: string }
// レスポンス: { steam_id, total_owned, truncated, unmatched_count, matched: MatchedGame[] }
// エラー: { code, error }（invalid_input / not_found / private_profile / not_configured /
//        rate_limited / upstream）
//
// 必要なSecrets: STEAM_API_KEY（https://steamcommunity.com/dev/apikey で取得）、
// TWITCH_CLIENT_ID / TWITCH_CLIENT_SECRET（igdb-proxyと共通）。

import { createClient } from 'jsr:@supabase/supabase-js@2';
import {
  buildExternalGamesQuery,
  buildMatches,
  chunk,
  parseSteamInput,
} from './steam.ts';
import type { GameRow, OwnedGame } from './steam.ts';

const STEAM_API = 'https://api.steampowered.com';
const IGDB_API = 'https://api.igdb.com/v4';
/** 1回で処理する所有ゲーム数の上限（IGDBのレート制限と実行時間のため）。 */
const MAX_OWNED = 3000;
const IGDB_BATCH = 500;
/** IGDBは秒間4リクエストまで。余裕を持って間隔を空ける。 */
const IGDB_INTERVAL_MS = 300;
const RATE_LIMIT_PER_MINUTE = 5;

class ImportError extends Error {
  constructor(public code: string, message: string, public status: number) {
    super(message);
  }
}

const sleep = (ms: number) => new Promise((resolve) => setTimeout(resolve, ms));

async function steamGet(path: string, params: Record<string, string>): Promise<any> {
  const url = `${STEAM_API}/${path}?${new URLSearchParams(params)}`;
  const response = await fetch(url);
  if (response.status === 403) {
    throw new ImportError('not_configured', 'Steam APIキーが無効です', 500);
  }
  if (!response.ok) {
    throw new ImportError('upstream', `Steamから取得できませんでした（${response.status}）`, 502);
  }
  return response.json();
}

async function resolveSteamId(input: string, apiKey: string): Promise<string> {
  const target = parseSteamInput(input);
  if (!target) {
    throw new ImportError(
      'invalid_input',
      'SteamのプロフィールURLか、カスタムURLの名前を入力してください',
      400,
    );
  }
  if ('steamId' in target) return target.steamId;
  const data = await steamGet('ISteamUser/ResolveVanityURL/v1/', {
    key: apiKey,
    vanityurl: target.vanity,
  });
  if (data?.response?.success !== 1 || !data.response.steamid) {
    throw new ImportError('not_found', 'Steamのユーザーが見つかりませんでした', 404);
  }
  return data.response.steamid as string;
}

async function getOwnedGames(steamId: string, apiKey: string): Promise<OwnedGame[]> {
  const data = await steamGet('IPlayerService/GetOwnedGames/v1/', {
    key: apiKey,
    steamid: steamId,
    include_appinfo: '1',
    include_played_free_games: '1',
    format: 'json',
  });
  const body = data?.response ?? {};
  // 「ゲームの詳細」が非公開だと、game_count自体が返らず空のオブジェクトになる。
  if (typeof body.game_count !== 'number') {
    throw new ImportError(
      'private_profile',
      'Steamのプロフィールの「ゲームの詳細」を「公開」にしてから、もう一度お試しください',
      422,
    );
  }
  return (body.games ?? []) as OwnedGame[];
}

async function getTwitchToken(): Promise<string> {
  const params = new URLSearchParams({
    client_id: Deno.env.get('TWITCH_CLIENT_ID')!,
    client_secret: Deno.env.get('TWITCH_CLIENT_SECRET')!,
    grant_type: 'client_credentials',
  });
  const response = await fetch(`https://id.twitch.tv/oauth2/token?${params}`, { method: 'POST' });
  if (!response.ok) throw new ImportError('upstream', 'IGDBの認証に失敗しました', 502);
  return (await response.json()).access_token as string;
}

async function igdbExternalGames(
  token: string,
  appIds: number[],
): Promise<{ game: number; uid: string }[]> {
  const request = (useSourceField: boolean) =>
    fetch(`${IGDB_API}/external_games`, {
      method: 'POST',
      headers: {
        'Client-ID': Deno.env.get('TWITCH_CLIENT_ID')!,
        Authorization: `Bearer ${token}`,
        'Content-Type': 'text/plain',
      },
      body: buildExternalGamesQuery(appIds, useSourceField),
    });

  let response = await request(true);
  // 項目名の移行中で`external_game_source`が使えない場合は、従来の`category`で再試行する。
  if (response.status === 400) response = await request(false);
  if (!response.ok) throw new ImportError('upstream', `IGDBから取得できませんでした（${response.status}）`, 502);
  return (await response.json()) as { game: number; uid: string }[];
}

Deno.serve(async (req) => {
  const json = (body: unknown, status = 200) =>
    new Response(JSON.stringify(body), {
      status,
      headers: { 'Content-Type': 'application/json' },
    });

  if (req.method !== 'POST') {
    return new Response('Method Not Allowed', { status: 405 });
  }
  const authHeader = req.headers.get('Authorization');
  if (!authHeader) return json({ code: 'unauthorized', error: '認証情報がありません' }, 401);

  try {
    const callerClient = createClient(
      Deno.env.get('SUPABASE_URL')!,
      Deno.env.get('SUPABASE_ANON_KEY')!,
      { global: { headers: { Authorization: authHeader } } },
    );
    const {
      data: { user },
      error: userError,
    } = await callerClient.auth.getUser();
    if (userError || !user) return json({ code: 'unauthorized', error: '認証に失敗しました' }, 401);

    let input: { steam_input?: string };
    try {
      input = await req.json();
    } catch {
      return json({ code: 'invalid_input', error: '不正なリクエストです' }, 400);
    }

    const apiKey = Deno.env.get('STEAM_API_KEY');
    if (!apiKey) return json({ code: 'not_configured', error: 'Steam連携は準備中です' }, 500);

    const admin = createClient(
      Deno.env.get('SUPABASE_URL')!,
      Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!,
    );

    // 有効なJWTがあれば何度でも呼べてしまうため、ユーザーごとにレート制限をかける。
    const rate = await admin.rpc('check_rate_limit', {
      p_key: `steam-import:user:${user.id}`,
      p_limit: RATE_LIMIT_PER_MINUTE,
      p_window_seconds: 60,
    });
    if (!rate.error && rate.data === false) {
      return json({ code: 'rate_limited', error: '短時間に何度も実行されました。少し待ってからお試しください' }, 429);
    }

    const steamId = await resolveSteamId(input.steam_input ?? '', apiKey);
    const allOwned = await getOwnedGames(steamId, apiKey);
    const truncated = allOwned.length > MAX_OWNED;
    const owned = allOwned.slice(0, MAX_OWNED);
    if (owned.length === 0) {
      return json({ steam_id: steamId, total_owned: 0, truncated: false, unmatched_count: 0, matched: [] });
    }

    const token = await getTwitchToken();
    const appIdToGameId = new Map<number, number>();
    for (const ids of chunk(owned.map((g) => g.appid), IGDB_BATCH)) {
      for (const row of await igdbExternalGames(token, ids)) {
        const appId = Number(row.uid);
        if (!appIdToGameId.has(appId)) appIdToGameId.set(appId, row.game);
      }
      await sleep(IGDB_INTERVAL_MS);
    }

    const gamesById = new Map<number, GameRow>();
    for (const ids of chunk([...new Set(appIdToGameId.values())], 200)) {
      const rows = await admin
        .from('games')
        .select('id, name, name_ja, cover_url, game_type_id')
        .in('id', ids);
      if (rows.error) throw new Error(rows.error.message);
      for (const row of (rows.data ?? []) as GameRow[]) gamesById.set(row.id, row);
    }

    const { matched, unmatchedCount } = buildMatches(owned, appIdToGameId, gamesById);
    return json({
      steam_id: steamId,
      total_owned: allOwned.length,
      truncated,
      unmatched_count: unmatchedCount,
      matched,
    });
  } catch (error) {
    if (error instanceof ImportError) {
      return json({ code: error.code, error: error.message }, error.status);
    }
    console.error('steam-import failed', error);
    return json({ code: 'upstream', error: '取り込みに失敗しました。時間をおいてお試しください' }, 500);
  }
});
