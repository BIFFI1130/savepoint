import 'package:flutter_test/flutter_test.dart';
import 'package:savepoint/features/game_log/domain/game_log.dart';
import 'package:savepoint/features/game_search/domain/game.dart';
import 'package:savepoint/features/home/presentation/providers/home_providers.dart';

SimilarGame _s(int id) => SimilarGame(id: id, name: 'Similar $id');

GameLogWithGame _log(
  int id, {
  required List<int> similar,
  GameLogStatus status = GameLogStatus.played,
  double? rating,
  required int day,
}) {
  final at = DateTime(2026, 1, day);
  return GameLogWithGame(
    log: GameLog(
      id: 'l$id',
      gameId: id,
      status: status,
      rating: rating,
      createdAt: at,
      updatedAt: at,
    ),
    game: Game(id: id, name: 'Game $id', similarGames: similar.map(_s).toList()),
  );
}

List<int> _ids(List<SimilarGame> games) => games.map((g) => g.id).toList();

void main() {
  group('rankSimilarGames', () {
    test('複数の高評価作品に似ている作品を上位にする', () {
      final result = rankSimilarGames([
        _log(1, similar: [100, 200], rating: 5, day: 1),
        _log(2, similar: [200, 300], rating: 4.5, day: 2),
      ], limit: 10);
      // 200は2本から挙がるので最上位。
      expect(_ids(result).first, 200);
      expect(_ids(result), containsAll([100, 200, 300]));
    });

    test('低評価の作品に似ているだけの作品は薦めない', () {
      final result = rankSimilarGames([
        _log(1, similar: [100], rating: 1.5, day: 1),
        _log(2, similar: [200], rating: 4, day: 2),
      ], limit: 10);
      expect(_ids(result), [200]);
    });

    test('高評価の根拠は、遊びたい・未評価より重い', () {
      final result = rankSimilarGames([
        _log(1, similar: [100], status: GameLogStatus.wantToPlay, day: 3),
        _log(2, similar: [200], rating: 5, day: 1),
        _log(3, similar: [300], rating: null, day: 2),
      ], limit: 10);
      expect(_ids(result), [200, 100, 300]);
    });

    test('同点なら、より最近追加した記録から見つかった作品を先にする', () {
      final result = rankSimilarGames([
        _log(1, similar: [100], rating: 4, day: 1),
        _log(2, similar: [200], rating: 4, day: 5),
      ], limit: 10);
      expect(_ids(result), [200, 100]);
    });

    test('既に記録済みの作品は除外し、上限で打ち切る', () {
      final result = rankSimilarGames([
        _log(1, similar: [2, 100, 200, 300], rating: 5, day: 1),
        _log(2, similar: [], rating: 5, day: 2),
      ], limit: 2);
      expect(_ids(result).contains(2), isFalse);
      expect(result.length, 2);
    });

    test('記録が空なら空', () {
      expect(rankSimilarGames(const [], limit: 5), isEmpty);
    });
  });
}
