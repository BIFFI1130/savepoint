import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:savepoint/features/game_log/presentation/widgets/empty_library_card.dart';

void main() {
  testWidgets('案内を表示し、押すとSteam取り込み画面へ遷移する', (tester) async {
    final router = GoRouter(
      routes: [
        GoRoute(
          path: '/',
          builder: (context, state) =>
              const Scaffold(body: Center(child: EmptyLibraryCard())),
        ),
        GoRoute(
          path: '/steam-import',
          builder: (context, state) => const Scaffold(body: Text('取り込み画面')),
        ),
      ],
    );
    await tester.pumpWidget(MaterialApp.router(routerConfig: router));

    expect(find.text('ゲームを記録しはじめよう'), findsOneWidget);
    expect(find.textContaining('検索」タブ'), findsOneWidget);

    await tester.tap(find.text('Steamから取り込む'));
    await tester.pumpAndSettle();
    expect(find.text('取り込み画面'), findsOneWidget);
  });
}
