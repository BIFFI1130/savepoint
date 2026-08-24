import 'package:flutter/foundation.dart';

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

  /// 「遊んだ」記録を新規作成 or 更新する（1ユーザー1ゲームにつき1件）。
  /// 評価は任意（未評価はratingにnullを保存し、星の統計には含めない）。
  Future<void> upsertPlayedLog({
    required int gameId,
    double? rating,
    String? reviewText,
    bool hasSpoiler = false,
    bool isCleared = false,
    GameLogVisibility visibility = GameLogVisibility.public,
  }) async {
    final userId = supabase.auth.currentUser!.id;
    await supabase.from('game_logs').upsert(
      {
        'user_id': userId,
        'game_id': gameId,
        'status': GameLogStatus.played.toDb(),
        'rating': rating,
        'review_text': reviewText,
        'has_spoiler': hasSpoiler,
        'is_cleared': isCleared,
        'visibility': visibility.dbValue,
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      },
      onConflict: 'user_id,game_id',
    );
  }

  /// 「遊びたい」としてワンタップで記録する。既存の評価・レビューがあれば保持される
  /// （upsertのペイロードに含めない列はON CONFLICT時に上書きされないため）。
  Future<void> markWantToPlay(int gameId) async {
    final userId = supabase.auth.currentUser!.id;
    await supabase.from('game_logs').upsert(
      {
        'user_id': userId,
        'game_id': gameId,
        'status': GameLogStatus.wantToPlay.toDb(),
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      },
      onConflict: 'user_id,game_id',
    );
  }

  Future<void> deleteLog(String logId) async {
    await supabase.from('game_logs').delete().eq('id', logId);
  }

  /// 「遊びたい」リストの優先度を設定する。nullで未設定に戻す。
  Future<void> setPriority(String logId, BacklogPriority? priority) async {
    await supabase
        .from('game_logs')
        .update({'priority': priority?.dbValue})
        .eq('id', logId);
  }

  /// フォロー中ユーザーの新着として、フォロワーへプッシュ通知する
  /// （notify-follow-activity Edge Function）。新規追加（初めての記録）の
  /// 場合のみ呼び出す想定で、既存記録の編集では呼ばない。
  /// ベストエフォートの副作用のため、失敗しても記録の保存自体には影響させない。
  Future<void> notifyFollowersOfNewLog({
    required int gameId,
    required GameLogStatus status,
    GameLogVisibility visibility = GameLogVisibility.public,
  }) async {
    try {
      await supabase.functions.invoke(
        'notify-follow-activity',
        body: {
          'game_id': gameId,
          'status': status.toDb(),
          'visibility': visibility.dbValue,
        },
      );
    } catch (error, stackTrace) {
      debugPrint('notifyFollowersOfNewLog failed: $error\n$stackTrace');
    }
  }
}
