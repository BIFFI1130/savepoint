import 'package:flutter/material.dart';

import '../../collections/domain/collection.dart';
import '../../game_log/domain/game_log.dart';

/// 実績の定義（固定リスト）。
class Achievement {
  const Achievement({
    required this.id,
    required this.title,
    required this.description,
    required this.icon,
    required this.target,
  });

  final String id;
  final String title;
  final String description;
  final IconData icon;
  final int target;
}

/// ある実績に対する現在の達成状況。
class AchievementStatus {
  const AchievementStatus({
    required this.achievement,
    required this.currentProgress,
    this.achievedAt,
  });

  final Achievement achievement;
  final int currentProgress;
  final DateTime? achievedAt;

  bool get achieved => currentProgress >= achievement.target;
}

const _playedMilestones = [
  Achievement(id: 'played_1', title: '最初の記録', description: '「遊んだ」を1本記録する', icon: Icons.flag_outlined, target: 1),
  Achievement(id: 'played_10', title: '記録の習慣', description: '「遊んだ」を10本記録する', icon: Icons.local_fire_department_outlined, target: 10),
  Achievement(id: 'played_30', title: 'ゲーム好き', description: '「遊んだ」を30本記録する', icon: Icons.local_fire_department, target: 30),
  Achievement(id: 'played_50', title: '生粋のゲーマー', description: '「遊んだ」を50本記録する', icon: Icons.military_tech_outlined, target: 50),
  Achievement(id: 'played_100', title: '殿堂入り', description: '「遊んだ」を100本記録する', icon: Icons.military_tech, target: 100),
];

const _reviewMilestones = [
  Achievement(id: 'review_1', title: 'レビュアーデビュー', description: 'レビューを1件書く', icon: Icons.edit_note_outlined, target: 1),
  Achievement(id: 'review_10', title: '物書き', description: 'レビューを10件書く', icon: Icons.edit_note, target: 10),
];

const _fiveStarMilestones = [
  Achievement(id: 'five_star_10', title: '熱狂的ファン', description: '★5評価を10回つける', icon: Icons.star_outline, target: 10),
];

const _platformMilestones = [
  Achievement(id: 'platform_3', title: '幅広いプレイヤー', description: '3種類以上のハードで記録する', icon: Icons.devices_other_outlined, target: 3),
  Achievement(id: 'platform_5', title: 'マルチプラットフォーマー', description: '5種類以上のハードで記録する', icon: Icons.devices_other, target: 5),
];

const _collectionCreateMilestone = Achievement(
  id: 'collection_1',
  title: 'コレクター誕生',
  description: 'コレクションを1つ作成する',
  icon: Icons.collections_bookmark_outlined,
  target: 1,
);

const _collectionGamesMilestone = Achievement(
  id: 'collection_games_10',
  title: '整理整頓',
  description: 'コレクションに合計10本追加する',
  icon: Icons.collections_bookmark,
  target: 10,
);

const _streakMilestone = Achievement(
  id: 'streak_3',
  title: '継続は力なり',
  description: '3ヶ月連続で「遊んだ」を記録する',
  icon: Icons.calendar_month_outlined,
  target: 3,
);

/// 全実績の定義一覧。
List<Achievement> get allAchievements => [
      ..._playedMilestones,
      ..._reviewMilestones,
      ..._fiveStarMilestones,
      ..._platformMilestones,
      _collectionCreateMilestone,
      _collectionGamesMilestone,
      _streakMilestone,
    ];

DateTime? _nthDate(List<GameLogWithGame> sortedAscending, int n) =>
    sortedAscending.length >= n ? sortedAscending[n - 1].log.createdAt : null;

/// [logs] と [collections] から全実績の達成状況を判定する。
List<AchievementStatus> evaluateAchievements(
  List<GameLogWithGame> logs,
  List<Collection> collections,
) {
  final played = logs.where((e) => e.log.status == GameLogStatus.played).toList()
    ..sort((a, b) => a.log.createdAt.compareTo(b.log.createdAt));
  final reviewed = played
      .where((e) => e.log.reviewText != null && e.log.reviewText!.isNotEmpty)
      .toList();
  final fiveStar = played.where((e) => e.log.rating == 5).toList();

  final statuses = <AchievementStatus>[
    for (final a in _playedMilestones)
      AchievementStatus(
        achievement: a,
        currentProgress: played.length,
        achievedAt: _nthDate(played, a.target),
      ),
    for (final a in _reviewMilestones)
      AchievementStatus(
        achievement: a,
        currentProgress: reviewed.length,
        achievedAt: _nthDate(reviewed, a.target),
      ),
    for (final a in _fiveStarMilestones)
      AchievementStatus(
        achievement: a,
        currentProgress: fiveStar.length,
        achievedAt: _nthDate(fiveStar, a.target),
      ),
  ];

  // 対応ハードの種類数：記録順に累積distinct件数を追跡し、達成した瞬間のcreatedAtを求める。
  final seenPlatforms = <String>{};
  final platformMilestoneDates = <String, DateTime>{};
  for (final entry in played) {
    seenPlatforms.addAll(entry.game.platforms);
    for (final a in _platformMilestones) {
      if (!platformMilestoneDates.containsKey(a.id) &&
          seenPlatforms.length >= a.target) {
        platformMilestoneDates[a.id] = entry.log.createdAt;
      }
    }
  }
  for (final a in _platformMilestones) {
    statuses.add(AchievementStatus(
      achievement: a,
      currentProgress: seenPlatforms.length,
      achievedAt: platformMilestoneDates[a.id],
    ));
  }

  // コレクション：一覧は作成日時の降順なので、最後の要素が最初に作成したコレクション。
  statuses.add(AchievementStatus(
    achievement: _collectionCreateMilestone,
    currentProgress: collections.length,
    achievedAt: collections.isEmpty ? null : collections.last.createdAt,
  ));
  final totalCollectionGames =
      collections.fold<int>(0, (sum, c) => sum + c.gameCount);
  statuses.add(AchievementStatus(
    achievement: _collectionGamesMilestone,
    currentProgress: totalCollectionGames,
  ));

  // 連続記録月数：記録がある年月をユニーク化し、最長の連続区間を求める。
  final monthKeys = played
      .map((e) => e.log.createdAt.year * 12 + e.log.createdAt.month)
      .toSet()
      .toList()
    ..sort();
  var longestStreak = monthKeys.isEmpty ? 0 : 1;
  var currentStreak = monthKeys.isEmpty ? 0 : 1;
  for (var i = 1; i < monthKeys.length; i++) {
    currentStreak = monthKeys[i] == monthKeys[i - 1] + 1 ? currentStreak + 1 : 1;
    if (currentStreak > longestStreak) longestStreak = currentStreak;
  }
  statuses.add(AchievementStatus(
    achievement: _streakMilestone,
    currentProgress: longestStreak,
  ));

  return statuses;
}

/// あと1つで達成できる実績（未達成かつ残り目標数が1）の一覧。
List<AchievementStatus> nearCompletionAchievements(
  List<AchievementStatus> statuses,
) {
  return statuses
      .where((s) => !s.achieved && s.achievement.target - s.currentProgress == 1)
      .toList();
}
