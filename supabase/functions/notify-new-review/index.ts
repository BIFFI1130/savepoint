// notify-new-review
//
// フォロー中のユーザーが新しくレビュー（評価・レビュー本文）を投稿したとき、
// そのフォロワー全員（「フォロー中ユーザーの新着レビュー通知」を有効にしている人のみ）へ
// FCM経由でプッシュ通知する Edge Function。
//
// 呼び出し元（Flutter）は、「遊んだ」記録の保存が成功し、かつそれが新規レビュー
// （それまで評価・レビュー本文が無かった記録に、今回はじめて付いた）だった直後に
// このFunctionを呼ぶ（supabase.functions.invoke('notify-new-review', body: {...})）。
// 呼び出し元のJWTから本人（レビューを書いた側）のuser_idを検証するため、
// 他人になりすまして通知を送らせることはできない。ベストエフォートの副作用の
// ため、送信失敗が記録の保存自体を失敗させることはない（呼び出し側で結果を待たない想定）。
//
// リクエストボディ:
//   { game_id: number }  -- レビューを投稿したゲームのID
//
// 必要なSecrets: notify-new-followerと共通（FCM_SERVICE_ACCOUNT_JSON等）。

import { createClient } from 'jsr:@supabase/supabase-js@2';

interface NotifyRequest {
  game_id: number;
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
  if (!body.game_id) {
    return new Response(JSON.stringify({ error: 'パラメータが不足しています' }), {
      status: 400,
      headers: { 'Content-Type': 'application/json' },
    });
  }

  try {
    // 呼び出し元のJWTでユーザーを検証する（レビューを書いた本人）。
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

    const followsResult = await adminClient
      .from('follows')
      .select('follower_id')
      .eq('followee_id', user.id);
    if (followsResult.error) throw new Error(followsResult.error.message);

    const followerIds = (followsResult.data ?? [])
      .map((row) => row.follower_id as string)
      .filter((id) => id !== user.id);
    if (followerIds.length === 0) {
      return new Response(JSON.stringify({ success: true, sent: 0 }), {
        headers: { 'Content-Type': 'application/json' },
      });
    }

    const [optedInResult, gameResult, authorResult] = await Promise.all([
      adminClient
        .from('profiles')
        .select('id')
        .in('id', followerIds)
        .eq('notify_following_reviews', true),
      adminClient
        .from('games')
        .select('name, name_ja')
        .eq('id', body.game_id)
        .maybeSingle(),
      adminClient.from('profiles').select('display_name').eq('id', user.id).maybeSingle(),
    ]);
    if (optedInResult.error) throw new Error(optedInResult.error.message);

    const optedInIds = (optedInResult.data ?? []).map((row) => row.id as string);
    if (optedInIds.length === 0) {
      return new Response(JSON.stringify({ success: true, sent: 0 }), {
        headers: { 'Content-Type': 'application/json' },
      });
    }

    const tokensResult = await adminClient
      .from('device_tokens')
      .select('token')
      .in('user_id', optedInIds);
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

    const authorName = authorResult.data?.display_name?.trim() || '名前未設定';
    const gameName =
      gameResult.data?.name_ja?.trim() || gameResult.data?.name?.trim() || 'ゲーム';
    const title = '新着レビュー';
    const messageBody = `${authorName}さんが「${gameName}」のレビューを投稿しました`;

    let sent = 0;
    const staleTokens: string[] = [];
    for (const row of tokens) {
      const result = await sendFcmMessage(
        accessToken,
        serviceAccount.project_id,
        row.token,
        title,
        messageBody,
        { type: 'new_review', game_id: String(body.game_id) },
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
    console.error('notify-new-review failed', error);
    return new Response(
      JSON.stringify({ error: error instanceof Error ? error.message : String(error) }),
      { status: 500, headers: { 'Content-Type': 'application/json' } },
    );
  }
});
