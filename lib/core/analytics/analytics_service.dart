import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final firebaseAnalyticsProvider = Provider<FirebaseAnalytics>((ref) {
  return FirebaseAnalytics.instance;
});

/// GoRouterのobserversに渡し、画面遷移を自動でFirebase Analyticsに送る。
final analyticsRouteObserverProvider = Provider<FirebaseAnalyticsObserver>((ref) {
  return FirebaseAnalyticsObserver(analytics: ref.watch(firebaseAnalyticsProvider));
});

/// アプリ内の主要な操作に対応するカスタムイベントをまとめたヘルパー。
/// 呼び出し側は各操作の成功直後に対応するメソッドを呼ぶだけでよい。
class AppAnalytics {
  const AppAnalytics(this._analytics);

  final FirebaseAnalytics _analytics;

  Future<void> logSignUp(String method) => _analytics.logSignUp(signUpMethod: method);

  Future<void> logLogin(String method) => _analytics.logLogin(loginMethod: method);

  Future<void> logRecordCreated({
    required String status,
    required bool hasRating,
    required bool hasReview,
  }) {
    return _analytics.logEvent(
      name: 'record_created',
      parameters: {
        'status': status,
        'has_rating': hasRating ? 1 : 0,
        'has_review': hasReview ? 1 : 0,
      },
    );
  }

  Future<void> logRecordDeleted() => _analytics.logEvent(name: 'record_deleted');

  Future<void> logSearch(String query) => _analytics.logSearch(searchTerm: query);

  Future<void> logCollectionCreated() =>
      _analytics.logEvent(name: 'collection_created');

  Future<void> logFollowUser() => _analytics.logEvent(name: 'follow_user');

  Future<void> logAchievementUnlocked(String achievementId) =>
      _analytics.logUnlockAchievement(id: achievementId);

  Future<void> logShare({required String contentType}) => _analytics.logShare(
        contentType: contentType,
        itemId: contentType,
        method: 'share_sheet',
      );

  Future<void> logReviewPrompted() =>
      _analytics.logEvent(name: 'review_prompted');

  Future<void> logBacklogReminderToggled(bool enabled) => _analytics.logEvent(
        name: 'backlog_reminder_toggled',
        parameters: {'enabled': enabled ? 1 : 0},
      );
}

final appAnalyticsProvider = Provider<AppAnalytics>((ref) {
  return AppAnalytics(ref.watch(firebaseAnalyticsProvider));
});
