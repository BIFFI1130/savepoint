import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:share_plus/share_plus.dart';

import '../../../../core/config/app_links.dart';

/// プロフィール共有用のQRコード・招待リンクを表示するボトムシート。
/// リンクはhttpsの中継ページ（docs/u/）で、アプリ導入済みなら「アプリで開く」から
/// `savepoint://user/{userId}`経由で該当プロフィールへ遷移し（[DeepLinkService]・
/// app.dartの`_handleDeepLink`で処理）、未導入ならストアへ誘導する。カスタムスキームを
/// 直接共有すると、LINE/Xなどでリンク化されず、未導入の相手には何も起きない。
class ProfileShareSheet extends StatelessWidget {
  const ProfileShareSheet({
    super.key,
    required this.userId,
    required this.displayLabel,
  });

  final String userId;
  final String displayLabel;

  String get _link => AppLinks.profileUrl(userId);

  static Future<void> show(
    BuildContext context, {
    required String userId,
    required String displayLabel,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) =>
          ProfileShareSheet(userId: userId, displayLabel: displayLabel),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'プロフィールを共有',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 4),
            Text(
              'このQRコード・リンクを知っている人は、あなたのプロフィールに'
              '直接アクセスしてフォローできます',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.outline,
                  ),
            ),
            const SizedBox(height: 24),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
              ),
              child: QrImageView(
                data: _link,
                size: 200,
                backgroundColor: Colors.white,
              ),
            ),
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      _link,
                      style: Theme.of(context).textTheme.bodyMedium,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.copy_outlined),
                    tooltip: 'リンクをコピー',
                    onPressed: () async {
                      await Clipboard.setData(ClipboardData(text: _link));
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('リンクをコピーしました')),
                        );
                      }
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: () {
                SharePlus.instance.share(
                  ShareParams(
                    text:
                        '$displayLabelさんをSavePointでフォローしよう\n$_link\n${AppLinks.shareHashtag}',
                  ),
                );
              },
              icon: const Icon(Icons.ios_share),
              label: const Text('共有する'),
            ),
          ],
        ),
      ),
    );
  }
}
