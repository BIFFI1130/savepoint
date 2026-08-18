import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../core/analytics/analytics_service.dart';
import '../../../../core/review/review_prompt_service.dart';
import '../../../collections/presentation/providers/collection_providers.dart';
import '../../../game_log/presentation/providers/log_providers.dart';
import '../../domain/achievement.dart';

const _seenAchievementsKey = 'seen_achievement_ids';

/// マイログ・コレクションの変化を監視し、新しく解放された実績を検出する。
/// [evaluateAchievements] は毎回全件を再計算する純粋関数のため、
/// 「前回まで解放していなかったが今回解放された」実績はSharedPreferencesに
/// 保存した「見た実績ID一覧」との差分で判定する。
///
/// 新規解放があれば、実績ごとにアナリティクスイベントを送り、
/// ストアレビュー依頼のトリガーとしても使う。
/// 初回起動時（見た実績IDが1件も無い状態）は、既存データの移行等で
/// 大量の実績が一度に「新規解放」扱いになるのを避けるため、記録だけ行い
/// イベント送信・レビュー依頼は行わない。
final newlyUnlockedAchievementsProvider = FutureProvider<List<Achievement>>((ref) async {
  final logs = await ref.watch(myLogsProvider.future);
  final collections = await ref.watch(myCollectionsProvider.future);
  final statuses = evaluateAchievements(logs, collections);
  final achievedIds = statuses.where((s) => s.achieved).map((s) => s.achievement.id).toSet();

  final prefs = await SharedPreferences.getInstance();
  final seenIds = (prefs.getStringList(_seenAchievementsKey) ?? const []).toSet();
  final isFirstRun = seenIds.isEmpty;
  final newlyUnlockedIds = achievedIds.difference(seenIds);

  if (achievedIds.difference(seenIds).isNotEmpty || seenIds.difference(achievedIds).isNotEmpty) {
    await prefs.setStringList(_seenAchievementsKey, achievedIds.toList());
  }

  if (newlyUnlockedIds.isEmpty || isFirstRun) return const [];

  final analytics = ref.read(appAnalyticsProvider);
  for (final id in newlyUnlockedIds) {
    await analytics.logAchievementUnlocked(id);
  }
  await ref.read(reviewPromptServiceProvider).maybeRequestReview();

  return statuses
      .where((s) => newlyUnlockedIds.contains(s.achievement.id))
      .map((s) => s.achievement)
      .toList();
});
