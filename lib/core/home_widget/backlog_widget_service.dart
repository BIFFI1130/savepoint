import 'package:flutter/foundation.dart';
import 'package:home_widget/home_widget.dart';

import '../../features/game_log/domain/game_log.dart';
import '../utils/nearest_upcoming_backlog_entry.dart';

/// 積みゲー（「遊びたい」）の中で発売が一番近い作品を、Androidのホーム画面
/// ウィジェット（BacklogWidgetProvider）向けに同期する。失敗しても握りつぶし、
/// アプリの動作をブロックしない（ReleaseReminderService等と同じ方針）。
class BacklogWidgetService {
  const BacklogWidgetService();

  static const _androidProviderName = 'BacklogWidgetProvider';
  static const _iosWidgetName = 'BacklogWidget';

  Future<void> sync(List<GameLogWithGame> logs) async {
    try {
      final nearest = nearestUpcomingBacklogEntry(logs);
      if (nearest == null) {
        await HomeWidget.saveWidgetData<String?>('backlog_title', null);
        await HomeWidget.saveWidgetData<String?>('backlog_release_date', null);
        await HomeWidget.saveWidgetData<String?>('backlog_game_id', null);
      } else {
        final releaseDate = nearest.game.firstReleaseDate!;
        final releaseDateIso =
            releaseDate.toIso8601String().substring(0, 10);
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
      }
      await HomeWidget.updateWidget(
        androidName: _androidProviderName,
        iOSName: _iosWidgetName,
      );
    } catch (error, stackTrace) {
      debugPrint('BacklogWidgetService.sync failed: $error\n$stackTrace');
    }
  }
}
