/// アプリの環境変数。
///
/// `--dart-define-from-file=env/dev.json` で起動時に注入する。
/// 値は env/dev.json（gitignore対象）で管理し、リポジトリには含めない。
class Env {
  static const supabaseUrl = String.fromEnvironment('SUPABASE_URL');
  static const supabaseAnonKey = String.fromEnvironment('SUPABASE_ANON_KEY');

  static void assertConfigured() {
    if (supabaseUrl.isEmpty || supabaseAnonKey.isEmpty) {
      throw StateError(
        'SUPABASE_URL / SUPABASE_ANON_KEY が設定されていません。\n'
        'env/dev.json を用意し、--dart-define-from-file=env/dev.json を付けて起動してください。',
      );
    }
  }
}
