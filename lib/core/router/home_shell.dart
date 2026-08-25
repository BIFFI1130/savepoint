import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/achievements/presentation/providers/achievement_tracker_provider.dart';
import '../../features/game_log/presentation/screens/my_logs_screen.dart';
import '../../features/game_search/presentation/screens/game_search_screen.dart';
import '../../features/home/presentation/screens/home_tabs_screen.dart';
import '../../features/trending/presentation/screens/trending_screen.dart';

/// 「ホーム」「検索」「トレンド」「マイログ」の4タブを切り替えるホーム画面。
/// フォロー中ユーザー一覧（旧「つながり」タブ）は、マイログのフォロー人数から
/// 遷移する画面として残っている。
class HomeShell extends ConsumerStatefulWidget {
  const HomeShell({super.key, this.initialIndex = 0});

  final int initialIndex;

  @override
  ConsumerState<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends ConsumerState<HomeShell> {
  late int _index = widget.initialIndex;

  static const _screens = [
    HomeTabsScreen(),
    GameSearchScreen(),
    TrendingScreen(),
    MyLogsScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    // ログイン中は常にマウントされているこの画面から、新規解放された実績を
    // 監視する（アナリティクス送信・レビュー依頼のトリガーを兼ねる）。
    ref.listen(newlyUnlockedAchievementsProvider, (previous, next) {
      next.whenData((unlocked) {
        if (unlocked.isEmpty) return;
        final messenger = ScaffoldMessenger.maybeOf(context);
        if (messenger == null) return;
        final title = unlocked.length == 1
            ? '実績解放：${unlocked.first.title}'
            : '実績を${unlocked.length}件解放しました';
        messenger.showSnackBar(SnackBar(content: Text(title)));
      });
    });

    // 「あと1つ」で達成できる実績に新しく入ったタイミングで、後押しのバナーを表示する。
    ref.listen(nearCompletionAchievementsProvider, (previous, next) {
      next.whenData((near) {
        if (near.isEmpty) return;
        final messenger = ScaffoldMessenger.maybeOf(context);
        if (messenger == null) return;
        final title = near.length == 1
            ? '『${near.first.title}』まであと1つ！'
            : '${near.length}件の実績があと1つで達成できます';
        messenger.showSnackBar(SnackBar(content: Text(title)));
      });
    });

    return Scaffold(
      body: IndexedStack(index: _index, children: _screens),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (value) => setState(() => _index = value),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.home_outlined), label: 'ホーム'),
          NavigationDestination(icon: Icon(Icons.search), label: '検索'),
          NavigationDestination(icon: Icon(Icons.trending_up), label: 'トレンド'),
          NavigationDestination(icon: Icon(Icons.bookmark), label: 'マイログ'),
        ],
      ),
    );
  }
}
