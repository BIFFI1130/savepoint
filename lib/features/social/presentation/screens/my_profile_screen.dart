import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../../../core/subscription/subscription_providers.dart';
import '../../../../core/widgets/async_state_views.dart';
import '../../../../core/widgets/avatar_image.dart';
import '../../../../core/widgets/genre_badge_selector.dart';
import '../../../favorites/presentation/providers/favorite_providers.dart';
import '../../../favorites/presentation/widgets/favorite_games_list.dart';
import '../../domain/social_profile.dart';
import '../providers/social_providers.dart';
import '../widgets/profile_share_sheet.dart';

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
  ProfileVisibility _profileVisibility = ProfileVisibility.private_;
  Set<String> _favoriteGenres = {};
  bool _initialized = false;
  bool _isSaving = false;
  bool _isUploadingAvatar = false;

  @override
  void initState() {
    super.initState();
    ref.read(profileSaveAdProvider).preload();
  }

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
            profileVisibility: _profileVisibility,
            gameHistory: _gameHistoryController.text.trim(),
            favoriteGenres: _favoriteGenres.toList(),
          );
      ref.invalidate(myProfileProvider);
      if (!ref.read(isAdFreeProvider)) {
        await ref.read(profileSaveAdProvider).show();
      }
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

  Future<void> _toggleShowIdentityInPublicReviews(bool value) async {
    await ref
        .read(socialRepositoryProvider)
        .setShowIdentityInPublicReviews(value);
    ref.invalidate(myProfileProvider);
  }

  @override
  Widget build(BuildContext context) {
    final profileAsync = ref.watch(myProfileProvider);
    final favoritesAsync = ref.watch(myFavoritesProvider);

    profileAsync.whenData((profile) {
      if (!_initialized) {
        _initialized = true;
        _profileVisibility =
            profile?.profileVisibility ?? ProfileVisibility.private_;
        _gameHistoryController.text = profile?.gameHistory ?? '';
        _favoriteGenres = {...?profile?.favoriteGenres};
      }
    });

    final profile = profileAsync.valueOrNull;
    return Scaffold(
      appBar: AppBar(
        title: const Text('プロフィール'),
        actions: [
          IconButton(
            icon: const Icon(Icons.qr_code),
            tooltip: 'プロフィールを共有',
            onPressed: profile == null
                ? null
                : () => ProfileShareSheet.show(
                      context,
                      userId: profile.id,
                      displayLabel: profile.displayLabel,
                    ),
          ),
        ],
      ),
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
            Text('公開範囲', style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 4),
            SegmentedButton<ProfileVisibility>(
              segments: [
                for (final v in ProfileVisibility.values)
                  ButtonSegment(value: v, label: Text(v.label)),
              ],
              selected: {_profileVisibility},
              onSelectionChanged: (selection) =>
                  setState(() => _profileVisibility = selection.first),
            ),
            const SizedBox(height: 4),
            Text(
              _profileVisibility.description,
              style: Theme.of(context).textTheme.bodySmall,
            ),
            Consumer(
              builder: (context, ref, _) {
                final profileAsync = ref.watch(myProfileProvider);
                return SwitchListTile(
                  value: profileAsync.value?.showIdentityInPublicReviews ??
                      false,
                  onChanged: profileAsync.isLoading
                      ? null
                      : _toggleShowIdentityInPublicReviews,
                  contentPadding: EdgeInsets.zero,
                  title: const Text('「みんなのレビュー」に身元を表示する'),
                  subtitle: const Text(
                    'フォロー関係のない全ユーザーが見る「みんなのレビュー」に、あなたの'
                    'ユーザー名・アバターを表示します（デフォルトでオン）。タップで'
                    'プロフィールに遷移できるため、フォローされるきっかけになります。'
                    'オフにすると匿名で表示されます。',
                  ),
                );
              },
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

