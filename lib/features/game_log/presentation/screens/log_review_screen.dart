import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/widgets/async_state_views.dart';
import '../../../../core/widgets/star_rating.dart';
import '../../../game_search/presentation/providers/game_search_providers.dart';
import '../providers/log_providers.dart';

class LogReviewScreen extends ConsumerStatefulWidget {
  const LogReviewScreen({super.key, required this.gameId});

  final int gameId;

  @override
  ConsumerState<LogReviewScreen> createState() => _LogReviewScreenState();
}

class _LogReviewScreenState extends ConsumerState<LogReviewScreen> {
  final _reviewController = TextEditingController();
  double _rating = 0;
  bool _hasSpoiler = false;
  bool _isSaving = false;
  bool _initialized = false;

  @override
  void dispose() {
    _reviewController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_rating == 0) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('評価を選択してください')));
      return;
    }
    setState(() => _isSaving = true);
    try {
      await ref.read(logRepositoryProvider).upsertPlayedLog(
            gameId: widget.gameId,
            rating: _rating.round(),
            reviewText: _reviewController.text.trim().isEmpty
                ? null
                : _reviewController.text.trim(),
            hasSpoiler: _hasSpoiler,
          );
      ref.invalidate(myLogsProvider);
      ref.invalidate(existingLogProvider(widget.gameId));
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('記録を保存しました')));
        context.go('/home', extra: 1);
      }
    } catch (e) {
      debugPrint('game_logs upsert failed: $e');
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('保存に失敗しました: $e')));
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final gameAsync = ref.watch(gameDetailsProvider(widget.gameId));
    final existingLogAsync = ref.watch(existingLogProvider(widget.gameId));

    existingLogAsync.whenData((existingLog) {
      if (!_initialized && existingLog != null) {
        _initialized = true;
        _rating = existingLog.rating?.toDouble() ?? 0;
        _reviewController.text = existingLog.reviewText ?? '';
        _hasSpoiler = existingLog.hasSpoiler;
      }
    });

    return Scaffold(
      appBar: AppBar(title: const Text('記録・評価・レビュー')),
      body: gameAsync.when(
        data: (game) {
          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (game != null)
                  Text(
                    game.name,
                    style: Theme.of(context).textTheme.titleLarge,
                    textAlign: TextAlign.center,
                  ),
                const SizedBox(height: 16),
                Center(
                  child: StarRating(
                    rating: _rating,
                    onChanged: (value) => setState(() => _rating = value),
                  ),
                ),
                const SizedBox(height: 24),
                TextField(
                  controller: _reviewController,
                  maxLines: 6,
                  decoration: const InputDecoration(
                    labelText: 'レビュー（任意）',
                    hintText: 'プレイした感想を書きましょう',
                    border: OutlineInputBorder(),
                    alignLabelWithHint: true,
                  ),
                ),
                CheckboxListTile(
                  value: _hasSpoiler,
                  onChanged: (value) => setState(() => _hasSpoiler = value ?? false),
                  contentPadding: EdgeInsets.zero,
                  controlAffinity: ListTileControlAffinity.leading,
                  title: const Text('ネタバレを含む'),
                  subtitle: const Text('ストーリーの結末や重要な展開に触れている場合はオンにしてください'),
                ),
                const SizedBox(height: 8),
                FilledButton(
                  onPressed: _isSaving ? null : _save,
                  child: _isSaving
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('保存する'),
                ),
              ],
            ),
          );
        },
        loading: () => const LoadingView(),
        error: (error, _) => const ErrorView(message: 'ゲーム情報の取得に失敗しました'),
      ),
    );
  }
}
