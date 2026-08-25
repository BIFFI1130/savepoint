import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/analytics/analytics_service.dart';
import '../../../../core/supabase/supabase_client.dart';
import '../../../../core/widgets/async_state_views.dart';
import '../../../../core/widgets/star_rating.dart';
import '../../../game_search/presentation/providers/game_search_providers.dart';
import '../../data/log_draft_service.dart';
import '../../domain/game_log.dart';
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
  bool _isCleared = false;
  bool _isSaving = false;
  bool _initialized = false;
  bool _draftApplied = false;
  bool _hadReview = false;
  GameLogVisibility _visibility = GameLogVisibility.public;

  @override
  void initState() {
    super.initState();
    _loadDraftIfAny();
  }

  @override
  void dispose() {
    _reviewController.dispose();
    super.dispose();
  }

  bool get _hasReview => _rating > 0 || _reviewController.text.trim().isNotEmpty;

  /// 保存せずに離脱した下書きがあれば復元する。サーバーから取得した既存の記録
  /// （_hadReviewの判定に使う）とは独立して扱い、どちらが先に届いても正しく
  /// 動くようにする（既存記録の初期化ロジックとは別のフラグ_draftAppliedで管理）。
  Future<void> _loadDraftIfAny() async {
    final draft = await ref.read(logDraftServiceProvider).load(widget.gameId);
    if (draft == null || !mounted || _draftApplied) return;
    _draftApplied = true;
    setState(() {
      _rating = draft.rating;
      _reviewController.text = draft.reviewText;
      _hasSpoiler = draft.hasSpoiler;
      _isCleared = draft.isCleared;
      _visibility = draft.visibility;
    });
  }

  void _saveDraft() {
    unawaited(
      ref.read(logDraftServiceProvider).save(
            widget.gameId,
            LogDraft(
              rating: _rating,
              reviewText: _reviewController.text,
              hasSpoiler: _hasSpoiler,
              isCleared: _isCleared,
              visibility: _visibility,
            ),
          ),
    );
  }

  Future<void> _openReviewSheet() async {
    final result = await showModalBottomSheet<_ReviewSheetResult>(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) => _ReviewSheet(
        initialRating: _rating,
        initialReviewText: _reviewController.text,
        initialHasSpoiler: _hasSpoiler,
      ),
    );

    if (result != null) {
      setState(() {
        _rating = result.rating;
        _reviewController.text = result.reviewText;
        _hasSpoiler = result.hasSpoiler;
      });
      _saveDraft();
    }
  }

  Future<void> _save() async {
    setState(() => _isSaving = true);
    final isNewReview = !_hadReview && _hasReview;
    try {
      await ref.read(logRepositoryProvider).upsertPlayedLog(
            gameId: widget.gameId,
            rating: _rating == 0 ? null : _rating,
            reviewText: _reviewController.text.trim().isEmpty
                ? null
                : _reviewController.text.trim(),
            hasSpoiler: _hasSpoiler,
            isCleared: _isCleared,
            visibility: _visibility,
          );
      await ref.read(appAnalyticsProvider).logRecordCreated(
            status: 'played',
            hasRating: _rating > 0,
            hasReview: _reviewController.text.trim().isNotEmpty,
          );
      ref.invalidate(myLogsProvider);
      ref.invalidate(existingLogProvider(widget.gameId));
      unawaited(ref.read(logDraftServiceProvider).clear(widget.gameId));
      if (isNewReview && _visibility != GameLogVisibility.private_) {
        unawaited(_notifyFollowersOfNewReview());
      }
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('記録を保存しました')));
        context.pop();
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

  /// フォロー中ユーザーへ新着レビューを通知する（notify-new-review Edge Function）。
  /// ベストエフォートの副作用のため、失敗しても記録の保存自体には影響させない。
  Future<void> _notifyFollowersOfNewReview() async {
    try {
      await supabase.functions.invoke(
        'notify-new-review',
        body: {'game_id': widget.gameId},
      );
    } catch (error, stackTrace) {
      debugPrint('notifyFollowersOfNewReview failed: $error\n$stackTrace');
    }
  }

  Widget _buildReviewSection(BuildContext context) {
    if (!_hasReview) {
      return OutlinedButton.icon(
        onPressed: _openReviewSheet,
        icon: const Icon(Icons.rate_review_outlined),
        label: const Text('レビューを付ける（任意）'),
      );
    }
    return Card(
      child: InkWell(
        onTap: _openReviewSheet,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (_rating > 0) ...[
                      StarRating(rating: _rating, size: 20),
                      const SizedBox(height: 4),
                    ],
                    if (_reviewController.text.trim().isNotEmpty)
                      Text(
                        _reviewController.text.trim(),
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                      ),
                    if (_hasSpoiler) ...[
                      const SizedBox(height: 4),
                      const Chip(
                        label: Text('ネタバレ'),
                        visualDensity: VisualDensity.compact,
                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                    ],
                  ],
                ),
              ),
              const Icon(Icons.edit_outlined),
            ],
          ),
        ),
      ),
    );
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
        _isCleared = existingLog.isCleared;
        _visibility = existingLog.visibility;
        _hadReview = _hasReview;
      }
    });

    return Scaffold(
      appBar: AppBar(title: const Text('記録・評価・レビュー')),
      body: gameAsync.when(
        data: (game) {
          final releaseDate = game?.firstReleaseDate;
          if (releaseDate != null && releaseDate.isAfter(DateTime.now())) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  'このゲームはまだ発売されていないため記録できません。発売後に改めてお試しください。',
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }
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
                _buildReviewSection(context),
                const SizedBox(height: 8),
                CheckboxListTile(
                  value: _isCleared,
                  onChanged: (value) {
                    setState(() => _isCleared = value ?? false);
                    _saveDraft();
                  },
                  contentPadding: EdgeInsets.zero,
                  controlAffinity: ListTileControlAffinity.leading,
                  title: const Text('クリアした'),
                  subtitle: const Text('エンディングまで到達した場合はオンにしてください'),
                ),
                const SizedBox(height: 16),
                Text('公開範囲', style: Theme.of(context).textTheme.titleSmall),
                const SizedBox(height: 4),
                SegmentedButton<GameLogVisibility>(
                  segments: [
                    for (final v in GameLogVisibility.values)
                      ButtonSegment(value: v, label: Text(v.label)),
                  ],
                  selected: {_visibility},
                  onSelectionChanged: (selection) {
                    setState(() => _visibility = selection.first);
                    _saveDraft();
                  },
                ),
                const SizedBox(height: 4),
                Text(
                  _visibility.description,
                  style: Theme.of(context).textTheme.bodySmall,
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

class _ReviewSheetResult {
  const _ReviewSheetResult({
    required this.rating,
    required this.reviewText,
    required this.hasSpoiler,
  });

  final double rating;
  final String reviewText;
  final bool hasSpoiler;
}

/// レビュー入力用のボトムシート。自前でTextEditingControllerを持ち、
/// ウィジェット自身のライフサイクルに合わせて破棄する
/// （シートを閉じた直後に呼び出し側で破棄すると、閉じるアニメーション中の
/// TextFieldがdispose済みのcontrollerを参照してクラッシュするため）。
class _ReviewSheet extends StatefulWidget {
  const _ReviewSheet({
    required this.initialRating,
    required this.initialReviewText,
    required this.initialHasSpoiler,
  });

  final double initialRating;
  final String initialReviewText;
  final bool initialHasSpoiler;

  @override
  State<_ReviewSheet> createState() => _ReviewSheetState();
}

class _ReviewSheetState extends State<_ReviewSheet> {
  late final _reviewController = TextEditingController(text: widget.initialReviewText);
  late double _rating = widget.initialRating;
  late bool _hasSpoiler = widget.initialHasSpoiler;

  @override
  void dispose() {
    _reviewController.dispose();
    super.dispose();
  }

  void _post() {
    Navigator.pop(
      context,
      _ReviewSheetResult(
        rating: _rating,
        reviewText: _reviewController.text,
        hasSpoiler: _hasSpoiler,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 16,
        bottom: MediaQuery.of(context).viewInsets.bottom + 16,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'レビューを書く',
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
            if (_rating > 0)
              Center(
                child: TextButton(
                  onPressed: () => setState(() => _rating = 0),
                  child: const Text('評価なしにする'),
                ),
              ),
            const SizedBox(height: 8),
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
              onPressed: _post,
              child: const Text('投稿する'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('キャンセル'),
            ),
          ],
        ),
      ),
    );
  }
}
