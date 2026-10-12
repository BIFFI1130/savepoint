import 'package:flutter_test/flutter_test.dart';
import 'package:savepoint/features/game_log/domain/backlog_estimate.dart';
import 'package:savepoint/features/game_log/domain/game_log.dart';
import 'package:savepoint/features/game_search/domain/game.dart';

GameLogWithGame _entry(
  int id, {
  GameLogStatus status = GameLogStatus.wantToPlay,
  int? normally,
  int? hastily,
  int? completely,
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
      timeToBeatNormallySeconds: normally,
      timeToBeatHastilySeconds: hastily,
      timeToBeatCompletelySeconds: completely,
    ),
  );
}

void main() {
  group('estimateBacklog', () {
    test('「遊びたい」だけを集計し、短い順に並べる', () {
      final result = estimateBacklog([
        _entry(1, normally: 10 * 3600),
        _entry(2, normally: 2 * 3600),
        _entry(3, status: GameLogStatus.played, normally: 99 * 3600),
        _entry(4, normally: 5 * 3600),
      ]);
      expect(result.entries.map((e) => e.entry.game.id), [2, 4, 1]);
      expect(result.totalHours, 17);
      expect(result.totalGames, 3);
      expect(result.missingCount, 0);
    });

    test('クリア時間が無い作品は合計に含めず、本数だけ数える', () {
      final result = estimateBacklog([
        _entry(1, normally: 3600),
        _entry(2),
        _entry(3, normally: 0),
      ]);
      expect(result.countedGames, 1);
      expect(result.missingCount, 2);
      expect(result.totalGames, 3);
    });

    test('通常が無ければ急ぎ、それも無ければ完全を使う', () {
      expect(clearTimeSeconds(_entry(1, hastily: 100).game), 100);
      expect(clearTimeSeconds(_entry(1, completely: 300).game), 300);
      expect(
        clearTimeSeconds(_entry(1, normally: 200, hastily: 100).game),
        200,
      );
      expect(clearTimeSeconds(_entry(1).game), isNull);
    });

    test('週あたりの時間から消化週数を出す', () {
      final result = estimateBacklog([_entry(1, normally: 50 * 3600)]);
      expect(result.weeksToFinish(5), 10);
      expect(result.weeksToFinish(0), 0);
    });

    test('longestは長い順', () {
      final result = estimateBacklog([
        _entry(1, normally: 1 * 3600),
        _entry(2, normally: 9 * 3600),
        _entry(3, normally: 5 * 3600),
      ]);
      expect(result.longest(2).map((e) => e.entry.game.id), [2, 3]);
    });

    test('空でも例外にならない', () {
      final result = estimateBacklog(const []);
      expect(result.totalGames, 0);
      expect(result.weeksToFinish(5), 0);
    });
  });

  group('describeWeeks', () {
    test('期間の大きさに応じた表現にする', () {
      expect(describeWeeks(0), 'なし');
      expect(describeWeeks(0.5), '1週間未満');
      expect(describeWeeks(3), '約3週間');
      expect(describeWeeks(26), '約6か月');
      expect(describeWeeks(60), '約1年2か月');
      expect(describeWeeks(52.18 * 2), '約2.0年');
      expect(describeWeeks(52.18 * 5.4), '約5.4年');
    });
  });
}
