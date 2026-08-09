import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/igdb_repository.dart';
import '../../domain/game.dart';

final igdbRepositoryProvider = Provider<IgdbRepository>((ref) {
  return IgdbRepository();
});

/// ゲーム検索の状態。入力のたびに [search] を呼ぶと、内部でデバウンスしてから検索を実行する。
class GameSearchNotifier extends AsyncNotifier<List<Game>> {
  Timer? _debounce;

  @override
  FutureOr<List<Game>> build() {
    ref.onDispose(() => _debounce?.cancel());
    return [];
  }

  void search(String query) {
    _debounce?.cancel();
    if (query.trim().isEmpty) {
      state = const AsyncData([]);
      return;
    }
    _debounce = Timer(const Duration(milliseconds: 450), () async {
      state = const AsyncLoading();
      state = await AsyncValue.guard(
        () => ref.read(igdbRepositoryProvider).search(query),
      );
    });
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
