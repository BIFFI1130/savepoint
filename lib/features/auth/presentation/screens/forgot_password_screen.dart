import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../providers/auth_providers.dart';

/// パスワード再設定メールの送信画面。送信後は、成功したかどうかに関わらず
/// 同じ完了メッセージを表示する（登録有無をメールアドレスの存在確認に
/// 使われないようにするため）。
class ForgotPasswordScreen extends ConsumerStatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  ConsumerState<ForgotPasswordScreen> createState() =>
      _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends ConsumerState<ForgotPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  bool _isLoading = false;
  bool _isSent = false;

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);
    try {
      await ref
          .read(authRepositoryProvider)
          .resetPasswordForEmail(_emailController.text.trim());
    } on AuthException catch (_) {
      // メールアドレスの存在有無で挙動を変えないよう、エラーでも完了扱いにする。
    } catch (_) {
      // 同上。
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
    if (mounted) setState(() => _isSent = true);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('パスワードを再設定')),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: _isSent
                ? Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.mark_email_read_outlined,
                        size: 48,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        '入力したメールアドレス宛に、パスワード再設定用のリンクを送信しました。\n'
                        'メール内のリンクを開いて、新しいパスワードを設定してください。',
                        textAlign: TextAlign.center,
                      ),
                    ],
                  )
                : Form(
                    key: _formKey,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const Text(
                          '登録済みのメールアドレスを入力してください。'
                          'パスワード再設定用のリンクをお送りします。',
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _emailController,
                          keyboardType: TextInputType.emailAddress,
                          decoration: const InputDecoration(
                            labelText: 'メールアドレス',
                            border: OutlineInputBorder(),
                          ),
                          validator: (value) =>
                              (value == null || !value.contains('@'))
                                  ? '有効なメールアドレスを入力してください'
                                  : null,
                        ),
                        const SizedBox(height: 16),
                        FilledButton(
                          onPressed: _isLoading ? null : _submit,
                          child: _isLoading
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                )
                              : const Text('再設定メールを送信'),
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
