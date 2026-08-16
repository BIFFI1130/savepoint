import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../game_search/domain/game.dart';
import '../../../game_search/presentation/providers/game_search_providers.dart';

/// カレンダー画面の絞り込み条件。[platforms]・[genres] は複数選択可能
/// （選択されたうちどれか1つでも当てはまればOR条件で含める）。
typedef CalendarFilter = ({
  Set<String> platforms,
  Set<String> genres,
  bool includeAdult,
  bool includeIndie,
});

/// 表示中の日付範囲の開始日＋日数＋絞り込み条件。この組み合わせ単位でリクエストを
/// キャッシュする。デイリー表示で使う（表示中の日の前後をまとめて取得しておき、
/// 1日スワイプするたびに通信しないようにするため）。
typedef CalendarRangeRequest = ({DateTime rangeStart, int days, CalendarFilter filter});

/// 指定した日付範囲（[CalendarRangeRequest.rangeStart]から[CalendarRangeRequest.days]日間）
/// に発売予定・発売済みのゲーム一覧（人気順）。
final calendarRangeReleasesProvider =
    FutureProvider.family<List<Game>, CalendarRangeRequest>((ref, request) async {
  return ref.read(igdbRepositoryProvider).calendarRangeReleases(
        rangeStart: request.rangeStart,
        days: request.days,
        platforms: request.filter.platforms,
        genres: request.filter.genres,
        includeAdult: request.filter.includeAdult,
        includeIndie: request.filter.includeIndie,
      );
});
