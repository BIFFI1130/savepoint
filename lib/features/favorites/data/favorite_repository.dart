import '../../../core/supabase/supabase_client.dart';
import '../domain/favorite_game.dart';

class FavoriteRepository {
  String get _myId => supabase.auth.currentUser!.id;

  /// favorite_games_feedはfollowsとのJOINを含むビューのため、PostgREST側の
  /// `.order()`だけでは並び順が保証されない。取得後にpositionでクライアント側
  /// ソートし直すことで、常に登録順位どおりに表示されるようにする。
  List<FavoriteGameEntry> _parseAndSort(List rows) {
    final entries = rows
        .cast<Map<String, dynamic>>()
        .map(FavoriteGameEntry.fromJson)
        .toList();
    entries.sort((a, b) => a.position.compareTo(b.position));
    return entries;
  }

  Future<List<FavoriteGameEntry>> fetchMyFavorites() async {
    final rows = await supabase
        .from('favorite_games_feed')
        .select()
        .eq('user_id', _myId);
    return _parseAndSort(rows as List);
  }

  /// フォロー中かつ公開プロフィールの場合のみ中身が返る（favorite_games_feedのRLS）。
  Future<List<FavoriteGameEntry>> fetchFavoritesForUser(String userId) async {
    final rows = await supabase
        .from('favorite_games_feed')
        .select()
        .eq('user_id', userId);
    return _parseAndSort(rows as List);
  }

  /// 推しゲーの一覧を丸ごと入れ替える（[gameIds]は最大5件、選んだ表示順）。
  /// [ranked]は順位あり（1位〜5位）で表示するか、順不同で表示するかを表す。
  Future<void> saveFavorites({
    required List<int> gameIds,
    required bool ranked,
  }) async {
    await supabase
        .from('profiles')
        .update({'favorites_ranked': ranked})
        .eq('id', _myId);
    await supabase.from('favorite_games').delete().eq('user_id', _myId);
    if (gameIds.isEmpty) return;
    await supabase.from('favorite_games').insert([
      for (var i = 0; i < gameIds.length; i++)
        {'user_id': _myId, 'game_id': gameIds[i], 'position': i + 1},
    ]);
  }
}
