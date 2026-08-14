import 'package:flutter_test/flutter_test.dart';
import 'package:savepoint/features/achievements/domain/achievement.dart';
import 'package:savepoint/features/collections/domain/collection.dart';
import 'package:savepoint/features/game_log/domain/game_log.dart';
import 'package:savepoint/features/game_search/domain/game.dart';

GameLogWithGame _played({
  required int id,
  required DateTime createdAt,
  int? rating,
  String? reviewText,
  List<String> platforms = const [],
}) {
  return GameLogWithGame(
    log: GameLog(
      id: 'log-$id',
      gameId: id,
      status: GameLogStatus.played,
      rating: rating,
      reviewText: reviewText,
      createdAt: createdAt,
      updatedAt: createdAt,
    ),
    game: Game(id: id, name: 'Game $id', platforms: platforms),
  );
}

Collection _collection({required String id, required int gameCount, required DateTime createdAt}) {
  return Collection(
    id: id,
    name: 'Collection $id',
    gameCount: gameCount,
    createdAt: createdAt,
    updatedAt: createdAt,
  );
}

AchievementStatus _find(List<AchievementStatus> statuses, String id) =>
    statuses.firstWhere((s) => s.achievement.id == id);

void main() {
  test('記録0件では最初の記録マイルストーンも未達成', () {
    final statuses = evaluateAchievements([], []);
    final first = _find(statuses, 'played_1');
    expect(first.achieved, isFalse);
    expect(first.currentProgress, 0);
    expect(first.achievedAt, isNull);
  });

  test('記録数マイルストーンは達成した瞬間のcreatedAtを記録する', () {
    final logs = List.generate(
      10,
      (i) => _played(id: i, createdAt: DateTime(2026, 1, i + 1)),
    );
    final statuses = evaluateAchievements(logs, []);

    final first = _find(statuses, 'played_1');
    expect(first.achieved, isTrue);
    expect(first.achievedAt, DateTime(2026, 1, 1));

    final ten = _find(statuses, 'played_10');
    expect(ten.achieved, isTrue);
    expect(ten.achievedAt, DateTime(2026, 1, 10));

    final thirty = _find(statuses, 'played_30');
    expect(thirty.achieved, isFalse);
    expect(thirty.currentProgress, 10);
  });

  test('レビュー・★5評価は該当する記録のみをカウントする', () {
    final logs = [
      _played(id: 1, createdAt: DateTime(2026, 1, 1), rating: 5, reviewText: 'よかった'),
      _played(id: 2, createdAt: DateTime(2026, 1, 2), rating: 3),
      _played(id: 3, createdAt: DateTime(2026, 1, 3), rating: 5),
    ];
    final statuses = evaluateAchievements(logs, []);

    expect(_find(statuses, 'review_1').currentProgress, 1);
    expect(_find(statuses, 'five_star_10').currentProgress, 2);
  });

  test('対応ハードの種類数は記録順の累積distinctで判定する', () {
    final logs = [
      _played(id: 1, createdAt: DateTime(2026, 1, 1), platforms: ['Switch']),
      _played(id: 2, createdAt: DateTime(2026, 1, 2), platforms: ['PS5']),
      // 3件目でSwitch/PS5/PCの3種類目に到達。
      _played(id: 3, createdAt: DateTime(2026, 1, 3), platforms: ['PC']),
    ];
    final statuses = evaluateAchievements(logs, []);
    final platform3 = _find(statuses, 'platform_3');
    expect(platform3.achieved, isTrue);
    expect(platform3.achievedAt, DateTime(2026, 1, 3));
    expect(_find(statuses, 'platform_5').achieved, isFalse);
  });

  test('コレクション関連はcollections引数から集計する', () {
    final collections = [
      _collection(id: 'a', gameCount: 4, createdAt: DateTime(2026, 2, 1)),
      _collection(id: 'b', gameCount: 7, createdAt: DateTime(2026, 1, 1)),
    ];
    final statuses = evaluateAchievements([], collections);

    final createMilestone = _find(statuses, 'collection_1');
    expect(createMilestone.achieved, isTrue);
    // 一覧は作成日時の降順で返る想定のため、最後の要素（最も古い）が最初の作成日。
    expect(createMilestone.achievedAt, DateTime(2026, 1, 1));

    expect(_find(statuses, 'collection_games_10').currentProgress, 11);
  });

  group('連続記録月数（streak）', () {
    test('連続していない月は最長1としてカウントする', () {
      final logs = [
        _played(id: 1, createdAt: DateTime(2026, 1, 15)),
        _played(id: 2, createdAt: DateTime(2026, 3, 15)),
      ];
      final statuses = evaluateAchievements(logs, []);
      expect(_find(statuses, 'streak_3').currentProgress, 1);
    });

    test('3ヶ月連続で記録すると達成する', () {
      final logs = [
        _played(id: 1, createdAt: DateTime(2026, 1, 15)),
        _played(id: 2, createdAt: DateTime(2026, 2, 3)),
        _played(id: 3, createdAt: DateTime(2026, 3, 28)),
      ];
      final statuses = evaluateAchievements(logs, []);
      final streak = _find(statuses, 'streak_3');
      expect(streak.currentProgress, 3);
      expect(streak.achieved, isTrue);
    });

    test('年をまたぐ連続（12月→1月）も正しくつながる', () {
      final logs = [
        _played(id: 1, createdAt: DateTime(2025, 12, 1)),
        _played(id: 2, createdAt: DateTime(2026, 1, 1)),
        _played(id: 3, createdAt: DateTime(2026, 2, 1)),
      ];
      final statuses = evaluateAchievements(logs, []);
      expect(_find(statuses, 'streak_3').currentProgress, 3);
    });

    test('同じ月に複数回記録しても1ヶ月としてカウントする', () {
      final logs = [
        _played(id: 1, createdAt: DateTime(2026, 1, 1)),
        _played(id: 2, createdAt: DateTime(2026, 1, 20)),
      ];
      final statuses = evaluateAchievements(logs, []);
      expect(_find(statuses, 'streak_3').currentProgress, 1);
    });
  });
}
