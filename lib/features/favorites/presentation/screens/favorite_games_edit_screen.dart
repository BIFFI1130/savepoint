import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/subscription/subscription_providers.dart';
import '../../../../core/widgets/async_state_views.dart';
import '../../../../core/widgets/cover_image.dart';
import '../../../../core/widgets/igdb_footer.dart';
import '../../../game_log/domain/game_log.dart';
import '../../../game_log/presentation/providers/log_providers.dart';
import '../../../game_search/domain/game.dart';
import '../../../game_search/presentation/providers/game_search_providers.dart';
import '../providers/favorite_providers.dart';

const _maxFavoritesFree = 5;
// DB側の安全弁と合わせている（サブスク特典「推しゲー登録数の上限撤廃」）。
const _maxFavoritesSubscriber = 50;

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
  List<int>? _initialGameIds;
  bool _initialRanked = true;

  @override
  void initState() {
    super.initState();
    // 編集中に読み込ませておき、保存時にはすぐ表示できるようにする。
    ref.read(favoriteSaveAdProvider).preload();
  }

  void _hydrate(List<_FavoriteSlot> slots, bool ranked) {
    if (_slots != null) return;
    _slots = slots;
    _ranked = ranked;
    _initialGameIds = slots.map((s) => s.gameId).toList();
    _initialRanked = ranked;
  }

  /// 保存していない変更があるかどうか（並び替え・追加・削除・順位あり設定の変更を含む）。
  bool get _isDirty {
    final slots = _slots;
    final initialIds = _initialGameIds;
    if (slots == null || initialIds == null) return false;
    if (_ranked != _initialRanked) return true;
    final currentIds = slots.map((s) => s.gameId).toList();
    if (currentIds.length != initialIds.length) return true;
    for (var i = 0; i < currentIds.length; i++) {
      if (currentIds[i] != initialIds[i]) return true;
    }
    return false;
  }

  Future<bool> _confirmDiscard() async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('編集内容を破棄しますか？'),
        content: const Text('保存していない変更があります。このまま戻ると変更は失われます。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('編集を続ける'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('破棄する'),
          ),
        ],
      ),
    );
    return result ?? false;
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
      _initialGameIds = _slots!.map((s) => s.gameId).toList();
      _initialRanked = _ranked;
      // サブスク未加入の場合のみ、保存の区切りとして全画面広告を挟む。
      // 広告が未読み込みの場合はshow()が即座に返るため、保存自体はブロックしない。
      if (!ref.read(isAdFreeProvider)) {
        await ref.read(favoriteSaveAdProvider).show();
      }
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
    final isAdFree = ref.watch(isAdFreeProvider);
    final maxFavorites = isAdFree ? _maxFavoritesSubscriber : _maxFavoritesFree;

    return PopScope(
      canPop: !_isDirty,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        final shouldPop = await _confirmDiscard();
        if (shouldPop && context.mounted) {
          Navigator.of(context).pop();
        }
      },
      child: Scaffold(
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
                          message: 'まだ推しゲーが登録されていません',
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
                const IgdbFooter(),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
                  child: FilledButton.icon(
                    onPressed: slots.length >= maxFavorites ? null : _addGame,
                    icon: const Icon(Icons.add),
                    label: Text(
                      slots.length >= maxFavorites
                          ? '最大$maxFavorites件まで登録できます'
                          : 'ゲームを追加（${slots.length}/$maxFavorites）',
                    ),
                  ),
                ),
                if (!isAdFree && slots.length >= _maxFavoritesFree)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                    child: OutlinedButton.icon(
                      onPressed: () => context.push('/subscription/paywall'),
                      icon: const Icon(Icons.workspace_premium_outlined),
                      label: const Text('サブスクに加入すると上限なく登録できます'),
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
      ),
    );
  }
}

enum _PickerMode { myLogs, search }

/// マイログの「遊んだ」またはタイトル検索から、推しゲーに追加するゲームを選ぶボトムシート。
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
  _PickerMode _mode = _PickerMode.myLogs;

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

  void _pick({required int gameId, required String name, String? coverUrl}) {
    Navigator.of(
      context,
    ).pop(_FavoriteSlot(gameId: gameId, name: name, coverUrl: coverUrl));
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
              SegmentedButton<_PickerMode>(
                segments: const [
                  ButtonSegment(
                    value: _PickerMode.myLogs,
                    label: Text('マイログから'),
                    icon: Icon(Icons.videogame_asset),
                  ),
                  ButtonSegment(
                    value: _PickerMode.search,
                    label: Text('検索する'),
                    icon: Icon(Icons.search),
                  ),
                ],
                selected: {_mode},
                onSelectionChanged: (selection) =>
                    setState(() => _mode = selection.first),
              ),
              const SizedBox(height: 8),
              if (_mode == _PickerMode.search) ...[
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
              ],
              Expanded(
                child: _mode == _PickerMode.myLogs
                    ? _buildMyLogsResults()
                    : _buildSearchResults(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMyLogsResults() {
    final logsAsync = ref.watch(myLogsProvider);
    return logsAsync.when(
      data: (logs) {
        final played = logs
            .where((l) => l.log.status == GameLogStatus.played)
            .toList()
          ..sort((a, b) => b.log.createdAt.compareTo(a.log.createdAt));
        if (played.isEmpty) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Text(
                'まだ「遊んだ」に登録されたゲームがありません。\n「検索する」から選んでください。',
                textAlign: TextAlign.center,
              ),
            ),
          );
        }
        return ListView.separated(
          itemCount: played.length,
          separatorBuilder: (context, index) => const Divider(height: 1),
          itemBuilder: (context, index) {
            final entry = played[index];
            final game = entry.game;
            final alreadyAdded = widget.excludeIds.contains(game.id);
            return ListTile(
              leading: CoverImage(url: game.coverUrl, width: 40, height: 56),
              title: Text(game.displayName),
              trailing: alreadyAdded
                  ? const Icon(Icons.check, color: Colors.grey)
                  : null,
              onTap: alreadyAdded
                  ? null
                  : () => _pick(
                      gameId: game.id,
                      name: game.displayName,
                      coverUrl: game.coverUrl,
                    ),
            );
          },
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) => const Center(child: Text('マイログの取得に失敗しました')),
    );
  }

  Widget _buildSearchResults() {
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
              : () => _pick(
                  gameId: game.id,
                  name: game.displayName,
                  coverUrl: game.coverUrl,
                ),
        );
      },
    );
  }
}
