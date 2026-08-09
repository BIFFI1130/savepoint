import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../data/auth_repository.dart';

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepository();
});

/// Supabase の認証状態変化を流す Stream。ログイン/ログアウトに応じて画面遷移を制御するために使う。
final authStateChangesProvider = StreamProvider<AuthState>((ref) {
  return ref.watch(authRepositoryProvider).onAuthStateChange;
});

/// 現在ログイン中のユーザー（未ログインなら null）。
final currentUserProvider = Provider<User?>((ref) {
  final authState = ref.watch(authStateChangesProvider);
  return authState.valueOrNull?.session?.user ??
      ref.watch(authRepositoryProvider).currentUser;
});
