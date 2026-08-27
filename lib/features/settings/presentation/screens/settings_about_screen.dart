import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

/// 設定 → アプリについて。プライバシーポリシー・利用規約へのリンク。
class SettingsAboutScreen extends StatelessWidget {
  const SettingsAboutScreen({super.key});

  static const _privacyPolicyUrl =
      'https://biffi1130.github.io/savepoint/privacy-policy.html';
  static const _termsOfServiceUrl =
      'https://biffi1130.github.io/savepoint/terms-of-service.html';

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
        ],
      ),
    );
  }
}
