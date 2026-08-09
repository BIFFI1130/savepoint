/// 関連作品（ゲーム詳細画面で表示する簡易情報のみ）。
class SimilarGame {
  const SimilarGame({required this.id, required this.name, this.coverUrl});

  final int id;
  final String name;
  final String? coverUrl;

  factory SimilarGame.fromJson(Map<String, dynamic> json) {
    return SimilarGame(
      id: json['id'] as int,
      name: json['name'] as String? ?? '(タイトル不明)',
      coverUrl: json['cover_url'] as String?,
    );
  }
}

/// ゲーム情報（IGDBから取得し、Supabaseの games テーブルにキャッシュされたもの）。
///
/// [developers]・[publishers]・[similarGames]・[summaryJa] はゲーム詳細取得
/// （igdb-proxyのdetailsアクション）でのみ取得され、検索結果一覧では空/nullになる。
class Game {
  const Game({
    required this.id,
    required this.name,
    this.coverUrl,
    this.firstReleaseDate,
    this.platforms = const [],
    this.summary,
    this.summaryJa,
    this.developers = const [],
    this.publishers = const [],
    this.similarGames = const [],
    this.igdbUrl,
  });

  final int id;
  final String name;
  final String? coverUrl;
  final DateTime? firstReleaseDate;
  final List<String> platforms;
  final String? summary;
  final String? summaryJa;
  final List<String> developers;
  final List<String> publishers;
  final List<SimilarGame> similarGames;

  /// このゲームのIGDB上のページURL。データ提供元（IGDB）への導線として表示する。
  final String? igdbUrl;

  int? get releaseYear => firstReleaseDate?.year;

  /// 表示用の概要。日本語訳があればそれを、なければ原文を返す。
  String? get displaySummary => summaryJa ?? summary;

  factory Game.fromJson(Map<String, dynamic> json) {
    return Game(
      id: json['id'] as int,
      name: json['name'] as String? ?? '(タイトル不明)',
      coverUrl: json['cover_url'] as String?,
      firstReleaseDate: json['first_release_date'] != null
          ? DateTime.tryParse(json['first_release_date'] as String)
          : null,
      platforms: (json['platforms'] as List?)?.cast<String>() ?? const [],
      summary: json['summary'] as String?,
      summaryJa: json['summary_ja'] as String?,
      developers: (json['developers'] as List?)?.cast<String>() ?? const [],
      publishers: (json['publishers'] as List?)?.cast<String>() ?? const [],
      similarGames: (json['similar_games'] as List?)
              ?.cast<Map<String, dynamic>>()
              .map(SimilarGame.fromJson)
              .toList() ??
          const [],
      igdbUrl: json['igdb_url'] as String?,
    );
  }
}
