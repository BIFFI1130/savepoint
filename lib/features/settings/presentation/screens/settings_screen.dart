import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/analytics/analytics_service.dart';
import '../../../../core/notifications/aged_backlog_reminder_service.dart';
import '../../../../core/notifications/backlog_reminder_service.dart';
import '../../../../core/notifications/memories_reminder_service.dart';
import '../../../../core/notifications/monthly_recap_reminder_service.dart';
import '../../../../core/notifications/push_notification_service.dart';
import '../../../../core/notifications/streak_reminder_service.dart';
import '../../../../core/subscription/subscription_providers.dart';
import '../../../../core/theme/theme_mode_service.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../../game_log/presentation/providers/log_providers.dart';
import '../../../social/presentation/providers/social_providers.dart';

/// 通知・プレミアム・アプリについて・アカウントの設定画面。
/// 元々はプロフィール画面に同居していたが、プロフィール編集（表示名・公開範囲・
/// ゲーム歴・好きなジャンル・推しゲー）とは性質が異なるため、マイログ画面から
/// 独立した設定画面として切り出した。
class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  bool _isDeletingAccount = false;

  static const _privacyPolicyUrl =
      'https://biffi1130.github.io/savepoint/privacy-policy.html';
  static const _termsOfServiceUrl =
      'https://biffi1130.github.io/savepoint/terms-of-service.html';

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

  Future<void> _toggleBacklogReminder(bool value) async {
    final service = ref.read(backlogReminderServiceProvider);
    if (value) {
      final granted = await service.enable();
      if (!granted && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('通知の許可が必要です。端末の設定から許可してください')),
        );
      }
    } else {
      await service.disable();
    }
    await ref.read(appAnalyticsProvider).logBacklogReminderToggled(value);
    ref.invalidate(backlogReminderEnabledProvider);
  }

  Future<void> _toggleStreakReminder(bool value) async {
    final service = ref.read(streakReminderServiceProvider);
    if (value) {
      final granted = await service.enable();
      if (!granted && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('通知の許可が必要です。端末の設定から許可してください')),
        );
      } else {
        final logs = ref.read(myLogsProvider).valueOrNull;
        if (logs != null) await service.syncSchedule(logs);
      }
    } else {
      await service.disable();
    }
    ref.invalidate(streakReminderEnabledProvider);
  }

  Future<void> _toggleAgedBacklogReminder(bool value) async {
    final service = ref.read(agedBacklogReminderServiceProvider);
    if (value) {
      final granted = await service.enable();
      if (!granted && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('通知の許可が必要です。端末の設定から許可してください')),
        );
      } else {
        final logs = ref.read(myLogsProvider).valueOrNull;
        if (logs != null) await service.syncSchedule(logs);
      }
    } else {
      await service.disable();
    }
    ref.invalidate(agedBacklogReminderEnabledProvider);
  }

  Future<void> _toggleMonthlyRecap(bool value) async {
    final service = ref.read(monthlyRecapReminderServiceProvider);
    if (value) {
      final granted = await service.enable();
      if (!granted && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('通知の許可が必要です。端末の設定から許可してください')),
        );
      }
    } else {
      await service.disable();
    }
    ref.invalidate(monthlyRecapEnabledProvider);
  }

  Future<void> _toggleMemoriesReminder(bool value) async {
    final service = ref.read(memoriesReminderServiceProvider);
    if (value) {
      final granted = await service.enable();
      if (!granted && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('通知の許可が必要です。端末の設定から許可してください')),
        );
      } else {
        final logs = ref.read(myLogsProvider).valueOrNull;
        if (logs != null) await service.syncSchedule(logs);
      }
    } else {
      await service.disable();
    }
    ref.invalidate(memoriesReminderEnabledProvider);
  }

  Future<void> _toggleFollowPush(bool value) async {
    final service = ref.read(pushNotificationServiceProvider);
    if (value) {
      final granted = await service.enable();
      if (!granted && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('通知の許可が必要です。端末の設定から許可してください')),
        );
      }
    } else {
      await service.disable();
    }
    ref.invalidate(followPushEnabledProvider);
  }

  Future<void> _toggleNotifyFollowingReviews(bool value) async {
    await ref.read(socialRepositoryProvider).setNotifyFollowingReviews(value);
    ref.invalidate(myProfileProvider);
  }

  Future<void> _toggleNotifyNewFollower(bool value) async {
    await ref.read(socialRepositoryProvider).setNotifyNewFollower(value);
    ref.invalidate(myProfileProvider);
  }

  Future<void> _toggleNotifyWeeklyDigest(bool value) async {
    await ref.read(socialRepositoryProvider).setNotifyWeeklyDigest(value);
    ref.invalidate(myProfileProvider);
  }

  Future<void> _confirmSignOut() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('ログアウトしますか？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('キャンセル'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('ログアウト'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await ref.read(authRepositoryProvider).signOut();
  }

  /// アカウント削除の入口。取り消せない操作のため、まず影響範囲を説明する確認
  /// ダイアログを出し、同意した場合のみ確認文字列の入力を要求する2段階の
  /// ダイアログ（[_DeleteAccountConfirmDialog]）に進む。
  Future<void> _confirmDeleteAccount() async {
    final agreed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('アカウントを削除しますか？'),
        content: const Text(
          '記録・評価・レビュー・コレクション・お気に入り（推しゲー）・'
          'フォロー関係・プロフィール画像など、あなたに関する全てのデータが'
          '完全に削除されます。\n\nこの操作は取り消せません。',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('キャンセル'),
          ),
          TextButton(
            style: TextButton.styleFrom(
              foregroundColor: Theme.of(context).colorScheme.error,
            ),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('次へ'),
          ),
        ],
      ),
    );
    if (agreed != true || !mounted) return;

    final finalConfirmed = await showDialog<bool>(
      context: context,
      builder: (context) => const _DeleteAccountConfirmDialog(),
    );
    if (finalConfirmed != true || !mounted) return;

    setState(() => _isDeletingAccount = true);
    try {
      await ref.read(authRepositoryProvider).deleteAccount();
      // 削除に成功するとサインアウトも完了し、ルーターのredirectで自動的に
      // サインイン画面に遷移する。ここでは何もしなくてよい。
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('アカウントの削除に失敗しました: $e')));
      }
    } finally {
      if (mounted) setState(() => _isDeletingAccount = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('設定')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text('表示', style: Theme.of(context).textTheme.titleMedium),
          Consumer(
            builder: (context, ref, _) {
              final themeMode = ref.watch(themeModeProvider);
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: SegmentedButton<ThemeMode>(
                  segments: const [
                    ButtonSegment(
                      value: ThemeMode.system,
                      label: Text('端末に合わせる'),
                    ),
                    ButtonSegment(value: ThemeMode.light, label: Text('ライト')),
                    ButtonSegment(value: ThemeMode.dark, label: Text('ダーク')),
                  ],
                  selected: {themeMode},
                  onSelectionChanged: (selection) => ref
                      .read(themeModeProvider.notifier)
                      .setThemeMode(selection.first),
                ),
              );
            },
          ),
          const SizedBox(height: 16),
          const Divider(),
          const SizedBox(height: 8),
          Text('通知', style: Theme.of(context).textTheme.titleMedium),
          Consumer(
            builder: (context, ref, _) {
              final enabledAsync = ref.watch(backlogReminderEnabledProvider);
              return SwitchListTile(
                value: enabledAsync.value ?? false,
                onChanged: enabledAsync.isLoading ? null : _toggleBacklogReminder,
                contentPadding: EdgeInsets.zero,
                title: const Text('積みゲーリマインダー'),
                subtitle: const Text('「遊びたい」の消化を週1回通知でお知らせします'),
              );
            },
          ),
          Consumer(
            builder: (context, ref, _) {
              final enabledAsync = ref.watch(streakReminderEnabledProvider);
              return SwitchListTile(
                value: enabledAsync.value ?? false,
                onChanged: enabledAsync.isLoading ? null : _toggleStreakReminder,
                contentPadding: EdgeInsets.zero,
                title: const Text('記録ストリークリマインダー'),
                subtitle: const Text('週間記録ストリークが途切れそうな時にお知らせします'),
              );
            },
          ),
          Consumer(
            builder: (context, ref, _) {
              final enabledAsync = ref.watch(agedBacklogReminderEnabledProvider);
              return SwitchListTile(
                value: enabledAsync.value ?? false,
                onChanged:
                    enabledAsync.isLoading ? null : _toggleAgedBacklogReminder,
                contentPadding: EdgeInsets.zero,
                title: const Text('積みゲー経年アラート'),
                subtitle: const Text('長期間手つかずの「遊びたい」作品をお知らせします'),
              );
            },
          ),
          Consumer(
            builder: (context, ref, _) {
              final enabledAsync = ref.watch(monthlyRecapEnabledProvider);
              return SwitchListTile(
                value: enabledAsync.value ?? false,
                onChanged: enabledAsync.isLoading ? null : _toggleMonthlyRecap,
                contentPadding: EdgeInsets.zero,
                title: const Text('月末のふりかえり通知'),
                subtitle: const Text('月末に今月の記録の振り返りをお知らせします'),
              );
            },
          ),
          Consumer(
            builder: (context, ref, _) {
              final enabledAsync = ref.watch(memoriesReminderEnabledProvider);
              return SwitchListTile(
                value: enabledAsync.value ?? false,
                onChanged:
                    enabledAsync.isLoading ? null : _toggleMemoriesReminder,
                contentPadding: EdgeInsets.zero,
                title: const Text('1年前の今日'),
                subtitle: const Text('過去の同じ日に記録した作品があればお知らせします'),
              );
            },
          ),
          Consumer(
            builder: (context, ref, _) {
              final enabledAsync = ref.watch(followPushEnabledProvider);
              return SwitchListTile(
                value: enabledAsync.value ?? false,
                onChanged: enabledAsync.isLoading ? null : _toggleFollowPush,
                contentPadding: EdgeInsets.zero,
                title: const Text('プッシュ通知を有効にする'),
                subtitle: const Text('端末への通知の受信自体を許可します（種別ごとの設定は下記）'),
              );
            },
          ),
          Consumer(
            builder: (context, ref, _) {
              final profileAsync = ref.watch(myProfileProvider);
              return SwitchListTile(
                value: profileAsync.value?.notifyNewFollower ?? true,
                onChanged:
                    profileAsync.isLoading ? null : _toggleNotifyNewFollower,
                contentPadding: EdgeInsets.zero,
                title: const Text('新しいフォロワーの通知'),
                subtitle: const Text('誰かに新しくフォローされたときにお知らせします'),
              );
            },
          ),
          Consumer(
            builder: (context, ref, _) {
              final profileAsync = ref.watch(myProfileProvider);
              return SwitchListTile(
                value: profileAsync.value?.notifyFollowingReviews ?? true,
                onChanged: profileAsync.isLoading
                    ? null
                    : _toggleNotifyFollowingReviews,
                contentPadding: EdgeInsets.zero,
                title: const Text('フォロー中ユーザーの新着レビュー通知'),
                subtitle: const Text('フォロー中のユーザーがレビューを投稿したときにお知らせします'),
              );
            },
          ),
          Consumer(
            builder: (context, ref, _) {
              final profileAsync = ref.watch(myProfileProvider);
              return SwitchListTile(
                value: profileAsync.value?.notifyWeeklyDigest ?? true,
                onChanged:
                    profileAsync.isLoading ? null : _toggleNotifyWeeklyDigest,
                contentPadding: EdgeInsets.zero,
                title: const Text('フォロー中ユーザーの週間ダイジェスト'),
                subtitle: const Text('週1回、フォロー中のユーザーの新着記録をまとめてお知らせします'),
              );
            },
          ),
          const SizedBox(height: 16),
          const Divider(),
          const SizedBox(height: 8),
          Text('プレミアム', style: Theme.of(context).textTheme.titleMedium),
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
          const SizedBox(height: 16),
          const Divider(),
          const SizedBox(height: 8),
          Text('アプリについて', style: Theme.of(context).textTheme.titleMedium),
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
          const SizedBox(height: 16),
          const Divider(),
          const SizedBox(height: 8),
          Text('アカウント', style: Theme.of(context).textTheme.titleMedium),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.logout),
            title: const Text('ログアウト'),
            onTap: _confirmSignOut,
          ),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: Icon(
              Icons.delete_forever_outlined,
              color: Theme.of(context).colorScheme.error,
            ),
            title: Text(
              'アカウントを削除',
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
            subtitle: const Text('記録・レビューなど全てのデータが完全に削除されます'),
            trailing: _isDeletingAccount
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : null,
            onTap: _isDeletingAccount ? null : _confirmDeleteAccount,
          ),
        ],
      ),
    );
  }
}

/// アカウント削除の最終確認ダイアログ。「削除」と入力しないとボタンが有効化されない
/// ようにすることで、誤タップによる意図しない削除を防ぐ。
class _DeleteAccountConfirmDialog extends StatefulWidget {
  const _DeleteAccountConfirmDialog();

  @override
  State<_DeleteAccountConfirmDialog> createState() =>
      _DeleteAccountConfirmDialogState();
}

class _DeleteAccountConfirmDialogState
    extends State<_DeleteAccountConfirmDialog> {
  static const _confirmWord = '削除';
  final _controller = TextEditingController();
  bool _canDelete = false;

  @override
  void initState() {
    super.initState();
    _controller.addListener(() {
      final canDelete = _controller.text.trim() == _confirmWord;
      if (canDelete != _canDelete) setState(() => _canDelete = canDelete);
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('最終確認'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('本当に削除する場合は、下の欄に「$_confirmWord」と入力してください。'),
          const SizedBox(height: 12),
          TextField(
            controller: _controller,
            autofocus: true,
            decoration: const InputDecoration(
              labelText: _confirmWord,
              border: OutlineInputBorder(),
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('キャンセル'),
        ),
        FilledButton(
          style: FilledButton.styleFrom(
            backgroundColor: Theme.of(context).colorScheme.error,
            foregroundColor: Theme.of(context).colorScheme.onError,
          ),
          onPressed: _canDelete ? () => Navigator.pop(context, true) : null,
          child: const Text('完全に削除する'),
        ),
      ],
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
