import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:savepoint/features/game_log/domain/game_log.dart';
import 'package:savepoint/features/game_search/domain/game.dart';
import 'package:savepoint/features/summary/domain/period_summary.dart';
import 'package:savepoint/features/summary/presentation/widgets/summary_share_card.dart';

GameLogWithGame _entry(int id, {double? rating, String? nameJa}) {
  final at = DateTime(2026, 3, id);
  return GameLogWithGame(
    log: GameLog(
      id: 'log-$id',
      gameId: id,
      status: GameLogStatus.played,
      rating: rating,
      createdAt: at,
      updatedAt: at,
    ),
    game: Game(
      id: id,
      name: 'Game $id',
      nameJa: nameJa,
      genres: const ['Role-playing (RPG)', 'Adventure'],
    ),
  );
}

Future<void> _pump(WidgetTester tester, PeriodSummary summary) async {
  tester.view.physicalSize = const Size(360, 640);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(child: SummaryShareCard(summary: summary)),
      ),
    ),
  );
}

void main() {
  group('SummaryShareCard', () {
    final entries = [
      _entry(1, rating: 4),
      _entry(2, rating: 5, nameJa: 'とても長いタイトルのゲーム名がここに入りますよ、二行に収まるはず'),
      _entry(3, rating: 5),
      _entry(4),
      _entry(5, rating: 3),
      _entry(6, rating: 2),
    ];

    for (final type in [
      SummaryPeriodType.week,
      SummaryPeriodType.month,
      SummaryPeriodType.year,
      SummaryPeriodType.all,
    ]) {
      testWidgets('期間$typeで描画してもオーバーフローしない', (tester) async {
        final summary = summarizePeriod(
          entries,
          periodStart: type == SummaryPeriodType.year
              ? DateTime(2026)
              : DateTime(2026, 3),
          periodType: type,
        );
        await _pump(tester, summary);
        expect(tester.takeException(), isNull);
        expect(find.text('ゲーム人生を記録しよう'), findsOneWidget);
      });
    }

    testWidgets('年間はベストゲームを評価が最も高い最新の作品にする', (tester) async {
      final summary = summarizePeriod(
        entries,
        periodStart: DateTime(2026),
        periodType: SummaryPeriodType.year,
      );
      await _pump(tester, summary);
      expect(find.text('今年のベストゲーム'), findsOneWidget);
      // 星5が2本（id 2と3）のうち、新しいid 3。
      expect(find.text('Game 3'), findsOneWidget);
      expect(find.text('★ 5'), findsOneWidget);
    });

    testWidgets('1本だけならベストゲームは出さない', (tester) async {
      final summary = summarizePeriod(
        [_entry(1, rating: 5)],
        periodStart: DateTime(2026),
        periodType: SummaryPeriodType.year,
      );
      await _pump(tester, summary);
      expect(tester.takeException(), isNull);
      expect(find.text('今年のベストゲーム'), findsNothing);
    });

    testWidgets('記録が空でも描画できる', (tester) async {
      final summary = summarizePeriod(
        const [],
        periodStart: DateTime(2026),
        periodType: SummaryPeriodType.year,
      );
      await _pump(tester, summary);
      expect(tester.takeException(), isNull);
    });
  });
}
