import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/preferences/content_filter_prefs.dart';
import '../../data/igdb_repository.dart';
import '../../domain/game.dart';

final igdbRepositoryProvider = Provider<IgdbRepository>((ref) {
  return IgdbRepository();
});

/// カテゴリ探索時の並び替え。igdb-proxy側のSORT_CLAUSESキーと合わせている。
/// タイトル検索中（クエリあり）は無視される（IGDBは検索と並び替えを併用できない）。
enum GameSortType {
  popularity('popularity'),
  name('name'),
  releaseDate('release_date');

  const GameSortType(this.value);
  final String value;
}

/// 検索結果のページング状態。[games] は読み込み済み全件（積み重ね）、
/// [hasMore] はさらに次のページがありそうか、[isLoadingMore] は
/// スクロールによる追加読み込み中かどうかを表す。
class GameSearchResults {
  const GameSearchResults({
    this.games = const [],
    this.hasMore = false,
    this.isLoadingMore = false,
  });

  final List<Game> games;
  final bool hasMore;
  final bool isLoadingMore;

  GameSearchResults copyWith({
    List<Game>? games,
    bool? hasMore,
    bool? isLoadingMore,
  }) {
    return GameSearchResults(
      games: games ?? this.games,
      hasMore: hasMore ?? this.hasMore,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
    );
  }
}

/// ゲーム検索の状態。[search]・[setPlatforms]・[setDeveloper]・[setGenres] を呼ぶと、
/// 内部でデバウンスしてから（プラットフォーム・ジャンル選択のみ即時に）検索をやり直す。
/// [loadMore] で次のページを取得し、結果に積み重ねる（無限スクロール用）。
///
/// タイトル未入力でも [setGenres]・[setPlatforms]・[setDeveloper] のいずれかが
/// 選択されていれば「カテゴリ探索」として結果を返す。
/// [setPlatforms]・[setGenres] は複数選択可能で、選択されたうちどれか1つでも
/// 当てはまればOR条件で一覧に含める。
class GameSearchNotifier extends AsyncNotifier<GameSearchResults> {
  Timer? _debounce;
  String _query = '';
  Set<String> _platforms = {};
  String _developer = '';
  Set<String> _genres = {};
  GameSortType _sort = GameSortType.popularity;
  bool _includeUpcoming = false;
  late bool _includeAdult;
  late bool _includeIndie;

  @override
  FutureOr<GameSearchResults> build() {
    final prefs = ref.read(contentFilterPrefsProvider);
    _includeAdult = prefs.includeAdult;
    _includeIndie = prefs.includeIndie;
    ref.onDispose(() => _debounce?.cancel());
    return const GameSearchResults();
  }

  void search(String query) {
    _query = query;
    _schedule();
  }

  /// プラットフォームフィルタは選択肢をタップして選ぶだけなので即時反映する。
  void setPlatforms(Set<String> platforms) {
    _platforms = platforms;
    _schedule(immediate: true);
  }

  void setDeveloper(String developer) {
    _developer = developer;
    _schedule();
  }

  /// カテゴリ（ジャンル）チップも選ぶだけなので即時反映する。
  void setGenres(Set<String> genres) {
    _genres = genres;
    _schedule(immediate: true);
  }

  void setSort(GameSortType sort) {
    _sort = sort;
    _schedule(immediate: true);
  }

  GameSortType get sort => _sort;

  /// 発売時期順のときに、未発売（未来の発売日）作品も含めるかどうか。
  void setIncludeUpcoming(bool value) {
    _includeUpcoming = value;
    _schedule(immediate: true);
  }

  /// 成人向け作品も一覧に含めるかどうか（デフォルトfalse＝除外）。
  /// 設定はSharedPreferencesに永続化し、アプリ再起動後も保持する。
  void setIncludeAdult(bool value) {
    _includeAdult = value;
    ref.read(contentFilterPrefsProvider).setIncludeAdult(value);
    _schedule(immediate: true);
  }

  /// インディー作品を一覧から除外するかどうか（デフォルトtrue＝含める）。
  /// 設定はSharedPreferencesに永続化し、アプリ再起動後も保持する。
  void setIncludeIndie(bool value) {
    _includeIndie = value;
    ref.read(contentFilterPrefsProvider).setIncludeIndie(value);
    _schedule(immediate: true);
  }

  void _schedule({bool immediate = false}) {
    _debounce?.cancel();
    final hasQuery = _query.trim().isNotEmpty;
    final hasFilter =
        _genres.isNotEmpty || _platforms.isNotEmpty || _developer.isNotEmpty;
    if (!hasQuery && !hasFilter) {
      state = const AsyncData(GameSearchResults());
      return;
    }
    if (immediate) {
      _runSearch();
    } else {
      _debounce = Timer(const Duration(milliseconds: 450), _runSearch);
    }
  }

  Future<void> _runSearch() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final games = await ref.read(igdbRepositoryProvider).search(
            query: _query,
            platforms: _platforms,
            developer: _developer.isEmpty ? null : _developer,
            genres: _genres,
            sort: _sort.value,
            includeUpcoming: _includeUpcoming,
            includeAdult: _includeAdult,
            includeIndie: _includeIndie,
          );
      return GameSearchResults(
        games: games,
        hasMore: games.length >= IgdbRepository.pageSize,
      );
    });
  }

  /// 現在の検索条件のまま、次のページを取得して末尾に積み重ねる。
  Future<void> loadMore() async {
    final current = state.valueOrNull;
    if (current == null || current.isLoadingMore || !current.hasMore) return;

    state = AsyncData(current.copyWith(isLoadingMore: true));
    try {
      final more = await ref.read(igdbRepositoryProvider).search(
            query: _query,
            platforms: _platforms,
            developer: _developer.isEmpty ? null : _developer,
            genres: _genres,
            sort: _sort.value,
            includeUpcoming: _includeUpcoming,
            includeAdult: _includeAdult,
            includeIndie: _includeIndie,
            offset: current.games.length,
          );
      state = AsyncData(
        GameSearchResults(
          games: [...current.games, ...more],
          hasMore: more.length >= IgdbRepository.pageSize,
        ),
      );
    } catch (_) {
      // 追加読み込みの失敗は全画面エラーにせず、次のスクロールで再試行できるようにする。
      state = AsyncData(current.copyWith(isLoadingMore: false));
    }
  }
}

final gameSearchProvider =
    AsyncNotifierProvider<GameSearchNotifier, GameSearchResults>(
  GameSearchNotifier.new,
);

/// ゲーム詳細（IGDB IDで取得）。
final gameDetailsProvider =
    FutureProvider.family<Game?, int>((ref, gameId) async {
  return ref.read(igdbRepositoryProvider).getDetails(gameId);
});
