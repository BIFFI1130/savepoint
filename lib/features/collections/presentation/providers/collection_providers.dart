import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/collection_repository.dart';
import '../../domain/collection.dart';

final collectionRepositoryProvider = Provider<CollectionRepository>((ref) {
  return CollectionRepository();
});

/// 自分のコレクション一覧。作成・削除後は `ref.invalidate(myCollectionsProvider)` で再取得する。
final myCollectionsProvider = FutureProvider<List<Collection>>((ref) async {
  return ref.read(collectionRepositoryProvider).fetchMyCollections();
});

final collectionProvider =
    FutureProvider.family<Collection?, String>((ref, id) async {
  return ref.read(collectionRepositoryProvider).fetchCollection(id);
});

final collectionGamesProvider =
    FutureProvider.family<List<CollectionGame>, String>((ref, id) async {
  return ref.read(collectionRepositoryProvider).fetchCollectionGames(id);
});

/// 指定ゲームが含まれているコレクションidの集合（追加シートの選択状態表示に使う）。
final collectionsForGameProvider =
    FutureProvider.family<Set<String>, int>((ref, gameId) async {
  return ref.read(collectionRepositoryProvider).fetchCollectionIdsForGame(gameId);
});
