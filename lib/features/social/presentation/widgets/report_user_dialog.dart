import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/report_reason.dart';
import '../providers/social_providers.dart';

/// ユーザー通報ダイアログを表示し、確定されれば通報を送信する。
/// プロフィール画面（本人を通報）・「みんなのレビュー」カード（匿名表示中でも
/// 投稿者のuser_idは保持されているため通報可能）の両方から使う。
Future<void> showReportUserDialog(
  BuildContext context,
  WidgetRef ref,
  String userId,
) async {
  var selectedReason = ReportReason.spam;
  final detailController = TextEditingController();
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (context) => StatefulBuilder(
      builder: (context, setState) => AlertDialog(
        title: const Text('ユーザーを通報'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (final reason in ReportReason.values)
                ListTile(
                  onTap: () => setState(() => selectedReason = reason),
                  leading: Icon(
                    reason == selectedReason
                        ? Icons.radio_button_checked
                        : Icons.radio_button_unchecked,
                  ),
                  title: Text(reason.label),
                  contentPadding: EdgeInsets.zero,
                ),
              const SizedBox(height: 8),
              TextField(
                controller: detailController,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: '詳細（任意）',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('キャンセル'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('通報する'),
          ),
        ],
      ),
    ),
  );
  if (confirmed != true) return;
  await ref
      .read(socialRepositoryProvider)
      .reportUser(
        reportedUserId: userId,
        reason: selectedReason,
        detail: detailController.text.trim(),
      );
  if (context.mounted) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('通報を受け付けました')));
  }
}
