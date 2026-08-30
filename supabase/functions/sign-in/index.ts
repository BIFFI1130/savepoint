// sign-in
//
// メールアドレスまたはユーザーID（username）とパスワードでのサインインを一本化する
// Edge Function。
//
// クライアント（Flutter）が直接 `auth.signInWithPassword` を呼ぶ場合、ユーザーIDから
// メールアドレスを解決する処理をクライアント側またはanonから呼べるRPCで行う必要が
// あり、その場合「このユーザーIDに紐づくメールアドレスはこれです」という応答が
// 攻撃者に返ってしまう（ユーザーIDは検索機能上すでに公開情報だが、メールアドレスとの
// 紐付けはより機微な情報でありフィッシング等の材料になり得る）。
// この関数はメールアドレスへの解決をサーバー側（service role）だけで完結させ、
// クライアントにはメールアドレスを一切返さない。
//
// パスワードそのものの検証はGoTrue本体のトークンエンドポイント
// （/auth/v1/token?grant_type=password）にそのまま委譲する。これにより、
// メール直接ログインと同じレート制限・ブルートフォース対策がユーザーIDログインにも
// 等しく適用される。
//
// 認証に成功したかどうかに関わらず、「ユーザーIDが存在しない」と「パスワードが違う」を
// 区別しない汎用エラーのみを返す（アカウント列挙対策）。
//
// 必要な環境変数はSupabaseが自動的に注入する:
//   SUPABASE_URL, SUPABASE_ANON_KEY, SUPABASE_SERVICE_ROLE_KEY

import { createClient } from 'jsr:@supabase/supabase-js@2';

Deno.serve(async (req) => {
  if (req.method !== 'POST') {
    return new Response('Method Not Allowed', { status: 405 });
  }

  try {
    const { identifier, password } = await req.json();
    if (
      typeof identifier !== 'string' || typeof password !== 'string' ||
      identifier.trim().length === 0 || password.length === 0
    ) {
      return jsonResponse({ error: 'invalid_request' }, 400);
    }

    const supabaseUrl = Deno.env.get('SUPABASE_URL')!;
    const anonKey = Deno.env.get('SUPABASE_ANON_KEY')!;

    let email = identifier.trim();

    if (!email.includes('@')) {
      const adminClient = createClient(
        supabaseUrl,
        Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!,
      );

      const { data: profile } = await adminClient
        .from('profiles')
        .select('id')
        .eq('username', email)
        .maybeSingle();
      if (!profile) {
        return jsonResponse({ error: 'invalid_credentials' }, 400);
      }

      const { data: userData, error: userError } = await adminClient.auth.admin
        .getUserById(profile.id);
      if (userError || !userData?.user?.email) {
        return jsonResponse({ error: 'invalid_credentials' }, 400);
      }
      email = userData.user.email;
    }

    const tokenResponse = await fetch(
      `${supabaseUrl}/auth/v1/token?grant_type=password`,
      {
        method: 'POST',
        headers: { 'Content-Type': 'application/json', apikey: anonKey },
        body: JSON.stringify({ email, password }),
      },
    );
    const tokenData = await tokenResponse.json();
    if (!tokenResponse.ok) {
      return jsonResponse({ error: 'invalid_credentials' }, 400);
    }

    return jsonResponse({
      access_token: tokenData.access_token,
      refresh_token: tokenData.refresh_token,
    });
  } catch (error) {
    console.error('sign-in failed', error);
    return jsonResponse({ error: 'invalid_credentials' }, 400);
  }
});

function jsonResponse(body: unknown, status = 200) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { 'Content-Type': 'application/json' },
  });
}
