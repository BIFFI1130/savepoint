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

/// 表示中の年月＋絞り込み条件。この組み合わせ単位でリクエストをキャッシュする。
typedef CalendarMonthRequest = ({int year, int month, CalendarFilter filter});

/// 指定した年月に発売予定・発売済みのゲーム一覧（発売日昇順）。
final calendarReleasesProvider =
    FutureProvider.family<List<Game>, CalendarMonthRequest>((ref, request) async {
  return ref.read(igdbRepositoryProvider).calendarReleases(
        year: request.year,
        month: request.month,
        platforms: request.filter.platforms,
        genres: request.filter.genres,
        includeAdult: request.filter.includeAdult,
        includeIndie: request.filter.includeIndie,
      );
});
