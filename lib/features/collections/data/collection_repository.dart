import '../../../core/supabase/supabase_client.dart';
import '../domain/collection.dart';

class CollectionRepository {
  /// 自分のコレクション一覧（件数・カバー付き）を新しい順に取得する。
  Future<List<Collection>> fetchMyCollections() async {
    final rows = await supabase
        .from('collection_summary')
        .select()
        .order('created_at', ascending: false);
    return (rows as List)
        .cast<Map<String, dynamic>>()
        .map(Collection.fromJson)
        .toList(growable: false);
  }

  Future<Collection?> fetchCollection(String id) async {
    final row = await supabase
        .from('collection_summary')
        .select()
        .eq('id', id)
        .maybeSingle();
    if (row == null) return null;
    return Collection.fromJson(row);
  }

  /// 指定コレクションに含まれる作品を、追加した新しい順に取得する。
  Future<List<CollectionGame>> fetchCollectionGames(String collectionId) async {
    final rows = await supabase
        .from('collection_games')
        .select('added_at, games(*)')
        .eq('collection_id', collectionId)
        .order('added_at', ascending: false);
    return (rows as List)
        .cast<Map<String, dynamic>>()
        .map(CollectionGame.fromJson)
        .toList(growable: false);
  }

  Future<String> createCollection(String name) async {
    final userId = supabase.auth.currentUser!.id;
    final row = await supabase
        .from('collections')
        .insert({'user_id': userId, 'name': name})
        .select('id')
        .single();
    return row['id'] as String;
  }

  Future<void> renameCollection(String id, String name) async {
    await supabase.from('collections').update({
      'name': name,
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    }).eq('id', id);
  }

  Future<void> deleteCollection(String id) async {
    await supabase.from('collections').delete().eq('id', id);
  }

  Future<void> addGame(String collectionId, int gameId) async {
    final userId = supabase.auth.currentUser!.id;
    await supabase.from('collection_games').upsert(
      {
        'collection_id': collectionId,
        'game_id': gameId,
        'user_id': userId,
      },
      onConflict: 'collection_id,game_id',
    );
  }

  Future<void> removeGame(String collectionId, int gameId) async {
    await supabase
        .from('collection_games')
        .delete()
        .eq('collection_id', collectionId)
        .eq('game_id', gameId);
  }

  /// 指定ゲームが含まれているコレクションのidの集合（追加シートの選択状態表示用）。
  Future<Set<String>> fetchCollectionIdsForGame(int gameId) async {
    final rows = await supabase
        .from('collection_games')
        .select('collection_id')
        .eq('game_id', gameId);
    return (rows as List)
        .cast<Map<String, dynamic>>()
        .map((row) => row['collection_id'] as String)
        .toSet();
  }
}
