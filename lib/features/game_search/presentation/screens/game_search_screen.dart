import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/widgets/async_state_views.dart';
import '../../../../core/widgets/cover_image.dart';
import '../../domain/game.dart';
import '../providers/game_search_providers.dart';

/// 対応ハードフィルタの選択肢（表示ラベル, IGDB検索に渡す値）。
const _platformOptions = <(String label, String value)>[
  ('Switch', 'Switch'),
  ('PS5', 'PlayStation 5'),
  ('PS4', 'PlayStation 4'),
  ('Xbox', 'Xbox'),
  ('PC', 'Windows'),
  ('iOS', 'iOS'),
  ('Android', 'Android'),
];

/// カテゴリ（ジャンル）フィルタの選択肢（表示ラベル, IGDBの正式なジャンル名）。
/// IGDBのジャンル一覧から、日本のユーザーに馴染みのある分類のみを抜粋している。
const _genreOptions = <(String label, String value)>[
  ('RPG', 'Role-playing (RPG)'),
  ('アクション', "Hack and slash/Beat 'em up"),
  ('シューティング', 'Shooter'),
  ('アドベンチャー', 'Adventure'),
  ('格闘', 'Fighting'),
  ('レース', 'Racing'),
  ('パズル', 'Puzzle'),
  ('ストラテジー', 'Strategy'),
  ('シミュレーション', 'Simulator'),
  ('スポーツ', 'Sport'),
  ('プラットフォーマー', 'Platform'),
  ('インディー', 'Indie'),
];

class GameSearchScreen extends ConsumerStatefulWidget {
  const GameSearchScreen({super.key});

  @override
  ConsumerState<GameSearchScreen> createState() => _GameSearchScreenState();
}

class _GameSearchScreenState extends ConsumerState<GameSearchScreen> {
  final _developerController = TextEditingController();
  final _scrollController = ScrollController();
  String? _selectedPlatform;
  String? _selectedGenre;
  String _queryText = '';
  GameSortType _sort = GameSortType.popularity;
  Timer? _developerDebounce;
  bool _showAdvanced = false;
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
      _selectedPlatform = _selectedPlatform == value ? null : value;
    });
    ref.read(gameSearchProvider.notifier).setPlatform(_selectedPlatform);
  }

  void _onGenreTap(String value) {
    setState(() {
      _selectedGenre = _selectedGenre == value ? null : value;
    });
    ref.read(gameSearchProvider.notifier).setGenre(_selectedGenre);
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

  @override
  Widget build(BuildContext context) {
    final resultsAsync = ref.watch(gameSearchProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('ゲームを探す')),
      body: Column(
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
              'カテゴリから探す',
              style: Theme.of(context).textTheme.labelMedium,
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: SizedBox(
              height: 40,
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: [
                  for (final option in _genreOptions)
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: FilterChip(
                        label: Text(option.$1),
                        selected: _selectedGenre == option.$2,
                        onSelected: (_) => _onGenreTap(option.$2),
                      ),
                    ),
                ],
              ),
            ),
          ),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: () => setState(() => _showAdvanced = !_showAdvanced),
              icon: Icon(
                _showAdvanced ? Icons.expand_less : Icons.expand_more,
              ),
              label: const Text('詳しく検索'),
            ),
          ),
          AnimatedSize(
            duration: const Duration(milliseconds: 200),
            child: _showAdvanced
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Text(
                          '対応ハード',
                          style: Theme.of(context).textTheme.labelMedium,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: SizedBox(
                          height: 40,
                          child: ListView(
                            scrollDirection: Axis.horizontal,
                            children: [
                              for (final option in _platformOptions)
                                Padding(
                                  padding: const EdgeInsets.only(right: 8),
                                  child: FilterChip(
                                    label: Text(option.$1),
                                    selected: _selectedPlatform == option.$2,
                                    onSelected: (_) => _onPlatformTap(option.$2),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
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
                  )
                : const SizedBox(width: double.infinity),
          ),
          _SortSelector(
            enabled: _queryText.trim().isEmpty,
            sort: _sort,
            onChanged: _onSortChanged,
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 8, 0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Icon(
                  Icons.view_list,
                  size: 20,
                  color: _isGridView
                      ? Theme.of(context).colorScheme.outline
                      : Theme.of(context).colorScheme.primary,
                ),
                Switch(
                  value: _isGridView,
                  onChanged: (value) => setState(() => _isGridView = value),
                ),
                Icon(
                  Icons.grid_view,
                  size: 20,
                  color: _isGridView
                      ? Theme.of(context).colorScheme.primary
                      : Theme.of(context).colorScheme.outline,
                ),
              ],
            ),
          ),
          Expanded(
            child: resultsAsync.when(
              data: (results) {
                if (results.games.isEmpty) {
                  return const EmptyView(
                    message: 'ゲームタイトルを検索するか、\nカテゴリを選んで探してみましょう',
                    icon: Icons.videogame_asset_outlined,
                  );
                }
                return _isGridView
                    ? _GameGrid(
                        games: results.games,
                        isLoadingMore: results.isLoadingMore,
                        scrollController: _scrollController,
                      )
                    : _GameList(
                        games: results.games,
                        isLoadingMore: results.isLoadingMore,
                        scrollController: _scrollController,
                      );
              },
              loading: () => const LoadingView(),
              error: (error, _) => ErrorView(
                message: 'ゲームの検索に失敗しました',
                onRetry: () => ref.invalidate(gameSearchProvider),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Text(
              'ゲーム情報提供: IGDB',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.outline,
                  ),
            ),
          ),
        ],
      ),
    );
  }
}

/// カテゴリ探索時の並び替え選択。タイトル検索中（[enabled] が false）は
/// 操作できない（IGDBは検索キーワードと並び替えを併用できないため）。
class _SortSelector extends StatelessWidget {
  const _SortSelector({
    required this.enabled,
    required this.sort,
    required this.onChanged,
  });

  final bool enabled;
  final GameSortType sort;
  final ValueChanged<GameSortType> onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: Opacity(
        opacity: enabled ? 1 : 0.4,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('並び替え', style: Theme.of(context).textTheme.labelMedium),
            const SizedBox(height: 4),
            SegmentedButton<GameSortType>(
              segments: const [
                ButtonSegment(
                  value: GameSortType.popularity,
                  label: Text('人気順'),
                ),
                ButtonSegment(
                  value: GameSortType.name,
                  label: Text('辞書順'),
                ),
                ButtonSegment(
                  value: GameSortType.releaseDate,
                  label: Text('発売時期順'),
                ),
              ],
              selected: {sort},
              onSelectionChanged:
                  enabled ? (selection) => onChanged(selection.first) : null,
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

class _GameList extends StatelessWidget {
  const _GameList({
    required this.games,
    required this.isLoadingMore,
    required this.scrollController,
  });

  final List<Game> games;
  final bool isLoadingMore;
  final ScrollController scrollController;

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      controller: scrollController,
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
          title: Text(game.name),
          subtitle: game.releaseYear != null ? Text('${game.releaseYear}年') : null,
          onTap: () => context.push('/games/${game.id}'),
        );
      },
    );
  }
}

/// グリッド表示（1行3件・画像のみ）。
class _GameGrid extends StatelessWidget {
  const _GameGrid({
    required this.games,
    required this.isLoadingMore,
    required this.scrollController,
  });

  final List<Game> games;
  final bool isLoadingMore;
  final ScrollController scrollController;

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      controller: scrollController,
      padding: const EdgeInsets.all(8),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        childAspectRatio: 0.7,
        crossAxisSpacing: 6,
        mainAxisSpacing: 6,
      ),
      itemCount: games.length + (isLoadingMore ? 3 : 0),
      itemBuilder: (context, index) {
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
    );
  }
}
