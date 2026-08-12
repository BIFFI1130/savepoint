import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/favorite_repository.dart';
import '../../domain/favorite_game.dart';

final favoriteRepositoryProvider = Provider<FavoriteRepository>((ref) {
  return FavoriteRepository();
});

/// 自分の推しゲー一覧（登録順位順）。
final myFavoritesProvider = FutureProvider<List<FavoriteGameEntry>>((
  ref,
) async {
  return ref.read(favoriteRepositoryProvider).fetchMyFavorites();
});

/// 指定ユーザーの推しゲー一覧（フォロー中かつ公開プロフィールの場合のみ中身が返る）。
final favoritesForUserProvider =
    FutureProvider.family<List<FavoriteGameEntry>, String>((ref, userId) async {
      return ref.read(favoriteRepositoryProvider).fetchFavoritesForUser(userId);
    });
