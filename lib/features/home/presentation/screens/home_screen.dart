import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/ads/native_ad_card.dart';
import '../../../../core/preferences/content_filter_prefs.dart';
import '../../../../core/subscription/subscription_providers.dart';
import '../../../../core/widgets/async_state_views.dart';
import '../../../../core/widgets/cover_image.dart';
import '../../../../core/widgets/igdb_footer.dart';
import '../../../game_search/domain/game.dart';
import '../providers/home_providers.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // ホーム画面自体ではジャンル・対応ハードの絞り込みは行わない（各セクションの見出し
    // ＞から遷移した先の一覧画面で選べる）。成人向け・インディー作品の表示設定のみ、
    // 永続化された共通設定をそのまま反映する。
    final contentFilterPrefs = ref.watch(contentFilterPrefsProvider);
    // platforms/genresはconstにして、build()のたびに新しいSetインスタンスが
    // 生成されるのを防ぐ（Setは既定で参照比較のため、非constだと再ビルドのたびに
    // familyプロバイダーが「別の条件」と誤認し、取得中のリクエストが完了する前に
    // 何度も再スタートしてホーム画面が読み込み中のまま固まってしまう）。
    final noFilter = (
      platforms: const <String>{},
      genres: const <String>{},
      includeAdult: contentFilterPrefs.includeAdult,
      includeIndie: contentFilterPrefs.includeIndie,
    );
    final releasesAsync = ref.watch(weeklyReleasesProvider(noFilter));
    final monthlyReleasesAsync = ref.watch(monthlyReleasesProvider(noFilter));
    final top100Async = ref.watch(top100Provider(noFilter));

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 8),
          _SectionHeader(
            title: '今週発売のゲーム',
            onTap: () => context.push('/home/weekly', extra: noFilter),
          ),
          releasesAsync.when(
            data: (games) {
              if (games.isEmpty) {
                return const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16, vertical: 24),
                  child: Text('今週発売予定のタイトルは見つかりませんでした'),
                );
              }
              return _CoverCarousel(
                games: games,
                showNativeAd: !ref.watch(isAdFreeProvider),
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
                onRetry: () => ref.invalidate(weeklyReleasesProvider(noFilter)),
              ),
            ),
          ),
          const SizedBox(height: 24),
          _SectionHeader(
            title: '今月発売のゲーム',
            onTap: () => context.push('/home/monthly', extra: noFilter),
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
                onRetry: () =>
                    ref.invalidate(monthlyReleasesProvider(noFilter)),
              ),
            ),
          ),
          const SizedBox(height: 24),
          _SectionHeader(
            title: 'IGDB：TOP100',
            onTap: () => context.push('/home/top100', extra: noFilter),
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
                onRetry: () => ref.invalidate(top100Provider(noFilter)),
              ),
            ),
          ),
          const SizedBox(height: 24),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16),
            child: IgdbFooter(padding: EdgeInsets.zero),
          ),
        ],
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
/// 順位（1始まり）バッジを重ねて表示する（IGDB TOP100用）。[showNativeAd] を有効にすると、
/// 3枚目の位置にゲームカードと同じ寸法のネイティブ広告カードを差し込む
/// （件数が少なく3枚目が存在しない場合は広告を出さない）。
class _CoverCarousel extends StatelessWidget {
  const _CoverCarousel({
    required this.games,
    this.showRank = false,
    this.showNativeAd = false,
  });

  final List<Game> games;
  final bool showRank;
  final bool showNativeAd;

  static const _nativeAdPosition = 2;

  @override
  Widget build(BuildContext context) {
    final adIndex =
        showNativeAd && games.length > _nativeAdPosition ? _nativeAdPosition : null;
    final itemCount = games.length + (adIndex != null ? 1 : 0);

    return SizedBox(
      height: 160,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: itemCount,
        separatorBuilder: (context, index) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          if (adIndex != null && index == adIndex) {
            return const NativeAdCard();
          }
          final gameIndex = adIndex != null && index > adIndex ? index - 1 : index;
          final game = games[gameIndex];
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
                            '${gameIndex + 1}',
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
