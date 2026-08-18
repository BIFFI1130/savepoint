import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/analytics/analytics_service.dart';
import '../../../../core/widgets/advanced_filters_section.dart';
import '../../../../core/widgets/async_state_views.dart';
import '../../../../core/widgets/game_sliver_grid.dart';
import '../../../../core/widgets/game_sliver_list.dart';
import '../../../../core/widgets/genre_badge_selector.dart';
import '../../../social/presentation/providers/social_providers.dart';
import '../../domain/platform_options.dart';
import '../providers/game_search_providers.dart';

class GameSearchScreen extends ConsumerStatefulWidget {
  const GameSearchScreen({super.key});

  @override
  ConsumerState<GameSearchScreen> createState() => _GameSearchScreenState();
}

class _GameSearchScreenState extends ConsumerState<GameSearchScreen> {
  final _queryController = TextEditingController();
  final _developerController = TextEditingController();
  final _scrollController = ScrollController();
  final Set<String> _selectedPlatforms = {};
  final Set<String> _selectedGenres = {};
  String _queryText = '';
  GameSortType _sort = GameSortType.popularity;
  bool _includeUpcoming = false;
  bool _includeAdult = false;
  bool _includeIndie = false;
  Timer? _developerDebounce;
  Timer? _searchAnalyticsDebounce;
  bool _isGridView = false;

  bool get _hasActiveFilter =>
      _selectedPlatforms.isNotEmpty ||
      _selectedGenres.isNotEmpty ||
      _includeAdult ||
      _includeIndie ||
      _developerController.text.trim().isNotEmpty;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _queryController.dispose();
    _developerController.dispose();
    _developerDebounce?.cancel();
    _searchAnalyticsDebounce?.cancel();
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    final nearBottom =
        _scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 300;
    if (nearBottom) {
      ref.read(gameSearchProvider.notifier).loadMore();
    }
  }

  void _onDeveloperChanged(String value) {
    _developerDebounce?.cancel();
    _developerDebounce = Timer(const Duration(milliseconds: 450), () {
      ref.read(gameSearchProvider.notifier).setDeveloper(value);
      if (mounted) setState(() {});
    });
  }

  void _onQueryChanged(String value) {
    setState(() => _queryText = value);
    ref.read(gameSearchProvider.notifier).search(value);

    // 検索語のアナリティクス送信は、1文字ごとに送ると無意味にノイズが増えるため
    // 入力が落ち着いてからまとめて1回だけ送る。
    _searchAnalyticsDebounce?.cancel();
    final trimmed = value.trim();
    if (trimmed.isEmpty) return;
    _searchAnalyticsDebounce = Timer(const Duration(milliseconds: 800), () {
      ref.read(appAnalyticsProvider).logSearch(trimmed);
    });
  }

  void _clearQuery() {
    _queryController.clear();
    _onQueryChanged('');
  }

  void _onSortChanged(GameSortType sort) {
    setState(() => _sort = sort);
    ref.read(gameSearchProvider.notifier).setSort(sort);
  }

  void _onIncludeUpcomingChanged(bool value) {
    setState(() => _includeUpcoming = value);
    ref.read(gameSearchProvider.notifier).setIncludeUpcoming(value);
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
                if (_selectedGenres.contains(value)) {
                  _selectedGenres.remove(value);
                } else {
                  _selectedGenres.add(value);
                }
              });
              ref.read(gameSearchProvider.notifier).setGenres(_selectedGenres);
              setSheetState(() {});
            }

            void togglePlatform(String value) {
              setState(() {
                if (_selectedPlatforms.contains(value)) {
                  _selectedPlatforms.remove(value);
                } else {
                  _selectedPlatforms.add(value);
                }
              });
              ref.read(gameSearchProvider.notifier).setPlatforms(_selectedPlatforms);
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
                                _selectedGenres.clear();
                                _selectedPlatforms.clear();
                                _includeAdult = false;
                                _includeIndie = false;
                                _developerController.clear();
                              });
                              ref.read(gameSearchProvider.notifier)
                                ..setGenres(_selectedGenres)
                                ..setPlatforms(_selectedPlatforms)
                                ..setIncludeAdult(false)
                                ..setIncludeIndie(false)
                                ..setDeveloper('');
                              setSheetState(() {});
                            },
                            child: const Text('リセット'),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text('ジャンルから探す', style: Theme.of(context).textTheme.labelMedium),
                      const SizedBox(height: 8),
                      GenreBadgeSelector(
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
                          ref.read(gameSearchProvider.notifier).setIncludeAdult(value);
                          setSheetState(() {});
                        },
                        showAdultOption: isAdultUser,
                        includeIndie: _includeIndie,
                        onIncludeIndieChanged: (value) {
                          setState(() => _includeIndie = value);
                          ref.read(gameSearchProvider.notifier).setIncludeIndie(value);
                          setSheetState(() {});
                        },
                        children: [
                          Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: TextField(
                              controller: _developerController,
                              decoration: const InputDecoration(
                                labelText: '開発元で絞り込み（任意）',
                                hintText: '例：Nintendo',
                                prefixIcon: Icon(Icons.apartment_outlined),
                                border: OutlineInputBorder(),
                                isDense: true,
                              ),
                              onChanged: (value) {
                                _onDeveloperChanged(value);
                                setSheetState(() {});
                              },
                            ),
                          ),
                        ],
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
    final resultsAsync = ref.watch(gameSearchProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('ゲームを探す'),
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
        controller: _scrollController,
        slivers: [
          SliverToBoxAdapter(child: _buildHeader(context)),
          resultsAsync.when(
            data: (results) {
              if (results.games.isEmpty) {
                return const SliverFillRemaining(
                  hasScrollBody: false,
                  child: EmptyView(
                    message: 'ゲームタイトルを検索するか、\nジャンルを選んで探してみましょう',
                    icon: Icons.videogame_asset_outlined,
                  ),
                );
              }
              return _isGridView
                  ? GameSliverGrid(
                      games: results.games,
                      isLoadingMore: results.isLoadingMore,
                    )
                  : GameSliverList(
                      games: results.games,
                      isLoadingMore: results.isLoadingMore,
                    );
            },
            loading: () => const SliverFillRemaining(
              hasScrollBody: false,
              child: LoadingView(),
            ),
            error: (error, _) => SliverFillRemaining(
              hasScrollBody: false,
              child: ErrorView(
                message: 'ゲームの検索に失敗しました',
                onRetry: () => ref.invalidate(gameSearchProvider),
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Text(
                'ゲーム情報提供: IGDB',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.outline,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: TextField(
            controller: _queryController,
            decoration: InputDecoration(
              hintText: 'タイトルで検索',
              prefixIcon: const Icon(Icons.search),
              suffixIcon: _queryText.isEmpty
                  ? null
                  : IconButton(
                      icon: const Icon(Icons.clear),
                      tooltip: '検索文字列をクリア',
                      onPressed: _clearQuery,
                    ),
              border: const OutlineInputBorder(),
            ),
            onChanged: _onQueryChanged,
          ),
        ),
        _SortSelector(
          enabled: _queryText.trim().isEmpty,
          sort: _sort,
          onChanged: _onSortChanged,
          includeUpcoming: _includeUpcoming,
          onIncludeUpcomingChanged: _onIncludeUpcomingChanged,
        ),
        const SizedBox(height: 4),
        const Divider(height: 1),
      ],
    );
  }
}

const _sortLabels = <GameSortType, String>{
  GameSortType.popularity: '人気順',
  GameSortType.name: '辞書順',
  GameSortType.releaseDate: '発売時期順',
};

/// カテゴリ探索時の並び替え選択。タイトル検索中（[enabled] が false）は
/// 操作できない（IGDBは検索キーワードと並び替えを併用できないため）。
class _SortSelector extends StatelessWidget {
  const _SortSelector({
    required this.enabled,
    required this.sort,
    required this.onChanged,
    required this.includeUpcoming,
    required this.onIncludeUpcomingChanged,
  });

  final bool enabled;
  final GameSortType sort;
  final ValueChanged<GameSortType> onChanged;
  final bool includeUpcoming;
  final ValueChanged<bool> onIncludeUpcomingChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: Opacity(
        opacity: enabled ? 1 : 0.4,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text('並び替え：', style: Theme.of(context).textTheme.labelMedium),
                const SizedBox(width: 8),
                DropdownButton<GameSortType>(
                  value: sort,
                  isDense: true,
                  items: [
                    for (final entry in _sortLabels.entries)
                      DropdownMenuItem(
                        value: entry.key,
                        child: Text(entry.value),
                      ),
                  ],
                  onChanged: enabled
                      ? (value) {
                          if (value != null) onChanged(value);
                        }
                      : null,
                ),
              ],
            ),
            if (sort == GameSortType.releaseDate)
              CheckboxListTile(
                value: includeUpcoming,
                onChanged: enabled
                    ? (value) => onIncludeUpcomingChanged(value ?? false)
                    : null,
                contentPadding: EdgeInsets.zero,
                controlAffinity: ListTileControlAffinity.leading,
                dense: true,
                title: const Text('発売予定作品も含める'),
              ),
            if (!enabled)
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Text(
                  'タイトル検索中は関連度順で表示されます',
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
