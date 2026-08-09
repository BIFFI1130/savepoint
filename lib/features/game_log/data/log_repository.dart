import '../../../core/supabase/supabase_client.dart';
import '../domain/game_log.dart';

class LogRepository {
  /// 自分が投稿した記録を、紐づくゲーム情報付きで新しい順に取得する。
  /// RLSにより自分の行しか返らないため、user_idでの絞り込みは不要。
  Future<List<GameLogWithGame>> fetchMyLogs() async {
    final rows = await supabase
        .from('game_logs')
        .select('*, games(*)')
        .order('updated_at', ascending: false);

    return (rows as List)
        .cast<Map<String, dynamic>>()
        .map(GameLogWithGame.fromJson)
        .toList(growable: false);
  }

  /// 指定ゲームに対する自分の記録（未投稿ならnull）。
  Future<GameLog?> fetchLogForGame(int gameId) async {
    final row = await supabase
        .from('game_logs')
        .select()
        .eq('game_id', gameId)
        .maybeSingle();
    if (row == null) return null;
    return GameLog.fromJson(row);
  }

  /// 記録を新規作成 or 更新する（1ユーザー1ゲームにつき1件）。
  Future<void> upsertLog({
    required int gameId,
    required int rating,
    String? reviewText,
  }) async {
    final userId = supabase.auth.currentUser!.id;
    await supabase.from('game_logs').upsert(
      {
        'user_id': userId,
        'game_id': gameId,
        'rating': rating,
        'review_text': reviewText,
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      },
      onConflict: 'user_id,game_id',
    );
  }

  Future<void> deleteLog(String logId) async {
    await supabase.from('game_logs').delete().eq('id', logId);
  }
}
