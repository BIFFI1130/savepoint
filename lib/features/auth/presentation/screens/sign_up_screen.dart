import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/analytics/analytics_service.dart';
import '../providers/auth_providers.dart';

class SignUpScreen extends ConsumerStatefulWidget {
  const SignUpScreen({super.key});

  @override
  ConsumerState<SignUpScreen> createState() => _SignUpScreenState();
}

class _SignUpScreenState extends ConsumerState<SignUpScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _signUp() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);
    try {
      await ref.read(authRepositoryProvider).signUpWithEmail(
            email: _emailController.text.trim(),
            password: _passwordController.text,
          );
      await ref.read(appAnalyticsProvider).logSignUp('email');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('確認メールを送信しました。メール内のリンクを開いて登録を完了してください')),
        );
        context.pop();
      }
    } on AuthException catch (e) {
      // メール確認を有効化している場合、既に確認済みのメールアドレスで再度サインアップ
      // しても専用のエラーコードは返らない（GoTrue側がアカウント列挙対策として、
      // 未登録の場合と同じ「確認メールを送信した」という見た目の応答を返すため）。
      // ただしAPIバージョンによっては引き続きエラーコードが返るケースもあるため、
      // 念のため他の失敗と見分けが付かない汎用メッセージに差し替える処理は残す。
      if (e.code == 'user_already_exists' || e.code == 'email_exists') {
        _showError('登録に失敗しました。時間をおいて再度お試しください。');
      } else {
        _showError(e.message);
      }
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
                  const SizedBox(height: 16),
                  FilledButton(
                    onPressed: _isLoading ? null : _signUp,
                    child: _isLoading
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('登録する'),
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
