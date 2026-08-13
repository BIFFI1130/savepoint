import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../supabase/supabase_client.dart';

/// ログイン中ユーザーのプロフィールに生年月（birth_year/birth_month）が設定されて
/// いるかを監視し、未設定の場合に起動時の生年月入力画面への強制リダイレクトが
/// 必要かどうかをrouterに伝える。[UsernameGateController]と同じ設計。
class BirthdateGateController extends ChangeNotifier {
  BirthdateGateController() {
    _refresh();
    _authSub = supabase.auth.onAuthStateChange.listen((_) => _refresh());
  }

  /// null=判定中（まだ問い合わせ中）、true=生年月入力画面への誘導が必要、false=不要。
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
        .select('birth_year, birth_month')
        .eq('id', user.id)
        .maybeSingle();
    final birthYear = row?['birth_year'] as int?;
    final birthMonth = row?['birth_month'] as int?;
    needsOnboarding = birthYear == null || birthMonth == null;
    notifyListeners();
  }

  /// 生年月入力画面で保存に成功した際に呼び、以降のリダイレクトを止める。
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

final birthdateGateProvider = Provider<BirthdateGateController>((ref) {
  final controller = BirthdateGateController();
  ref.onDispose(controller.dispose);
  return controller;
});
