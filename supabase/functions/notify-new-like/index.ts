// notify-new-like
//
// 誰かが自分の記録に「いいね」したとき、記録の投稿者へFCM経由でプッシュ通知する
// Edge Function。
//
// 呼び出し元（Flutter）は、いいね操作が成功した直後にこのFunctionを呼ぶ
// （supabase.functions.invoke('notify-new-like', body: {...})）。
// 呼び出し元のJWTから本人（いいねした側）のuser_idを検証するため、
// 他人になりすまして通知を送らせることはできない。ベストエフォートの副作用の
// ため、送信失敗がいいね自体を失敗させることはない（呼び出し側で結果を待たない想定）。
//
// リクエストボディ:
//   { log_id: string }  -- いいねされた記録のID
//
// 必要なSecrets: notify-new-followerと共通（FCM_SERVICE_ACCOUNT_JSON等）。

import { createClient } from 'jsr:@supabase/supabase-js@2';

interface NotifyRequest {
  log_id: string;
}

interface ServiceAccount {
  client_email: string;
  private_key: string;
  project_id: string;
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

/** 1分あたりの許容通知送信リクエスト数。通常利用では十分な余裕を持たせている。 */
const RATE_LIMIT_PER_MINUTE = 20;

async function checkRateLimit(
  db: ReturnType<typeof createClient>,
  key: string,
): Promise<boolean> {
  const { data, error } = await db.rpc('check_rate_limit', {
    p_key: key,
    p_limit: RATE_LIMIT_PER_MINUTE,
    p_window_seconds: 60,
  });
  if (error) {
    // レート制限の判定自体が失敗した場合は、機能を止めないよう許可する側に倒す。
    console.error('check_rate_limit failed', error);
    return true;
  }
  return data === true;
}

/// 1件のFCMメッセージを送信する。戻り値は「無効化されたトークンとして削除すべきか」。
async function sendFcmMessage(
  accessToken: string,
  projectId: string,
  token: string,
  title: string,
  body: string,
  data: Record<string, string>,
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

Deno.serve(async (req) => {
  if (req.method !== 'POST') {
    return new Response('Method Not Allowed', { status: 405 });
  }

  const authHeader = req.headers.get('Authorization');
  if (!authHeader) {
    return new Response(JSON.stringify({ error: '認証情報がありません' }), {
      status: 401,
      headers: { 'Content-Type': 'application/json' },
    });
  }

  let body: NotifyRequest;
  try {
    body = await req.json();
  } catch {
    return new Response(JSON.stringify({ error: '不正なリクエストです' }), {
      status: 400,
      headers: { 'Content-Type': 'application/json' },
    });
  }
  if (!body.log_id) {
    return new Response(JSON.stringify({ error: 'パラメータが不足しています' }), {
      status: 400,
      headers: { 'Content-Type': 'application/json' },
    });
  }

  try {
    // 呼び出し元のJWTでユーザーを検証する（いいねした本人）。
    const callerClient = createClient(
      Deno.env.get('SUPABASE_URL')!,
      Deno.env.get('SUPABASE_ANON_KEY')!,
      { global: { headers: { Authorization: authHeader } } },
    );
    const {
      data: { user },
      error: userError,
    } = await callerClient.auth.getUser();
    if (userError || !user) {
      return new Response(JSON.stringify({ error: '認証に失敗しました' }), {
        status: 401,
        headers: { 'Content-Type': 'application/json' },
      });
    }

    const adminClient = createClient(
      Deno.env.get('SUPABASE_URL')!,
      Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!,
    );

    // 呼び出し元が実際にこの記録へいいねしているかを確認する。これが無いと、
    // 有効なJWTさえあれば任意のlog_idを指定して「いいねされました」という
    // 偽の通知を、実際にはいいねしていなくても記録の投稿者へ送りつけられてしまう。
    const likeResult = await adminClient
      .from('game_log_likes')
      .select('log_id')
      .eq('log_id', body.log_id)
      .eq('user_id', user.id)
      .maybeSingle();
    if (likeResult.error) throw new Error(likeResult.error.message);
    if (!likeResult.data) {
      return new Response(JSON.stringify({ success: true, sent: 0 }), {
        headers: { 'Content-Type': 'application/json' },
      });
    }

    // 同じ理由（有効なJWTさえあれば高速に繰り返し呼び出せる）で、通知スパムを
    // 防ぐため呼び出し元ごとにレート制限をかける。
    const rateLimitOk = await checkRateLimit(adminClient, `notify-new-like:user:${user.id}`);
    if (!rateLimitOk) {
      return new Response(JSON.stringify({ success: true, sent: 0 }), {
        status: 429,
        headers: { 'Content-Type': 'application/json' },
      });
    }

    const logResult = await adminClient
      .from('game_logs')
      .select('user_id, game_id')
      .eq('id', body.log_id)
      .maybeSingle();
    if (logResult.error) throw new Error(logResult.error.message);
    if (!logResult.data) {
      return new Response(JSON.stringify({ success: true, sent: 0 }), {
        headers: { 'Content-Type': 'application/json' },
      });
    }

    const ownerId = logResult.data.user_id as string;
    const gameId = logResult.data.game_id as number;

    // 自分の記録に自分でいいねすることは無いはずだが、念のため無視する。
    if (user.id === ownerId) {
      return new Response(JSON.stringify({ success: true, sent: 0 }), {
        headers: { 'Content-Type': 'application/json' },
      });
    }

    const [likerResult, ownerResult, gameResult, tokensResult] = await Promise.all([
      adminClient.from('profiles').select('display_name').eq('id', user.id).maybeSingle(),
      adminClient
        .from('profiles')
        .select('notify_new_like')
        .eq('id', ownerId)
        .maybeSingle(),
      adminClient.from('games').select('name, name_ja').eq('id', gameId).maybeSingle(),
      adminClient.from('device_tokens').select('token').eq('user_id', ownerId),
    ]);

    if (ownerResult.data?.notify_new_like === false) {
      return new Response(JSON.stringify({ success: true, sent: 0 }), {
        headers: { 'Content-Type': 'application/json' },
      });
    }

    if (tokensResult.error) throw new Error(tokensResult.error.message);
    const tokens = (tokensResult.data ?? []) as { token: string }[];
    if (tokens.length === 0) {
      return new Response(JSON.stringify({ success: true, sent: 0 }), {
        headers: { 'Content-Type': 'application/json' },
      });
    }

    const serviceAccountJson = Deno.env.get('FCM_SERVICE_ACCOUNT_JSON');
    if (!serviceAccountJson) {
      console.error('FCM_SERVICE_ACCOUNT_JSON is not set');
      return new Response(JSON.stringify({ success: false, error: 'FCM未設定' }), {
        status: 500,
        headers: { 'Content-Type': 'application/json' },
      });
    }
    const serviceAccount: ServiceAccount = JSON.parse(serviceAccountJson);
    const accessToken = await getAccessToken(serviceAccount);

    const likerName = likerResult.data?.display_name?.trim() || '誰か';
    const gameName =
      gameResult.data?.name_ja?.trim() || gameResult.data?.name?.trim() || 'ゲーム';
    const title = 'いいねされました';
    const messageBody = `${likerName}さんが『${gameName}』の記録にいいねしました`;

    let sent = 0;
    const staleTokens: string[] = [];
    for (const row of tokens) {
      const result = await sendFcmMessage(
        accessToken,
        serviceAccount.project_id,
        row.token,
        title,
        messageBody,
        { type: 'new_like', game_id: String(gameId) },
      );
      if (result.ok) sent++;
      if (result.shouldDeleteToken) staleTokens.push(row.token);
    }

    if (staleTokens.length > 0) {
      await adminClient.from('device_tokens').delete().in('token', staleTokens);
    }

    return new Response(JSON.stringify({ success: true, sent }), {
      headers: { 'Content-Type': 'application/json' },
    });
  } catch (error) {
    console.error('notify-new-like failed', error);
    return new Response(
      JSON.stringify({ error: error instanceof Error ? error.message : String(error) }),
      { status: 500, headers: { 'Content-Type': 'application/json' } },
    );
  }
});
