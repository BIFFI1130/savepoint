import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/supabase/supabase_client.dart';
import '../domain/game_log.dart';
import '../domain/steam_library.dart';

/// Steamライブラリの取得と、記録としての一括取り込み。
abstract class SteamImportRepository {
  /// [input]（プロフィールURL・SteamID64・カスタムURLの名前）の所有ゲームを取得する。
  /// 取得できない場合は[SteamImportException]を投げる。
  Future<SteamLibrary> fetchLibrary(String input);

  /// [played]を「遊んだ」、[wantToPlay]を「遊びたい」として記録し、新規に追加された件数を返す。
  /// 既に記録のあるゲームは変更しない。
  Future<int> importLogs({
    required List<SteamGame> played,
    required List<SteamGame> wantToPlay,
    required GameLogVisibility visibility,
  });
}

class SupabaseSteamImportRepository implements SteamImportRepository {
  static const _chunkSize = 200;

  @override
  Future<SteamLibrary> fetchLibrary(String input) async {
    try {
      final response = await supabase.functions.invoke(
        'steam-import',
        body: {'steam_input': input},
      );
      return SteamLibrary.fromJson(response.data as Map<String, dynamic>);
    } on FunctionException catch (error) {
      final details = error.details;
      if (details is Map && details['error'] is String) {
        throw SteamImportException(
          (details['code'] as String?) ?? 'upstream',
          details['error'] as String,
        );
      }
      throw const SteamImportException(
        'upstream',
        '取り込みに失敗しました。時間をおいてお試しください',
      );
    }
  }

  @override
  Future<int> importLogs({
    required List<SteamGame> played,
    required List<SteamGame> wantToPlay,
    required GameLogVisibility visibility,
  }) async {
    final userId = supabase.auth.currentUser!.id;
    final rows = <Map<String, dynamic>>[
      for (final game in played)
        _row(userId, game, GameLogStatus.played, visibility),
      for (final game in wantToPlay)
        _row(userId, game, GameLogStatus.wantToPlay, visibility),
    ];

    var inserted = 0;
    for (var i = 0; i < rows.length; i += _chunkSize) {
      final end = i + _chunkSize > rows.length ? rows.length : i + _chunkSize;
      // ON CONFLICT DO NOTHING。既に記録のあるゲームの評価・レビューを上書きしない。
      final result = await supabase
          .from('game_logs')
          .upsert(
            rows.sublist(i, end),
            onConflict: 'user_id,game_id',
            ignoreDuplicates: true,
          )
          .select('game_id');
      inserted += (result as List).length;
    }
    return inserted;
  }

  Map<String, dynamic> _row(
    String userId,
    SteamGame game,
    GameLogStatus status,
    GameLogVisibility visibility,
  ) {
    return {
      'user_id': userId,
      'game_id': game.gameId,
      'status': status.toDb(),
      'visibility': visibility.dbValue,
    };
  }
}
