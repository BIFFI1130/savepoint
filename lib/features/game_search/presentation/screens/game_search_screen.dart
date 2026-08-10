import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/widgets/advanced_filters_section.dart';
import '../../../../core/widgets/async_state_views.dart';
import '../../../../core/widgets/cover_image.dart';
import '../../domain/game.dart';
import '../../domain/platform_options.dart';
import '../providers/game_search_providers.dart';

/// ジャンルフィルタの選択肢（表示ラベル, IGDBの正式なジャンル名, バッジのアイコンと色）。
/// IGDBのジャンル一覧から、日本のユーザーに馴染みのある分類のみを抜粋している。
const _genreOptions = <(String label, String value, IconData icon, Color color)>[
  ('RPG', 'Role-playing (RPG)', Icons.castle, Color(0xFF6750A4)),
  ('アクション', "Hack and slash/Beat 'em up", Icons.bolt, Color(0xFFB3261E)),
  ('シューティング', 'Shooter', Icons.gps_fixed, Color(0xFF006C51)),
  ('アドベンチャー', 'Adventure', Icons.explore, Color(0xFF8B5000)),
  ('格闘', 'Fighting', Icons.sports_mma, Color(0xFF9C4146)),
  ('レース', 'Racing', Icons.directions_car_filled, Color(0xFF3A5B9B)),
  ('パズル', 'Puzzle', Icons.extension, Color(0xFF6E5A00)),
  ('ストラテジー', 'Strategy', Icons.psychology, Color(0xFF4A6148)),
  ('シミュレーション', 'Simulator', Icons.precision_manufacturing, Color(0xFF5C5F77)),
  ('スポーツ', 'Sport', Icons.sports_soccer, Color(0xFF1D6B5B)),
  ('プラットフォーマー', 'Platform', Icons.terrain, Color(0xFF7A5230)),
  ('インディー', 'Indie', Icons.auto_awesome, Color(0xFF884191)),
];

class GameSearchScreen extends ConsumerStatefulWidget {
  const GameSearchScreen({super.key});

  @override
  ConsumerState<GameSearchScreen> createState() => _GameSearchScreenState();
}

class _GameSearchScreenState extends ConsumerState<GameSearchScreen> {
  final _developerController = TextEditingController();
  final _scrollController = ScrollController();
  final Set<String> _selectedPlatforms = {};
  final Set<String> _selectedGenres = {};
  String _queryText = '';
  GameSortType _sort = GameSortType.popularity;
  bool _includeUpcoming = false;
  bool _includeAdult = false;
  Timer? _developerDebounce;
  bool _isGridView = false;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _developerController.dispose();
    _developerDebounce?.cancel();
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    final nearBottom = _scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 300;
    if (nearBottom) {
      ref.read(gameSearchProvider.notifier).loadMore();
    }
  }

  void _onPlatformTap(String value) {
    setState(() {
      if (_selectedPlatforms.contains(value)) {
        _selectedPlatforms.remove(value);
      } else {
        _selectedPlatforms.add(value);
      }
    });
    ref.read(gameSearchProvider.notifier).setPlatforms(_selectedPlatforms);
  }

  void _onGenreTap(String value) {
    setState(() {
      if (_selectedGenres.contains(value)) {
        _selectedGenres.remove(value);
      } else {
        _selectedGenres.add(value);
      }
    });
    ref.read(gameSearchProvider.notifier).setGenres(_selectedGenres);
  }

  void _onDeveloperChanged(String value) {
    _developerDebounce?.cancel();
    _developerDebounce = Timer(const Duration(milliseconds: 450), () {
      ref.read(gameSearchProvider.notifier).setDeveloper(value);
    });
  }

  void _onQueryChanged(String value) {
    setState(() => _queryText = value);
    ref.read(gameSearchProvider.notifier).search(value);
  }

  void _onSortChanged(GameSortType sort) {
    setState(() => _sort = sort);
    ref.read(gameSearchProvider.notifier).setSort(sort);
  }

  void _onIncludeUpcomingChanged(bool value) {
    setState(() => _includeUpcoming = value);
    ref.read(gameSearchProvider.notifier).setIncludeUpcoming(value);
  }

  void _onIncludeAdultChanged(bool value) {
    setState(() => _includeAdult = value);
    ref.read(gameSearchProvider.notifier).setIncludeAdult(value);
  }

  @override
  Widget build(BuildContext context) {
    final resultsAsync = ref.watch(gameSearchProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('ゲームを探す')),
      body: CustomScrollView(
        controller: _scrollController,
        slivers: [
          SliverToBoxAdapter(child: _buildFilters(context)),
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
                  ? _GameSliverGrid(
                      games: results.games,
                      isLoadingMore: results.isLoadingMore,
                    )
                  : _GameSliverList(
                      games: results.games,
                      isLoadingMore: results.isLoadingMore,
                    );
            },
            loading: () =>
                const SliverFillRemaining(hasScrollBody: false, child: LoadingView()),
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

  Widget _buildFilters(BuildContext context) {
    return Column(
      children: [
        Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: TextField(
              decoration: const InputDecoration(
                hintText: 'タイトルで検索',
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(),
              ),
              onChanged: _onQueryChanged,
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
            child: Text(
              'ジャンルから探す',
              style: Theme.of(context).textTheme.labelMedium,
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final option in _genreOptions)
                  SizedBox(
                    width: 112,
                    height: 112,
                    child: _GenreBadge(
                      label: option.$1,
                      icon: option.$3,
                      color: option.$4,
                      selected: _selectedGenres.contains(option.$2),
                      onTap: () => _onGenreTap(option.$2),
                    ),
                  ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: Text(
              '対応ハード',
              style: Theme.of(context).textTheme.labelMedium,
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final option in platformOptions)
                  FilterChip(
                    label: Text(option.$1),
                    selected: _selectedPlatforms.contains(option.$2),
                    onSelected: (_) => _onPlatformTap(option.$2),
                  ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: AdvancedFiltersSection(
              includeAdult: _includeAdult,
              onIncludeAdultChanged: _onIncludeAdultChanged,
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
                    onChanged: _onDeveloperChanged,
                  ),
                ),
              ],
            ),
          ),
          _SortSelector(
            enabled: _queryText.trim().isEmpty,
            sort: _sort,
            onChanged: _onSortChanged,
            includeUpcoming: _includeUpcoming,
            onIncludeUpcomingChanged: _onIncludeUpcomingChanged,
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 8, 0),
            child: Align(
              alignment: Alignment.centerRight,
              child: IconButton(
                onPressed: () => setState(() => _isGridView = !_isGridView),
                icon: Icon(_isGridView ? Icons.view_list : Icons.grid_view),
                tooltip: _isGridView ? 'リスト表示に切り替え' : 'グリッド表示に切り替え',
              ),
            ),
          ),
        ],
      );
  }
}

/// ジャンルの選択肢を表す正方形のバッジ。アイコンを中央に、ラベルを右下に配置する。
class _GenreBadge extends StatelessWidget {
  const _GenreBadge({
    required this.label,
    required this.icon,
    required this.color,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final Color color;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: 1,
      child: Material(
        color: color,
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: onTap,
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              border: selected
                  ? Border.all(
                      color: Theme.of(context).colorScheme.primary,
                      width: 3,
                    )
                  : null,
            ),
            child: Stack(
              children: [
                Align(
                  alignment: const Alignment(0, -0.3),
                  child: Icon(icon, size: 38, color: Colors.white70),
                ),
                if (selected)
                  const Positioned(
                    top: 4,
                    left: 4,
                    child: Icon(
                      Icons.check_circle,
                      color: Colors.white,
                      size: 20,
                    ),
                  ),
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.45),
                      borderRadius: const BorderRadius.only(
                        bottomLeft: Radius.circular(10),
                        bottomRight: Radius.circular(10),
                      ),
                    ),
                    child: Text(
                      label,
                      textAlign: TextAlign.right,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10.5,
                        height: 1.2,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
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

class _GameSliverList extends StatelessWidget {
  const _GameSliverList({required this.games, required this.isLoadingMore});

  final List<Game> games;
  final bool isLoadingMore;

  @override
  Widget build(BuildContext context) {
    return SliverList.separated(
      itemCount: games.length + (isLoadingMore ? 1 : 0),
      separatorBuilder: (context, index) => const Divider(height: 1),
      itemBuilder: (context, index) {
        if (index >= games.length) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 16),
            child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
          );
        }
        final game = games[index];
        return ListTile(
          leading: CoverImage(url: game.coverUrl, width: 44, height: 60),
          title: Text(game.displayName),
          subtitle: game.releaseYear != null ? Text('${game.releaseYear}年') : null,
          onTap: () => context.push('/games/${game.id}'),
        );
      },
    );
  }
}

/// グリッド表示（1行3件・画像のみ）。
class _GameSliverGrid extends StatelessWidget {
  const _GameSliverGrid({required this.games, required this.isLoadingMore});

  final List<Game> games;
  final bool isLoadingMore;

  @override
  Widget build(BuildContext context) {
    return SliverPadding(
      padding: const EdgeInsets.all(8),
      sliver: SliverGrid(
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3,
          childAspectRatio: 0.7,
          crossAxisSpacing: 6,
          mainAxisSpacing: 6,
        ),
        delegate: SliverChildBuilderDelegate(
          (context, index) {
            if (index >= games.length) {
              return const Center(
                child: CircularProgressIndicator(strokeWidth: 2),
              );
            }
            final game = games[index];
            return GestureDetector(
              onTap: () => context.push('/games/${game.id}'),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: CoverImage(
                  url: game.coverUrl,
                  width: double.infinity,
                  height: double.infinity,
                ),
              ),
            );
          },
          childCount: games.length + (isLoadingMore ? 3 : 0),
        ),
      ),
    );
  }
}
