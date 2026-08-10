import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/widgets/async_state_views.dart';
import '../../../../core/widgets/cover_image.dart';
import '../../../game_search/domain/platform_options.dart';
import '../providers/home_providers.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  String? _selectedPlatform;

  void _onPlatformTap(String value) {
    setState(() {
      _selectedPlatform = _selectedPlatform == value ? null : value;
    });
  }

  @override
  Widget build(BuildContext context) {
    final releasesAsync = ref.watch(weeklyReleasesProvider(_selectedPlatform));

    return Scaffold(
      appBar: AppBar(title: const Text('ホーム')),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Text(
                '今週発売のゲーム',
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
            SizedBox(
              height: 40,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                children: [
                  for (final option in platformOptions)
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
            const SizedBox(height: 8),
            releasesAsync.when(
              data: (games) {
                if (games.isEmpty) {
                  return const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16, vertical: 24),
                    child: Text('今週発売予定のタイトルは見つかりませんでした'),
                  );
                }
                return SizedBox(
                  height: 160,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: games.length,
                    separatorBuilder: (context, index) => const SizedBox(width: 8),
                    itemBuilder: (context, index) {
                      final game = games[index];
                      return GestureDetector(
                        onTap: () => context.push('/games/${game.id}'),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: CoverImage(
                            url: game.coverUrl,
                            width: 110,
                            height: 160,
                          ),
                        ),
                      );
                    },
                  ),
                );
              },
              loading: () => const SizedBox(
                height: 160,
                child: LoadingView(),
              ),
              error: (error, _) => Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: ErrorView(
                  message: '今週発売のゲームの取得に失敗しました',
                  onRetry: () =>
                      ref.invalidate(weeklyReleasesProvider(_selectedPlatform)),
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
