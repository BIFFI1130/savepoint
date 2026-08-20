import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/router/app_router.dart';
import 'core/subscription/subscription_service.dart';
import 'core/theme/app_theme.dart';
import 'features/auth/presentation/providers/auth_providers.dart';

class SavePointApp extends ConsumerWidget {
  const SavePointApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
