import 'package:flutter_test/flutter_test.dart';
import 'package:savepoint/features/game_log/domain/game_log.dart';
import 'package:savepoint/features/game_search/domain/game.dart';
import 'package:savepoint/features/summary/domain/period_summary.dart';

GameLogWithGame _entry({
  required int id,
  required GameLogStatus status,
  required DateTime createdAt,
  int? rating,
  List<String> genres = const [],
}) {
  return GameLogWithGame(
    log: GameLog(
      id: 'log-$id',
      gameId: id,
      status: status,
      rating: rating,
      createdAt: createdAt,
      updatedAt: createdAt,
    ),
    game: Game(id: id, name: 'Game $id', genres: genres),
  );
}

void main() {
  group('summarizePeriod（月間）', () {
    final logs = [
      // 対象月（2026年3月）内の「遊んだ」記録。
      _entry(
        id: 1,
        status: GameLogStatus.played,
        createdAt: DateTime(2026, 3, 5),
        rating: 5,
        genres: ['Role-playing (RPG)'],
      ),
      _entry(
        id: 2,
        status: GameLogStatus.played,
        createdAt: DateTime(2026, 3, 20),
        rating: 3,
        genres: ['Role-playing (RPG)', 'Adventure'],
      ),
      // 対象月内の「遊びたい」追加。
      _entry(
        id: 3,
        status: GameLogStatus.wantToPlay,
        createdAt: DateTime(2026, 3, 10),
      ),
      // 月の最終日ちょうど（境界値、含まれるべき）。
      _entry(
        id: 4,
        status: GameLogStatus.played,
        createdAt: DateTime(2026, 3, 31, 23, 59),
        genres: ['Role-playing (RPG)'],
      ),
      // 翌月に入った直後（境界値、除外されるべき）。
      _entry(
        id: 5,
        status: GameLogStatus.played,
        createdAt: DateTime(2026, 4, 1),
      ),
      // 前月（除外されるべき）。
      _entry(
        id: 6,
        status: GameLogStatus.played,
        createdAt: DateTime(2026, 2, 28),
      ),
    ];

    final summary = summarizePeriod(
      logs,
      periodStart: DateTime(2026, 3),
      periodType: SummaryPeriodType.month,
    );

    test('期間内の「遊んだ」のみを集計する', () {
      expect(summary.playedCount, 3);
    });

    test('期間内の「遊びたい」追加件数を数える', () {
      expect(summary.wantToPlayAddedCount, 1);
    });

    test('平均評価は評価未入力を除いて計算する', () {
      // (5 + 3) / 2 = 4.0（id=4は評価未入力なので分母に含めない）
      expect(summary.averageRating, 4.0);
    });

    test('ジャンル別件数はgenreLabelで日本語ラベルに変換され、多い順に並ぶ', () {
      final entries = summary.genreCounts.entries.toList();
      expect(entries.first.key, 'RPG');
      expect(entries.first.value, 3);
      expect(summary.genreCounts['アドベンチャー'], 1);
    });

    test('月末23:59は期間内、翌月0:00は期間外', () {
      final ids = summary.playedEntries.map((e) => e.game.id).toSet();
      expect(ids, contains(4));
      expect(ids, isNot(contains(5)));
      expect(ids, isNot(contains(6)));
    });
  });

  test('評価が1件もなければaverageRatingはnull', () {
    final summary = summarizePeriod(
      [
        _entry(
          id: 1,
          status: GameLogStatus.played,
          createdAt: DateTime(2026, 3, 1),
        ),
      ],
      periodStart: DateTime(2026, 3),
      periodType: SummaryPeriodType.month,
    );
    expect(summary.averageRating, isNull);
  });

  test('all期間ではperiodStartを無視して全件を対象にする', () {
    final logs = [
      _entry(id: 1, status: GameLogStatus.played, createdAt: DateTime(2020, 1, 1)),
      _entry(id: 2, status: GameLogStatus.played, createdAt: DateTime(2026, 6, 1)),
    ];
    final summary = summarizePeriod(
      logs,
      periodStart: DateTime(2026, 3),
      periodType: SummaryPeriodType.all,
    );
    expect(summary.playedCount, 2);
  });

  test('year期間は1年分を対象にする', () {
    final logs = [
      _entry(id: 1, status: GameLogStatus.played, createdAt: DateTime(2026, 1, 1)),
      _entry(id: 2, status: GameLogStatus.played, createdAt: DateTime(2026, 12, 31)),
      _entry(id: 3, status: GameLogStatus.played, createdAt: DateTime(2027, 1, 1)),
      _entry(id: 4, status: GameLogStatus.played, createdAt: DateTime(2025, 12, 31)),
    ];
    final summary = summarizePeriod(
      logs,
      periodStart: DateTime(2026),
      periodType: SummaryPeriodType.year,
    );
    expect(summary.playedCount, 2);
  });
}
