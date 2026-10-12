import { assertEquals } from 'jsr:@std/assert@1';
import { buildExternalGamesQuery, buildMatches, chunk, parseSteamInput } from './steam.ts';
import type { GameRow, OwnedGame } from './steam.ts';

Deno.test('parseSteamInput: 17桁のSteamID64', () => {
  assertEquals(parseSteamInput('76561198000000000'), { steamId: '76561198000000000' });
  assertEquals(parseSteamInput('  76561198000000000 '), { steamId: '76561198000000000' });
});

Deno.test('parseSteamInput: プロフィールURL', () => {
  assertEquals(
    parseSteamInput('https://steamcommunity.com/profiles/76561198000000000/'),
    { steamId: '76561198000000000' },
  );
  assertEquals(
    parseSteamInput('https://steamcommunity.com/id/my_name-1/games/?tab=all'),
    { vanity: 'my_name-1' },
  );
  assertEquals(parseSteamInput('steamcommunity.com/id/taro'), { vanity: 'taro' });
});

Deno.test('parseSteamInput: カスタムURLの名前だけ', () => {
  assertEquals(parseSteamInput('taro_yamada'), { vanity: 'taro_yamada' });
});

Deno.test('parseSteamInput: 不正な入力は拒否する', () => {
  assertEquals(parseSteamInput(''), null);
  assertEquals(parseSteamInput('a'), null);
  assertEquals(parseSteamInput('https://evil.example.com/id/taro'), null);
  assertEquals(parseSteamInput('https://steamcommunity.com.evil.example/id/taro'), null);
  assertEquals(parseSteamInput('https://steamcommunity.com/market/'), null);
  assertEquals(parseSteamInput('taro yamada'), null);
  assertEquals(parseSteamInput('<script>alert(1)</script>'), null);
  // 数字だけの名前もSteamのカスタムURLとしては有効なため、17桁以外は名前として扱う
  // （存在しなければSteam側で「見つからない」になるだけで害はない）。
  assertEquals(parseSteamInput('1234567890123456'), { vanity: '1234567890123456' });
});

Deno.test('buildExternalGamesQuery: 項目名の違いと値のクォート', () => {
  assertEquals(
    buildExternalGamesQuery([10, 20], true),
    'fields game,uid; where external_game_source = 1 & uid = ("10","20"); limit 500;',
  );
  assertEquals(
    buildExternalGamesQuery([10], false),
    'fields game,uid; where category = 1 & uid = ("10"); limit 500;',
  );
});

Deno.test('chunk', () => {
  assertEquals(chunk([1, 2, 3, 4, 5], 2), [[1, 2], [3, 4], [5]]);
  assertEquals(chunk([], 3), []);
});

const row = (id: number, name: string, gameType: number | null = 0, nameJa: string | null = null): GameRow => ({
  id,
  name,
  name_ja: nameJa,
  cover_url: `https://img/${id}.jpg`,
  game_type_id: gameType,
});

Deno.test('buildMatches: 対応づけ・除外・並び順', () => {
  const owned: OwnedGame[] = [
    { appid: 1, playtime_forever: 0 }, // 未プレイ
    { appid: 2, playtime_forever: 600 }, // 遊んだ
    { appid: 3, playtime_forever: 30 },
    { appid: 4, playtime_forever: 10 }, // DLC → 除外
    { appid: 5, playtime_forever: 10 }, // IGDBに対応なし → 除外
    { appid: 6, playtime_forever: 20 }, // gamesテーブルに行なし → 除外
  ];
  const appToGame = new Map([[1, 101], [2, 102], [3, 103], [4, 104], [6, 106]]);
  const games = new Map<number, GameRow>([
    [101, row(101, 'Alpha')],
    [102, row(102, 'Beta', 0, 'ベータ')],
    [103, row(103, 'Gamma', null)],
    [104, row(104, 'Delta DLC', 1)],
  ]);
  const { matched, unmatchedCount } = buildMatches(owned, appToGame, games);
  assertEquals(matched.map((m) => [m.game_id, m.name, m.playtime_minutes]), [
    [102, 'ベータ', 600],
    [103, 'Gamma', 30],
    [101, 'Alpha', 0],
  ]);
  assertEquals(unmatchedCount, 3);
});

Deno.test('buildMatches: 同じIGDBゲームに複数のappidが対応する場合は長い方を残す', () => {
  const owned: OwnedGame[] = [
    { appid: 1, playtime_forever: 5 },
    { appid: 2, playtime_forever: 90 },
  ];
  const appToGame = new Map([[1, 101], [2, 101]]);
  const games = new Map([[101, row(101, 'Alpha')]]);
  const { matched } = buildMatches(owned, appToGame, games);
  assertEquals(matched.length, 1);
  assertEquals(matched[0].playtime_minutes, 90);
});
