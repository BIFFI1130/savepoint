import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../domain/game_log.dart';

/// 記録・評価・レビュー編集画面（[LogReviewScreen]）の入力途中の内容。
/// 保存せずに画面を離れても、次に開いたときに復元できるようにする。
class LogDraft {
  const LogDraft({
    required this.rating,
    required this.reviewText,
    required this.hasSpoiler,
    required this.isCleared,
    required this.visibility,
  });

  final double rating;
  final String reviewText;
  final bool hasSpoiler;
  final bool isCleared;
  final GameLogVisibility visibility;

  Map<String, dynamic> toJson() => {
        'rating': rating,
        'reviewText': reviewText,
        'hasSpoiler': hasSpoiler,
        'isCleared': isCleared,
        'visibility': visibility.dbValue,
      };

  factory LogDraft.fromJson(Map<String, dynamic> json) => LogDraft(
        rating: (json['rating'] as num).toDouble(),
        reviewText: json['reviewText'] as String,
        hasSpoiler: json['hasSpoiler'] as bool,
        isCleared: json['isCleared'] as bool,
        visibility: GameLogVisibility.fromDb(json['visibility'] as String?),
      );
}

/// ゲームIDごとに下書きをSharedPreferencesへ保存・復元する。
class LogDraftService {
  String _keyFor(int gameId) => 'log_draft_$gameId';

  Future<void> save(int gameId, LogDraft draft) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyFor(gameId), jsonEncode(draft.toJson()));
  }

  Future<LogDraft?> load(int gameId) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_keyFor(gameId));
    if (raw == null) return null;
    try {
      return LogDraft.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      return null;
    }
  }

  Future<void> clear(int gameId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyFor(gameId));
  }
}
