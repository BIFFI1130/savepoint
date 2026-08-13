import '../../../core/supabase/supabase_client.dart';
import '../domain/game_log_stats.dart';

/// game_log_stats ビュー（全ユーザー集計の「遊んだ／遊びたい」件数）への読み取り専用アクセス。
class StatsRepository {
  Future<GameLogStats?> fetchStatsForGame(int gameId) async {
    final row = await supabase
        .from('game_log_stats')
        .select()
        .eq('game_id', gameId)
        .maybeSingle();
    if (row == null) return null;
    return GameLogStats.fromJson(row);
  }

  /// [genres] は複数選択可能で、選択されたうちどれか1つでも当てはまればOR条件で含める。
  Future<List<GameLogStats>> fetchTopWantToPlay({
    int limit = 20,
    bool includeAdult = false,
    Set<String> genres = const {},
  }) async {
    var query = supabase
        .from('game_log_stats')
        .select()
        .gt('want_to_play_count', 0);
    if (!includeAdult) {
      query = query.eq('is_adult', false);
    }
    if (genres.isNotEmpty) {
      query = query.overlaps('genres', genres.toList());
    }
    final rows =
        await query.order('want_to_play_count', ascending: false).limit(limit);
    return (rows as List)
        .cast<Map<String, dynamic>>()
        .map(GameLogStats.fromJson)
        .toList(growable: false);
  }

  /// [genres] は複数選択可能で、選択されたうちどれか1つでも当てはまればOR条件で含める。
  Future<List<GameLogStats>> fetchTopPlayed({
    int limit = 20,
    bool includeAdult = false,
    Set<String> genres = const {},
  }) async {
    var query =
        supabase.from('game_log_stats').select().gt('played_count', 0);
    if (!includeAdult) {
      query = query.eq('is_adult', false);
    }
    if (genres.isNotEmpty) {
      query = query.overlaps('genres', genres.toList());
    }
    final rows =
        await query.order('played_count', ascending: false).limit(limit);
    return (rows as List)
        .cast<Map<String, dynamic>>()
        .map(GameLogStats.fromJson)
        .toList(growable: false);
  }
}
