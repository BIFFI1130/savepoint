import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/subscription/subscription_providers.dart';
import '../../../social/presentation/providers/social_providers.dart';

/// 設定 → プレミアム。契約状況の確認・購入画面への導線・閲覧数の分析。
class SettingsPremiumScreen extends StatelessWidget {
  const SettingsPremiumScreen({super.key});

  Future<void> _openUrl(String url) async {
    final uri = Uri.tryParse(url);
    if (uri == null) return;
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  /// ストア（App Store/Play）のサブスクリプション管理画面を開く。
  Future<void> _openManagementUrl(WidgetRef ref) async {
    final url = ref.read(customerInfoProvider).valueOrNull?.managementURL;
    if (url == null) return;
    await _openUrl(url);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('プレミアム')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Consumer(
            builder: (context, ref, _) {
              final isAdFree = ref.watch(isAdFreeProvider);
              if (isAdFree) {
                return ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.check_circle_outline),
                  title: const Text('ご契約中'),
                  subtitle: const Text('広告非表示・閲覧数の分析・ジャンル絞り込みなどが使えます。タップで契約内容を確認できます'),
                  onTap: () => _openManagementUrl(ref),
                );
              }
              return ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.workspace_premium_outlined),
                title: const Text('プレミアムプランについて見る'),
                subtitle: const Text('広告非表示・閲覧数の分析・ジャンル絞り込みなど'),
                onTap: () => context.push('/subscription/paywall'),
              );
            },
          ),
          Consumer(
            builder: (context, ref, _) {
              final isAdFree = ref.watch(isAdFreeProvider);
              if (!isAdFree) return const SizedBox.shrink();
              final profileViewsAsync = ref.watch(myProfileViewCountProvider);
              final reviewViewsAsync = ref.watch(myReviewViewCountProvider);
              return Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Row(
                  children: [
                    Expanded(
                      child: _ViewCountCard(
                        icon: Icons.person_search_outlined,
                        label: 'プロフィール閲覧数',
                        count: profileViewsAsync.value,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _ViewCountCard(
                        icon: Icons.visibility_outlined,
                        label: 'レビュー閲覧数',
                        count: reviewViewsAsync.value,
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

/// サブスク特典「閲覧数の分析」の1件分のカード。
class _ViewCountCard extends StatelessWidget {
  const _ViewCountCard({
    required this.icon,
    required this.label,
    required this.count,
  });

  final IconData icon;
  final String label;
  final int? count;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: Theme.of(context).colorScheme.primary),
            const SizedBox(height: 4),
            Text(
              count?.toString() ?? '—',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            Text(label, style: Theme.of(context).textTheme.labelSmall),
          ],
        ),
      ),
    );
  }
}
