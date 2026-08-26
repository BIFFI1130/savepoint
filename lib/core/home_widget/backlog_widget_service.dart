import 'dart:convert';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/foundation.dart';
import 'package:home_widget/home_widget.dart';

import '../../features/game_log/domain/game_log.dart';
import '../../features/game_log/domain/weekly_streak.dart';
import '../../features/summary/domain/period_summary.dart';
import '../utils/nearest_upcoming_backlog_entry.dart';
import '../utils/todays_releasing_backlog_entries.dart';

/// 積みゲー（「遊びたい」）の中で発売が一番近い作品、本日発売の作品一覧、
/// 週間記録ストリーク、今月の記録本数を、ホーム画面ウィジェット
/// （Android: BacklogWidgetProvider/TodayReleasesWidgetProvider/
/// StreakWidgetProvider/MonthlyStatsWidgetProvider、iOS: BacklogWidget/
/// TodayReleasesWidget/StreakWidget/MonthlyStatsWidget）向けに同期する。
/// 失敗しても握りつぶし、アプリの動作をブロックしない
/// （ReleaseReminderService等と同じ方針）。
class BacklogWidgetService {
  const BacklogWidgetService();

  static const _androidProviderName = 'BacklogWidgetProvider';
  static const _iosWidgetName = 'BacklogWidget';
  static const _androidTodayReleasesProviderName =
      'TodayReleasesWidgetProvider';
  static const _iosTodayReleasesWidgetName = 'TodayReleasesWidget';
  static const _androidStreakProviderName = 'StreakWidgetProvider';
  static const _iosStreakWidgetName = 'StreakWidget';
  static const _androidMonthlyStatsProviderName = 'MonthlyStatsWidgetProvider';
  static const _iosMonthlyStatsWidgetName = 'MonthlyStatsWidget';

  /// ギャラリーウィジェットに表示する最大件数（Android RemoteViewsが固定スロット
  /// 数しか持てないため、ネイティブ側のレイアウトもこの件数に合わせて作られている）。
  static const _maxTodayReleases = 4;

  Future<void> sync(List<GameLogWithGame> logs) async {
    try {
      await _syncNearest(logs);
      await _syncTodayReleases(logs);
      await _syncStreak(logs);
      await _syncMonthlyStats(logs);
      await HomeWidget.updateWidget(
        androidName: _androidProviderName,
        iOSName: _iosWidgetName,
      );
      await HomeWidget.updateWidget(
        androidName: _androidTodayReleasesProviderName,
        iOSName: _iosTodayReleasesWidgetName,
      );
      await HomeWidget.updateWidget(
        androidName: _androidStreakProviderName,
        iOSName: _iosStreakWidgetName,
      );
      await HomeWidget.updateWidget(
        androidName: _androidMonthlyStatsProviderName,
        iOSName: _iosMonthlyStatsWidgetName,
      );
    } catch (error, stackTrace) {
      debugPrint('BacklogWidgetService.sync failed: $error\n$stackTrace');
    }
  }

  Future<void> _syncNearest(List<GameLogWithGame> logs) async {
    final nearest = nearestUpcomingBacklogEntry(logs);
    if (nearest == null) {
      await HomeWidget.saveWidgetData<String?>('backlog_title', null);
      await HomeWidget.saveWidgetData<String?>('backlog_release_date', null);
      await HomeWidget.saveWidgetData<String?>('backlog_game_id', null);
      await HomeWidget.saveWidgetData<String?>('backlog_cover_image', null);
      return;
    }

    final releaseDate = nearest.game.firstReleaseDate!;
    final releaseDateIso = releaseDate.toIso8601String().substring(0, 10);
    await HomeWidget.saveWidgetData<String>(
      'backlog_title',
      nearest.game.displayName,
    );
    await HomeWidget.saveWidgetData<String>(
      'backlog_release_date',
      releaseDateIso,
    );
    await HomeWidget.saveWidgetData<String>(
      'backlog_game_id',
      nearest.game.id.toString(),
    );

    final coverPath = await _saveCoverImage(
      'backlog_cover_image',
      nearest.game.coverUrl,
    );
    await HomeWidget.saveWidgetData<String?>('backlog_cover_image', coverPath);
  }

  /// 週間記録ストリークをウィジェットに同期する（0週なら空文字にして非表示）。
  /// ストリーク単体ウィジェット（StreakWidget）向けに、数字とラベルも別途保存する。
  Future<void> _syncStreak(List<GameLogWithGame> logs) async {
    final streak = currentWeeklyStreak(logs);
    await HomeWidget.saveWidgetData<String>(
      'backlog_streak',
      streak >= 1 ? '🔥$streak週連続' : '',
    );
    await HomeWidget.saveWidgetData<String>(
      'streak_widget_count',
      streak.toString(),
    );
    await HomeWidget.saveWidgetData<String>(
      'streak_widget_label',
      streak >= 1 ? '週連続で記録中' : '週間記録ストリーク',
    );
  }

  /// 今月「遊んだ」件数・新規に「遊びたい」に追加した件数を、今月の統計ウィジェット
  /// （MonthlyStatsWidget）向けに同期する。
  Future<void> _syncMonthlyStats(List<GameLogWithGame> logs) async {
    final now = DateTime.now();
    final summary = summarizePeriod(
      logs,
      periodStart: DateTime(now.year, now.month),
      periodType: SummaryPeriodType.month,
    );
    await HomeWidget.saveWidgetData<String>(
      'monthly_stats_month_label',
      '${now.month}月の記録',
    );
    await HomeWidget.saveWidgetData<String>(
      'monthly_stats_played_count',
      summary.playedCount.toString(),
    );
    await HomeWidget.saveWidgetData<String>(
      'monthly_stats_want_to_play_count',
      summary.wantToPlayAddedCount.toString(),
    );
  }

  Future<void> _syncTodayReleases(List<GameLogWithGame> logs) async {
    final todaysReleases = todaysReleasingBacklogEntries(
      logs,
    ).take(_maxTodayReleases);

    final items = <Map<String, String?>>[];
    var index = 0;
    for (final entry in todaysReleases) {
      final coverPath = await _saveCoverImage(
        'today_release_image_$index',
        entry.game.coverUrl,
      );
      items.add({
        'id': entry.game.id.toString(),
        'title': entry.game.displayName,
        'image': coverPath,
      });
      index++;
    }

    await HomeWidget.saveWidgetData<String>(
      'today_releases_json',
      jsonEncode(items),
    );
  }

  /// [coverUrl]をPNGとしてウィジェット共有ストレージに保存し、保存先のファイル
  /// パスを返す。URLが無い、またはダウンロード・保存に失敗した場合はnull
  /// （ネイティブ側はnullの場合、画像を表示せずテキストのみにフォールバックする）。
  Future<String?> _saveCoverImage(String key, String? coverUrl) async {
    if (coverUrl == null || coverUrl.isEmpty) return null;
    try {
      return await HomeWidget.saveImage(
        key,
        CachedNetworkImageProvider(coverUrl),
      );
    } catch (error, stackTrace) {
      debugPrint(
        'BacklogWidgetService._saveCoverImage failed for $key: $error\n$stackTrace',
      );
      return null;
    }
  }
}
