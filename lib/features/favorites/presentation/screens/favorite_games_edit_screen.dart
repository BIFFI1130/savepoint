import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/widgets/async_state_views.dart';
import '../../../../core/widgets/cover_image.dart';
import '../../../game_search/domain/game.dart';
import '../../../game_search/presentation/providers/game_search_providers.dart';
import '../providers/favorite_providers.dart';

const _maxFavorites = 5;

class _FavoriteSlot {
  const _FavoriteSlot({
    required this.gameId,
    required this.name,
    this.coverUrl,
  });

  final int gameId;
  final String name;
  final String? coverUrl;
}

class FavoriteGamesEditScreen extends ConsumerStatefulWidget {
  const FavoriteGamesEditScreen({super.key});

  @override
  ConsumerState<FavoriteGamesEditScreen> createState() =>
      _FavoriteGamesEditScreenState();
}

class _FavoriteGamesEditScreenState
    extends ConsumerState<FavoriteGamesEditScreen> {
  List<_FavoriteSlot>? _slots;
  bool _ranked = true;
  bool _isSaving = false;

  void _hydrate(List<_FavoriteSlot> slots, bool ranked) {
    if (_slots != null) return;
    _slots = slots;
    _ranked = ranked;
  }

  Future<void> _addGame() async {
    final picked = await showModalBottomSheet<_FavoriteSlot>(
      context: context,
      isScrollControlled: true,
      builder: (context) =>
          _GameSearchSheet(excludeIds: _slots!.map((s) => s.gameId).toSet()),
    );
    if (picked == null) return;
    setState(() => _slots!.add(picked));
  }

  void _removeAt(int index) {
    setState(() => _slots!.removeAt(index));
  }

  void _onReorder(int oldIndex, int newIndex) {
    setState(() {
      if (newIndex > oldIndex) newIndex -= 1;
      final item = _slots!.removeAt(oldIndex);
      _slots!.insert(newIndex, item);
    });
  }

  void _moveBy(int index, int offset) {
    setState(() {
      final item = _slots!.removeAt(index);
      _slots!.insert(index + offset, item);
    });
  }

  Future<void> _save() async {
    setState(() => _isSaving = true);
    try {
      await ref
          .read(favoriteRepositoryProvider)
          .saveFavorites(
            gameIds: _slots!.map((s) => s.gameId).toList(),
            ranked: _ranked,
          );
      ref.invalidate(myFavoritesProvider);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('推しゲーを更新しました')));
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('保存に失敗しました: $e')));
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final favoritesAsync = ref.watch(myFavoritesProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('オレの推しゲーを編集'),
        actions: [
          TextButton(
            onPressed: (_slots == null || _isSaving) ? null : _save,
            child: _isSaving
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('保存'),
          ),
        ],
      ),
      body: favoritesAsync.when(
        data: (favorites) {
          _hydrate([
            for (final f in favorites)
              _FavoriteSlot(
                gameId: f.gameId,
                name: f.displayGameName,
                coverUrl: f.gameCoverUrl,
              ),
          ], favorites.isEmpty ? true : favorites.first.favoritesRanked);
          final slots = _slots!;
          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: SegmentedButton<bool>(
                  segments: const [
                    ButtonSegment(value: true, label: Text('順位あり')),
                    ButtonSegment(value: false, label: Text('順不同')),
                  ],
                  selected: {_ranked},
                  onSelectionChanged: (selection) =>
                      setState(() => _ranked = selection.first),
                ),
              ),
              Expanded(
                child: slots.isEmpty
                    ? const EmptyView(
                        message: 'まだ推しゲーが登録されていません\n右下のボタンから追加しましょう',
                        icon: Icons.favorite_border,
                      )
                    : ReorderableListView.builder(
                        buildDefaultDragHandles: false,
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        itemCount: slots.length,
                        onReorder: _onReorder,
                        itemBuilder: (context, index) {
                          final slot = slots[index];
                          return ListTile(
                            key: ValueKey(slot.gameId),
                            leading: _ranked
                                ? CircleAvatar(child: Text('${index + 1}'))
                                : const Icon(
                                    Icons.favorite,
                                    color: Colors.pink,
                                  ),
                            title: Row(
                              children: [
                                CoverImage(
                                  url: slot.coverUrl,
                                  width: 32,
                                  height: 44,
                                ),
                                const SizedBox(width: 12),
                                Expanded(child: Text(slot.name)),
                              ],
                            ),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  icon: const Icon(Icons.arrow_upward),
                                  iconSize: 20,
                                  visualDensity: VisualDensity.compact,
                                  tooltip: '上へ移動',
                                  onPressed: index == 0
                                      ? null
                                      : () => _moveBy(index, -1),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.arrow_downward),
                                  iconSize: 20,
                                  visualDensity: VisualDensity.compact,
                                  tooltip: '下へ移動',
                                  onPressed: index == slots.length - 1
                                      ? null
                                      : () => _moveBy(index, 1),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.close),
                                  visualDensity: VisualDensity.compact,
                                  tooltip: '削除',
                                  onPressed: () => _removeAt(index),
                                ),
                                ReorderableDragStartListener(
                                  index: index,
                                  child: const Padding(
                                    padding: EdgeInsets.symmetric(
                                      horizontal: 4,
                                    ),
                                    child: Icon(Icons.drag_handle),
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
              ),
              Padding(
                padding: const EdgeInsets.all(16),
                child: FilledButton.icon(
                  onPressed: slots.length >= _maxFavorites ? null : _addGame,
                  icon: const Icon(Icons.add),
                  label: Text(
                    slots.length >= _maxFavorites
                        ? '最大5件まで登録できます'
                        : 'ゲームを追加（${slots.length}/$_maxFavorites）',
                  ),
                ),
              ),
            ],
          );
        },
        loading: () => const LoadingView(),
        error: (error, _) => ErrorView(
          message: '推しゲーの取得に失敗しました',
          onRetry: () => ref.invalidate(myFavoritesProvider),
        ),
      ),
    );
  }
}

/// タイトル検索して推しゲーに追加するゲームを選ぶボトムシート。
class _GameSearchSheet extends ConsumerStatefulWidget {
  const _GameSearchSheet({required this.excludeIds});

  final Set<int> excludeIds;

  @override
  ConsumerState<_GameSearchSheet> createState() => _GameSearchSheetState();
}

class _GameSearchSheetState extends ConsumerState<_GameSearchSheet> {
  final _controller = TextEditingController();
  Timer? _debounce;
  List<Game> _results = [];
  bool _isLoading = false;
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  void _onChanged(String value) {
    _debounce?.cancel();
    final query = value.trim();
    if (query.isEmpty) {
      setState(() {
        _results = [];
        _isLoading = false;
        _error = null;
      });
      return;
    }
    _debounce = Timer(const Duration(milliseconds: 450), () => _search(query));
  }

  Future<void> _search(String query) async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final games = await ref.read(igdbRepositoryProvider).search(query: query);
      if (!mounted) return;
      setState(() {
        _results = games;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = '検索に失敗しました';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          left: 16,
          right: 16,
          top: 16,
          bottom: MediaQuery.of(context).viewInsets.bottom + 16,
        ),
        child: SizedBox(
          height: MediaQuery.of(context).size.height * 0.7,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('ゲームを追加', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              TextField(
                controller: _controller,
                autofocus: true,
                decoration: const InputDecoration(
                  hintText: 'タイトルで検索',
                  prefixIcon: Icon(Icons.search),
                  border: OutlineInputBorder(),
                ),
                onChanged: _onChanged,
              ),
              const SizedBox(height: 8),
              Expanded(child: _buildResults()),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildResults() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return Center(child: Text(_error!));
    }
    if (_results.isEmpty) {
      return const Center(child: Text('タイトルを入力して検索してください'));
    }
    return ListView.separated(
      itemCount: _results.length,
      separatorBuilder: (context, index) => const Divider(height: 1),
      itemBuilder: (context, index) {
        final game = _results[index];
        final alreadyAdded = widget.excludeIds.contains(game.id);
        return ListTile(
          leading: CoverImage(url: game.coverUrl, width: 40, height: 56),
          title: Text(game.displayName),
          trailing: alreadyAdded
              ? const Icon(Icons.check, color: Colors.grey)
              : null,
          onTap: alreadyAdded
              ? null
              : () => Navigator.of(context).pop(
                  _FavoriteSlot(
                    gameId: game.id,
                    name: game.displayName,
                    coverUrl: game.coverUrl,
                  ),
                ),
        );
      },
    );
  }
}
