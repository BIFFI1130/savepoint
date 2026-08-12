import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/widgets/advanced_filters_section.dart';
import '../../../../core/widgets/async_state_views.dart';
import '../../../../core/widgets/cover_image.dart';
import '../../../../core/widgets/genre_badge_selector.dart';
import '../../../game_search/domain/game.dart';
import '../../../game_search/domain/platform_options.dart';
import '../providers/home_providers.dart';
import 'release_list_screen.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  final Set<String> _selectedPlatforms = {};
  final Set<String> _selectedGenres = {};
  bool _includeAdult = false;
  bool _includeIndie = false;

  void _onPlatformTap(String value) {
    setState(() {
      if (_selectedPlatforms.contains(value)) {
        _selectedPlatforms.remove(value);
      } else {
        _selectedPlatforms.add(value);
      }
    });
  }

  void _onGenreTap(String value) {
    setState(() {
      if (_selectedGenres.contains(value)) {
        _selectedGenres.remove(value);
      } else {
        _selectedGenres.add(value);
      }
    });
  }

  void _onIncludeAdultChanged(bool value) {
    setState(() => _includeAdult = value);
  }

  void _onIncludeIndieChanged(bool value) {
    setState(() => _includeIndie = value);
  }

  @override
  Widget build(BuildContext context) {
    final filter = (
      platforms: _selectedPlatforms,
      genres: _selectedGenres,
      includeAdult: _includeAdult,
      includeIndie: _includeIndie,
    );
    final releasesAsync = ref.watch(weeklyReleasesProvider(filter));
    final monthlyReleasesAsync = ref.watch(monthlyReleasesProvider(filter));
    final top100Async = ref.watch(top100Provider(filter));

    return Scaffold(
      appBar: AppBar(title: const Text('ホーム')),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Divider(height: 24),
            _SectionHeader(
              title: '今週発売のゲーム',
              onTap: () => context.push('/home/weekly', extra: filter),
            ),
            releasesAsync.when(
              data: (games) {
                if (games.isEmpty) {
                  return const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16, vertical: 24),
                    child: Text('今週発売予定のタイトルは見つかりませんでした'),
                  );
                }
                return _CoverCarousel(games: games);
              },
              loading: () => const SizedBox(
                height: 160,
                child: LoadingView(),
              ),
              error: (error, _) => Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: ErrorView(
                  message: '今週発売のゲームの取得に失敗しました',
                  onRetry: () => ref.invalidate(weeklyReleasesProvider(filter)),
                ),
              ),
            ),
            const SizedBox(height: 24),
            _SectionHeader(
              title: '今月発売のゲーム',
              onTap: () => context.push('/home/monthly', extra: filter),
            ),
            monthlyReleasesAsync.when(
              data: (games) {
                if (games.isEmpty) {
                  return const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16, vertical: 24),
                    child: Text('今月発売予定のタイトルは見つかりませんでした'),
                  );
                }
                return _CoverCarousel(games: games);
              },
              loading: () => const SizedBox(
                height: 160,
                child: LoadingView(),
              ),
              error: (error, _) => Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: ErrorView(
                  message: '今月発売のゲームの取得に失敗しました',
                  onRetry: () => ref.invalidate(monthlyReleasesProvider(filter)),
                ),
              ),
            ),
            const SizedBox(height: 24),
            _SectionHeader(
              title: 'IGDB：TOP100',
              onTap: () => context.push('/home/top100', extra: filter),
            ),
            top100Async.when(
              data: (games) {
                if (games.isEmpty) {
                  return const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16, vertical: 24),
                    child: Text('該当するタイトルは見つかりませんでした'),
                  );
                }
                return _CoverCarousel(games: games, showRank: true);
              },
              loading: () => const SizedBox(
                height: 160,
                child: LoadingView(),
              ),
              error: (error, _) => Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: ErrorView(
                  message: 'IGDB TOP100の取得に失敗しました',
                  onRetry: () => ref.invalidate(top100Provider(filter)),
                ),
              ),
            ),
            const SizedBox(height: 24),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              child: Text(
                'ゲーム情報提供: IGDB',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.outline,
                    ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// セクション見出し。タップ（見出しテキストまたは＞アイコン）すると、そのセクションを
/// 全件一覧できる画面（[ReleaseListScreen]）に遷移する。
class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title, required this.onTap});

  final String title;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 12, 8),
        child: Row(
          children: [
            Expanded(
              child: Text(
                title,
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
            Icon(
              Icons.chevron_right,
              color: Theme.of(context).colorScheme.outline,
            ),
          ],
        ),
      ),
    );
  }
}

/// ゲームカバーの横スクロール一覧。[showRank] を有効にすると各カードの左上に
/// 順位（1始まり）バッジを重ねて表示する（IGDB TOP100用）。
class _CoverCarousel extends StatelessWidget {
  const _CoverCarousel({required this.games, this.showRank = false});

  final List<Game> games;
  final bool showRank;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 160,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: games.length,
        separatorBuilder: (context, index) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final game = games[index];
          final cover = ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: CoverImage(url: game.coverUrl, width: 110, height: 160),
          );
          return GestureDetector(
            onTap: () => context.push('/games/${game.id}'),
            child: showRank
                ? Stack(
                    children: [
                      cover,
                      Positioned(
                        top: 4,
                        left: 4,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.black54,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            '${index + 1}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    ],
                  )
                : cover,
          );
        },
      ),
    );
  }
}
