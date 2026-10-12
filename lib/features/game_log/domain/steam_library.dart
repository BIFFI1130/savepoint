/// Steamの所有ゲームのうち、SavePointに取り込める1本。
class SteamGame {
  const SteamGame({
    required this.gameId,
    required this.name,
    this.coverUrl,
    required this.playtimeMinutes,
  });

  /// IGDBのゲームID（`games.id`と同じ）。
  final int gameId;
  final String name;
  final String? coverUrl;
  final int playtimeMinutes;

  /// 一度でも遊んだか（累計プレイ時間が1分以上）。
  bool get played => playtimeMinutes > 0;

  factory SteamGame.fromJson(Map<String, dynamic> json) {
    return SteamGame(
      gameId: json['game_id'] as int,
      name: json['name'] as String,
      coverUrl: json['cover_url'] as String?,
      playtimeMinutes: (json['playtime_minutes'] as num?)?.toInt() ?? 0,
    );
  }
}

/// steam-import Edge Functionの結果。
class SteamLibrary {
  const SteamLibrary({
    required this.totalOwned,
    required this.unmatchedCount,
    required this.truncated,
    required this.games,
  });

  /// Steamで所有している全ゲーム数（取り込めないものも含む）。
  final int totalOwned;

  /// IGDBに対応する作品が見つからない・DLC等の理由で取り込めない本数。
  final int unmatchedCount;

  /// 所有数が多すぎて、一部のみ処理した場合true。
  final bool truncated;

  final List<SteamGame> games;

  /// プレイ時間のある（遊んだ）ゲーム。
  List<SteamGame> get playedGames =>
      games.where((g) => g.played).toList(growable: false);

  /// 未プレイのゲーム（＝積みゲー）。
  List<SteamGame> get unplayedGames =>
      games.where((g) => !g.played).toList(growable: false);

  factory SteamLibrary.fromJson(Map<String, dynamic> json) {
    return SteamLibrary(
      totalOwned: (json['total_owned'] as num?)?.toInt() ?? 0,
      unmatchedCount: (json['unmatched_count'] as num?)?.toInt() ?? 0,
      truncated: json['truncated'] as bool? ?? false,
      games: [
        for (final item in (json['matched'] as List? ?? const []))
          SteamGame.fromJson(item as Map<String, dynamic>),
      ],
    );
  }
}

/// Steamの取得に失敗した理由。[message]はそのまま画面に表示できる日本語。
class SteamImportException implements Exception {
  const SteamImportException(this.code, this.message);

  final String code;
  final String message;

  @override
  String toString() => 'SteamImportException($code): $message';
}
