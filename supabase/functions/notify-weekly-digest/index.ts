// notify-weekly-digest
//
// フォロー中ユーザーの新着記録を週1回まとめて知らせるダイジェスト通知。
// notify-new-follower/notify-new-review と異なり、呼び出し元はユーザーではなく
// pg_cron（毎週月曜10:00 JST、supabase/migrations/20260826000200_...を参照）
// なので、ユーザーJWTではなく共有シークレット（x-cron-secretヘッダ）で検証する。
//
// 必要なSecrets: FCM_SERVICE_ACCOUNT_JSON（既存2関数と共通）、CRON_SECRET
// （supabase secrets set CRON_SECRET=... で、migrationに埋め込んだ値と同じものを設定する）。

import { createClient } from 'jsr:@supabase/supabase-js@2';

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

  const cronSecret = Deno.env.get('CRON_SECRET');
  if (!cronSecret || req.headers.get('x-cron-secret') !== cronSecret) {
    return new Response(JSON.stringify({ error: '認証に失敗しました' }), {
      status: 401,
      headers: { 'Content-Type': 'application/json' },
    });
  }

  try {
    const adminClient = createClient(
      Deno.env.get('SUPABASE_URL')!,
      Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!,
    );

    const recipientsResult = await adminClient.rpc('weekly_digest_recipients');
    if (recipientsResult.error) throw new Error(recipientsResult.error.message);

    const recipients = (recipientsResult.data ?? []) as {
      user_id: string;
      log_count: number;
    }[];
    if (recipients.length === 0) {
      return new Response(JSON.stringify({ success: true, sent: 0 }), {
        headers: { 'Content-Type': 'application/json' },
      });
    }

    const recipientIds = recipients.map((r) => r.user_id);
    const optedInResult = await adminClient
      .from('profiles')
      .select('id')
      .in('id', recipientIds)
      .eq('notify_weekly_digest', true);
    if (optedInResult.error) throw new Error(optedInResult.error.message);

    const optedInIds = new Set((optedInResult.data ?? []).map((row) => row.id as string));
    const optedInRecipients = recipients.filter((r) => optedInIds.has(r.user_id));
    if (optedInRecipients.length === 0) {
      return new Response(JSON.stringify({ success: true, sent: 0 }), {
        headers: { 'Content-Type': 'application/json' },
      });
    }

    const tokensResult = await adminClient
      .from('device_tokens')
      .select('user_id, token')
      .in(
        'user_id',
        optedInRecipients.map((r) => r.user_id),
      );
    if (tokensResult.error) throw new Error(tokensResult.error.message);

    const tokensByUser = new Map<string, string[]>();
    for (const row of (tokensResult.data ?? []) as { user_id: string; token: string }[]) {
      const list = tokensByUser.get(row.user_id) ?? [];
      list.push(row.token);
      tokensByUser.set(row.user_id, list);
    }
    if (tokensByUser.size === 0) {
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

    let sent = 0;
    const staleTokens: string[] = [];
    for (const recipient of optedInRecipients) {
      const tokens = tokensByUser.get(recipient.user_id) ?? [];
      if (tokens.length === 0) continue;
      const title = '今週のタイムライン';
      const body = `フォロー中のユーザーが今週${recipient.log_count}件の記録を追加しました`;
      for (const token of tokens) {
        const result = await sendFcmMessage(
          accessToken,
          serviceAccount.project_id,
          token,
          title,
          body,
          { type: 'weekly_digest' },
        );
        if (result.ok) sent++;
        if (result.shouldDeleteToken) staleTokens.push(token);
      }
    }

    if (staleTokens.length > 0) {
      await adminClient.from('device_tokens').delete().in('token', staleTokens);
    }

    return new Response(JSON.stringify({ success: true, sent }), {
      headers: { 'Content-Type': 'application/json' },
    });
  } catch (error) {
    console.error('notify-weekly-digest failed', error);
    return new Response(
      JSON.stringify({ error: error instanceof Error ? error.message : String(error) }),
      { status: 500, headers: { 'Content-Type': 'application/json' } },
    );
  }
});
