/// 1言語分の対応状況（音声・字幕・UIそれぞれに対応しているか）。
class LanguageSupport {
  const LanguageSupport({
    required this.language,
    this.audio = false,
    this.subtitles = false,
    this.interfaceSupport = false,
  });

  final String language;
  final bool audio;
  final bool subtitles;
  final bool interfaceSupport;

  factory LanguageSupport.fromJson(Map<String, dynamic> json) {
    return LanguageSupport(
      language: json['language'] as String? ?? '',
      audio: json['audio'] as bool? ?? false,
      subtitles: json['subtitles'] as bool? ?? false,
      interfaceSupport: json['interface'] as bool? ?? false,
    );
  }
}

/// 関連作品（ゲーム詳細画面で表示する簡易情報のみ）。
class SimilarGame {
  const SimilarGame({
    required this.id,
    required this.name,
    this.coverUrl,
    this.nameJa,
    this.isJapaneseDeveloper = false,
  });

  final int id;
  final String name;
  final String? coverUrl;
  final String? nameJa;

  /// 開発元が日本の会社かどうか。
  final bool isJapaneseDeveloper;

  /// 表示用のタイトル。IGDBのLocalized Title（日本）があればそれを、無ければ原題を返す。
  String get displayName => nameJa ?? name;

  factory SimilarGame.fromJson(Map<String, dynamic> json) {
    return SimilarGame(
      id: json['id'] as int,
      name: json['name'] as String? ?? '(タイトル不明)',
      coverUrl: json['cover_url'] as String?,
      nameJa: json['name_ja'] as String?,
      isJapaneseDeveloper: json['is_japanese_developer'] as bool? ?? false,
    );
  }
}

/// ゲーム情報（IGDBから取得し、Supabaseの games テーブルにキャッシュされたもの）。
///
/// [developers]・[publishers]・[similarGames]・[summaryJa]・[officialUrl] はゲーム詳細取得
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
    this.nameJa,
    this.genres = const [],
    this.isAdult = false,
    this.isJapaneseDeveloper = false,
    this.developers = const [],
    this.publishers = const [],
    this.similarGames = const [],
    this.igdbUrl,
    this.officialUrl,
    this.timeToBeatHastilySeconds,
    this.timeToBeatNormallySeconds,
    this.timeToBeatCompletelySeconds,
    this.screenshotUrls = const [],
    this.trailerYoutubeId,
    this.ageRatingOrganization,
    this.ageRatingValue,
    this.languageSupports = const [],
    this.seriesGames = const [],
  });

  final int id;
  final String name;
  final String? coverUrl;
  final DateTime? firstReleaseDate;
  final List<String> platforms;
  final String? summary;
  final String? summaryJa;
  final String? nameJa;

  /// IGDBのジャンル名一覧（英語表記）。
  final List<String> genres;

  /// 成人向け作品かどうか（IGDBのthemesに"Erotic"が含まれるかで判定）。
  final bool isAdult;

  /// 開発元が日本の会社かどうか。タイトルを日本語表示するかどうかの判定に使う。
  final bool isJapaneseDeveloper;
  final List<String> developers;
  final List<String> publishers;
  final List<SimilarGame> similarGames;

  /// このゲームのIGDB上のページURL。データ提供元（IGDB）への導線として表示する。
  final String? igdbUrl;

  /// 公式サイトのURL（日本語ページらしいものがあれば優先）。
  final String? officialUrl;

  /// IGDBの平均クリア時間（Time To Beat、秒単位）。データが無いゲームも多いため、
  /// いずれもnullの場合は詳細画面でセクションごと非表示にする。
  final int? timeToBeatHastilySeconds;
  final int? timeToBeatNormallySeconds;
  final int? timeToBeatCompletelySeconds;

  /// ゲームのスクリーンショット画像URL一覧（試験実装、詳細取得時のみ）。
  final List<String> screenshotUrls;

  /// トレーラーのYouTube動画ID（試験実装、詳細取得時のみ。無ければnull）。
  final String? trailerYoutubeId;

  /// 年齢レーティング団体名（例: "CERO"）。日本向けにCERO優先、無ければESRB等に
  /// フォールバックして1件だけ選んだもの（試験実装、詳細取得時のみ）。
  final String? ageRatingOrganization;

  /// 年齢レーティングの区分（例: CEROなら"D"）。
  final String? ageRatingValue;

  /// 対応言語一覧（言語ごとに音声・字幕・UIの対応状況を持つ、試験実装）。
  /// データが無い場合は空リスト（「非対応」ではなく「不明」の意味）。
  final List<LanguageSupport> languageSupports;

  /// 同じシリーズの他の作品（IGDBの公式コレクション情報に基づく、試験実装）。
  final List<SimilarGame> seriesGames;

  /// 上記いずれか1つでもデータがあれば true。
  bool get hasTimeToBeat =>
      timeToBeatHastilySeconds != null ||
      timeToBeatNormallySeconds != null ||
      timeToBeatCompletelySeconds != null;

  int? get releaseYear => firstReleaseDate?.year;

  /// 表示用の概要。日本語訳があればそれを、なければ原文を返す。
  String? get displaySummary => summaryJa ?? summary;

  /// 表示用のタイトル。IGDBのLocalized Title（日本）があればそれを、無ければ原題を返す。
  String get displayName => nameJa ?? name;

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
      nameJa: json['name_ja'] as String?,
      genres: (json['genres'] as List?)?.cast<String>() ?? const [],
      isAdult: json['is_adult'] as bool? ?? false,
      isJapaneseDeveloper: json['is_japanese_developer'] as bool? ?? false,
      developers: (json['developers'] as List?)?.cast<String>() ?? const [],
      publishers: (json['publishers'] as List?)?.cast<String>() ?? const [],
      similarGames: (json['similar_games'] as List?)
              ?.cast<Map<String, dynamic>>()
              .map(SimilarGame.fromJson)
              .toList() ??
          const [],
      igdbUrl: json['igdb_url'] as String?,
      officialUrl: json['official_url'] as String?,
      timeToBeatHastilySeconds: json['time_to_beat_hastily_seconds'] as int?,
      timeToBeatNormallySeconds: json['time_to_beat_normally_seconds'] as int?,
      timeToBeatCompletelySeconds: json['time_to_beat_completely_seconds'] as int?,
      screenshotUrls:
          (json['screenshot_urls'] as List?)?.cast<String>() ?? const [],
      trailerYoutubeId: json['trailer_youtube_id'] as String?,
      ageRatingOrganization: json['age_rating_organization'] as String?,
      ageRatingValue: json['age_rating_value'] as String?,
      languageSupports: (json['language_supports'] as List?)
              ?.cast<Map<String, dynamic>>()
              .map(LanguageSupport.fromJson)
              .toList() ??
          const [],
      seriesGames: (json['series_games'] as List?)
              ?.cast<Map<String, dynamic>>()
              .map(SimilarGame.fromJson)
              .toList() ??
          const [],
    );
  }
}
