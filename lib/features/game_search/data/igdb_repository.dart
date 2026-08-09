import '../../../core/supabase/supabase_client.dart';
import '../domain/game.dart';

/// IGDB検索は Supabase Edge Function `igdb-proxy` を経由して行う。
/// IGDB/TwitchのシークレットはFlutter側に一切持たせず、サーバー側（Edge Function）のみが保持する。
class IgdbRepository {
  Future<List<Game>> search(String query) async {
    if (query.trim().isEmpty) return [];

    final response = await supabase.functions.invoke(
      'igdb-proxy',
      body: {'action': 'search', 'query': query.trim()},
    );

    final data = response.data;
    if (data is! List) return [];
    return data
        .cast<Map<String, dynamic>>()
        .map(Game.fromJson)
        .toList(growable: false);
  }

  Future<Game?> getDetails(int gameId) async {
    final response = await supabase.functions.invoke(
      'igdb-proxy',
      body: {'action': 'details', 'id': gameId},
    );

    final data = response.data;
    if (data is! Map) return null;
    return Game.fromJson(data.cast<String, dynamic>());
  }
}
