import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:permission_handler/permission_handler.dart' as ph;

import '../../../../core/notifications/aged_backlog_reminder_service.dart';
import '../../../../core/notifications/backlog_reminder_service.dart';
import '../../../../core/notifications/memories_reminder_service.dart';
import '../../../../core/notifications/monthly_recap_reminder_service.dart';
import '../../../../core/notifications/push_notification_service.dart';
import '../../../../core/notifications/streak_reminder_service.dart';
import '../../../game_log/presentation/providers/log_providers.dart';
import '../../../social/presentation/providers/social_providers.dart';

/// 設定 → 通知。
class SettingsNotificationsScreen extends ConsumerStatefulWidget {
  const SettingsNotificationsScreen({super.key});

  @override
  ConsumerState<SettingsNotificationsScreen> createState() =>
      _SettingsNotificationsScreenState();
}

class _SettingsNotificationsScreenState
    extends ConsumerState<SettingsNotificationsScreen> {
  Future<void> _toggleBacklogReminder(bool value) async {
    final service = ref.read(backlogReminderServiceProvider);
    if (value) {
      final granted = await service.enable();
      if (!granted && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('通知の許可が必要です。端末の設定から許可してください')),
        );
      }
    } else {
      await service.disable();
    }
    ref.invalidate(backlogReminderEnabledProvider);
  }

  Future<void> _toggleStreakReminder(bool value) async {
    final service = ref.read(streakReminderServiceProvider);
    if (value) {
      final granted = await service.enable();
      if (!granted && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('通知の許可が必要です。端末の設定から許可してください')),
        );
      } else {
        final logs = ref.read(myLogsProvider).valueOrNull;
        if (logs != null) await service.syncSchedule(logs);
      }
    } else {
      await service.disable();
    }
    ref.invalidate(streakReminderEnabledProvider);
  }

  Future<void> _toggleAgedBacklogReminder(bool value) async {
    final service = ref.read(agedBacklogReminderServiceProvider);
    if (value) {
      final granted = await service.enable();
      if (!granted && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('通知の許可が必要です。端末の設定から許可してください')),
        );
      } else {
        final logs = ref.read(myLogsProvider).valueOrNull;
        if (logs != null) await service.syncSchedule(logs);
      }
    } else {
      await service.disable();
    }
    ref.invalidate(agedBacklogReminderEnabledProvider);
  }

  Future<void> _toggleMonthlyRecap(bool value) async {
    final service = ref.read(monthlyRecapReminderServiceProvider);
    if (value) {
      final granted = await service.enable();
      if (!granted && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('通知の許可が必要です。端末の設定から許可してください')),
        );
      }
    } else {
      await service.disable();
    }
    ref.invalidate(monthlyRecapEnabledProvider);
  }

  Future<void> _toggleMemoriesReminder(bool value) async {
    final service = ref.read(memoriesReminderServiceProvider);
    if (value) {
      final granted = await service.enable();
      if (!granted && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('通知の許可が必要です。端末の設定から許可してください')),
        );
      } else {
        final logs = ref.read(myLogsProvider).valueOrNull;
        if (logs != null) await service.syncSchedule(logs);
      }
    } else {
      await service.disable();
    }
    ref.invalidate(memoriesReminderEnabledProvider);
  }

  Future<void> _toggleNotifyFollowingReviews(bool value) async {
    await ref.read(socialRepositoryProvider).setNotifyFollowingReviews(value);
    ref.invalidate(myProfileProvider);
  }

  Future<void> _toggleNotifyNewFollower(bool value) async {
    await ref.read(socialRepositoryProvider).setNotifyNewFollower(value);
    ref.invalidate(myProfileProvider);
  }

  Future<void> _toggleNotifyWeeklyDigest(bool value) async {
    await ref.read(socialRepositoryProvider).setNotifyWeeklyDigest(value);
    ref.invalidate(myProfileProvider);
  }

  Future<void> _toggleNotifyNewLike(bool value) async {
    await ref.read(socialRepositoryProvider).setNotifyNewLike(value);
    ref.invalidate(myProfileProvider);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('通知')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Consumer(
            builder: (context, ref, _) {
              final enabledAsync = ref.watch(backlogReminderEnabledProvider);
              return SwitchListTile(
                value: enabledAsync.value ?? false,
                onChanged: enabledAsync.isLoading ? null : _toggleBacklogReminder,
                contentPadding: EdgeInsets.zero,
                title: const Text('積みゲーリマインダー'),
                subtitle: const Text('「遊びたい」の消化を週1回通知でお知らせします'),
              );
            },
          ),
          _WeekdayTimeScheduleRow(
            getSchedule: () =>
                ref.read(backlogReminderServiceProvider).getSchedule(),
            setSchedule: (weekday, hour, minute) => ref
                .read(backlogReminderServiceProvider)
                .setSchedule(weekday: weekday, hour: hour, minute: minute),
          ),
          Consumer(
            builder: (context, ref, _) {
              final enabledAsync = ref.watch(streakReminderEnabledProvider);
              return SwitchListTile(
                value: enabledAsync.value ?? false,
                onChanged: enabledAsync.isLoading ? null : _toggleStreakReminder,
                contentPadding: EdgeInsets.zero,
                title: const Text('記録ストリークリマインダー'),
                subtitle: const Text('週間記録ストリークが途切れそうな時にお知らせします'),
              );
            },
          ),
          _WeekdayTimeScheduleRow(
            getSchedule: () =>
                ref.read(streakReminderServiceProvider).getSchedule(),
            setSchedule: (weekday, hour, minute) async {
              await ref
                  .read(streakReminderServiceProvider)
                  .setSchedule(weekday: weekday, hour: hour, minute: minute);
              final logs = ref.read(myLogsProvider).valueOrNull;
              if (logs != null) {
                await ref.read(streakReminderServiceProvider).syncSchedule(logs);
              }
            },
          ),
          Consumer(
            builder: (context, ref, _) {
              final enabledAsync = ref.watch(agedBacklogReminderEnabledProvider);
              return SwitchListTile(
                value: enabledAsync.value ?? false,
                onChanged:
                    enabledAsync.isLoading ? null : _toggleAgedBacklogReminder,
                contentPadding: EdgeInsets.zero,
                title: const Text('積みゲー経年アラート'),
                subtitle: const Text('長期間手つかずの「遊びたい」作品をお知らせします'),
              );
            },
          ),
          Consumer(
            builder: (context, ref, _) {
              final enabledAsync = ref.watch(monthlyRecapEnabledProvider);
              return SwitchListTile(
                value: enabledAsync.value ?? false,
                onChanged: enabledAsync.isLoading ? null : _toggleMonthlyRecap,
                contentPadding: EdgeInsets.zero,
                title: const Text('月末のふりかえり通知'),
                subtitle: const Text('月末に今月の記録の振り返りをお知らせします'),
              );
            },
          ),
          _TimeScheduleRow(
            getSchedule: () =>
                ref.read(monthlyRecapReminderServiceProvider).getSchedule(),
            setSchedule: (hour, minute) => ref
                .read(monthlyRecapReminderServiceProvider)
                .setSchedule(hour: hour, minute: minute),
          ),
          Consumer(
            builder: (context, ref, _) {
              final enabledAsync = ref.watch(memoriesReminderEnabledProvider);
              return SwitchListTile(
                value: enabledAsync.value ?? false,
                onChanged:
                    enabledAsync.isLoading ? null : _toggleMemoriesReminder,
                contentPadding: EdgeInsets.zero,
                title: const Text('1年前の今日'),
                subtitle: const Text('過去の同じ日に記録した作品があればお知らせします'),
              );
            },
          ),
          const _PushPermissionTile(),
          Consumer(
            builder: (context, ref, _) {
              final profileAsync = ref.watch(myProfileProvider);
              return SwitchListTile(
                value: profileAsync.value?.notifyNewFollower ?? true,
                onChanged:
                    profileAsync.isLoading ? null : _toggleNotifyNewFollower,
                contentPadding: EdgeInsets.zero,
                title: const Text('新しいフォロワーの通知'),
                subtitle: const Text('誰かに新しくフォローされたときにお知らせします'),
              );
            },
          ),
          Consumer(
            builder: (context, ref, _) {
              final profileAsync = ref.watch(myProfileProvider);
              return SwitchListTile(
                value: profileAsync.value?.notifyFollowingReviews ?? true,
                onChanged: profileAsync.isLoading
                    ? null
                    : _toggleNotifyFollowingReviews,
                contentPadding: EdgeInsets.zero,
                title: const Text('フォロー中ユーザーの新着レビュー通知'),
                subtitle: const Text('フォロー中のユーザーがレビューを投稿したときにお知らせします'),
              );
            },
          ),
          Consumer(
            builder: (context, ref, _) {
              final profileAsync = ref.watch(myProfileProvider);
              return SwitchListTile(
                value: profileAsync.value?.notifyWeeklyDigest ?? true,
                onChanged:
                    profileAsync.isLoading ? null : _toggleNotifyWeeklyDigest,
                contentPadding: EdgeInsets.zero,
                title: const Text('フォロー中ユーザーの週間ダイジェスト'),
                subtitle: const Text('週1回、フォロー中のユーザーの新着記録をまとめてお知らせします'),
              );
            },
          ),
          Consumer(
            builder: (context, ref, _) {
              final profileAsync = ref.watch(myProfileProvider);
              return SwitchListTile(
                value: profileAsync.value?.notifyNewLike ?? true,
                onChanged:
                    profileAsync.isLoading ? null : _toggleNotifyNewLike,
                contentPadding: EdgeInsets.zero,
                title: const Text('いいね通知'),
                subtitle: const Text('自分の記録にいいねされたときにお知らせします'),
              );
            },
          ),
        ],
      ),
    );
  }
}

/// 「プッシュ通知を有効にする」行。アプリ独自のON/OFFは持たず、iPhone（端末）側の
/// 本アプリの通知許可状態をそのまま表示する。タップすると、まだ一度も許可を
/// 求めていなければOSの許可ダイアログを出し、既に許可/拒否が確定していれば
/// 端末の設定アプリの本アプリの通知設定画面を直接開く（iOSは一度確定した許可を
/// アプリ側から再度ダイアログで尋ねることができないため）。
class _PushPermissionTile extends ConsumerWidget {
  const _PushPermissionTile();

  Future<void> _handleTap(WidgetRef ref) async {
    final service = ref.read(pushNotificationServiceProvider);
    final status = await service.authorizationStatus();
    if (status.isDenied) {
      final granted = await service.requestPermission();
      if (!granted) await service.openSystemSettings();
    } else {
      await service.openSystemSettings();
    }
    ref.invalidate(pushAuthorizationStatusProvider);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final statusAsync = ref.watch(pushAuthorizationStatusProvider);
    final status = statusAsync.value;
    final outline = Theme.of(context).colorScheme.outline;
    final (String subtitle, IconData icon, Color color) = switch (status) {
      null => ('確認中…', Icons.notifications_outlined, outline),
      ph.PermissionStatus.granted ||
      ph.PermissionStatus.limited ||
      ph.PermissionStatus.provisional => (
          '有効です（端末の設定から変更できます）',
          Icons.notifications_active_outlined,
          Theme.of(context).colorScheme.primary,
        ),
      ph.PermissionStatus.permanentlyDenied ||
      ph.PermissionStatus.restricted => (
          '端末の設定でブロックされています。タップして設定を開く',
          Icons.notifications_off_outlined,
          Theme.of(context).colorScheme.error,
        ),
      ph.PermissionStatus.denied => (
          'タップして許可する',
          Icons.notifications_off_outlined,
          outline,
        ),
    };
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(icon, color: color),
      title: const Text('プッシュ通知を有効にする'),
      subtitle: Text(subtitle),
      onTap: statusAsync.isLoading ? null : () => _handleTap(ref),
    );
  }
}

const _weekdayLabels = {
  DateTime.monday: '月曜',
  DateTime.tuesday: '火曜',
  DateTime.wednesday: '水曜',
  DateTime.thursday: '木曜',
  DateTime.friday: '金曜',
  DateTime.saturday: '土曜',
  DateTime.sunday: '日曜',
};

String _timeLabel(int hour, int minute) =>
    '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}';

/// 曜日+時刻の通知タイミング設定行（積みゲーリマインダー・記録ストリーク用）。
class _WeekdayTimeScheduleRow extends StatefulWidget {
  const _WeekdayTimeScheduleRow({
    required this.getSchedule,
    required this.setSchedule,
  });

  final Future<({int weekday, int hour, int minute})> Function() getSchedule;
  final Future<void> Function(int weekday, int hour, int minute) setSchedule;

  @override
  State<_WeekdayTimeScheduleRow> createState() =>
      _WeekdayTimeScheduleRowState();
}

class _WeekdayTimeScheduleRowState extends State<_WeekdayTimeScheduleRow> {
  ({int weekday, int hour, int minute})? _schedule;

  @override
  void initState() {
    super.initState();
    widget.getSchedule().then((value) {
      if (mounted) setState(() => _schedule = value);
    });
  }

  Future<void> _edit() async {
    final schedule = _schedule;
    if (schedule == null) return;
    var weekday = schedule.weekday;
    final time = await showDialog<TimeOfDay>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('通知タイミングを変更'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButton<int>(
                value: weekday,
                isExpanded: true,
                items: [
                  for (final entry in _weekdayLabels.entries)
                    DropdownMenuItem(value: entry.key, child: Text(entry.value)),
                ],
                onChanged: (value) {
                  if (value != null) setDialogState(() => weekday = value);
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('キャンセル'),
            ),
            FilledButton(
              onPressed: () async {
                final picked = await showTimePicker(
                  context: context,
                  initialTime: TimeOfDay(hour: schedule.hour, minute: schedule.minute),
                );
                if (picked != null && context.mounted) {
                  Navigator.pop(context, picked);
                }
              },
              child: const Text('時刻を選ぶ'),
            ),
          ],
        ),
      ),
    );
    if (time == null) return;
    await widget.setSchedule(weekday, time.hour, time.minute);
    final updated = await widget.getSchedule();
    if (mounted) setState(() => _schedule = updated);
  }

  @override
  Widget build(BuildContext context) {
    final schedule = _schedule;
    return Padding(
      padding: const EdgeInsets.only(left: 16, bottom: 8),
      child: InkWell(
        onTap: schedule == null ? null : _edit,
        child: Text(
          schedule == null
              ? ''
              : '通知タイミング：${_weekdayLabels[schedule.weekday]} ${_timeLabel(schedule.hour, schedule.minute)}（変更する）',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.primary,
              ),
        ),
      ),
    );
  }
}

/// 時刻のみの通知タイミング設定行（月末のふりかえり通知用）。
class _TimeScheduleRow extends StatefulWidget {
  const _TimeScheduleRow({required this.getSchedule, required this.setSchedule});

  final Future<({int hour, int minute})> Function() getSchedule;
  final Future<void> Function(int hour, int minute) setSchedule;

  @override
  State<_TimeScheduleRow> createState() => _TimeScheduleRowState();
}

class _TimeScheduleRowState extends State<_TimeScheduleRow> {
  ({int hour, int minute})? _schedule;

  @override
  void initState() {
    super.initState();
    widget.getSchedule().then((value) {
      if (mounted) setState(() => _schedule = value);
    });
  }

  Future<void> _edit() async {
    final schedule = _schedule;
    if (schedule == null) return;
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: schedule.hour, minute: schedule.minute),
    );
    if (picked == null) return;
    await widget.setSchedule(picked.hour, picked.minute);
    final updated = await widget.getSchedule();
    if (mounted) setState(() => _schedule = updated);
  }

  @override
  Widget build(BuildContext context) {
    final schedule = _schedule;
    return Padding(
      padding: const EdgeInsets.only(left: 16, bottom: 8),
      child: InkWell(
        onTap: schedule == null ? null : _edit,
        child: Text(
          schedule == null
              ? ''
              : '通知時刻：${_timeLabel(schedule.hour, schedule.minute)}（変更する）',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.primary,
              ),
        ),
      ),
    );
  }
}
