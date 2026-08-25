import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../../../core/ads/banner_ad_widget.dart';
import '../../../../core/analytics/analytics_service.dart';
import '../../../../core/subscription/subscription_providers.dart';
import '../../../../core/widgets/async_state_views.dart';
import '../../../game_log/domain/game_log.dart';
import '../../../game_log/presentation/providers/log_providers.dart';
import '../../domain/gamer_type.dart';

/// プレイ傾向診断（性格診断風）。全期間の記録（ジャンル比率・評価パターン・
/// 完走率・積みゲー量）から「ゲーマータイプ」を算出し、SNSでシェアできる
/// カードとして表示する。誰でも無料で使える（新規ユーザー獲得の入口として
/// あえてサブスク特典にしない）。
class GamerTypeScreen extends ConsumerStatefulWidget {
  const GamerTypeScreen({super.key});

  @override
  ConsumerState<GamerTypeScreen> createState() => _GamerTypeScreenState();
}

class _GamerTypeScreenState extends ConsumerState<GamerTypeScreen> {
  final _cardKey = GlobalKey();
  bool _isSharing = false;

  Future<void> _share() async {
    if (_isSharing) return;
    setState(() => _isSharing = true);
    try {
      final boundary =
          _cardKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
      if (boundary == null) return;
      final image = await boundary.toImage(pixelRatio: 3);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      if (byteData == null) return;
      final dir = await getTemporaryDirectory();
      final file = File(
        '${dir.path}/savepoint_gamer_type_${DateTime.now().millisecondsSinceEpoch}.png',
      );
      await file.writeAsBytes(byteData.buffer.asUint8List());
      await SharePlus.instance.share(
        ShareParams(
          files: [XFile(file.path)],
          text: 'SavePointでプレイ傾向を診断してみました',
        ),
      );
      await ref.read(appAnalyticsProvider).logShare(contentType: 'gamer_type');
    } finally {
      if (mounted) setState(() => _isSharing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final logsAsync = ref.watch(myLogsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('プレイ傾向診断')),
      body: Column(
        children: [
          Expanded(child: _buildBody(context, logsAsync)),
          if (!ref.watch(isAdFreeProvider)) const BannerAdWidget(),
        ],
      ),
    );
  }

  Widget _buildBody(
    BuildContext context,
    AsyncValue<List<GameLogWithGame>> logsAsync,
  ) {
    return logsAsync.when(
        data: (logs) {
          final type = diagnoseGamerType(logs);
          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: SizedBox(
              width: double.infinity,
              child: Column(
                children: [
                  RepaintBoundary(
                    key: _cardKey,
                    child: _GamerTypeCard(type: type),
                  ),
                  const SizedBox(height: 20),
                  FilledButton.icon(
                    onPressed: _isSharing ? null : _share,
                    icon: _isSharing
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.ios_share),
                    label: const Text('診断結果をシェア'),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '記録を重ねるほど、診断結果は変わっていきます',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.outline,
                        ),
                  ),
                ],
              ),
            ),
          );
        },
        loading: () => const LoadingView(),
        error: (error, _) => ErrorView(
          message: '診断に失敗しました',
          onRetry: () => ref.invalidate(myLogsProvider),
        ),
      );
  }
}

/// 診断結果カード。画面表示・シェア画像の両方に使う正方形寄りのカード。
class _GamerTypeCard extends StatelessWidget {
  const _GamerTypeCard({required this.type});

  final GamerType type;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 340,
      padding: const EdgeInsets.fromLTRB(28, 36, 28, 36),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [type.color, Color.lerp(type.color, Colors.black, 0.35)!],
        ),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        children: [
          const Text(
            'SavePoint プレイ傾向診断',
            style: TextStyle(color: Colors.white70, fontSize: 13),
          ),
          const SizedBox(height: 24),
          Text(type.emoji, style: const TextStyle(fontSize: 64)),
          const SizedBox(height: 16),
          Text(
            'あなたは',
            style: const TextStyle(color: Colors.white70, fontSize: 14),
          ),
          const SizedBox(height: 4),
          Text(
            type.title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 26,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            type.description,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 14,
              height: 1.6,
            ),
          ),
        ],
      ),
    );
  }
}
