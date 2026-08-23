import 'package:flutter/material.dart';

import '../../../timeline/presentation/screens/timeline_screen.dart';
import 'home_screen.dart';

/// ホーム画面上部のタブバー。「ホーム」（従来のホーム内容）と「タイムライン」
/// （自分とフォロー中ユーザーのマイログ追加を時系列で確認できる）を切り替える。
class HomeTabsScreen extends StatefulWidget {
  const HomeTabsScreen({super.key});

  @override
  State<HomeTabsScreen> createState() => _HomeTabsScreenState();
}

class _HomeTabsScreenState extends State<HomeTabsScreen>
    with SingleTickerProviderStateMixin {
  late final _controller = TabController(length: 2, vsync: this)
    ..addListener(() => setState(() {}));

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_controller.index == 0 ? 'ホーム' : 'タイムライン'),
        bottom: TabBar(
          controller: _controller,
          tabs: const [
            Tab(text: 'ホーム'),
            Tab(text: 'タイムライン'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _controller,
        children: const [
          HomeScreen(),
          TimelineScreen(),
        ],
      ),
    );
  }
}
