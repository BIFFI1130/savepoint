import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/preferences/content_filter_prefs.dart';
import '../../../../core/widgets/advanced_filters_section.dart';
import '../../../../core/widgets/async_state_views.dart';
import '../../../../core/widgets/game_sliver_grid.dart';
import '../../../../core/widgets/game_sliver_list.dart';
import '../../../../core/widgets/genre_filter_section.dart';
import '../../../../core/widgets/igdb_footer.dart';
import '../../../game_search/domain/game.dart';
import '../../../game_search/domain/platform_options.dart';
import '../../../social/presentation/providers/social_providers.dart';
import '../providers/home_providers.dart';

/// ホーム画面「あなたへのおすすめ」見出しの＞から遷移する全件一覧画面。
/// 母集団（関連作品の候補）が既に確定しているため、ジャンル・対応ハード・
/// 成人向け表示の絞り込みは他の一覧画面と違いクライアント側で行う
/// （「インディー作品を表示しない」は判定に必要なデータを持たないため対象外）。
class RecommendedGamesScreen extends ConsumerStatefulWidget {
  const RecommendedGamesScreen({super.key});

  @override
  ConsumerState<RecommendedGamesScreen> createState() =>
      _RecommendedGamesScreenState();
}

class _RecommendedGamesScreenState
    extends ConsumerState<RecommendedGamesScreen> {
  Set<String> _selectedPlatforms = {};
  Set<String> _selectedGenres = {};
  late bool _includeAdult;
  bool _isGridView = false;

  @override
  void initState() {
    super.initState();
    _includeAdult = ref.read(contentFilterPrefsProvider).includeAdult;
  }

  bool get _hasActiveFilter =>
      _selectedPlatforms.isNotEmpty || _selectedGenres.isNotEmpty || _includeAdult;

  List<Game> _applyFilter(List<Game> games) {
    return games.where((game) {
      if (_selectedPlatforms.isNotEmpty &&
          !game.platforms.any(_selectedPlatforms.contains)) {
        return false;
      }
      if (_selectedGenres.isNotEmpty &&
          !game.genres.any(_selectedGenres.contains)) {
        return false;
      }
      if (!_includeAdult && game.isAdult) return false;
      return true;
    }).toList(growable: false);
  }

  void _openFilterSheet() {
    final isAdultUser = ref.read(isAdultUserProvider);
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (sheetContext, setSheetState) {
            void toggleGenre(String value) {
              setState(() {
                _selectedGenres = _selectedGenres.contains(value)
                    ? ({..._selectedGenres}..remove(value))
                    : ({..._selectedGenres}..add(value));
              });
              setSheetState(() {});
            }

            void togglePlatform(String value) {
              setState(() {
                _selectedPlatforms = _selectedPlatforms.contains(value)
                    ? ({..._selectedPlatforms}..remove(value))
                    : ({..._selectedPlatforms}..add(value));
              });
              setSheetState(() {});
            }

            return DraggableScrollableSheet(
              expand: false,
              initialChildSize: 0.75,
              minChildSize: 0.4,
              maxChildSize: 0.95,
              builder: (context, scrollController) {
                return SingleChildScrollView(
                  controller: scrollController,
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('絞り込み', style: Theme.of(context).textTheme.titleMedium),
                          TextButton(
                            onPressed: () {
                              setState(() {
                                _selectedGenres = {};
                                _selectedPlatforms = {};
                                _includeAdult = false;
                              });
                              ref.read(contentFilterPrefsProvider).setIncludeAdult(false);
                              setSheetState(() {});
                            },
                            child: const Text('リセット'),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      GenreFilterSection(
                        selectedGenres: _selectedGenres,
                        onToggle: toggleGenre,
                      ),
                      const SizedBox(height: 16),
                      Text('対応ハード', style: Theme.of(context).textTheme.labelMedium),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          for (final option in platformOptions)
                            FilterChip(
                              label: Text(option.$1),
                              selected: _selectedPlatforms.contains(option.$2),
                              onSelected: (_) => togglePlatform(option.$2),
                            ),
                        ],
                      ),
                      AdvancedFiltersSection(
                        includeAdult: _includeAdult,
                        onIncludeAdultChanged: (value) {
                          setState(() => _includeAdult = value);
                          ref.read(contentFilterPrefsProvider).setIncludeAdult(value);
                          setSheetState(() {});
                        },
                        showAdultOption: isAdultUser,
                      ),
                    ],
                  ),
                );
              },
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final resultsAsync = ref.watch(recommendedGamesFullProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('あなたへのおすすめ'),
        actions: [
          IconButton(
            icon: Icon(
              _hasActiveFilter ? Icons.filter_alt : Icons.filter_alt_outlined,
              color: _hasActiveFilter ? Theme.of(context).colorScheme.primary : null,
            ),
            tooltip: '絞り込み',
            onPressed: _openFilterSheet,
          ),
          IconButton(
            onPressed: () => setState(() => _isGridView = !_isGridView),
            icon: Icon(_isGridView ? Icons.view_list : Icons.grid_view),
            tooltip: _isGridView ? 'リスト表示に切り替え' : 'グリッド表示に切り替え',
          ),
        ],
      ),
      body: CustomScrollView(
        slivers: [
          resultsAsync.when(
            data: (games) {
              final filtered = _applyFilter(games);
              if (filtered.isEmpty) {
                return const SliverFillRemaining(
                  hasScrollBody: false,
                  child: EmptyView(
                    message: '該当するタイトルは見つかりませんでした',
                    icon: Icons.videogame_asset_outlined,
                  ),
                );
              }
              return _isGridView
                  ? GameSliverGrid(games: filtered)
                  : GameSliverList(games: filtered);
            },
            loading: () => const SliverFillRemaining(
              hasScrollBody: false,
              child: LoadingView(),
            ),
            error: (error, _) => SliverFillRemaining(
              hasScrollBody: false,
              child: ErrorView(
                message: '取得に失敗しました',
                onRetry: () => ref.invalidate(recommendedGamesFullProvider),
              ),
            ),
          ),
          const IgdbFooterSliver(),
        ],
      ),
    );
  }
}
