import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../domain/game_log.dart';
import '../../domain/steam_library.dart';
import '../providers/log_providers.dart';
import '../providers/steam_import_providers.dart';

/// Steamの所有ゲームを取得し、「遊んだ」「遊びたい（積みゲー）」として一括で取り込む画面。
class SteamImportScreen extends ConsumerStatefulWidget {
  const SteamImportScreen({super.key});

  @override
  ConsumerState<SteamImportScreen> createState() => _SteamImportScreenState();
}

class _SteamImportScreenState extends ConsumerState<SteamImportScreen> {
  final _controller = TextEditingController();

  bool _isLoading = false;
  bool _isImporting = false;
  String? _error;
  SteamLibrary? _library;
  int? _importedCount;

  bool _importPlayed = true;
  bool _importUnplayed = true;
  bool _isPublic = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _fetch() async {
    final input = _controller.text.trim();
    if (input.isEmpty || _isLoading) return;
    FocusScope.of(context).unfocus();
    setState(() {
      _isLoading = true;
      _error = null;
      _library = null;
      _importedCount = null;
    });
    try {
      final library = await ref
          .read(steamImportRepositoryProvider)
          .fetchLibrary(input);
      if (!mounted) return;
      setState(() => _library = library);
    } on SteamImportException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } catch (_) {
      if (mounted) {
        setState(() => _error = '取り込みに失敗しました。時間をおいてお試しください');
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _import(SteamLibrary library) async {
    if (_isImporting) return;
    setState(() => _isImporting = true);
    try {
      final count = await ref.read(steamImportRepositoryProvider).importLogs(
            played: _importPlayed ? library.playedGames : const [],
            wantToPlay: _importUnplayed ? library.unplayedGames : const [],
            visibility: _isPublic
                ? GameLogVisibility.public
                : GameLogVisibility.private_,
          );
      ref.invalidate(myLogsProvider);
      if (mounted) setState(() => _importedCount = count);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('取り込みに失敗しました。もう一度お試しください')),
        );
      }
    } finally {
      if (mounted) setState(() => _isImporting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final library = _library;
    return Scaffold(
      appBar: AppBar(title: const Text('Steamから取り込む')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            'Steamで持っているゲームを、SavePointの記録として一括で追加できます。'
            '遊んだゲームは「遊んだ」、未プレイのゲームは「遊びたい」（積みゲー）になります。',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _controller,
            enabled: !_isLoading && !_isImporting,
            textInputAction: TextInputAction.search,
            autocorrect: false,
            onSubmitted: (_) => _fetch(),
            decoration: const InputDecoration(
              labelText: 'SteamのプロフィールURLまたはカスタムURLの名前',
              hintText: 'https://steamcommunity.com/id/あなたの名前',
              helperText: 'Steamのプロフィールの「ゲームの詳細」を「公開」にしておいてください',
              helperMaxLines: 2,
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          FilledButton(
            onPressed: _isLoading || _isImporting ? null : _fetch,
            child: _isLoading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('ライブラリを取得'),
          ),
          if (_error != null) ...[
            const SizedBox(height: 16),
            Text(
              _error!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ],
          if (library != null) ..._buildResult(context, library),
        ],
      ),
    );
  }

  List<Widget> _buildResult(BuildContext context, SteamLibrary library) {
    final theme = Theme.of(context);
    if (library.games.isEmpty) {
      return [
        const SizedBox(height: 24),
        Text(
          library.totalOwned == 0
              ? 'このSteamアカウントにはゲームが見つかりませんでした'
              : '取り込めるゲームが見つかりませんでした（Steamに${library.totalOwned}本ありますが、'
                  'SavePointの作品データと対応づけられませんでした）',
        ),
      ];
    }

    if (_importedCount != null) {
      return [
        const SizedBox(height: 24),
        Card(
          margin: EdgeInsets.zero,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$_importedCount本を取り込みました',
                  style: theme.textTheme.titleMedium,
                ),
                const SizedBox(height: 4),
                Text(
                  _importedCount == 0
                      ? 'すべて既にSavePointに記録があったため、追加はありません'
                      : '評価やレビューは、マイログから後でいつでも付けられます',
                  style: theme.textTheme.bodySmall,
                ),
                const SizedBox(height: 12),
                FilledButton.tonal(
                  onPressed: () => context.push('/backlog-estimate'),
                  child: const Text('積みゲーの消化にかかる期間を見る'),
                ),
              ],
            ),
          ),
        ),
      ];
    }

    final played = library.playedGames;
    final unplayed = library.unplayedGames;
    final selectedCount = (_importPlayed ? played.length : 0) +
        (_importUnplayed ? unplayed.length : 0);

    return [
      const SizedBox(height: 24),
      Text(
        'Steamで取り込めるゲーム: ${library.games.length}本',
        style: theme.textTheme.titleMedium,
      ),
      if (library.unmatchedCount > 0 || library.truncated)
        Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Text(
            [
              if (library.unmatchedCount > 0)
                '${library.unmatchedCount}本はDLCなど対応する作品がないため含めていません',
              if (library.truncated) '所有数が多いため、先頭の一部のみ処理しました',
            ].join('\n'),
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.outline,
            ),
          ),
        ),
      const SizedBox(height: 8),
      CheckboxListTile(
        contentPadding: EdgeInsets.zero,
        value: _importPlayed,
        onChanged: (value) => setState(() => _importPlayed = value ?? false),
        title: Text('遊んだゲーム ${played.length}本'),
        subtitle: const Text('プレイ時間があるゲームを「遊んだ」として追加'),
      ),
      CheckboxListTile(
        contentPadding: EdgeInsets.zero,
        value: _importUnplayed,
        onChanged: (value) => setState(() => _importUnplayed = value ?? false),
        title: Text('未プレイのゲーム ${unplayed.length}本'),
        subtitle: const Text('「遊びたい」（積みゲー）として追加'),
      ),
      SwitchListTile(
        contentPadding: EdgeInsets.zero,
        value: _isPublic,
        onChanged: (value) => setState(() => _isPublic = value),
        title: const Text('取り込んだ記録を公開する'),
        subtitle: const Text('オフ（非公開）のままなら、あなただけに表示されます'),
      ),
      const SizedBox(height: 8),
      Text(
        '既にSavePointに記録があるゲームは変更しません。',
        style: theme.textTheme.bodySmall?.copyWith(
          color: theme.colorScheme.outline,
        ),
      ),
      const SizedBox(height: 12),
      FilledButton(
        onPressed: selectedCount == 0 || _isImporting
            ? null
            : () => _import(library),
        child: _isImporting
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : Text('$selectedCount本を取り込む'),
      ),
    ];
  }
}
