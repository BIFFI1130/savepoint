import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../../core/supabase/supabase_client.dart';

class LikeRepository {
  String get _myId => supabase.auth.currentUser!.id;

  /// 指定したログID群のいいね数。0件のログはキーごと省略される（呼び出し側で
  /// 存在しないキーは0件として扱う）。
  Future<Map<String, int>> fetchLikeCounts(List<String> logIds) async {
    if (logIds.isEmpty) return {};
    final rows = await supabase
        .from('game_log_like_counts')
        .select()
        .inFilter('log_id', logIds);
    return {
      for (final row in (rows as List).cast<Map<String, dynamic>>())
        row['log_id'] as String: row['like_count'] as int,
    };
  }

  /// 指定したログID群のうち、自分がいいね済みのもの。
  Future<Set<String>> fetchMyLikedLogIds(List<String> logIds) async {
    if (logIds.isEmpty) return {};
    final rows = await supabase
        .from('game_log_likes')
        .select('log_id')
        .inFilter('log_id', logIds);
    return (rows as List)
        .cast<Map<String, dynamic>>()
        .map((row) => row['log_id'] as String)
        .toSet();
  }

  Future<void> like(String logId) async {
    await supabase.from('game_log_likes').insert({
      'log_id': logId,
      'user_id': _myId,
    });
    unawaited(_notifyNewLike(logId));
  }

  /// 記録の投稿者へ、いいねされたことをプッシュ通知する（notify-new-like
  /// Edge Function）。ベストエフォートの副作用のため、失敗してもいいね自体の
  /// 成功には影響させない。
  Future<void> _notifyNewLike(String logId) async {
    try {
      await supabase.functions.invoke(
        'notify-new-like',
        body: {'log_id': logId},
      );
    } catch (error, stackTrace) {
      debugPrint('notifyNewLike failed: $error\n$stackTrace');
    }
  }

  Future<void> unlike(String logId) async {
    await supabase
        .from('game_log_likes')
        .delete()
        .eq('log_id', logId)
        .eq('user_id', _myId);
  }
}
