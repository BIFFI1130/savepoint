// notify-release-changes
//
// 「遊びたい」に入れた作品の発売日が決まった・変更されたときに、その作品を積んでいる
// ユーザーへプッシュ通知する。
//
// 変更の検知はアプリ側ではなくDBトリガー（public.queue_release_date_change）が行い、
// release_date_changesテーブルに積む（IGDBのデータダンプ取り込みでgames.first_release_dateが
// 更新されたとき）。この関数はそのキューをcronで定期的に処理する。
// 呼び出し元はpg_cron（6時間おき、supabase/migrations/20261012000000_...を参照）なので、
// ユーザーJWTではなく共有シークレット（x-cron-secretヘッダ）で検証する。
//
// 必要なSecrets: FCM_SERVICE_ACCOUNT_JSON、CRON_SECRET（notify-weekly-digestと共通）。

import { createClient } from 'jsr:@supabase/supabase-js@2';

interface ServiceAccount {
  client_email: string;
  private_key: string;
  project_id: string;
}

/// x-cron-secretヘッダの比較を定数時間で行う。単純な`!==`比較は理論上、
/// 不一致が見つかった時点で早期リターンするため、応答時間差から1バイトずつ
/// シークレットを推測されるタイミングサイドチャネルの余地がある
/// （ネットワーク越しでは実用上ほぼ悪用不可能だが、対策コストが低いため入れておく）。
function timingSafeEqual(a: string, b: string): boolean {
  const aBytes = new TextEncoder().encode(a);
  const bBytes = new TextEncoder().encode(b);
  if (aBytes.length !== bBytes.length) return false;
  let diff = 0;
  for (let i = 0; i < aBytes.length; i++) diff |= aBytes[i] ^ bBytes[i];
  return diff === 0;
}

function base64url(input: ArrayBuffer | string): string {
  const bytes =
    typeof input === 'string' ? new TextEncoder().encode(input) : new Uint8Array(input);
  let binary = '';
  for (const byte of bytes) binary += String.fromCharCode(byte);
  return btoa(binary).replace(/\+/g, '-').replace(/\//g, '_').replace(/=+$/, '');
}

async function importPrivateKey(pem: string): Promise<CryptoKey> {
  const pemContents = pem
    .replace('-----BEGIN PRIVATE KEY-----', '')
    .replace('-----END PRIVATE KEY-----', '')
    .replace(/\s/g, '');
  const binaryDer = Uint8Array.from(atob(pemContents), (c) => c.charCodeAt(0));
  return crypto.subtle.importKey(
    'pkcs8',
    binaryDer.buffer,
    { name: 'RSASSA-PKCS1-v1_5', hash: 'SHA-256' },
    false,
    ['sign'],
  );
}

/// Service AccountのJWTベアラーフローで、FCM HTTP v1 API用のOAuth2アクセストークンを取得する。
async function getAccessToken(serviceAccount: ServiceAccount): Promise<string> {
  const header = { alg: 'RS256', typ: 'JWT' };
  const now = Math.floor(Date.now() / 1000);
  const claimSet = {
    iss: serviceAccount.client_email,
    scope: 'https://www.googleapis.com/auth/firebase.messaging',
    aud: 'https://oauth2.googleapis.com/token',
    iat: now,
    exp: now + 3600,
  };
  const signingInput = `${base64url(JSON.stringify(header))}.${base64url(JSON.stringify(claimSet))}`;
  const key = await importPrivateKey(serviceAccount.private_key);
  const signature = await crypto.subtle.sign(
    'RSASSA-PKCS1-v1_5',
    key,
    new TextEncoder().encode(signingInput),
  );
  const jwt = `${signingInput}.${base64url(signature)}`;

  const response = await fetch('https://oauth2.googleapis.com/token', {
    method: 'POST',
    headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
    body: new URLSearchParams({
      grant_type: 'urn:ietf:params:oauth:grant-type:jwt-bearer',
      assertion: jwt,
    }),
  });
  const data = await response.json();
  if (!response.ok) {
    throw new Error(`OAuth token request failed: ${JSON.stringify(data)}`);
  }
  return data.access_token as string;
}

/// 1件のFCMメッセージを送信する。戻り値は「無効化されたトークンとして削除すべきか」。
async function sendFcmMessage(
  accessToken: string,
  projectId: string,
  token: string,
  title: string,
  body: string,
  data: Record<string, string>,
  channelId: string,
): Promise<{ ok: boolean; shouldDeleteToken: boolean }> {
  const response = await fetch(
    `https://fcm.googleapis.com/v1/projects/${projectId}/messages:send`,
    {
      method: 'POST',
      headers: {
        Authorization: `Bearer ${accessToken}`,
        'Content-Type': 'application/json',
      },
      body: JSON.stringify({
        message: {
          token,
          notification: { title, body },
          data,
          apns: { payload: { aps: { sound: 'default' } } },
          android: { notification: { channel_id: channelId } },
        },
      }),
    },
  );
  if (response.ok) return { ok: true, shouldDeleteToken: false };

  const errorBody = await response.json().catch(() => null);
  const errorCode = errorBody?.error?.details?.find(
    (d: { errorCode?: string }) => d.errorCode,
  )?.errorCode;
  const shouldDeleteToken = errorCode === 'UNREGISTERED' || errorCode === 'NOT_FOUND';
  console.error('FCM send failed', token, response.status, errorBody);
  return { ok: false, shouldDeleteToken };
}


/** 1回の実行で処理する変更の上限。残りは次回に持ち越す。 */
const BATCH_LIMIT = 200;
/** 1人に1回の実行で個別に送る通知の上限（超えた分は「ほかN件」にまとめる）。 */
const MAX_PER_USER = 5;
/** `.in()`に渡すIDの数の上限（URLが長くなりすぎないように分割する）。 */
const IN_CHUNK = 100;

function chunk<T>(items: T[], size: number): T[][] {
  const out: T[][] = [];
  for (let i = 0; i < items.length; i += size) out.push(items.slice(i, i + size));
  return out;
}

function formatDate(date: string | null): string {
  if (!date) return '未定';
  const [y, m, d] = date.split('-').map(Number);
  return `${y}年${m}月${d}日`;
}

interface ChangeRow {
  id: number;
  game_id: number;
  old_date: string | null;
  new_date: string | null;
  games: { name: string; name_ja: string | null } | { name: string; name_ja: string | null }[] | null;
}

interface GameChange {
  gameId: number;
  name: string;
  oldDate: string | null;
  newDate: string | null;
}

function describe(change: GameChange): { title: string; body: string } {
  const { name, oldDate, newDate } = change;
  if (!oldDate && newDate) {
    return { title: '発売日が決まりました', body: `「${name}」の発売日は${formatDate(newDate)}です` };
  }
  if (oldDate && !newDate) {
    return { title: '発売日が未定になりました', body: `「${name}」の発売日が未定に変更されました` };
  }
  return {
    title: '発売日が変更されました',
    body: `「${name}」${formatDate(oldDate)} → ${formatDate(newDate)}`,
  };
}

Deno.serve(async (req) => {
  if (req.method !== 'POST') {
    return new Response('Method Not Allowed', { status: 405 });
  }

  const cronSecret = Deno.env.get('CRON_SECRET');
  const providedSecret = req.headers.get('x-cron-secret');
  if (!cronSecret || !providedSecret || !timingSafeEqual(providedSecret, cronSecret)) {
    return new Response(JSON.stringify({ error: '認証に失敗しました' }), {
      status: 401,
      headers: { 'Content-Type': 'application/json' },
    });
  }

  const json = (body: unknown, status = 200) =>
    new Response(JSON.stringify(body), {
      status,
      headers: { 'Content-Type': 'application/json' },
    });

  try {
    const admin = createClient(
      Deno.env.get('SUPABASE_URL')!,
      Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!,
    );

    const pending = await admin
      .from('release_date_changes')
      .select('id, game_id, old_date, new_date, games(name, name_ja)')
      .is('processed_at', null)
      .order('detected_at', { ascending: true })
      .limit(BATCH_LIMIT);
    if (pending.error) throw new Error(pending.error.message);
    const rows = (pending.data ?? []) as unknown as ChangeRow[];
    if (rows.length === 0) return json({ success: true, changes: 0, sent: 0 });

    // 同じ作品が短期間に何度も変わった場合は、最初の日付→最後の日付の1件にまとめる。
    const merged = new Map<number, GameChange>();
    for (const row of rows) {
      const game = Array.isArray(row.games) ? row.games[0] : row.games;
      const existing = merged.get(row.game_id);
      if (existing) {
        existing.newDate = row.new_date;
      } else {
        merged.set(row.game_id, {
          gameId: row.game_id,
          name: game?.name_ja ?? game?.name ?? '作品',
          oldDate: row.old_date,
          newDate: row.new_date,
        });
      }
    }

    // 通知の重複を避けるため、送信より先に処理済みにする（失敗時は取りこぼしの方を許容する）。
    for (const ids of chunk(rows.map((r) => r.id), IN_CHUNK)) {
      const marked = await admin
        .from('release_date_changes')
        .update({ processed_at: new Date().toISOString() })
        .in('id', ids);
      if (marked.error) throw new Error(marked.error.message);
    }

    // 実質的に日付が変わっていないもの（変更→元に戻った）は通知しない。
    const effective = [...merged.values()].filter((c) => c.oldDate !== c.newDate);
    if (effective.length === 0) return json({ success: true, changes: 0, sent: 0 });

    const changeByGame = new Map(effective.map((c) => [c.gameId, c]));
    const gameIds = [...changeByGame.keys()];

    // 「遊びたい」に入れているユーザーを集める。
    const changesByUser = new Map<string, GameChange[]>();
    for (const ids of chunk(gameIds, IN_CHUNK)) {
      const logs = await admin
        .from('game_logs')
        .select('user_id, game_id')
        .in('game_id', ids)
        .eq('status', 'want_to_play');
      if (logs.error) throw new Error(logs.error.message);
      for (const log of logs.data ?? []) {
        const change = changeByGame.get(log.game_id as number);
        if (!change) continue;
        const list = changesByUser.get(log.user_id as string) ?? [];
        list.push(change);
        changesByUser.set(log.user_id as string, list);
      }
    }
    if (changesByUser.size === 0) return json({ success: true, changes: effective.length, sent: 0 });

    // 通知を受け取る設定のユーザーと、その端末トークンに絞る。
    const optedIn = new Set<string>();
    for (const ids of chunk([...changesByUser.keys()], IN_CHUNK)) {
      const profiles = await admin
        .from('profiles')
        .select('id')
        .in('id', ids)
        .eq('notify_release_changes', true);
      if (profiles.error) throw new Error(profiles.error.message);
      for (const p of profiles.data ?? []) optedIn.add(p.id as string);
    }

    const tokensByUser = new Map<string, string[]>();
    for (const ids of chunk([...optedIn], IN_CHUNK)) {
      const tokens = await admin.from('device_tokens').select('token, user_id').in('user_id', ids);
      if (tokens.error) throw new Error(tokens.error.message);
      for (const t of tokens.data ?? []) {
        const list = tokensByUser.get(t.user_id as string) ?? [];
        list.push(t.token as string);
        tokensByUser.set(t.user_id as string, list);
      }
    }
    if (tokensByUser.size === 0) return json({ success: true, changes: effective.length, sent: 0 });

    const serviceAccountJson = Deno.env.get('FCM_SERVICE_ACCOUNT_JSON');
    if (!serviceAccountJson) {
      console.error('FCM_SERVICE_ACCOUNT_JSON is not set');
      return json({ success: false, error: 'FCM未設定' }, 500);
    }
    const serviceAccount: ServiceAccount = JSON.parse(serviceAccountJson);
    const accessToken = await getAccessToken(serviceAccount);

    let sent = 0;
    const staleTokens: string[] = [];
    for (const [userId, tokens] of tokensByUser) {
      const changes = changesByUser.get(userId) ?? [];
      const messages = changes.slice(0, MAX_PER_USER).map((change) => ({
        ...describe(change),
        data: { type: 'release_change', game_id: String(change.gameId) },
      }));
      if (changes.length > MAX_PER_USER) {
        messages.push({
          title: '発売日が変更されました',
          body: `ほか${changes.length - MAX_PER_USER}件の「遊びたい」作品の発売日が変更されました`,
          data: { type: 'release_change', game_id: '' },
        });
      }
      for (const token of tokens) {
        for (const message of messages) {
          const result = await sendFcmMessage(
            accessToken,
            serviceAccount.project_id,
            token,
            message.title,
            message.body,
            message.data,
            'release_change',
          );
          if (result.ok) sent++;
          if (result.shouldDeleteToken) {
            staleTokens.push(token);
            break;
          }
        }
      }
    }

    if (staleTokens.length > 0) {
      for (const ids of chunk([...new Set(staleTokens)], IN_CHUNK)) {
        await admin.from('device_tokens').delete().in('token', ids);
      }
    }

    return json({ success: true, changes: effective.length, sent });
  } catch (error) {
    console.error('notify-release-changes failed', error);
    return json({ error: error instanceof Error ? error.message : String(error) }, 500);
  }
});
