import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/widgets/async_state_views.dart';
import '../../../../core/widgets/cover_image.dart';
import '../../../../core/widgets/star_rating.dart';
import '../providers/log_providers.dart';

class MyLogsScreen extends ConsumerWidget {
  const MyLogsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final logsAsync = ref.watch(myLogsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('マイログ')),
      body: RefreshIndicator(
        onRefresh: () => ref.refresh(myLogsProvider.future),
        child: logsAsync.when(
          data: (logs) {
            if (logs.isEmpty) {
              return ListView(
                children: const [
                  SizedBox(height: 120),
                  EmptyView(
                    message: 'まだ記録がありません\nゲームを検索して記録してみましょう',
                    icon: Icons.bookmark_border,
                  ),
                ],
              );
            }
            return ListView.separated(
              itemCount: logs.length,
              separatorBuilder: (context, index) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final entry = logs[index];
                return ListTile(
                  leading: CoverImage(
                    url: entry.game.coverUrl,
                    width: 44,
                    height: 60,
                  ),
                  title: Text(entry.game.name),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      StarRating(rating: entry.log.rating.toDouble(), size: 16),
                      if (entry.log.reviewText != null &&
                          entry.log.reviewText!.isNotEmpty)
                        Text(
                          entry.log.reviewText!,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                    ],
                  ),
                  isThreeLine: entry.log.reviewText != null &&
                      entry.log.reviewText!.isNotEmpty,
                  onTap: () => context.push('/games/${entry.game.id}/log'),
                );
              },
            );
          },
          loading: () => const LoadingView(),
          error: (error, _) => ErrorView(
            message: 'ログの取得に失敗しました',
            onRetry: () => ref.invalidate(myLogsProvider),
          ),
        ),
      ),
    );
  }
}
