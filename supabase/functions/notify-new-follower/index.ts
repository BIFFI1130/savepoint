// notify-new-follower
//
// 誰かに新しくフォローされたとき、フォローされた本人へFCM経由でプッシュ通知する
// Edge Function。
//
// 呼び出し元（Flutter）は、フォロー操作が成功した直後にこのFunctionを呼ぶ
// （supabase.functions.invoke('notify-new-follower', body: {...})）。
// 呼び出し元のJWTから本人（フォローした側）のuser_idを検証するため、
// 他人になりすまして通知を送らせることはできない。ベストエフォートの副作用の
// ため、送信失敗がフォロー自体を失敗させることはない（呼び出し側で結果を待たない想定）。
//
// リクエストボディ:
//   { followee_id: string }  -- フォローされた側（通知の送り先）のユーザーID
//
// 必要なSecrets:
//   FCM_SERVICE_ACCOUNT_JSON - FirebaseプロジェクトのService Account JSON（1行の文字列）。
//     Firebaseコンソール → プロジェクトの設定 → サービスアカウント → 新しい秘密鍵の生成、で
//     ダウンロードしたJSONの中身をそのまま`supabase secrets set`で登録する。
//   SUPABASE_URL, SUPABASE_ANON_KEY, SUPABASE_SERVICE_ROLE_KEY はSupabaseが自動的に注入する。

import { createClient } from 'jsr:@supabase/supabase-js@2';

interface NotifyRequest {
  followee_id: string;
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
  if (!body.followee_id) {
    return new Response(JSON.stringify({ error: 'パラメータが不足しています' }), {
      status: 400,
      headers: { 'Content-Type': 'application/json' },
    });
  }

  try {
    // 呼び出し元のJWTでユーザーを検証する（フォローした本人）。
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

    // 自分自身をフォローすることは無いはずだが、念のため無視する。
    if (user.id === body.followee_id) {
      return new Response(JSON.stringify({ success: true, sent: 0 }), {
        headers: { 'Content-Type': 'application/json' },
      });
    }

    const adminClient = createClient(
      Deno.env.get('SUPABASE_URL')!,
      Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!,
    );

    const [followerResult, tokensResult] = await Promise.all([
      adminClient.from('profiles').select('display_name').eq('id', user.id).maybeSingle(),
      adminClient
        .from('device_tokens')
        .select('token, platform')
        .eq('user_id', body.followee_id),
    ]);

    if (tokensResult.error) throw new Error(tokensResult.error.message);
    const tokens = (tokensResult.data ?? []) as { token: string; platform: string }[];
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

    // ユーザーIDは表示しない方針のため、表示名が無ければ汎用の文言にする。
    const followerName = followerResult.data?.display_name?.trim() || '新しいフォロワー';
    const title = '新しいフォロワー';
    const messageBody = `${followerName}さんにフォローされました`;

    let sent = 0;
    const staleTokens: string[] = [];
    for (const row of tokens) {
      const result = await sendFcmMessage(
        accessToken,
        serviceAccount.project_id,
        row.token,
        title,
        messageBody,
        { type: 'new_follower', user_id: user.id },
      );
      if (result.ok) sent++;
      if (result.shouldDeleteToken) staleTokens.push(row.token);
    }

    // 無効化されたトークン（アンインストール・再インストール等）は掃除しておく。
    if (staleTokens.length > 0) {
      await adminClient.from('device_tokens').delete().in('token', staleTokens);
    }

    return new Response(JSON.stringify({ success: true, sent }), {
      headers: { 'Content-Type': 'application/json' },
    });
  } catch (error) {
    console.error('notify-new-follower failed', error);
    return new Response(
      JSON.stringify({ error: error instanceof Error ? error.message : String(error) }),
      { status: 500, headers: { 'Content-Type': 'application/json' } },
    );
  }
});
