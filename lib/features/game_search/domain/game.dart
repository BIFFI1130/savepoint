/// ゲーム情報（IGDBから取得し、Supabaseの games テーブルにキャッシュされたもの）。
class Game {
  const Game({
    required this.id,
    required this.name,
    this.coverUrl,
    this.firstReleaseDate,
    this.platforms = const [],
    this.summary,
  });

  final int id;
  final String name;
  final String? coverUrl;
  final DateTime? firstReleaseDate;
  final List<String> platforms;
  final String? summary;

  int? get releaseYear => firstReleaseDate?.year;

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
    );
  }
}
