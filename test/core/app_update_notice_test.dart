import 'package:flutter_test/flutter_test.dart';
import 'package:savepoint/core/update/app_update_notice.dart';
import 'package:shared_preferences/shared_preferences.dart';

StoreVersionInfo _info(String version) => StoreVersionInfo(
  version: version,
  releaseNotes: 'notes',
  storeUrl: 'https://example.com',
);

void main() {
  group('isNewerVersion', () {
    test('数値としてバージョンを比較する', () {
      expect(isNewerVersion('1.0.8', '1.0.7'), isTrue);
      expect(isNewerVersion('1.1.0', '1.0.9'), isTrue);
      expect(isNewerVersion('2.0.0', '1.9.9'), isTrue);
      // 文字列比較なら "1.0.9" > "1.0.10" になってしまうケース。
      expect(isNewerVersion('1.0.10', '1.0.9'), isTrue);
      expect(isNewerVersion('1.0.9', '1.0.10'), isFalse);
    });

    test('同じ・古いバージョンは新しくない', () {
      expect(isNewerVersion('1.0.7', '1.0.7'), isFalse);
      expect(isNewerVersion('1.0.6', '1.0.7'), isFalse);
      expect(isNewerVersion('1.0', '1.0.0'), isFalse);
      expect(isNewerVersion('1.0.1', '1.0'), isTrue);
    });

    test('解釈できない値ではお知らせを出さない', () {
      expect(isNewerVersion('abc', '1.0.7'), isFalse);
      expect(isNewerVersion('1.0.8', ''), isFalse);
      expect(isNewerVersion('1.0.8-beta', '1.0.7'), isFalse);
    });
  });

  group('AppUpdateNotice', () {
    setUp(() => SharedPreferences.setMockInitialValues({}));

    test('新しいバージョンがあれば返す', () async {
      final notice = AppUpdateNotice(
        currentVersion: '1.0.7',
        fetcher: () async => _info('1.0.8'),
      );
      expect((await notice.versionToAnnounce())?.version, '1.0.8');
    });

    test('最新なら返さない', () async {
      final notice = AppUpdateNotice(
        currentVersion: '1.0.8',
        fetcher: () async => _info('1.0.8'),
      );
      expect(await notice.versionToAnnounce(), isNull);
    });

    test('「あとで」にしたバージョンは再度出さないが、さらに新しい版は出す', () async {
      var latest = '1.0.8';
      var clock = DateTime(2026, 10, 1, 9);
      final notice = AppUpdateNotice(
        currentVersion: '1.0.7',
        fetcher: () async => _info(latest),
        now: () => clock,
      );
      expect((await notice.versionToAnnounce())?.version, '1.0.8');
      await notice.dismiss('1.0.8');

      clock = clock.add(const Duration(hours: 13));
      expect(await notice.versionToAnnounce(), isNull);

      latest = '1.0.9';
      clock = clock.add(const Duration(hours: 13));
      expect((await notice.versionToAnnounce())?.version, '1.0.9');
    });

    test('12時間以内の再確認はストアに問い合わせない', () async {
      var calls = 0;
      var clock = DateTime(2026, 10, 1, 9);
      final notice = AppUpdateNotice(
        currentVersion: '1.0.8',
        fetcher: () async {
          calls++;
          return _info('1.0.8');
        },
        now: () => clock,
      );
      await notice.versionToAnnounce();
      clock = clock.add(const Duration(hours: 1));
      await notice.versionToAnnounce();
      expect(calls, 1);
      clock = clock.add(const Duration(hours: 12));
      await notice.versionToAnnounce();
      expect(calls, 2);
    });

    test('取得に失敗したら確認済みにせず、次回すぐ再試行する', () async {
      var calls = 0;
      final notice = AppUpdateNotice(
        currentVersion: '1.0.7',
        fetcher: () async {
          calls++;
          return calls == 1 ? null : _info('1.0.8');
        },
      );
      expect(await notice.versionToAnnounce(), isNull);
      expect((await notice.versionToAnnounce())?.version, '1.0.8');
    });
  });
}
