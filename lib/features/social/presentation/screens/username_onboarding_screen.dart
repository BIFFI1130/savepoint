import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/onboarding/username_gate.dart';
import '../providers/social_providers.dart';

final _usernamePattern = RegExp(r'^[a-zA-Z0-9]+$');

/// アプリ起動時にユーザーIDが未設定の場合に必ず経由させる、ユーザーID入力画面。
/// システムのバックボタンでは閉じられない（[PopScope]でブロック）。ユーザーIDは
/// 半角英数字のみ・一意で、一度設定するとこのアプリの他画面からは変更できない。
class UsernameOnboardingScreen extends ConsumerStatefulWidget {
  const UsernameOnboardingScreen({super.key});

  @override
  ConsumerState<UsernameOnboardingScreen> createState() =>
      _UsernameOnboardingScreenState();
}

class _UsernameOnboardingScreenState
    extends ConsumerState<UsernameOnboardingScreen> {
  final _controller = TextEditingController();
  bool _isSaving = false;
  bool _initialized = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final value = _controller.text.trim();
    if (value.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('ユーザーIDを入力してください')));
      return;
    }
    if (!_usernamePattern.hasMatch(value)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('ユーザーIDは半角英数字のみ使用できます')),
      );
      return;
    }
    setState(() => _isSaving = true);
    try {
      await ref.read(socialRepositoryProvider).setUsername(value);
      ref.invalidate(myProfileProvider);
      ref.read(usernameGateProvider).markCompleted();
      if (mounted) context.go('/home');
    } catch (e) {
      final message = e.toString().contains('duplicate')
          ? 'そのユーザーIDは既に使われています'
          : '保存に失敗しました: $e';
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
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
        _controller.text = profile?.username ?? '';
      }
    });

    return PopScope(
      canPop: false,
      child: Scaffold(
        appBar: AppBar(
          automaticallyImplyLeading: false,
          title: const Text('ユーザーIDの設定'),
        ),
        body: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                'ユーザーIDを設定してください',
                style: Theme.of(context).textTheme.titleLarge,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              const Text(
                '半角英数字のみ使用できます。他のユーザーと重複はできず、'
                '一度設定すると通常は変更できません。',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              TextField(
                controller: _controller,
                autofocus: true,
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp('[a-zA-Z0-9]')),
                ],
                decoration: const InputDecoration(
                  labelText: 'ユーザーID',
                  border: OutlineInputBorder(),
                ),
                onSubmitted: (_) => _isSaving ? null : _submit(),
              ),
              const SizedBox(height: 24),
              FilledButton(
                onPressed: _isSaving ? null : _submit,
                child: _isSaving
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('決定する'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
