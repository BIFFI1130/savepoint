import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/like_repository.dart';

final likeRepositoryProvider = Provider<LikeRepository>((ref) {
  return LikeRepository();
});

class LikesState {
  const LikesState({this.counts = const {}, this.likedByMe = const {}});

  final Map<String, int> counts;
  final Set<String> likedByMe;

  int countFor(String logId) => counts[logId] ?? 0;
  bool isLikedByMe(String logId) => likedByMe.contains(logId);
}

/// タイムライン等に表示されているログのいいね数・自分のいいね状態をまとめて扱う。
/// [ensureLoaded] は既に読み込み済みのログIDをスキップするので、表示中の一覧が
/// 更新されるたびに呼んでも無駄な通信は発生しない。
class LikesNotifier extends Notifier<LikesState> {
  final Set<String> _pending = {};

  @override
  LikesState build() => const LikesState();

  Future<void> ensureLoaded(Iterable<String> logIds) async {
    final missing = logIds
        .where((id) => !state.counts.containsKey(id) && !_pending.contains(id))
        .toList();
    if (missing.isEmpty) return;
    _pending.addAll(missing);
    try {
      final repo = ref.read(likeRepositoryProvider);
      final results = await Future.wait([
        repo.fetchLikeCounts(missing),
        repo.fetchMyLikedLogIds(missing),
      ]);
      final counts = results[0] as Map<String, int>;
      final liked = results[1] as Set<String>;
      state = LikesState(
        counts: {
          ...state.counts,
          for (final id in missing) id: counts[id] ?? 0,
        },
        likedByMe: {...state.likedByMe, ...liked},
      );
    } finally {
      _pending.removeAll(missing);
    }
  }

  /// いいね/取り消しを即座に画面へ反映し、裏でAPI呼び出しする。失敗時は元に戻す。
  Future<void> toggle(String logId) async {
    final wasLiked = state.isLikedByMe(logId);
    final previousCount = state.countFor(logId);
    state = LikesState(
      counts: {
        ...state.counts,
        logId: previousCount + (wasLiked ? -1 : 1),
      },
      likedByMe: wasLiked
          ? ({...state.likedByMe}..remove(logId))
          : ({...state.likedByMe}..add(logId)),
    );
    try {
      final repo = ref.read(likeRepositoryProvider);
      if (wasLiked) {
        await repo.unlike(logId);
      } else {
        await repo.like(logId);
      }
    } catch (_) {
      state = LikesState(
        counts: {...state.counts, logId: previousCount},
        likedByMe: wasLiked
            ? ({...state.likedByMe}..add(logId))
            : ({...state.likedByMe}..remove(logId)),
      );
    }
  }
}

final likesProvider = NotifierProvider<LikesNotifier, LikesState>(
  LikesNotifier.new,
);
