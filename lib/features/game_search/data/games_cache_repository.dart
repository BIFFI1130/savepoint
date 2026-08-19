import '../../../core/supabase/supabase_client.dart';
import '../domain/game.dart';

/// IGDB Data Dumps（Data Partner限定機能）を取り込んでローカルにミラーした
/// `games`テーブルから、絞り込みのみで自由文検索を伴わない4つの一覧を返す。
/// SupabaseのPostgres関数（RPC、`supabase/migrations/20260820000000_add_igdb_dump_cache.sql`）
/// 経由で呼び出す。`games`テーブル自体はクライアントから直接SELECTさせず、
/// 固定シェイプ・件数上限を強制できるRPC越しにのみ公開している。
///
/// 自由文検索（search）・ゲーム詳細（details、Google翻訳等のライブなエンリッチメントを
/// 伴う）はこのリポジトリの対象外で、[IgdbRepository]（igdb-proxy経由）のまま。
class GamesCacheRepository {
  Future<List<Game>> weeklyReleases({
    Set<String> platforms = const {},
    Set<String> genres = const {},
    bool includeAdult = false,
    bool includeIndie = false,
  }) async {
    final data = await supabase.rpc('igdb_weekly_releases', params: {
      'p_platforms': platforms.toList(),
      'p_genres': genres.toList(),
      'p_include_adult': includeAdult,
      'p_include_indie': includeIndie,
    });
    return _toGames(data);
  }

  Future<List<Game>> monthlyReleases({
    Set<String> platforms = const {},
    Set<String> genres = const {},
    bool includeAdult = false,
    bool includeIndie = false,
  }) async {
    final data = await supabase.rpc('igdb_monthly_releases', params: {
      'p_platforms': platforms.toList(),
      'p_genres': genres.toList(),
      'p_include_adult': includeAdult,
      'p_include_indie': includeIndie,
    });
    return _toGames(data);
  }

  Future<List<Game>> top100({
    Set<String> platforms = const {},
    Set<String> genres = const {},
    bool includeAdult = false,
    bool includeIndie = false,
  }) async {
    final data = await supabase.rpc('igdb_top100', params: {
      'p_platforms': platforms.toList(),
      'p_genres': genres.toList(),
      'p_include_adult': includeAdult,
      'p_include_indie': includeIndie,
    });
    return _toGames(data);
  }

  Future<List<Game>> calendarRangeReleases({
    required DateTime rangeStart,
    required int days,
    Set<String> platforms = const {},
    Set<String> genres = const {},
    bool includeAdult = false,
    bool includeIndie = false,
  }) async {
    final rangeStartStr =
        '${rangeStart.year.toString().padLeft(4, '0')}-'
        '${rangeStart.month.toString().padLeft(2, '0')}-'
        '${rangeStart.day.toString().padLeft(2, '0')}';
    final data = await supabase.rpc('igdb_calendar_releases', params: {
      'p_range_start': rangeStartStr,
      'p_days': days,
      'p_platforms': platforms.toList(),
      'p_genres': genres.toList(),
      'p_include_adult': includeAdult,
      'p_include_indie': includeIndie,
    });
    return _toGames(data);
  }

  /// 取り込みが正常に稼働しているかの鮮度確認。最後に成功した取り込み時刻
  /// （なければnull）を返す。呼び出し側がこれを見て、古すぎる/取得できない
  /// 場合はライブ経路（[IgdbRepository]）にフォールバックする。
  Future<DateTime?> lastSuccessfulSync() async {
    final data = await supabase.rpc('igdb_dump_last_success');
    if (data == null) return null;
    return DateTime.tryParse(data as String);
  }

  List<Game> _toGames(dynamic data) {
    if (data is! List) return [];
    return data
        .cast<Map<String, dynamic>>()
        .map(Game.fromJson)
        .toList(growable: false);
  }
}
