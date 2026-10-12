import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:savepoint/features/game_log/data/steam_import_repository.dart';
import 'package:savepoint/features/game_log/domain/game_log.dart';
import 'package:savepoint/features/game_log/domain/steam_library.dart';
import 'package:savepoint/features/game_log/presentation/providers/steam_import_providers.dart';
import 'package:savepoint/features/game_log/presentation/screens/steam_import_screen.dart';

class _FakeRepository implements SteamImportRepository {
  _FakeRepository({this.library, this.error});

  final SteamLibrary? library;
  final SteamImportException? error;

  String? fetchedInput;
  List<SteamGame>? importedPlayed;
  List<SteamGame>? importedWantToPlay;
  GameLogVisibility? importedVisibility;

  @override
  Future<SteamLibrary> fetchLibrary(String input) async {
    fetchedInput = input;
    if (error != null) throw error!;
    return library!;
  }

  @override
  Future<int> importLogs({
    required List<SteamGame> played,
    required List<SteamGame> wantToPlay,
    required GameLogVisibility visibility,
  }) async {
    importedPlayed = played;
    importedWantToPlay = wantToPlay;
    importedVisibility = visibility;
    return played.length + wantToPlay.length;
  }
}

SteamGame _game(int id, int minutes) =>
    SteamGame(gameId: id, name: 'Game $id', playtimeMinutes: minutes);

final _library = SteamLibrary(
  totalOwned: 5,
  unmatchedCount: 2,
  truncated: false,
  games: [_game(1, 600), _game(2, 30), _game(3, 0)],
);

Future<void> _pump(WidgetTester tester, _FakeRepository repository) async {
  tester.view.physicalSize = const Size(800, 1800);
  tester.view.devicePixelRatio = 2;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [steamImportRepositoryProvider.overrideWithValue(repository)],
      child: const MaterialApp(home: SteamImportScreen()),
    ),
  );
}

Future<void> _fetch(WidgetTester tester, String input) async {
  await tester.enterText(find.byType(TextField), input);
  await tester.tap(find.text('ライブラリを取得'));
  await tester.pumpAndSettle();
}

void main() {
  group('SteamLibrary', () {
    test('JSONから変換し、遊んだ/未プレイに分ける', () {
      final library = SteamLibrary.fromJson({
        'total_owned': 10,
        'unmatched_count': 4,
        'truncated': true,
        'matched': [
          {'game_id': 1, 'name': 'A', 'cover_url': null, 'playtime_minutes': 120},
          {'game_id': 2, 'name': 'B', 'cover_url': 'u', 'playtime_minutes': 0},
        ],
      });
      expect(library.totalOwned, 10);
      expect(library.unmatchedCount, 4);
      expect(library.truncated, isTrue);
      expect(library.playedGames.map((g) => g.gameId), [1]);
      expect(library.unplayedGames.map((g) => g.gameId), [2]);
    });

    test('項目が欠けていても落ちない', () {
      final library = SteamLibrary.fromJson({});
      expect(library.games, isEmpty);
      expect(library.totalOwned, 0);
    });
  });

  group('SteamImportScreen', () {
    testWidgets('取得した件数を表示し、既定では非公開で全件取り込む', (tester) async {
      final repository = _FakeRepository(library: _library);
      await _pump(tester, repository);
      await _fetch(tester, ' https://steamcommunity.com/id/taro ');

      expect(repository.fetchedInput, 'https://steamcommunity.com/id/taro');
      expect(find.text('Steamで取り込めるゲーム: 3本'), findsOneWidget);
      expect(find.text('遊んだゲーム 2本'), findsOneWidget);
      expect(find.text('未プレイのゲーム 1本'), findsOneWidget);
      expect(find.textContaining('2本はDLCなど'), findsOneWidget);

      await tester.tap(find.text('3本を取り込む'));
      await tester.pumpAndSettle();

      expect(repository.importedPlayed!.map((g) => g.gameId), [1, 2]);
      expect(repository.importedWantToPlay!.map((g) => g.gameId), [3]);
      expect(repository.importedVisibility, GameLogVisibility.private_);
      expect(find.text('3本を取り込みました'), findsOneWidget);
    });

    testWidgets('未プレイを外すと、遊んだゲームだけを渡す', (tester) async {
      final repository = _FakeRepository(library: _library);
      await _pump(tester, repository);
      await _fetch(tester, 'taro');

      await tester.tap(find.text('未プレイのゲーム 1本'));
      await tester.pumpAndSettle();
      expect(find.text('2本を取り込む'), findsOneWidget);

      await tester.tap(find.text('2本を取り込む'));
      await tester.pumpAndSettle();
      expect(repository.importedPlayed!.length, 2);
      expect(repository.importedWantToPlay, isEmpty);
    });

    testWidgets('公開をオンにすると公開で取り込む', (tester) async {
      final repository = _FakeRepository(library: _library);
      await _pump(tester, repository);
      await _fetch(tester, 'taro');

      await tester.tap(find.text('取り込んだ記録を公開する'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('3本を取り込む'));
      await tester.pumpAndSettle();
      expect(repository.importedVisibility, GameLogVisibility.public);
    });

    testWidgets('すべて外すと取り込みボタンが押せない', (tester) async {
      final repository = _FakeRepository(library: _library);
      await _pump(tester, repository);
      await _fetch(tester, 'taro');

      await tester.tap(find.text('遊んだゲーム 2本'));
      await tester.tap(find.text('未プレイのゲーム 1本'));
      await tester.pumpAndSettle();

      final button = tester.widget<FilledButton>(
        find.widgetWithText(FilledButton, '0本を取り込む'),
      );
      expect(button.onPressed, isNull);
    });

    testWidgets('取得に失敗した理由を表示し、取り込み項目は出さない', (tester) async {
      final repository = _FakeRepository(
        error: const SteamImportException(
          'private_profile',
          'Steamのプロフィールの「ゲームの詳細」を「公開」にしてから、もう一度お試しください',
        ),
      );
      await _pump(tester, repository);
      await _fetch(tester, 'taro');

      expect(find.textContaining('「ゲームの詳細」を「公開」'), findsWidgets);
      expect(find.textContaining('を取り込む'), findsNothing);
    });

    testWidgets('取り込める作品が無いときは案内を表示する', (tester) async {
      final repository = _FakeRepository(
        library: const SteamLibrary(
          totalOwned: 4,
          unmatchedCount: 4,
          truncated: false,
          games: [],
        ),
      );
      await _pump(tester, repository);
      await _fetch(tester, 'taro');
      expect(find.textContaining('取り込めるゲームが見つかりませんでした'), findsOneWidget);
    });
  });
}
