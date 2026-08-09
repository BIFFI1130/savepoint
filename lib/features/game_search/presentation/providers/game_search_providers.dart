import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/igdb_repository.dart';
import '../../domain/game.dart';

final igdbRepositoryProvider = Provider<IgdbRepository>((ref) {
  return IgdbRepository();
});

/// ゲーム検索の状態。[search]・[setPlatform]・[setDeveloper] を呼ぶと、
/// 内部でデバウンスしてから（プラットフォーム選択のみ即時に）検索を実行する。
class GameSearchNotifier extends AsyncNotifier<List<Game>> {
  Timer? _debounce;
  String _query = '';
  String? _platform;
  String _developer = '';

  @override
  FutureOr<List<Game>> build() {
    ref.onDispose(() => _debounce?.cancel());
    return [];
  }

  void search(String query) {
    _query = query;
    _schedule();
  }

  /// プラットフォームフィルタは選択肢をタップして選ぶだけなので即時反映する。
  void setPlatform(String? platform) {
    _platform = platform;
    _schedule(immediate: true);
  }

  void setDeveloper(String developer) {
    _developer = developer;
    _schedule();
  }

  void _schedule({bool immediate = false}) {
    _debounce?.cancel();
    if (_query.trim().isEmpty) {
      state = const AsyncData([]);
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
    state = await AsyncValue.guard(
      () => ref.read(igdbRepositoryProvider).search(
            _query,
            platform: _platform,
            developer: _developer.isEmpty ? null : _developer,
          ),
    );
  }
}

final gameSearchProvider =
    AsyncNotifierProvider<GameSearchNotifier, List<Game>>(
  GameSearchNotifier.new,
);

/// ゲーム詳細（IGDB IDで取得）。
final gameDetailsProvider =
    FutureProvider.family<Game?, int>((ref, gameId) async {
  return ref.read(igdbRepositoryProvider).getDetails(gameId);
});
