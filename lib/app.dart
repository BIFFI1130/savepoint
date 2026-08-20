import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/deep_links/deep_link_service.dart';
import 'core/router/app_router.dart';
import 'core/subscription/subscription_service.dart';
import 'core/supabase/supabase_client.dart';
import 'core/theme/app_theme.dart';
import 'features/auth/presentation/providers/auth_providers.dart';

class SavePointApp extends ConsumerStatefulWidget {
  const SavePointApp({super.key});

  @override
  ConsumerState<SavePointApp> createState() => _SavePointAppState();
}

class _SavePointAppState extends ConsumerState<SavePointApp> {
  @override
  void initState() {
    super.initState();
    DeepLinkService(_handleDeepLink).init();
  }

  /// パスワード再設定メールのリンク（`savepoint://reset-password?code=...`）を受け取り、
  /// セッションを確立してから再設定画面へ遷移する。それ以外のリンクは無視する。
  Future<void> _handleDeepLink(Uri uri) async {
    if (uri.scheme != 'savepoint' || uri.host != 'reset-password') return;
    try {
      await supabase.auth.getSessionFromUrl(uri);
      ref.read(routerProvider).go('/reset-password');
    } catch (error, stackTrace) {
      debugPrint('パスワード再設定リンクの処理に失敗しました: $error\n$stackTrace');
    }
  }

  @override
  Widget build(BuildContext context) {
    final router = ref.watch(routerProvider);

    // ログイン中のSupabaseユーザーIDをRevenueCatに紐付け、同一アカウントの
    // 再インストール・機種変更でも購入権利が引き継がれるようにする。
    ref.listen(currentUserProvider, (previous, next) {
      if (next != null) {
        SubscriptionService.logIn(next.id);
      } else if (previous != null) {
        SubscriptionService.logOut();
      }
    });

    return MaterialApp.router(
      title: 'SavePoint',
      debugShowCheckedModeBanner: false,
      locale: const Locale('ja', 'JP'),
      supportedLocales: const [Locale('ja', 'JP')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      routerConfig: router,
    );
  }
}
