import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/widgets/async_state_views.dart';
import '../providers/social_providers.dart';

class ProfileSettingsScreen extends ConsumerStatefulWidget {
  const ProfileSettingsScreen({super.key});

  @override
  ConsumerState<ProfileSettingsScreen> createState() =>
      _ProfileSettingsScreenState();
}

class _ProfileSettingsScreenState
    extends ConsumerState<ProfileSettingsScreen> {
  final _usernameController = TextEditingController();
  final _displayNameController = TextEditingController();
  bool _isPublic = false;
  bool _isSaving = false;
  bool _initialized = false;

  @override
  void dispose() {
    _usernameController.dispose();
    _displayNameController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() => _isSaving = true);
    try {
      await ref.read(socialRepositoryProvider).updateMyProfile(
            username: _usernameController.text.trim(),
            displayName: _displayNameController.text.trim(),
            isPublic: _isPublic,
          );
      ref.invalidate(myProfileProvider);
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('プロフィールを保存しました')));
        Navigator.of(context).pop();
      }
    } catch (e) {
      final message = e.toString().contains('duplicate')
          ? 'そのユーザー名は既に使われています'
          : '保存に失敗しました: $e';
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(message)));
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final profileAsync = ref.watch(myProfileProvider);

    profileAsync.whenData((profile) {
      if (!_initialized) {
        _initialized = true;
        _usernameController.text = profile?.username ?? '';
        _displayNameController.text = profile?.displayName ?? '';
        _isPublic = profile?.isPublic ?? false;
      }
    });

    return Scaffold(
      appBar: AppBar(title: const Text('プロフィール設定')),
      body: profileAsync.when(
        data: (_) => SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextField(
                controller: _usernameController,
                decoration: const InputDecoration(
                  labelText: 'ユーザー名（半角英数字、他ユーザーがあなたを検索する際に使われます）',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _displayNameController,
                decoration: const InputDecoration(
                  labelText: '表示名（任意）',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
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
              FilledButton(
                onPressed: _isSaving ? null : _save,
                child: _isSaving
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('保存する'),
              ),
            ],
          ),
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
