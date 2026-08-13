import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/update/update_gate.dart';

/// TestFlight／Firebase App Distributionで配布された古いビルドを起動した際に
/// 必ず表示する強制アップデート画面。システムのバックボタンでは閉じられない。
class UpdateRequiredScreen extends ConsumerWidget {
  const UpdateRequiredScreen({super.key});

  Future<void> _openUpdateLink(BuildContext context, WidgetRef ref) async {
    final url = ref.read(updateGateProvider).updateUrl;
    // iOSはTestFlightアプリを直接開く（`itms-beta://`）。update_urlが未取得の場合の
    // フォールバックとしても使う。Androidはservice roleがapp_versionsに保存した
    // Firebase App Distributionのテスター向けリンクを開く。
    final target = url ?? (Platform.isIOS ? 'itms-beta://' : null);
    if (target == null) return;
    final uri = Uri.parse(target);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else if (context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('リンクを開けませんでした')));
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return PopScope(
      canPop: false,
      child: Scaffold(
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.system_update,
                  size: 64,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(height: 24),
                Text(
                  'アップデートが必要です',
                  style: Theme.of(context).textTheme.titleLarge,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                const Text(
                  'このバージョンのSavePointはご利用いただけません。'
                  '最新版にアップデートしてください。',
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                FilledButton(
                  onPressed: () => _openUpdateLink(context, ref),
                  child: Text(
                    Platform.isIOS ? 'TestFlightを開く' : 'ダウンロードページを開く',
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
