import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:purchases_flutter/purchases_flutter.dart';

import '../config/env.dart';

/// RevenueCat SDKの薄いラッパー。APIキー未設定時は[configure]自体を行わず、
/// [isConfigured]をfalseのままにする。これにより課金機能全体が安全に無効化され
/// （エンタイトルメントは常に未保有扱い、ペイウォールは「準備中」表示になる）、
/// キー未設定のローカル開発・CIビルドでもクラッシュせず動き続ける。
class SubscriptionService {
  const SubscriptionService._();

  static bool _configured = false;
  static bool get isConfigured => _configured;

  static Future<void> configure() async {
    final apiKey =
        Platform.isIOS ? Env.revenueCatIosApiKey : Env.revenueCatAndroidApiKey;
    if (apiKey.isEmpty) return;

    try {
      await Purchases.configure(PurchasesConfiguration(apiKey));
      _configured = true;
    } catch (error, stackTrace) {
      debugPrint('SubscriptionService.configure failed: $error\n$stackTrace');
    }
  }

  /// ログイン中のSupabaseユーザーIDをRevenueCatの識別子に紐付ける。これにより
  /// 同じアカウントでの再インストール・機種変更でも購入権利が引き継がれる。
  static Future<void> logIn(String userId) async {
    if (!_configured) return;
    try {
      await Purchases.logIn(userId);
    } catch (error, stackTrace) {
      debugPrint('SubscriptionService.logIn failed: $error\n$stackTrace');
    }
  }

  /// サインアウト時にRevenueCat側の紐付けも解除する（匿名ユーザーに戻る）。
  static Future<void> logOut() async {
    if (!_configured) return;
    try {
      await Purchases.logOut();
    } catch (error, stackTrace) {
      debugPrint('SubscriptionService.logOut failed: $error\n$stackTrace');
    }
  }
}
