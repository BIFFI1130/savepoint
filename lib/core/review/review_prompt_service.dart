import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:in_app_review/in_app_review.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../analytics/analytics_service.dart';

const _promptedKey = 'review_prompt_already_shown';

/// ストアレビュー依頼を「ユーザーが実際にアプリを使い込んだと言えるタイミング」で
/// 一度だけトリガーする。OS側（App Store/Google Play）も表示回数を自動的に
/// 制限しているが、アプリ側でも多重リクエストを避けるためSharedPreferencesで
/// 「一度でもリクエスト済みか」を記録する。
class ReviewPromptService {
  ReviewPromptService(this._ref);

  final Ref _ref;

  Future<void> maybeRequestReview() async {
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getBool(_promptedKey) ?? false) return;

    final inAppReview = InAppReview.instance;
    if (!await inAppReview.isAvailable()) return;

    await prefs.setBool(_promptedKey, true);
    await _ref.read(appAnalyticsProvider).logReviewPrompted();
    await inAppReview.requestReview();
  }
}

final reviewPromptServiceProvider = Provider<ReviewPromptService>((ref) {
  return ReviewPromptService(ref);
});
