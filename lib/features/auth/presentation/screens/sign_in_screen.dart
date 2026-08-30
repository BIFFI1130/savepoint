import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/analytics/analytics_service.dart';
import '../providers/auth_providers.dart';

class SignInScreen extends ConsumerStatefulWidget {
  const SignInScreen({super.key});

  @override
  ConsumerState<SignInScreen> createState() => _SignInScreenState();
}

class _SignInScreenState extends ConsumerState<SignInScreen> {
  final _formKey = GlobalKey<FormState>();
  final _identifierController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;

  @override
  void dispose() {
    _identifierController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _signIn() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);
    try {
      await ref.read(authRepositoryProvider).signInWithIdentifier(
            identifier: _identifierController.text.trim(),
            password: _passwordController.text,
          );
      await ref.read(appAnalyticsProvider).logLogin('email');
    } on AuthException catch (e) {
      _showError(e.message);
    } catch (_) {
      _showError('サインインに失敗しました。時間をおいて再度お試しください。');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _signInWithApple() async {
    setState(() => _isLoading = true);
    try {
      await ref.read(authRepositoryProvider).signInWithApple();
      await ref.read(appAnalyticsProvider).logLogin('apple');
    } on SignInWithAppleAuthorizationException catch (e) {
      if (e.code != AuthorizationErrorCode.canceled) {
        _showError('Appleサインインに失敗しました。');
      }
    } on AuthException catch (e) {
      _showError(e.message);
    } catch (_) {
      _showError('Appleサインインに失敗しました。');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _signInWithGoogle() async {
    setState(() => _isLoading = true);
    try {
      await ref.read(authRepositoryProvider).signInWithGoogle();
      await ref.read(appAnalyticsProvider).logLogin('google');
    } on GoogleSignInException catch (e) {
      if (e.code != GoogleSignInExceptionCode.canceled) {
        _showError('Googleサインインに失敗しました。');
      }
    } on AuthException catch (e) {
      _showError(e.message);
    } catch (_) {
      _showError('Googleサインインに失敗しました。');
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
                  ClipRRect(
                    borderRadius: BorderRadius.circular(20),
                    child: Image.asset(
                      'assets/icon/icon_master.png',
                      width: 88,
                      height: 88,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'SavePoint',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.headlineMedium,
                  ),
                  Text(
                    '遊んだゲームを記録しよう',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 32),
                  TextFormField(
                    controller: _identifierController,
                    decoration: const InputDecoration(
                      labelText: 'メールアドレスまたはユーザーID',
                      border: OutlineInputBorder(),
                    ),
                    validator: (value) => (value == null || value.trim().isEmpty)
                        ? 'メールアドレスまたはユーザーIDを入力してください'
                        : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _passwordController,
                    obscureText: true,
                    decoration: const InputDecoration(
                      labelText: 'パスワード',
                      border: OutlineInputBorder(),
                    ),
                    validator: (value) => (value == null || value.length < 6)
                        ? 'パスワードは6文字以上で入力してください'
                        : null,
                  ),
                  const SizedBox(height: 16),
                  FilledButton(
                    onPressed: _isLoading ? null : _signIn,
                    child: _isLoading
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('サインイン'),
                  ),
                  TextButton(
                    onPressed: _isLoading ? null : () => context.push('/sign-up'),
                    child: const Text('アカウントをお持ちでない方はこちら'),
                  ),
                  TextButton(
                    onPressed: _isLoading
                        ? null
                        : () => context.push('/forgot-password'),
                    child: const Text('パスワードをお忘れですか？'),
                  ),
                  const SizedBox(height: 8),
                  const Row(
                    children: [
                      Expanded(child: Divider()),
                      Padding(
                        padding: EdgeInsets.symmetric(horizontal: 8),
                        child: Text('または'),
                      ),
                      Expanded(child: Divider()),
                    ],
                  ),
                  const SizedBox(height: 8),
                  SignInWithAppleButton(
                    onPressed: _isLoading ? () {} : _signInWithApple,
                  ),
                  const SizedBox(height: 8),
                  OutlinedButton.icon(
                    onPressed: _isLoading ? null : _signInWithGoogle,
                    icon: const Icon(Icons.g_mobiledata, size: 28),
                    label: const Text('Googleでサインイン'),
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size.fromHeight(44),
                    ),
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
