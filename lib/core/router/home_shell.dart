import 'package:flutter/material.dart';

import '../../features/game_log/presentation/screens/my_logs_screen.dart';
import '../../features/game_search/presentation/screens/game_search_screen.dart';
import '../../features/home/presentation/screens/home_screen.dart';
import '../../features/social/presentation/screens/social_feed_screen.dart';
import '../../features/trending/presentation/screens/trending_screen.dart';

/// 「ホーム」「検索」「トレンド」「マイログ」「つながり」の5タブを切り替えるホーム画面。
class HomeShell extends StatefulWidget {
  const HomeShell({super.key, this.initialIndex = 0});

  final int initialIndex;

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  late int _index = widget.initialIndex;

  static const _screens = [
    HomeScreen(),
    GameSearchScreen(),
    TrendingScreen(),
    MyLogsScreen(),
    SocialFeedScreen(),
  ];

  @override
  Widget build(BuildContext context) {
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
          NavigationDestination(icon: Icon(Icons.people_outline), label: 'つながり'),
        ],
      ),
    );
  }
}
