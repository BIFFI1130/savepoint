import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:savepoint/features/game_log/domain/backlog_estimate.dart';
import 'package:savepoint/features/game_log/domain/game_log.dart';
import 'package:savepoint/features/game_log/presentation/providers/log_providers.dart';
import 'package:savepoint/features/game_log/presentation/screens/backlog_estimate_screen.dart';
import 'package:savepoint/features/game_log/presentation/widgets/backlog_share_card.dart';
import 'package:savepoint/features/game_search/domain/game.dart';

GameLogWithGame _entry(
  int id, {
  GameLogStatus status = GameLogStatus.wantToPlay,
  int? hours,
}) {
  final at = DateTime(2026, 1, id);
  return GameLogWithGame(
    log: GameLog(
      id: 'l$id',
      gameId: id,
      status: status,
      createdAt: at,
      updatedAt: at,
    ),
    game: Game(
      id: id,
      name: 'Game $id',
      timeToBeatNormallySeconds: hours == null ? null : hours * 3600,
    ),
  );
}

Future<void> _pumpScreen(
  WidgetTester tester,
  List<GameLogWithGame> logs,
) async {
  tester.view.physicalSize = const Size(800, 1600);
  tester.view.devicePixelRatio = 2;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [myLogsProvider.overrideWith((ref) async => logs)],
      child: const MaterialApp(home: BacklogEstimateScreen()),
    ),
  );
  await tester.pumpAndSettle();
}

/// 画面の結果カード内の文言のみを探す（画面外のシェア用カードにも同じ文言が出るため）。
Finder _inCard(String text) =>
    find.descendant(of: find.byType(Card), matching: find.text(text));

void main() {
  group('BacklogEstimateScreen', () {
    testWidgets('「遊びたい」が無ければ案内を表示する', (tester) async {
      await _pumpScreen(tester, [_entry(1, status: GameLogStatus.played)]);
      expect(find.textContaining('「遊びたい」にゲームを追加'), findsOneWidget);
    });

    testWidgets('合計時間と消化期間を表示し、時間を切り替えると更新される', (tester) async {
      // 合計60時間。週5時間なら12週間 → 約3か月。
      await _pumpScreen(tester, [
        _entry(1, hours: 20),
        _entry(2, hours: 40),
      ]);
      expect(_inCard('約3か月'), findsOneWidget);
      expect(find.textContaining('積みゲー 2本'), findsOneWidget);
      expect(find.textContaining('約60時間'), findsOneWidget);

      await tester.tap(find.text('20時間'));
      await tester.pumpAndSettle();
      // 週20時間なら3週間。
      expect(_inCard('約3週間'), findsOneWidget);
    });

    testWidgets('クリア時間が無い作品は注記し、全部無いなら計算不可にする', (tester) async {
      await _pumpScreen(tester, [_entry(1), _entry(2)]);
      expect(find.text('計算できません'), findsOneWidget);
      expect(find.textContaining('合計に含めていません'), findsOneWidget);
    });
  });

  testWidgets('BacklogShareCardはオーバーフローしない', (tester) async {
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final estimate = estimateBacklog([
      for (var i = 1; i <= 12; i++) _entry(i, hours: i * 7),
    ]);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: BacklogShareCard(estimate: estimate, hoursPerWeek: 2.5),
          ),
        ),
      ),
    );
    expect(tester.takeException(), isNull);
    expect(find.text('ゲーム人生を記録しよう'), findsOneWidget);
  });
}
