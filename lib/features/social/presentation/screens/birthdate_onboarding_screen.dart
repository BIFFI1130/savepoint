import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/onboarding/birthdate_gate.dart';
import '../../../../core/utils/age.dart';
import '../providers/social_providers.dart';

/// アプリ起動時に生年月が未設定の場合に必ず経由させる、生年月入力画面。
/// システムのバックボタンでは閉じられない（[PopScope]でブロック）。日は取得せず
/// 年・月のみを保存する（成人向け作品を表示する選択肢を出してよいかの判定に使う）。
class BirthdateOnboardingScreen extends ConsumerStatefulWidget {
  const BirthdateOnboardingScreen({super.key});

  @override
  ConsumerState<BirthdateOnboardingScreen> createState() =>
      _BirthdateOnboardingScreenState();
}

class _BirthdateOnboardingScreenState
    extends ConsumerState<BirthdateOnboardingScreen> {
  int? _year;
  int? _month;
  bool _isSaving = false;

  Future<void> _submit() async {
    final year = _year;
    final month = _month;
    if (year == null || month == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('生年月を選択してください')));
      return;
    }
    // 本アプリはプライバシーポリシー・利用規約で「13歳未満の方の利用を想定していない」
    // としているため、自己申告ベースではあるが最低限の年齢確認として入力を止める。
    if (isDefinitelyUnder13(year, month)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('本アプリは13歳未満の方はご利用いただけません')),
      );
      return;
    }
    setState(() => _isSaving = true);
    try {
      await ref
          .read(socialRepositoryProvider)
          .setBirthYearMonth(year: year, month: month);
      ref.invalidate(myProfileProvider);
      ref.read(birthdateGateProvider).markCompleted();
      if (mounted) context.go('/home');
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
    final currentYear = DateTime.now().year;
    final years = [for (var y = currentYear; y >= 1900; y--) y];

    return PopScope(
      canPop: false,
      child: Scaffold(
        appBar: AppBar(
          automaticallyImplyLeading: false,
          title: const Text('生年月の設定'),
        ),
        body: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                '生年月を設定してください',
                style: Theme.of(context).textTheme.titleLarge,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              const Text(
                '年齢確認のために使用します（日にちの入力は不要です）。',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<int>(
                      initialValue: _year,
                      decoration: const InputDecoration(
                        labelText: '生年',
                        border: OutlineInputBorder(),
                      ),
                      items: [
                        for (final y in years)
                          DropdownMenuItem(value: y, child: Text('$y年')),
                      ],
                      onChanged: (value) => setState(() => _year = value),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: DropdownButtonFormField<int>(
                      initialValue: _month,
                      decoration: const InputDecoration(
                        labelText: '生月',
                        border: OutlineInputBorder(),
                      ),
                      items: [
                        for (var m = 1; m <= 12; m++)
                          DropdownMenuItem(value: m, child: Text('$m月')),
                      ],
                      onChanged: (value) => setState(() => _month = value),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              FilledButton(
                onPressed: _isSaving ? null : _submit,
                child: _isSaving
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('決定する'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
