import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// 設定画面の入り口。表示・通知・プレミアム・アプリについて・アカウントの
/// 各セクションへ遷移するメニュー。元々は1画面に全項目を並べていたが、
/// 項目数が増えて長くなったため、セクションごとに別画面へ切り出した。
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('設定')),
      body: ListView(
        children: [
          _SettingsMenuTile(
            icon: Icons.palette_outlined,
            title: '表示',
            onTap: () => context.push('/settings/display'),
          ),
          _SettingsMenuTile(
            icon: Icons.notifications_outlined,
            title: '通知',
            onTap: () => context.push('/settings/notifications'),
          ),
          _SettingsMenuTile(
            icon: Icons.workspace_premium_outlined,
            title: 'プレミアム',
            onTap: () => context.push('/settings/premium'),
          ),
          _SettingsMenuTile(
            icon: Icons.info_outline,
            title: 'アプリについて',
            onTap: () => context.push('/settings/about'),
          ),
          _SettingsMenuTile(
            icon: Icons.person_outline,
            title: 'アカウント',
            onTap: () => context.push('/settings/account'),
          ),
        ],
      ),
    );
  }
}

class _SettingsMenuTile extends StatelessWidget {
  const _SettingsMenuTile({
    required this.icon,
    required this.title,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon),
      title: Text(title),
      trailing: const Icon(Icons.chevron_right),
      onTap: onTap,
    );
  }
}
