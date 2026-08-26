import 'dart:async';
import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/supabase/supabase_client.dart';
import '../domain/game_log.dart';

const _myLogsCacheKey = 'cached_my_logs_v1';

class LogRepository {
  /// 自分が投稿した記録を、紐づくゲーム情報付きで新しい順に取得する。
  /// RLSにより自分の行しか返らないため、user_idでの絞り込みは不要。
  /// 取得に成功した内容は端末にキャッシュし、次回オフライン時などで通信に
  /// 失敗した場合はキャッシュ済みの内容（最後に取得できた状態）を返す
  /// （キャッシュが無ければ例外をそのまま投げる）。
  Future<List<GameLogWithGame>> fetchMyLogs() async {
    try {
      final rows = await supabase
          .from('game_logs')
          .select('*, games(*)')
          .order('updated_at', ascending: false);
      final rawList = (rows as List).cast<Map<String, dynamic>>();
      unawaited(_cacheMyLogs(rawList));
      return rawList.map(GameLogWithGame.fromJson).toList(growable: false);
    } catch (error) {
      final cached = await _loadCachedMyLogs();
      if (cached != null) return cached;
      rethrow;
    }
  }

  Future<void> _cacheMyLogs(List<Map<String, dynamic>> rawList) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_myLogsCacheKey, jsonEncode(rawList));
    } catch (_) {
      // キャッシュ保存の失敗は無視する（オフライン対応はベストエフォートのため）。
    }
  }

  Future<List<GameLogWithGame>?> _loadCachedMyLogs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_myLogsCacheKey);
      if (raw == null) return null;
      final decoded = (jsonDecode(raw) as List).cast<Map<String, dynamic>>();
      return decoded.map(GameLogWithGame.fromJson).toList(growable: false);
    } catch (_) {
      return null;
    }
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

  /// 「プレイ中」としてワンタップで記録する。既存の評価・レビューがあれば保持される
  /// （upsertのペイロードに含めない列はON CONFLICT時に上書きされないため）。
  Future<void> markPlaying(int gameId) async {
    final userId = supabase.auth.currentUser!.id;
    await supabase.from('game_logs').upsert(
      {
        'user_id': userId,
        'game_id': gameId,
        'status': GameLogStatus.playing.toDb(),
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
}
