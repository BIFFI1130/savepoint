import 'package:flutter_test/flutter_test.dart';
import 'package:savepoint/core/utils/release_countdown.dart';

void main() {
  group('releaseCountdownLabel', () {
    test('発売日未設定ならnull', () {
      expect(releaseCountdownLabel(null), isNull);
    });

    test('発売日が過去ならnull', () {
      final yesterday = DateTime.now().subtract(const Duration(days: 1));
      expect(releaseCountdownLabel(yesterday), isNull);
    });

    test('発売日が今日なら「本日発売」', () {
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day, 23, 59);
      expect(releaseCountdownLabel(today), '本日発売');
    });

    test('発売日が未来なら残り日数を表示', () {
      final now = DateTime.now();
      final inTenDays = DateTime(now.year, now.month, now.day).add(
        const Duration(days: 10),
      );
      expect(releaseCountdownLabel(inTenDays), '発売まであと10日');
    });

    test('時刻部分は無視して日付のみで判定する', () {
      final now = DateTime.now();
      // 現在時刻が何時であっても、日付が今日なら「本日発売」になる。
      final todayMidnight = DateTime(now.year, now.month, now.day);
      expect(releaseCountdownLabel(todayMidnight), '本日発売');
    });
  });
}
