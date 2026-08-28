import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

const _secureStorage = FlutterSecureStorage(
  aOptions: AndroidOptions(encryptedSharedPreferences: true),
);

/// Supabaseのセッション（アクセストークン・リフレッシュトークンを含む）を、平文の
/// SharedPreferences/NSUserDefaultsではなくKeychain（iOS）/Android Keystore連携の
/// 暗号化ストレージに保存する[LocalStorage]実装。端末そのものが侵害された場合の
/// セッション窃取リスクを下げる。
class SecureLocalStorage extends LocalStorage {
  const SecureLocalStorage();

  static const _key = 'supabase.session';

  @override
  Future<void> initialize() async {}

  @override
  Future<bool> hasAccessToken() async =>
      await _secureStorage.containsKey(key: _key);

  @override
  Future<String?> accessToken() => _secureStorage.read(key: _key);

  @override
  Future<void> removePersistedSession() => _secureStorage.delete(key: _key);

  @override
  Future<void> persistSession(String persistSessionString) =>
      _secureStorage.write(key: _key, value: persistSessionString);
}

/// PKCEフロー（パスワードリセット・OAuth）のcode_verifierを保存する
/// [GotrueAsyncStorage]実装。同じ理由でKeychain/Android Keystoreへ保存する。
class SecureGotrueAsyncStorage extends GotrueAsyncStorage {
  @override
  Future<String?> getItem({required String key}) =>
      _secureStorage.read(key: key);

  @override
  Future<void> removeItem({required String key}) =>
      _secureStorage.delete(key: key);

  @override
  Future<void> setItem({required String key, required String value}) =>
      _secureStorage.write(key: key, value: value);
}
