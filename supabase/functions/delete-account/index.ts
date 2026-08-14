// delete-account
//
// ログイン中のユーザー自身のアカウントを完全に削除するEdge Function。
// Apple/GoogleのApp Store審査要件（アプリ内でのアカウント削除）に対応するためのもの。
//
// 使い方（Flutter側）:
//   supabase.functions.invoke('delete-account')
// 呼び出し元のAuthorizationヘッダー（ユーザー自身のJWT）から本人のuser_idを検証し、
// 他人のアカウントを削除できないようにする。
//
// 削除範囲:
//   - Supabase Storage "avatars" バケット配下の本人のアバター画像
//   - auth.users の当該行（service roleでadmin.deleteUserを実行）
//     → public.profiles.id が auth.users(id) を on delete cascade で参照しており、
//       game_logs/collections/collection_games/favorite_games/follows/blocks/reports
//       など本人に紐づく行はすべてこのcascadeで自動的に削除される
//       （各テーブルのFK制約は supabase/migrations 参照）。
//
// 必要な環境変数はSupabaseが自動的に注入する:
//   SUPABASE_URL, SUPABASE_ANON_KEY, SUPABASE_SERVICE_ROLE_KEY

import { createClient } from 'jsr:@supabase/supabase-js@2';

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

  try {
    // 呼び出し元のJWTでユーザーを検証する（anon keyのクライアントにヘッダーを
    // そのまま渡すことで、Supabase側がトークンの署名・有効期限を検証してくれる）。
    const callerClient = createClient(
      Deno.env.get('SUPABASE_URL')!,
      Deno.env.get('SUPABASE_ANON_KEY')!,
      { global: { headers: { Authorization: authHeader } } },
    );
    const { data: { user }, error: userError } = await callerClient.auth.getUser();
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

    // アバター画像の削除はベストエフォート（失敗してもアカウント削除自体は続行する。
    // 公開バケットの孤立ファイルが多少残っても、個人情報の完全消去という主目的には
    // 影響しないため）。
    try {
      const { data: files } = await adminClient.storage
        .from('avatars')
        .list(user.id);
      if (files && files.length > 0) {
        await adminClient.storage
          .from('avatars')
          .remove(files.map((f) => `${user.id}/${f.name}`));
      }
    } catch (storageError) {
      console.error('avatar cleanup failed', storageError);
    }

    // auth.users の削除。public.profiles以下、本人に紐づく全テーブルはFKの
    // on delete cascadeで連鎖削除される。
    const { error: deleteError } = await adminClient.auth.admin.deleteUser(user.id);
    if (deleteError) {
      throw new Error(`アカウント削除に失敗しました: ${deleteError.message}`);
    }

    return new Response(JSON.stringify({ success: true }), {
      headers: { 'Content-Type': 'application/json' },
    });
  } catch (error) {
    console.error('delete-account failed', error);
    return new Response(
      JSON.stringify({ error: error instanceof Error ? error.message : String(error) }),
      { status: 500, headers: { 'Content-Type': 'application/json' } },
    );
  }
});
