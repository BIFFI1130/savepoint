import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:purchases_flutter/purchases_flutter.dart';

import '../../../../core/subscription/subscription_providers.dart';
import '../../../../core/subscription/subscription_service.dart';
import '../../../../core/widgets/async_state_views.dart';

/// 「広告を非表示にする」等の課金プランを提示し、購入・復元を行う画面。
/// RevenueCatのAPIキーが未設定の間（事前準備が未完了の間）は、クラッシュせず
/// 「準備中」の無効化状態を表示する。
class PaywallScreen extends ConsumerStatefulWidget {
  const PaywallScreen({super.key});

  @override
  ConsumerState<PaywallScreen> createState() => _PaywallScreenState();
}

class _PaywallScreenState extends ConsumerState<PaywallScreen> {
  bool _isProcessing = false;

  Future<void> _purchase(Package package) async {
    setState(() => _isProcessing = true);
    try {
      await Purchases.purchase(PurchaseParams.package(package));
      ref.invalidate(customerInfoProvider);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('購入が完了しました')));
      }
    } on PlatformException catch (e) {
      final isCancelled =
          PurchasesErrorHelper.getErrorCode(e) ==
          PurchasesErrorCode.purchaseCancelledError;
      if (!isCancelled && mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('購入に失敗しました')));
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('購入に失敗しました')));
      }
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  Future<void> _restore() async {
    setState(() => _isProcessing = true);
    try {
      await Purchases.restorePurchases();
      ref.invalidate(customerInfoProvider);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('購入情報を復元しました')));
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('復元に失敗しました')));
      }
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isAdFree = ref.watch(isAdFreeProvider);
    final offeringsAsync = ref.watch(offeringsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('プレミアムプラン')),
      body: !SubscriptionService.isConfigured
          ? const EmptyView(
              message: '準備中です。もうしばらくお待ちください。',
              icon: Icons.hourglass_empty,
            )
          : isAdFree
          ? const EmptyView(
              message: 'すでにご契約中です。\nプロフィール画面から契約内容を確認できます。',
              icon: Icons.check_circle_outline,
            )
          : offeringsAsync.when(
              data: (offerings) {
                final packages = offerings?.current?.availablePackages ?? [];
                if (packages.isEmpty) {
                  return const EmptyView(message: '現在購入可能なプランがありません');
                }
                return ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    const Text('購入すると、次の特典が使えるようになります。'),
                    const SizedBox(height: 12),
                    const ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: Icon(Icons.block),
                      title: Text('アプリ内の広告がすべて非表示になる'),
                      dense: true,
                    ),
                    const ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: Icon(Icons.rate_review_outlined),
                      title: Text('ゲームごとに「みんなのレビュー」が見られる'),
                      dense: true,
                    ),
                    const ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: Icon(Icons.category_outlined),
                      title: Text('「ジャンルから探す」で絞り込み検索ができる'),
                      dense: true,
                    ),
                    const SizedBox(height: 16),
                    for (final package in packages) ...[
                      Card(
                        child: ListTile(
                          title: Text(package.storeProduct.title),
                          subtitle: Text(package.storeProduct.description),
                          trailing: FilledButton(
                            onPressed: _isProcessing
                                ? null
                                : () => _purchase(package),
                            child: Text(package.storeProduct.priceString),
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                    ],
                    const SizedBox(height: 16),
                    Center(
                      child: TextButton(
                        onPressed: _isProcessing ? null : _restore,
                        child: const Text('購入を復元'),
                      ),
                    ),
                  ],
                );
              },
              loading: () => const LoadingView(),
              error: (error, _) => ErrorView(
                message: 'プランの取得に失敗しました',
                onRetry: () => ref.invalidate(offeringsProvider),
              ),
            ),
    );
  }
}
