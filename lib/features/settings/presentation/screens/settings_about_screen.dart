import 'dart:io';

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/config/app_links.dart';

/// 設定 → アプリについて。レビュー投稿・プライバシーポリシー・利用規約へのリンク。
class SettingsAboutScreen extends StatelessWidget {
  const SettingsAboutScreen({super.key});

  static const _privacyPolicyUrl =
      'https://biffi1130.github.io/savepoint/privacy-policy.html';
  static const _termsOfServiceUrl =
      'https://biffi1130.github.io/savepoint/terms-of-service.html';
  static const _contactEmail = 'savepoint.record.game@gmail.com';

  Future<void> _openUrl(String url) async {
    final uri = Uri.tryParse(url);
    if (uri == null) return;
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('アプリについて')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Android版はまだ製品版のストアページが無いため、公開後に追加する。
          if (Platform.isIOS)
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.star_outline),
              title: const Text('SavePointを評価する'),
              subtitle: const Text('App Storeでレビューを書く'),
              onTap: () => _openUrl(AppLinks.appStoreWriteReviewUrl),
            ),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.privacy_tip_outlined),
            title: const Text('プライバシーポリシー'),
            onTap: () => _openUrl(_privacyPolicyUrl),
          ),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.description_outlined),
            title: const Text('利用規約'),
            onTap: () => _openUrl(_termsOfServiceUrl),
          ),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.mail_outline),
            title: const Text('お問い合わせ・不適切なコンテンツの報告'),
            subtitle: const Text(_contactEmail),
            onTap: () => _openUrl('mailto:$_contactEmail'),
          ),
        ],
      ),
    );
  }
}
