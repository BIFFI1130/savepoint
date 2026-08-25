import '../../../core/supabase/supabase_client.dart';

/// プロフィール・レビューの閲覧数トラッキング（サブスク特典「閲覧数の分析」用）。
/// 誰が見たかではなく件数のみを本人に見せる。自分自身の閲覧はカウントしない。
class ViewAnalyticsRepository {
  String? get _myId => supabase.auth.currentUser?.id;

  Future<void> recordProfileView(String viewedUserId) async {
    final myId = _myId;
    if (myId == null || myId == viewedUserId) return;
    try {
      await supabase.from('profile_views').insert({
        'viewed_user_id': viewedUserId,
        'viewer_id': myId,
      });
    } catch (_) {
      // 閲覧数トラッキングの失敗はベストエフォート。画面表示には影響させない。
    }
  }

  Future<void> recordReviewView(String logId, String reviewOwnerId) async {
    final myId = _myId;
    if (myId == null || myId == reviewOwnerId) return;
    try {
      await supabase.from('game_log_views').insert({
        'log_id': logId,
        'viewer_id': myId,
      });
    } catch (_) {
      // 閲覧数トラッキングの失敗はベストエフォート。画面表示には影響させない。
    }
  }

  /// 自分のプロフィールの累計閲覧数。
  Future<int> fetchMyProfileViewCount() async {
    final myId = _myId;
    if (myId == null) return 0;
    final row = await supabase
        .from('profile_view_counts')
        .select('view_count')
        .eq('viewed_user_id', myId)
        .maybeSingle();
    return (row?['view_count'] as num?)?.toInt() ?? 0;
  }

  /// 自分の全レビューの累計閲覧数（合計）。
  Future<int> fetchMyReviewViewCountTotal() async {
    final myId = _myId;
    if (myId == null) return 0;
    final logRows = await supabase
        .from('game_logs')
        .select('id')
        .eq('user_id', myId);
    final logIds = (logRows as List)
        .cast<Map<String, dynamic>>()
        .map((row) => row['id'] as String)
        .toList();
    if (logIds.isEmpty) return 0;

    final viewRows = await supabase
        .from('game_log_view_counts')
        .select('view_count')
        .inFilter('log_id', logIds);
    var total = 0;
    for (final row in (viewRows as List).cast<Map<String, dynamic>>()) {
      total += (row['view_count'] as num?)?.toInt() ?? 0;
    }
    return total;
  }
}
