// notify-app-update
//
// 新しいバージョンの公開を、端末へプッシュ通知で知らせる。リリース後に手動で1回呼ぶ
// （自動では送らない。審査通過後にストアへ反映されたことを確認してから実行する想定）。
//
// 呼び出し: x-cron-secretヘッダ（notify-weekly-digestと共通のCRON_SECRET）。
// リクエストボディ:
//   { version: "1.0.8",            -- 公開したバージョン（必須、数値のドット区切り）
//     title?: string, body?: string, -- 省略時は既定の文言
//     platform?: "ios" | "android",  -- 省略時は"ios"
//     dry_run?: boolean }            -- trueなら送らず、対象件数だけ返す
//
// 送信先は、platformが一致し、アップデートのお知らせをOFFにしておらず、かつ
// 端末に記録された版（device_tokens.app_version）が[version]より古い（未記録を含む）トークン。
//
// 必要なSecrets: FCM_SERVICE_ACCOUNT_JSON、CRON_SECRET。

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


const PAGE_SIZE = 1000;
/** 同時に送るFCMリクエスト数。 */
const SEND_CONCURRENCY = 10;
const VERSION_PATTERN = /^\d+(\.\d+){1,3}$/;

/** `a`が`b`より古い（数値として小さい）か。 */
function isOlderVersion(a: string, b: string): boolean {
  const pa = a.split('.').map((n) => Number.parseInt(n, 10));
  const pb = b.split('.').map((n) => Number.parseInt(n, 10));
  if (pa.some(Number.isNaN) || pb.some(Number.isNaN)) return false;
  const length = Math.max(pa.length, pb.length);
  for (let i = 0; i < length; i++) {
    const x = pa[i] ?? 0;
    const y = pb[i] ?? 0;
    if (x !== y) return x < y;
  }
  return false;
}

interface TokenRow {
  token: string;
  user_id: string;
  app_version: string | null;
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

  let input: {
    version?: string;
    title?: string;
    body?: string;
    platform?: string;
    dry_run?: boolean;
  };
  try {
    input = await req.json();
  } catch {
    return json({ error: '不正なリクエストです' }, 400);
  }
  const version = input.version?.trim() ?? '';
  if (!VERSION_PATTERN.test(version)) {
    return json({ error: 'versionは「1.0.8」のような形式で指定してください' }, 400);
  }
  const platform = input.platform ?? 'ios';
  if (platform !== 'ios' && platform !== 'android') {
    return json({ error: 'platformはiosまたはandroidを指定してください' }, 400);
  }
  const title = input.title?.trim() || 'SavePointの新しいバージョンが公開されました';
  const body =
    input.body?.trim() || `バージョン ${version} が公開されました。アップデートして新機能をお試しください。`;

  try {
    const admin = createClient(
      Deno.env.get('SUPABASE_URL')!,
      Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!,
    );

    const optedOut = new Set<string>();
    for (let from = 0; ; from += PAGE_SIZE) {
      const page = await admin
        .from('profiles')
        .select('id')
        .eq('notify_app_update', false)
        .range(from, from + PAGE_SIZE - 1);
      if (page.error) throw new Error(page.error.message);
      for (const row of page.data ?? []) optedOut.add(row.id as string);
      if ((page.data ?? []).length < PAGE_SIZE) break;
    }

    const targets: string[] = [];
    let skippedUpToDate = 0;
    let skippedOptOut = 0;
    for (let from = 0; ; from += PAGE_SIZE) {
      const page = await admin
        .from('device_tokens')
        .select('token, user_id, app_version')
        .eq('platform', platform)
        .order('id')
        .range(from, from + PAGE_SIZE - 1);
      if (page.error) throw new Error(page.error.message);
      const rows = (page.data ?? []) as TokenRow[];
      for (const row of rows) {
        if (optedOut.has(row.user_id)) {
          skippedOptOut++;
        } else if (row.app_version && !isOlderVersion(row.app_version, version)) {
          skippedUpToDate++;
        } else {
          targets.push(row.token);
        }
      }
      if (rows.length < PAGE_SIZE) break;
    }

    if (input.dry_run) {
      return json({
        success: true,
        dry_run: true,
        would_send: targets.length,
        skipped_up_to_date: skippedUpToDate,
        skipped_opt_out: skippedOptOut,
      });
    }
    if (targets.length === 0) {
      return json({ success: true, sent: 0, skipped_up_to_date: skippedUpToDate, skipped_opt_out: skippedOptOut });
    }

    const serviceAccountJson = Deno.env.get('FCM_SERVICE_ACCOUNT_JSON');
    if (!serviceAccountJson) {
      console.error('FCM_SERVICE_ACCOUNT_JSON is not set');
      return json({ success: false, error: 'FCM未設定' }, 500);
    }
    const serviceAccount: ServiceAccount = JSON.parse(serviceAccountJson);
    const accessToken = await getAccessToken(serviceAccount);

    let sent = 0;
    const staleTokens: string[] = [];
    for (let i = 0; i < targets.length; i += SEND_CONCURRENCY) {
      const results = await Promise.all(
        targets.slice(i, i + SEND_CONCURRENCY).map(async (token) => ({
          token,
          result: await sendFcmMessage(
            accessToken,
            serviceAccount.project_id,
            token,
            title,
            body,
            { type: 'app_update', version },
            'app_update',
          ),
        })),
      );
      for (const { token, result } of results) {
        if (result.ok) sent++;
        if (result.shouldDeleteToken) staleTokens.push(token);
      }
    }

    for (let i = 0; i < staleTokens.length; i += 100) {
      await admin.from('device_tokens').delete().in('token', staleTokens.slice(i, i + 100));
    }

    return json({
      success: true,
      sent,
      failed: targets.length - sent,
      skipped_up_to_date: skippedUpToDate,
      skipped_opt_out: skippedOptOut,
    });
  } catch (error) {
    console.error('notify-app-update failed', error);
    return json({ error: error instanceof Error ? error.message : String(error) }, 500);
  }
});
