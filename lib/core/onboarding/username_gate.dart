import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../supabase/supabase_client.dart';

/// ログイン中ユーザーのプロフィールにユーザーID（username）が設定されているかを監視し、
/// 一度も正規のユーザーID入力画面（オンボーディング）を経て設定したことがない
/// （＝usernameが未設定の）場合にのみ、起動時にその画面への強制リダイレクトが
/// 必要かどうかをrouterに伝える。一度設定済みのユーザーは以降強制されない。
class UsernameGateController extends ChangeNotifier {
  UsernameGateController() {
    _refresh();
    _authSub = supabase.auth.onAuthStateChange.listen((_) => _refresh());
  }

  /// null=判定中（まだ問い合わせ中）、true=ユーザーID入力画面への誘導が必要、
  /// false=不要。
  bool? needsOnboarding;

  StreamSubscription<dynamic>? _authSub;

  Future<void> _refresh() async {
    final user = supabase.auth.currentUser;
    if (user == null) {
      needsOnboarding = false;
      notifyListeners();
      return;
    }
    final row = await supabase
        .from('profiles')
        .select('username')
        .eq('id', user.id)
        .maybeSingle();
    final username = row?['username'] as String?;
    needsOnboarding = username == null || username.isEmpty;
    notifyListeners();
  }

  /// ユーザーID入力画面で保存に成功した際に呼び、以降のリダイレクトを止める。
  void markCompleted() {
    needsOnboarding = false;
    notifyListeners();
  }

  @override
  void dispose() {
    _authSub?.cancel();
    super.dispose();
  }
}

final usernameGateProvider = Provider<UsernameGateController>((ref) {
  final controller = UsernameGateController();
  ref.onDispose(controller.dispose);
  return controller;
});
