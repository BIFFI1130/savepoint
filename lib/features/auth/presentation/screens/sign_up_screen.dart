import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/analytics/analytics_service.dart';
import '../../data/auth_repository.dart';
import '../providers/auth_providers.dart';

const _termsOfServiceUrl =
    'https://biffi1130.github.io/savepoint/terms-of-service.html';
const _privacyPolicyUrl =
    'https://biffi1130.github.io/savepoint/privacy-policy.html';

Future<void> _openUrl(String url) async {
  final uri = Uri.tryParse(url);
  if (uri == null) return;
  await launchUrl(uri, mode: LaunchMode.externalApplication);
}

/// 新規登録の入口となる画面。ここではメールアドレスのみを入力させ、確認メールを
/// 送信するところまでを行う。ユーザーID・パスワードは、メール内のリンクを開いて
/// セッションが確立された後のオンボーディング画面でまとめて設定する。
class SignUpScreen extends ConsumerStatefulWidget {
  const SignUpScreen({super.key});

  @override
  ConsumerState<SignUpScreen> createState() => _SignUpScreenState();
}

class _SignUpScreenState extends ConsumerState<SignUpScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  bool _isLoading = false;
  bool _agreedToTerms = false;

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _signUp() async {
    if (!_formKey.currentState!.validate()) return;
    if (!_agreedToTerms) {
      _showError('利用規約への同意が必要です');
      return;
    }
    setState(() => _isLoading = true);
    try {
      await ref
          .read(authRepositoryProvider)
          .startEmailSignUp(_emailController.text.trim());
      await ref.read(appAnalyticsProvider).logSignUp('email');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('確認メールを送信しました。メール内のリンクを開いて登録を続けてください'),
          ),
        );
        context.pop();
      }
    } on EmailAlreadyRegisteredException {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'このメールアドレスは既に登録されています。サインイン画面からログインしてください',
            ),
          ),
        );
        context.pop();
      }
    } on AuthException catch (e) {
      _showError(e.message);
    } catch (_) {
      _showError('登録に失敗しました。時間をおいて再度お試しください。');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('新規登録')),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    'まずはメールアドレスを入力してください。確認メールに記載のリンクを'
                    '開くと、続けてユーザーIDとパスワードを設定できます。',
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _emailController,
                    keyboardType: TextInputType.emailAddress,
                    decoration: const InputDecoration(
                      labelText: 'メールアドレス',
                      border: OutlineInputBorder(),
                    ),
                    validator: (value) => (value == null || !value.contains('@'))
                        ? '有効なメールアドレスを入力してください'
                        : null,
                  ),
                  const SizedBox(height: 12),
                  CheckboxListTile(
                    contentPadding: EdgeInsets.zero,
                    controlAffinity: ListTileControlAffinity.leading,
                    value: _agreedToTerms,
                    onChanged: (value) =>
                        setState(() => _agreedToTerms = value ?? false),
                    title: Wrap(
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        const Text('『'),
                        GestureDetector(
                          onTap: () => _openUrl(_termsOfServiceUrl),
                          child: const Text(
                            '利用規約',
                            style: TextStyle(
                              color: Colors.blue,
                              decoration: TextDecoration.underline,
                            ),
                          ),
                        ),
                        const Text('』および『'),
                        GestureDetector(
                          onTap: () => _openUrl(_privacyPolicyUrl),
                          child: const Text(
                            'プライバシーポリシー',
                            style: TextStyle(
                              color: Colors.blue,
                              decoration: TextDecoration.underline,
                            ),
                          ),
                        ),
                        const Text('』に同意します（不適切なコンテンツ・迷惑行為は一切許容されません）'),
                      ],
                    ),
                  ),
                  const SizedBox(height: 4),
                  FilledButton(
                    onPressed: _isLoading ? null : _signUp,
                    child: _isLoading
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('確認メールを送信'),
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
