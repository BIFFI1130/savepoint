import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/ads/interstitial_ad_service.dart';
import '../../data/favorite_repository.dart';
import '../../domain/favorite_game.dart';

final favoriteRepositoryProvider = Provider<FavoriteRepository>((ref) {
  return FavoriteRepository();
});

/// 推しゲー保存時に表示する全画面広告。編集画面が開いている間に事前読み込みし、
/// 保存完了直後に表示する。
final favoriteSaveAdProvider = Provider<InterstitialAdService>((ref) {
  return InterstitialAdService();
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
