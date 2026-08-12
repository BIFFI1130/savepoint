import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/widgets/advanced_filters_section.dart';
import '../../../../core/widgets/async_state_views.dart';
import '../../../../core/widgets/game_sliver_grid.dart';
import '../../../../core/widgets/game_sliver_list.dart';
import '../../../../core/widgets/genre_badge_selector.dart';
import '../../../game_search/domain/platform_options.dart';
import '../providers/home_providers.dart';

/// ホーム画面の各セクション（今週発売・今月発売・IGDB TOP100）に対応する一覧種別。
enum ReleaseListType {
  weekly('今週発売のゲーム'),
  monthly('今月発売のゲーム'),
  top100('IGDB：TOP100');

  const ReleaseListType(this.title);
  final String title;
}

/// ホーム画面の見出し「＞」から遷移する、各セクションの全件一覧画面。
/// 検索画面と同じくジャンルバッジ・対応ハードの複数選択・詳しい条件・
/// リスト/グリッド切り替えに対応する。
class ReleaseListScreen extends ConsumerStatefulWidget {
  const ReleaseListScreen({super.key, required this.type, this.initialFilter});

  final ReleaseListType type;

  /// ホーム画面で選択中だったフィルタを初期値として引き継ぐ。
  final HomeReleasesFilter? initialFilter;

  @override
  ConsumerState<ReleaseListScreen> createState() => _ReleaseListScreenState();
}

class _ReleaseListScreenState extends ConsumerState<ReleaseListScreen> {
  late final Set<String> _selectedPlatforms = {
    ...?widget.initialFilter?.platforms,
  };
  late final Set<String> _selectedGenres = {
    ...?widget.initialFilter?.genres,
  };
  late bool _includeAdult = widget.initialFilter?.includeAdult ?? false;
  late bool _includeIndie = widget.initialFilter?.includeIndie ?? false;
  bool _isGridView = false;

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

  @override
  Widget build(BuildContext context) {
    final filter = (
      platforms: _selectedPlatforms,
      genres: _selectedGenres,
      includeAdult: _includeAdult,
      includeIndie: _includeIndie,
    );
    final provider = switch (widget.type) {
      ReleaseListType.weekly => weeklyReleasesProvider(filter),
      ReleaseListType.monthly => monthlyReleasesProvider(filter),
      ReleaseListType.top100 => top100Provider(filter),
    };
    final resultsAsync = ref.watch(provider);
    final showRank = widget.type == ReleaseListType.top100;

    return Scaffold(
      appBar: AppBar(title: Text(widget.type.title)),
      body: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(child: _buildFilters(context)),
          resultsAsync.when(
            data: (games) {
              if (games.isEmpty) {
                return const SliverFillRemaining(
                  hasScrollBody: false,
                  child: EmptyView(
                    message: '該当するタイトルは見つかりませんでした',
                    icon: Icons.videogame_asset_outlined,
                  ),
                );
              }
              return _isGridView
                  ? GameSliverGrid(games: games, showRank: showRank)
                  : GameSliverList(games: games, showRank: showRank);
            },
            loading: () => const SliverFillRemaining(
              hasScrollBody: false,
              child: LoadingView(),
            ),
            error: (error, _) => SliverFillRemaining(
              hasScrollBody: false,
              child: ErrorView(
                message: '取得に失敗しました',
                onRetry: () => ref.invalidate(provider),
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
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
          child: Text(
            'ジャンルから探す',
            style: Theme.of(context).textTheme.labelMedium,
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: GenreBadgeSelector(
            selectedGenres: _selectedGenres,
            onToggle: _onGenreTap,
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
          child: Text('対応ハード', style: Theme.of(context).textTheme.labelMedium),
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
            onIncludeAdultChanged: (value) =>
                setState(() => _includeAdult = value),
            includeIndie: _includeIndie,
            onIncludeIndieChanged: (value) =>
                setState(() => _includeIndie = value),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 8, 8),
          child: Align(
            alignment: Alignment.centerRight,
            child: IconButton(
              onPressed: () => setState(() => _isGridView = !_isGridView),
              icon: Icon(_isGridView ? Icons.view_list : Icons.grid_view),
              tooltip: _isGridView ? 'リスト表示に切り替え' : 'グリッド表示に切り替え',
            ),
          ),
        ),
        const Divider(height: 1),
      ],
    );
  }
}
