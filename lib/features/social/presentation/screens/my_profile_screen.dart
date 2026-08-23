import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/analytics/analytics_service.dart';
import '../../../../core/notifications/backlog_reminder_service.dart';
import '../../../../core/subscription/subscription_providers.dart';
import '../../../../core/widgets/async_state_views.dart';
import '../../../../core/widgets/avatar_image.dart';
import '../../../../core/widgets/genre_badge_selector.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../../favorites/presentation/providers/favorite_providers.dart';
import '../../../favorites/presentation/widgets/favorite_games_list.dart';
import '../../domain/social_profile.dart';
import '../providers/social_providers.dart';

/// 自分のプロフィール確認・編集ページ。プロフィール画像・表示名・公開設定・ゲーム歴・
/// 好きなジャンル・「オレの推しゲー」を確認・編集できる。ユーザーID（半角英数字、一意）は
/// 一度設定すると変更できないため、ここでは表示のみで編集はできない
/// （初回設定はアプリ起動時のユーザーID入力画面で行う）。
class MyProfileScreen extends ConsumerStatefulWidget {
  const MyProfileScreen({super.key});

  @override
  ConsumerState<MyProfileScreen> createState() => _MyProfileScreenState();
}

class _MyProfileScreenState extends ConsumerState<MyProfileScreen> {
  final _gameHistoryController = TextEditingController();
  bool _isPublic = false;
  Set<String> _favoriteGenres = {};
  bool _initialized = false;
  bool _isSaving = false;
  bool _isUploadingAvatar = false;
  bool _isDeletingAccount = false;

  @override
  void dispose() {
    _gameHistoryController.dispose();
    super.dispose();
  }

  Future<void> _pickAndUploadAvatar() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 1024,
      maxHeight: 1024,
      imageQuality: 85,
    );
    if (picked == null) return;

    setState(() => _isUploadingAvatar = true);
    try {
      final bytes = await File(picked.path).readAsBytes();
      final ext = picked.path.split('.').last.toLowerCase();
      await ref
          .read(socialRepositoryProvider)
          .uploadAvatar(bytes, fileExt: ext);
      ref.invalidate(myProfileProvider);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('プロフィール画像を更新しました')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('画像のアップロードに失敗しました: $e')));
      }
    } finally {
      if (mounted) setState(() => _isUploadingAvatar = false);
    }
  }

  Future<void> _editDisplayName(SocialProfile? profile) async {
    final result = await showDialog<String>(
      context: context,
      builder: (context) => _DisplayNameEditDialog(
        initialValue: profile?.displayName ?? '',
      ),
    );
    if (result == null) return;
    try {
      await ref.read(socialRepositoryProvider).updateDisplayName(result);
      ref.invalidate(myProfileProvider);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('保存に失敗しました: $e')));
      }
    }
  }

  void _toggleGenre(String value) {
    setState(() {
      _favoriteGenres = _favoriteGenres.contains(value)
          ? ({..._favoriteGenres}..remove(value))
          : ({..._favoriteGenres}..add(value));
    });
  }

  Future<void> _save() async {
    setState(() => _isSaving = true);
    try {
      await ref.read(socialRepositoryProvider).updateMyProfile(
            isPublic: _isPublic,
            gameHistory: _gameHistoryController.text.trim(),
            favoriteGenres: _favoriteGenres.toList(),
          );
      ref.invalidate(myProfileProvider);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('プロフィールを保存しました')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('保存に失敗しました: $e')));
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

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
    final profileAsync = ref.watch(myProfileProvider);
    final favoritesAsync = ref.watch(myFavoritesProvider);

    profileAsync.whenData((profile) {
      if (!_initialized) {
        _initialized = true;
        _isPublic = profile?.isPublic ?? false;
        _gameHistoryController.text = profile?.gameHistory ?? '';
        _favoriteGenres = {...?profile?.favoriteGenres};
      }
    });

    return Scaffold(
      appBar: AppBar(title: const Text('プロフィール')),
      body: profileAsync.when(
        data: (profile) => ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Center(
              child: Stack(
                children: [
                  AvatarImage(url: profile?.avatarUrl, radius: 48),
                  Positioned(
                    right: 0,
                    bottom: 0,
                    child: Material(
                      color: Theme.of(context).colorScheme.primary,
                      shape: const CircleBorder(),
                      child: InkWell(
                        customBorder: const CircleBorder(),
                        onTap: _isUploadingAvatar ? null : _pickAndUploadAvatar,
                        child: Padding(
                          padding: const EdgeInsets.all(6),
                          child: _isUploadingAvatar
                              ? SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.onPrimary,
                                  ),
                                )
                              : Icon(
                                  Icons.camera_alt,
                                  size: 16,
                                  color: Theme.of(context).colorScheme.onPrimary,
                                ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Center(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Flexible(
                    child: Text(
                      profile?.displayName?.isNotEmpty == true
                          ? profile!.displayName!
                          : '表示名未設定',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                  ),
                  InkWell(
                    onTap: () => _editDisplayName(profile),
                    borderRadius: BorderRadius.circular(12),
                    child: const Padding(
                      padding: EdgeInsets.only(left: 2, top: 2),
                      child: Icon(Icons.edit, size: 16),
                    ),
                  ),
                ],
              ),
            ),
            if (profile?.username != null) ...[
              const SizedBox(height: 2),
              Center(
                child: Text(
                  '@${profile!.username}',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Theme.of(context).colorScheme.outline,
                      ),
                ),
              ),
            ],
            const SizedBox(height: 24),
            SwitchListTile(
              value: _isPublic,
              onChanged: (value) => setState(() => _isPublic = value),
              contentPadding: EdgeInsets.zero,
              title: const Text('プロフィールを公開する'),
              subtitle: const Text(
                '公開にすると、あなたをフォローしているユーザーに「遊んだ／遊びたい」の'
                'ステータス（ゲーム名と状態のみ）が表示されます。評価・レビュー本文・'
                'クリア情報・優先度は公開されません。非公開の間は誰にも表示されません。',
              ),
            ),
            const SizedBox(height: 16),
            Text('ゲーム歴', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            TextField(
              controller: _gameHistoryController,
              maxLines: 4,
              decoration: const InputDecoration(
                hintText: '例: 子供の頃からRPGが好きで、最近はローグライクにハマっています',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 24),
            Text('好きなジャンル', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            GenreBadgeSelector(
              selectedGenres: _favoriteGenres,
              onToggle: _toggleGenre,
            ),
            const SizedBox(height: 16),
            Align(
              alignment: Alignment.centerRight,
              child: FilledButton(
                onPressed: _isSaving ? null : _save,
                child: _isSaving
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('保存する'),
              ),
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('オレの推しゲー', style: Theme.of(context).textTheme.titleMedium),
                TextButton(
                  onPressed: () => context.push('/favorites/edit'),
                  child: const Text('編集する'),
                ),
              ],
            ),
            const SizedBox(height: 8),
            favoritesAsync.when(
              data: (favorites) {
                if (favorites.isEmpty) {
                  return const Padding(
                    padding: EdgeInsets.symmetric(vertical: 16),
                    child: Text('まだ推しゲーが登録されていません'),
                  );
                }
                return FavoriteGamesList(favorites: favorites, isGridView: false);
              },
              loading: () => const Padding(
                padding: EdgeInsets.symmetric(vertical: 16),
                child: Center(child: CircularProgressIndicator()),
              ),
              error: (error, _) => const Padding(
                padding: EdgeInsets.symmetric(vertical: 16),
                child: Text('推しゲーの取得に失敗しました'),
              ),
            ),
            const SizedBox(height: 32),
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
                    subtitle: const Text('広告非表示・みんなのレビュー閲覧・ジャンル絞り込みが使えます。タップで契約内容を確認できます'),
                    onTap: () => _openManagementUrl(ref),
                  );
                }
                return ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.workspace_premium_outlined),
                  title: const Text('プレミアムプランについて見る'),
                  subtitle: const Text('広告非表示・みんなのレビュー閲覧・ジャンル絞り込み'),
                  onTap: () => context.push('/subscription/paywall'),
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
        loading: () => const LoadingView(),
        error: (error, _) => ErrorView(
          message: 'プロフィールの取得に失敗しました',
          onRetry: () => ref.invalidate(myProfileProvider),
        ),
      ),
    );
  }
}

/// 表示名編集ダイアログ。TextEditingControllerを自身のStateで管理し、
/// ダイアログのポップ（クローズアニメーション中）に伴う早すぎるdisposeを避ける
/// （showDialogの呼び出し側でコントローラーを作ってpop直後にdisposeすると、
/// アニメーション完了前でTextFieldがまだcontrollerを参照しており
/// 「'_dependents.isEmpty': is not true」で落ちることがある）。
class _DisplayNameEditDialog extends StatefulWidget {
  const _DisplayNameEditDialog({required this.initialValue});

  final String initialValue;

  @override
  State<_DisplayNameEditDialog> createState() =>
      _DisplayNameEditDialogState();
}

class _DisplayNameEditDialogState extends State<_DisplayNameEditDialog> {
  late final _controller = TextEditingController(text: widget.initialValue);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('表示名を編集'),
      content: TextField(
        controller: _controller,
        autofocus: true,
        decoration: const InputDecoration(
          labelText: '表示名（任意）',
          border: OutlineInputBorder(),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('キャンセル'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, _controller.text.trim()),
          child: const Text('保存'),
        ),
      ],
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
