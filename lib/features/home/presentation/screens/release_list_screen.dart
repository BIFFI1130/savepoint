import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/preferences/content_filter_prefs.dart';
import '../../../../core/widgets/advanced_filters_section.dart';
import '../../../../core/widgets/async_state_views.dart';
import '../../../../core/widgets/game_sliver_grid.dart';
import '../../../../core/widgets/game_sliver_list.dart';
import '../../../../core/widgets/genre_filter_section.dart';
import '../../../../core/widgets/igdb_footer.dart';
import '../../../game_search/domain/platform_options.dart';
import '../../../social/presentation/providers/social_providers.dart';
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
  // Riverpodのfamilyプロバイダーの引数として使うため、Setは常に新しいインスタンスに
  // 差し替える（同一インスタンスをin-placeでadd/removeすると、DartのSetは値の等価性を
  // 持たないためProviderが「引数が変わっていない」と誤認し、再フェッチされなくなる）。
  late Set<String> _selectedPlatforms = {
    ...?widget.initialFilter?.platforms,
  };
  late Set<String> _selectedGenres = {
    ...?widget.initialFilter?.genres,
  };
  late bool _matchAllGenres = widget.initialFilter?.matchAllGenres ?? false;
  late bool _includeAdult;
  late bool _includeIndie;
  bool _isGridView = false;

  @override
  void initState() {
    super.initState();
    final prefs = ref.read(contentFilterPrefsProvider);
    _includeAdult = widget.initialFilter?.includeAdult ?? prefs.includeAdult;
    _includeIndie = widget.initialFilter?.includeIndie ?? prefs.includeIndie;
  }

  void _onPlatformTap(String value) {
    setState(() {
      _selectedPlatforms = _selectedPlatforms.contains(value)
          ? ({..._selectedPlatforms}..remove(value))
          : ({..._selectedPlatforms}..add(value));
    });
  }

  void _onGenreTap(String value) {
    setState(() {
      _selectedGenres = _selectedGenres.contains(value)
          ? ({..._selectedGenres}..remove(value))
          : ({..._selectedGenres}..add(value));
    });
  }

  bool get _hasActiveFilter =>
      _selectedPlatforms.isNotEmpty ||
      _selectedGenres.isNotEmpty ||
      _includeAdult ||
      !_includeIndie;

  void _openFilterSheet() {
    final isAdultUser = ref.read(isAdultUserProvider);
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (sheetContext, setSheetState) {
            void toggleGenre(String value) {
              _onGenreTap(value);
              setSheetState(() {});
            }

            void togglePlatform(String value) {
              _onPlatformTap(value);
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
                                _matchAllGenres = false;
                                _selectedPlatforms = {};
                                _includeAdult = false;
                                _includeIndie = true;
                              });
                              final prefs = ref.read(contentFilterPrefsProvider);
                              prefs.setIncludeAdult(false);
                              prefs.setIncludeIndie(true);
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
                        matchAllGenres: _matchAllGenres,
                        onMatchAllChanged: (value) {
                          setState(() => _matchAllGenres = value);
                          setSheetState(() {});
                        },
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
                        includeIndie: _includeIndie,
                        onIncludeIndieChanged: (value) {
                          setState(() => _includeIndie = value);
                          ref.read(contentFilterPrefsProvider).setIncludeIndie(value);
                          setSheetState(() {});
                        },
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
    final filter = (
      platforms: _selectedPlatforms,
      genres: _selectedGenres,
      includeAdult: _includeAdult,
      includeIndie: _includeIndie,
      matchAllGenres: _matchAllGenres,
    );
    final provider = switch (widget.type) {
      ReleaseListType.weekly => weeklyReleasesProvider(filter),
      ReleaseListType.monthly => monthlyReleasesProvider(filter),
      ReleaseListType.top100 => top100Provider(filter),
    };
    final resultsAsync = ref.watch(provider);
    final showRank = widget.type == ReleaseListType.top100;

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.type.title),
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
          const IgdbFooterSliver(),
        ],
      ),
    );
  }
}
