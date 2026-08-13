import '../../../core/supabase/supabase_client.dart';
import '../domain/game.dart';

/// IGDB検索は Supabase Edge Function `igdb-proxy` を経由して行う。
/// IGDB/TwitchのシークレットはFlutter側に一切持たせず、サーバー側（Edge Function）のみが保持する。
class IgdbRepository {
  /// 1ページあたりの件数。igdb-proxy側のSEARCH_PAGE_SIZEと一致させている。
  static const pageSize = 24;

  /// [query] が空でも、[genres]・[platforms]・[developer] のいずれかがあれば
  /// カテゴリ探索（タイトル検索なしの絞り込み）として問い合わせる。
  /// [platforms]・[genres] は複数選択可能で、選択されたうちどれか1つでも
  /// 当てはまればOR条件で一覧に含める。
  /// [offset] を指定すると、その件数分をスキップして次のページを取得する
  /// （呼び出し側で結果を積み重ねれば「もっと見る」を実現できる）。
  /// [sort] はタイトル検索（[query]あり）の場合は無視される。IGDBは検索キーワード
  /// 指定時、関連度順以外の並び替えを受け付けないため（併用すると400/406エラー）。
  /// [includeUpcoming] は sort が発売時期順の場合のみ意味を持つ。falseなら
  /// 未来の発売日（未発売作品）を除外する。
  Future<List<Game>> search({
    String? query,
    Set<String> platforms = const {},
    String? developer,
    Set<String> genres = const {},
    String? sort,
    bool includeUpcoming = false,
    bool includeAdult = false,
    bool includeIndie = false,
    int offset = 0,
  }) async {
    final trimmedQuery = query?.trim() ?? '';
    final hasFilter = platforms.isNotEmpty ||
        (developer != null && developer.isNotEmpty) ||
        genres.isNotEmpty;
    if (trimmedQuery.isEmpty && !hasFilter) return [];

    final response = await supabase.functions.invoke(
      'igdb-proxy',
      body: {
        'action': 'search',
        if (trimmedQuery.isNotEmpty) 'query': trimmedQuery,
        if (platforms.isNotEmpty) 'platforms': platforms.toList(),
        if (developer != null && developer.isNotEmpty) 'developer': developer,
        if (genres.isNotEmpty) 'genres': genres.toList(),
        if (trimmedQuery.isEmpty && sort != null) 'sort': sort,
        if (trimmedQuery.isEmpty && includeUpcoming) 'includeUpcoming': true,
        if (includeAdult) 'includeAdult': true,
        if (includeIndie) 'includeIndie': true,
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

  /// 今週（月曜〜日曜）発売のゲーム一覧。人気順（評価数の多い順）。
  /// [platforms]・[genres] は複数選択可能で、選択されたうちどれか1つでも
  /// 当てはまればOR条件で含める。
  Future<List<Game>> weeklyReleases({
    Set<String> platforms = const {},
    Set<String> genres = const {},
    bool includeAdult = false,
    bool includeIndie = false,
  }) async {
    final response = await supabase.functions.invoke(
      'igdb-proxy',
      body: {
        'action': 'weekly_releases',
        if (platforms.isNotEmpty) 'platforms': platforms.toList(),
        if (genres.isNotEmpty) 'genres': genres.toList(),
        if (includeAdult) 'includeAdult': true,
        if (includeIndie) 'includeIndie': true,
      },
    );

    final data = response.data;
    if (data is! List) return [];
    return data
        .cast<Map<String, dynamic>>()
        .map(Game.fromJson)
        .toList(growable: false);
  }

  /// 今月（1日〜月末）発売のゲーム一覧。人気順（評価数の多い順）。
  /// [platforms]・[genres] は複数選択可能で、選択されたうちどれか1つでも
  /// 当てはまればOR条件で含める。
  Future<List<Game>> monthlyReleases({
    Set<String> platforms = const {},
    Set<String> genres = const {},
    bool includeAdult = false,
    bool includeIndie = false,
  }) async {
    final response = await supabase.functions.invoke(
      'igdb-proxy',
      body: {
        'action': 'monthly_releases',
        if (platforms.isNotEmpty) 'platforms': platforms.toList(),
        if (genres.isNotEmpty) 'genres': genres.toList(),
        if (includeAdult) 'includeAdult': true,
        if (includeIndie) 'includeIndie': true,
      },
    );

    final data = response.data;
    if (data is! List) return [];
    return data
        .cast<Map<String, dynamic>>()
        .map(Game.fromJson)
        .toList(growable: false);
  }

  /// IGDB公式のTop 100（https://www.igdb.com/top-100/games）と同じ考え方の
  /// 加重評価（weighted rating）順トップ100。発売日による絞り込みは行わない。
  /// [platforms]・[genres] は複数選択可能で、選択されたうちどれか1つでも
  /// 当てはまればOR条件で含める。
  Future<List<Game>> top100({
    Set<String> platforms = const {},
    Set<String> genres = const {},
    bool includeAdult = false,
    bool includeIndie = false,
  }) async {
    final response = await supabase.functions.invoke(
      'igdb-proxy',
      body: {
        'action': 'top100',
        if (platforms.isNotEmpty) 'platforms': platforms.toList(),
        if (genres.isNotEmpty) 'genres': genres.toList(),
        if (includeAdult) 'includeAdult': true,
        if (includeIndie) 'includeIndie': true,
      },
    );

    final data = response.data;
    if (data is! List) return [];
    return data
        .cast<Map<String, dynamic>>()
        .map(Game.fromJson)
        .toList(growable: false);
  }

  /// カレンダー表示用: 指定した年月に発売予定・発売済みのゲーム一覧（発売日昇順）。
  /// [platforms]・[genres] は複数選択可能で、選択されたうちどれか1つでも
  /// 当てはまればOR条件で含める。
  Future<List<Game>> calendarReleases({
    required int year,
    required int month,
    Set<String> platforms = const {},
    Set<String> genres = const {},
    bool includeAdult = false,
    bool includeIndie = false,
  }) async {
    final response = await supabase.functions.invoke(
      'igdb-proxy',
      body: {
        'action': 'calendar_releases',
        'year': year,
        'month': month,
        if (platforms.isNotEmpty) 'platforms': platforms.toList(),
        if (genres.isNotEmpty) 'genres': genres.toList(),
        if (includeAdult) 'includeAdult': true,
        if (includeIndie) 'includeIndie': true,
      },
    );

    final data = response.data;
    if (data is! List) return [];
    return data
        .cast<Map<String, dynamic>>()
        .map(Game.fromJson)
        .toList(growable: false);
  }
}
