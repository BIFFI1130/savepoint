import 'package:flutter_test/flutter_test.dart';
import 'package:savepoint/core/utils/nearest_upcoming_backlog_entry.dart';
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

  group('nearestUpcomingBacklogEntry', () {
    test('空リストならnull', () {
      expect(nearestUpcomingBacklogEntry([]), isNull);
    });

    test('遊んだ記録のみならnull（未発売でも対象外）', () {
      final entries = [
        GameLogWithGame(
          log: _log(id: 'a', gameId: 1, status: GameLogStatus.played),
          game: _game(id: 1, firstReleaseDate: inDays(10)),
        ),
      ];
      expect(nearestUpcomingBacklogEntry(entries), isNull);
    });

    test('発売済みの遊びたい記録は除外される', () {
      final entries = [
        GameLogWithGame(
          log: _log(id: 'a', gameId: 1),
          game: _game(id: 1, firstReleaseDate: inDays(-5)),
        ),
      ];
      expect(nearestUpcomingBacklogEntry(entries), isNull);
    });

    test('複数候補から発売日が最も近いものを選ぶ', () {
      final near = GameLogWithGame(
        log: _log(id: 'a', gameId: 1),
        game: _game(id: 1, firstReleaseDate: inDays(3)),
      );
      final far = GameLogWithGame(
        log: _log(id: 'b', gameId: 2),
        game: _game(id: 2, firstReleaseDate: inDays(30)),
      );
      final played = GameLogWithGame(
        log: _log(id: 'c', gameId: 3, status: GameLogStatus.played),
        game: _game(id: 3, firstReleaseDate: inDays(1)),
      );
      final result = nearestUpcomingBacklogEntry([far, played, near]);
      expect(result?.game.id, 1);
    });

    test('同日の場合はゲームIDの昇順でタイブレークする', () {
      final entryA = GameLogWithGame(
        log: _log(id: 'a', gameId: 5),
        game: _game(id: 5, firstReleaseDate: inDays(7)),
      );
      final entryB = GameLogWithGame(
        log: _log(id: 'b', gameId: 2),
        game: _game(id: 2, firstReleaseDate: inDays(7)),
      );
      final result = nearestUpcomingBacklogEntry([entryA, entryB]);
      expect(result?.game.id, 2);
    });
  });
}
