import '../../../core/supabase/supabase_client.dart';
import '../domain/game.dart';

/// IGDB検索は Supabase Edge Function `igdb-proxy` を経由して行う。
/// IGDB/TwitchのシークレットはFlutter側に一切持たせず、サーバー側（Edge Function）のみが保持する。
class IgdbRepository {
  /// 1ページあたりの件数。igdb-proxy側のSEARCH_PAGE_SIZEと一致させている。
  static const pageSize = 24;

  /// [query] が空でも、[genre]・[platform]・[developer] のいずれかがあれば
  /// カテゴリ探索（タイトル検索なしの絞り込み）として問い合わせる。
  /// [offset] を指定すると、その件数分をスキップして次のページを取得する
  /// （呼び出し側で結果を積み重ねれば「もっと見る」を実現できる）。
  /// [sort] はタイトル検索（[query]あり）の場合は無視される。IGDBは検索キーワード
  /// 指定時、関連度順以外の並び替えを受け付けないため（併用すると400/406エラー）。
  /// [includeUpcoming] は sort が発売時期順の場合のみ意味を持つ。falseなら
  /// 未来の発売日（未発売作品）を除外する。
  Future<List<Game>> search({
    String? query,
    String? platform,
    String? developer,
    String? genre,
    String? sort,
    bool includeUpcoming = false,
    int offset = 0,
  }) async {
    final trimmedQuery = query?.trim() ?? '';
    final hasFilter = (platform != null && platform.isNotEmpty) ||
        (developer != null && developer.isNotEmpty) ||
        (genre != null && genre.isNotEmpty);
    if (trimmedQuery.isEmpty && !hasFilter) return [];

    final response = await supabase.functions.invoke(
      'igdb-proxy',
      body: {
        'action': 'search',
        if (trimmedQuery.isNotEmpty) 'query': trimmedQuery,
        if (platform != null && platform.isNotEmpty) 'platform': platform,
        if (developer != null && developer.isNotEmpty) 'developer': developer,
        if (genre != null && genre.isNotEmpty) 'genre': genre,
        if (trimmedQuery.isEmpty && sort != null) 'sort': sort,
        if (trimmedQuery.isEmpty && includeUpcoming) 'includeUpcoming': true,
        if (offset > 0) 'offset': offset,
      },
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
