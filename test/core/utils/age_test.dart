import 'package:flutter_test/flutter_test.dart';
import 'package:savepoint/core/utils/age.dart';

void main() {
  final now = DateTime.now();

  group('isAdultBirthYearMonth', () {
    test('生年月が未設定ならfalse', () {
      expect(isAdultBirthYearMonth(null, null), isFalse);
      expect(isAdultBirthYearMonth(now.year - 20, null), isFalse);
      expect(isAdultBirthYearMonth(null, 5), isFalse);
    });

    test('18歳の誕生月を過ぎていればtrue', () {
      // 誕生月の翌月以降は確実に18歳。
      final birthMonth = now.month == 1 ? 12 : now.month - 1;
      final birthYear = now.month == 1 ? now.year - 19 : now.year - 18;
      expect(isAdultBirthYearMonth(birthYear, birthMonth), isTrue);
    });

    test('18歳の誕生月そのものはまだfalse（日が不明で安全側に倒す）', () {
      expect(isAdultBirthYearMonth(now.year - 18, now.month), isFalse);
    });

    test('19歳以上ならtrue', () {
      expect(isAdultBirthYearMonth(now.year - 19, now.month), isTrue);
      expect(isAdultBirthYearMonth(now.year - 30, 1), isTrue);
    });

    test('17歳以下ならfalse', () {
      expect(isAdultBirthYearMonth(now.year - 17, 1), isFalse);
      expect(isAdultBirthYearMonth(now.year, now.month), isFalse);
    });
  });
}
