import 'package:flutter_test/flutter_test.dart';
import 'package:savepoint/core/utils/todays_releasing_backlog_entries.dart';
import 'package:savepoint/features/game_log/domain/game_log.dart';
import 'package:savepoint/features/game_search/domain/game.dart';

GameLog _log({
  required String id,
  required int gameId,
  GameLogStatus status = GameLogStatus.wantToPlay,
}) {
  final now = DateTime.now();
  return GameLog(
    id: id,
    gameId: gameId,
    status: status,
    createdAt: now,
    updatedAt: now,
  );
}

Game _game({required int id, DateTime? firstReleaseDate}) {
  return Game(id: id, name: 'Game $id', firstReleaseDate: firstReleaseDate);
}

void main() {
  final now = DateTime.now();
  DateTime inDays(int days) =>
      DateTime(now.year, now.month, now.day).add(Duration(days: days));

  group('todaysReleasingBacklogEntries', () {
    test('空リストなら空リスト', () {
      expect(todaysReleasingBacklogEntries([]), isEmpty);
    });

    test('本日発売が無ければ空リスト', () {
      final entries = [
        GameLogWithGame(
          log: _log(id: 'a', gameId: 1),
          game: _game(id: 1, firstReleaseDate: inDays(3)),
        ),
      ];
      expect(todaysReleasingBacklogEntries(entries), isEmpty);
    });

    test('遊んだ記録は本日発売でも除外される', () {
      final entries = [
        GameLogWithGame(
          log: _log(id: 'a', gameId: 1, status: GameLogStatus.played),
          game: _game(id: 1, firstReleaseDate: inDays(0)),
        ),
      ];
      expect(todaysReleasingBacklogEntries(entries), isEmpty);
    });

    test('本日発売の遊びたい記録を全件返す', () {
      final todayA = GameLogWithGame(
        log: _log(id: 'a', gameId: 3),
        game: _game(id: 3, firstReleaseDate: inDays(0)),
      );
      final todayB = GameLogWithGame(
        log: _log(id: 'b', gameId: 1),
        game: _game(id: 1, firstReleaseDate: inDays(0)),
      );
      final future = GameLogWithGame(
        log: _log(id: 'c', gameId: 2),
        game: _game(id: 2, firstReleaseDate: inDays(5)),
      );
      final result = todaysReleasingBacklogEntries([todayA, future, todayB]);
      expect(result.map((e) => e.game.id).toList(), [1, 3]);
    });

    test('発売済みは除外される', () {
      final entries = [
        GameLogWithGame(
          log: _log(id: 'a', gameId: 1),
          game: _game(id: 1, firstReleaseDate: inDays(-1)),
        ),
      ];
      expect(todaysReleasingBacklogEntries(entries), isEmpty);
    });
  });
}
