import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/supabase/supabase_client.dart';

class AuthRepository {
  GoTrueClient get _auth => supabase.auth;

  Stream<AuthState> get onAuthStateChange => _auth.onAuthStateChange;

  User? get currentUser => _auth.currentUser;

  Future<void> signUpWithEmail({
    required String email,
    required String password,
  }) async {
    await _auth.signUp(email: email, password: password);
  }

  Future<void> signInWithEmail({
    required String email,
    required String password,
  }) async {
    await _auth.signInWithPassword(email: email, password: password);
  }

  /// パスワード再設定メールを送信する。メール内のリンクはディープリンク
  /// （`savepoint://reset-password`）でアプリに戻り、[updatePassword]で
  /// 新しいパスワードを設定する画面に遷移する。
  Future<void> resetPasswordForEmail(String email) async {
    await _auth.resetPasswordForEmail(email, redirectTo: _resetPasswordUrl);
  }

  /// パスワード再設定リンク経由で確立されたセッションを使って、新しいパスワードを設定する。
  Future<void> updatePassword(String newPassword) async {
    await _auth.updateUser(UserAttributes(password: newPassword));
  }

  static const _resetPasswordUrl = 'savepoint://reset-password';

  /// Apple のネイティブサインインシートを表示し、取得した ID トークンで Supabase にサインインする。
  Future<void> signInWithApple() async {
    final rawNonce = _generateRawNonce();
    final hashedNonce = sha256.convert(utf8.encode(rawNonce)).toString();

    final credential = await SignInWithApple.getAppleIDCredential(
      scopes: [
        AppleIDAuthorizationScopes.email,
        AppleIDAuthorizationScopes.fullName,
      ],
      nonce: hashedNonce,
    );

    final idToken = credential.identityToken;
    if (idToken == null) {
      throw const AuthException('Appleからのサインインに失敗しました（IDトークンが取得できません）。');
    }

    await _auth.signInWithIdToken(
      provider: OAuthProvider.apple,
      idToken: idToken,
      nonce: rawNonce,
    );
  }

  Future<void> signOut() async {
    await _auth.signOut();
  }

  /// ログイン中の自分のアカウントを完全に削除する（Edge Function `delete-account`
  /// 経由）。プロフィール・記録・コレクション・お気に入り・フォロー関係・アバター画像など
  /// 本人に紐づく全データがサーバー側で連鎖削除される。取り消しはできない。
  /// 削除に成功したら、ローカルのセッションも破棄してサインイン画面に戻す。
  Future<void> deleteAccount() async {
    final response = await supabase.functions.invoke('delete-account');
    final data = response.data;
    if (data is Map && data['error'] != null) {
      throw AuthException(data['error'].toString());
    }
    await signOut();
  }

  String _generateRawNonce([int length = 32]) {
    const charset =
        '0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz-._~';
    final random = Random.secure();
    return List.generate(
      length,
      (_) => charset[random.nextInt(charset.length)],
    ).join();
  }
}
