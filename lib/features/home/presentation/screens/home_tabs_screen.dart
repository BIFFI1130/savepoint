import 'package:flutter/material.dart';

import '../../../calendar/presentation/screens/release_calendar_screen.dart';
import '../../../timeline/presentation/screens/timeline_screen.dart';
import 'home_screen.dart';

const _tabTitles = ['ホーム', 'タイムライン', 'カレンダー'];

/// ホーム画面上部のタブバー。「ホーム」（従来のホーム内容）・「タイムライン」
/// （自分とフォロー中ユーザーのマイログ追加を時系列で確認できる）・「カレンダー」
/// （発売日カレンダー）を切り替える。
class HomeTabsScreen extends StatefulWidget {
  const HomeTabsScreen({super.key});

  @override
  State<HomeTabsScreen> createState() => _HomeTabsScreenState();
}

class _HomeTabsScreenState extends State<HomeTabsScreen>
    with SingleTickerProviderStateMixin {
  late final _controller = TabController(length: _tabTitles.length, vsync: this)
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
        toolbarHeight: 40,
        title: Text(_tabTitles[_controller.index]),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(36),
          child: TabBar(
            controller: _controller,
            padding: EdgeInsets.zero,
            tabs: const [
              Tab(height: 36, text: 'ホーム'),
              Tab(height: 36, text: 'タイムライン'),
              Tab(height: 36, text: 'カレンダー'),
            ],
          ),
        ),
      ),
      body: TabBarView(
        controller: _controller,
        children: const [
          HomeScreen(),
          TimelineScreen(),
          ReleaseCalendarScreen(),
        ],
      ),
    );
  }
}
