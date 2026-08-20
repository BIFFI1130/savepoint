import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:purchases_flutter/purchases_flutter.dart';

import 'entitlements.dart';
import 'subscription_service.dart';

/// RevenueCatの顧客情報（購入・エンタイトルメント状態）の変化を流すStream。
/// SDK未configure時は一度だけnullを流して終わる（＝問い合わせ自体ができないだけで、
/// 以降のエンタイトルメント判定は常にfalseになる）。
final customerInfoProvider = StreamProvider<CustomerInfo?>((ref) {
  if (!SubscriptionService.isConfigured) return Stream.value(null);

  final controller = StreamController<CustomerInfo?>();

  void listener(CustomerInfo info) => controller.add(info);
  Purchases.addCustomerInfoUpdateListener(listener);
  ref.onDispose(() {
    Purchases.removeCustomerInfoUpdateListener(listener);
    controller.close();
  });

  Purchases.getCustomerInfo().then(controller.add).catchError((_) {});

  return controller.stream;
});

/// 「広告を非表示にする」権利を保持しているかどうか。
final isAdFreeProvider = Provider<bool>((ref) {
  final customerInfo = ref.watch(customerInfoProvider).valueOrNull;
  return customerInfo?.entitlements.active.containsKey(Entitlements.adFree) ??
      false;
});

/// 購入可能なオファリング一覧。SDK未configure時はnull
/// （ペイウォール画面はこれをnullとして扱い「準備中」表示にする）。
final offeringsProvider = FutureProvider<Offerings?>((ref) async {
  if (!SubscriptionService.isConfigured) return null;
  return Purchases.getOfferings();
});
