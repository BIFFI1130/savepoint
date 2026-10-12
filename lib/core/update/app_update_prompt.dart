import 'dart:io';

import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import 'app_update_notice.dart';

/// 新しいバージョンが公開されていれば、更新を促すダイアログを出す（押し付けない任意更新）。
/// 現在はiOSのみ（Android版は製品版の公開後に対応する）。
Future<void> showAppUpdateNoticeIfNeeded(BuildContext context) async {
  if (!Platform.isIOS) return;
  final info = await PackageInfo.fromPlatform();
  final notice = AppUpdateNotice(currentVersion: info.version);
  final latest = await notice.versionToAnnounce();
  if (latest == null || !context.mounted) return;

  final notes = latest.releaseNotes?.trim();
  final shouldUpdate = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('新しいバージョンがあります'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('SavePoint ${latest.version} が公開されました。'),
            if (notes != null && notes.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text(notes, style: Theme.of(context).textTheme.bodySmall),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('あとで'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, true),
          child: const Text('アップデート'),
        ),
      ],
    ),
  );

  await notice.dismiss(latest.version);
  if (shouldUpdate == true) {
    await launchUrl(
      Uri.parse(latest.storeUrl),
      mode: LaunchMode.externalApplication,
    );
  }
}
