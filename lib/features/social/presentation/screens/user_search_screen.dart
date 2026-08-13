import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/widgets/async_state_views.dart';
import '../../../../core/widgets/avatar_image.dart';
import '../../domain/social_profile.dart';
import '../providers/social_providers.dart';

class UserSearchScreen extends ConsumerStatefulWidget {
  const UserSearchScreen({super.key});

  @override
  ConsumerState<UserSearchScreen> createState() => _UserSearchScreenState();
}

class _UserSearchScreenState extends ConsumerState<UserSearchScreen> {
  List<SocialProfile>? _results;
  bool _isSearching = false;

  Future<void> _onQueryChanged(String value) async {
    if (value.trim().isEmpty) {
      setState(() => _results = null);
      return;
    }
    setState(() => _isSearching = true);
    final results =
        await ref.read(socialRepositoryProvider).searchUsers(value);
    if (!mounted) return;
    setState(() {
      _results = results;
      _isSearching = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('ユーザーを探す')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              autofocus: true,
              decoration: const InputDecoration(
                hintText: 'ユーザーID・表示名で検索',
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(),
              ),
              onChanged: _onQueryChanged,
            ),
            const SizedBox(height: 16),
            Expanded(child: _buildResults(context)),
          ],
        ),
      ),
    );
  }

  Widget _buildResults(BuildContext context) {
    if (_isSearching) return const LoadingView();
    final results = _results;
    if (results == null) {
      return const EmptyView(
        message: 'ユーザーIDや表示名で検索してみましょう',
        icon: Icons.person_search_outlined,
      );
    }
    if (results.isEmpty) {
      return const EmptyView(
        message: '該当するユーザーが見つかりませんでした',
        icon: Icons.person_search_outlined,
      );
    }
    return ListView.separated(
      itemCount: results.length,
      separatorBuilder: (context, index) => const Divider(height: 1),
      itemBuilder: (context, index) {
        final profile = results[index];
        return ListTile(
          leading: AvatarImage(url: profile.avatarUrl),
          title: Text(profile.displayLabel),
          subtitle:
              profile.username != null ? Text('@${profile.username}') : null,
          onTap: () => context.push('/users/${profile.id}'),
        );
      },
    );
  }
}
