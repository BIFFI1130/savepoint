import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/onboarding/username_gate.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../providers/social_providers.dart';

final _usernamePattern = RegExp(r'^[a-zA-Z0-9]+$');

/// アプリ起動時にユーザーIDが未設定の場合に必ず経由させる、登録完了画面。
/// システムのバックボタンでは閉じられない（[PopScope]でブロック）。ユーザーIDは
/// 半角英数字のみ・一意で、一度設定するとこのアプリの他画面からは変更できない。
///
/// メールアドレスのみで新規登録した場合（=まだパスワード未設定）は、ここで
/// ユーザーIDと合わせてパスワードも設定させる。Google/Appleサインインの場合は
/// パスワードが不要なため、ユーザーIDのみを入力させる。
class UsernameOnboardingScreen extends ConsumerStatefulWidget {
  const UsernameOnboardingScreen({super.key});

  @override
  ConsumerState<UsernameOnboardingScreen> createState() =>
      _UsernameOnboardingScreenState();
}

class _UsernameOnboardingScreenState
    extends ConsumerState<UsernameOnboardingScreen> {
  final _formKey = GlobalKey<FormState>();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();
  bool _isSaving = false;
  bool _initialized = false;

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final username = _usernameController.text.trim();
    if (username.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('ユーザーIDを入力してください')));
      return;
    }
    if (!_usernamePattern.hasMatch(username)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('ユーザーIDは半角英数字のみ使用できます')),
      );
      return;
    }
    final needsPassword =
        ref.read(currentUserProvider)?.appMetadata['provider'] == 'email';
    if (needsPassword && !_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);
    try {
      if (needsPassword) {
        await ref
            .read(authRepositoryProvider)
            .updatePassword(_passwordController.text);
      }
      await ref.read(socialRepositoryProvider).setUsername(username);
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
        _usernameController.text = profile?.username ?? '';
      }
    });
    final needsPassword =
        ref.watch(currentUserProvider)?.appMetadata['provider'] == 'email';

    return PopScope(
      canPop: false,
      child: Scaffold(
        appBar: AppBar(
          automaticallyImplyLeading: false,
          title: const Text('登録の完了'),
        ),
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    needsPassword ? 'ユーザーIDとパスワードを設定してください' : 'ユーザーIDを設定してください',
                    style: Theme.of(context).textTheme.titleLarge,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'ユーザーIDは半角英数字のみ使用できます。他のユーザーと重複はできず、'
                    '一度設定すると通常は変更できません。',
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 24),
                  TextFormField(
                    controller: _usernameController,
                    autofocus: true,
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(RegExp('[a-zA-Z0-9]')),
                    ],
                    decoration: const InputDecoration(
                      labelText: 'ユーザーID',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  if (needsPassword) ...[
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _passwordController,
                      obscureText: true,
                      decoration: const InputDecoration(
                        labelText: 'パスワード（6文字以上）',
                        border: OutlineInputBorder(),
                      ),
                      validator: (value) => (value == null || value.length < 6)
                          ? 'パスワードは6文字以上で入力してください'
                          : null,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _confirmController,
                      obscureText: true,
                      decoration: const InputDecoration(
                        labelText: 'パスワード（確認）',
                        border: OutlineInputBorder(),
                      ),
                      validator: (value) => value != _passwordController.text
                          ? 'パスワードが一致しません'
                          : null,
                      onFieldSubmitted: (_) => _isSaving ? null : _submit(),
                    ),
                  ],
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
        ),
      ),
    );
  }
}
