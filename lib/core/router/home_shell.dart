import 'package:flutter/material.dart';

import '../../features/game_log/presentation/screens/my_logs_screen.dart';
import '../../features/game_search/presentation/screens/game_search_screen.dart';

/// 「検索」「マイログ」の2タブを切り替えるホーム画面。
class HomeShell extends StatefulWidget {
  const HomeShell({super.key, this.initialIndex = 0});

  final int initialIndex;

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  late int _index = widget.initialIndex;

  static const _screens = [GameSearchScreen(), MyLogsScreen()];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(index: _index, children: _screens),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (value) => setState(() => _index = value),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.search), label: '検索'),
          NavigationDestination(icon: Icon(Icons.bookmark), label: 'マイログ'),
        ],
      ),
    );
  }
}
