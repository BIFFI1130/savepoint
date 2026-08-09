import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/widgets/async_state_views.dart';
import '../../../../core/widgets/cover_image.dart';
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

class GameSearchScreen extends ConsumerStatefulWidget {
  const GameSearchScreen({super.key});

  @override
  ConsumerState<GameSearchScreen> createState() => _GameSearchScreenState();
}

class _GameSearchScreenState extends ConsumerState<GameSearchScreen> {
  final _developerController = TextEditingController();
  String? _selectedPlatform;
  Timer? _developerDebounce;
  bool _showAdvanced = false;

  @override
  void dispose() {
    _developerController.dispose();
    _developerDebounce?.cancel();
    super.dispose();
  }

  void _onPlatformTap(String value) {
    setState(() {
      _selectedPlatform = _selectedPlatform == value ? null : value;
    });
    ref.read(gameSearchProvider.notifier).setPlatform(_selectedPlatform);
  }

  void _onDeveloperChanged(String value) {
    _developerDebounce?.cancel();
    _developerDebounce = Timer(const Duration(milliseconds: 450), () {
      ref.read(gameSearchProvider.notifier).setDeveloper(value);
    });
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
              onChanged: (value) =>
                  ref.read(gameSearchProvider.notifier).search(value),
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
          Expanded(
            child: resultsAsync.when(
              data: (games) {
                if (games.isEmpty) {
                  return const EmptyView(
                    message: 'ゲームタイトルを検索してみましょう',
                    icon: Icons.videogame_asset_outlined,
                  );
                }
                return ListView.separated(
                  itemCount: games.length,
                  separatorBuilder: (context, index) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final game = games[index];
                    return ListTile(
                      leading: CoverImage(
                        url: game.coverUrl,
                        width: 44,
                        height: 60,
                      ),
                      title: Text(game.name),
                      subtitle: game.releaseYear != null
                          ? Text('${game.releaseYear}年')
                          : null,
                      onTap: () => context.push('/games/${game.id}'),
                    );
                  },
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
