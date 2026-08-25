import 'package:flutter/material.dart';

import '../../game_log/domain/game_log.dart';
import '../../game_search/domain/genre_options.dart';

/// プレイ傾向診断の結果。全期間の記録から算出する「ゲーマータイプ」。
class GamerType {
  const GamerType({
    required this.title,
    required this.emoji,
    required this.description,
    required this.color,
  });

  final String title;
  final String emoji;
  final String description;
  final Color color;
}

const _beginner = GamerType(
  title: 'ビギナー冒険者',
  emoji: '🌱',
  description: 'まだ旅は始まったばかり。記録を重ねるほど、あなたらしいゲーマータイプが見えてきます。',
  color: Color(0xFF6B9080),
);

const _backlogWarrior = GamerType(
  title: '積みゲー戦士',
  emoji: '📚',
  description: '「遊びたい」リストが右肩上がり。次から次へと気になる作品を見つける、目利きの探究心の持ち主。',
  color: Color(0xFF8B5000),
);

const _completionist = GamerType(
  title: 'コンプリート主義者',
  emoji: '🏆',
  description: '始めたゲームは最後までやり遂げる。エンディングを見届けるまでが、あなたにとっての「遊んだ」。',
  color: Color(0xFFB08900),
);

const _harshCritic = GamerType(
  title: '辛口批評家',
  emoji: '🧐',
  description: '甘い評価はしない主義。厳しい目でゲームと向き合うからこそ、あなたの★5には重みがある。',
  color: Color(0xFF6B4226),
);

const _generousFan = GamerType(
  title: '絶賛マシーン',
  emoji: '🎉',
  description: '遊んだゲームのほとんどが高評価。ポジティブにゲームを楽しむ、みんなの記録を見たくなるタイプ。',
  color: Color(0xFFB3261E),
);

const _explorer = GamerType(
  title: 'なんでも遊ぶ探検家',
  emoji: '🧭',
  description: 'ジャンルを問わず、気になったら手に取る。幅広い好奇心で、いろんな世界を旅している。',
  color: Color(0xFF006C51),
);

const _craftsman = GamerType(
  title: '一点集中の職人',
  emoji: '🎯',
  description: '好きなジャンルはとことん極める。狭く深く、自分の"好き"に真っ直ぐなプレイスタイル。',
  color: Color(0xFF4A6148),
);

const _storyTraveler = GamerType(
  title: '物語を旅する冒険者',
  emoji: '📖',
  description: 'RPGやアドベンチャーで紡がれる物語に心を惹かれる。次にどんな世界が待っているか、いつもワクワクしている。',
  color: Color(0xFF6750A4),
);

const _battler = GamerType(
  title: '反射神経のバトラー',
  emoji: '⚡',
  description: 'アクション・シューティング・格闘で腕を磨くタイプ。手に汗握る瞬間こそ、ゲームの醍醐味。',
  color: Color(0xFFB3261E),
);

const _strategist = GamerType(
  title: '頭脳派の戦略家',
  emoji: '♟️',
  description: 'ストラテジー・シミュレーションでじっくり考えるのが好き。一手先を読む、頭脳戦の求道者。',
  color: Color(0xFF4A6148),
);

const _casual = GamerType(
  title: '気軽に楽しむカジュアルゲーマー',
  emoji: '🎮',
  description: 'パズルやアーケードで肩の力を抜いて楽しむ。ゲームは"楽しむため"のもの、というシンプルなスタンス。',
  color: Color(0xFFC77800),
);

const _allRounder = GamerType(
  title: 'オールラウンダー',
  emoji: '🌟',
  description: 'これといった偏りのない、バランス型のゲーマー。どんな作品にも分け隔てなく向き合える柔軟さがある。',
  color: Color(0xFF3D5A80),
);

/// ジャンル表示ラベルを診断用の大カテゴリに丸める。対応表に無いジャンルは無視する
/// （診断結果には影響させない。ジャンル分布グラフとは異なり、母数の小さいジャンルの
/// 混入で結果がぶれないようにするため）。
const _genreCategories = <String, String>{
  'RPG': 'story',
  'アドベンチャー': 'story',
  'ビジュアルノベル': 'story',
  'アクション': 'action',
  'シューティング': 'action',
  '格闘': 'action',
  'プラットフォーマー': 'action',
  'ストラテジー': 'strategy',
  'シミュレーション': 'strategy',
  'リアルタイムストラテジー': 'strategy',
  'ターン制ストラテジー': 'strategy',
  'タクティクス': 'strategy',
  'パズル': 'casual',
  'アーケード': 'casual',
  'ピンボール': 'casual',
  'クイズ': 'casual',
  'カード・ボードゲーム': 'casual',
};

/// 全期間の記録から「ゲーマータイプ」を診断する。優先度順に条件を評価し、
/// 最初に一致したタイプを返す（1人につき必ず1タイプに定まる）。
GamerType diagnoseGamerType(List<GameLogWithGame> logs) {
  final played = logs.where((e) => e.log.status == GameLogStatus.played).toList();
  final wantToPlayCount =
      logs.where((e) => e.log.status == GameLogStatus.wantToPlay).length;
  final playedCount = played.length;

  if (playedCount < 3) return _beginner;

  if (wantToPlayCount >= 5 && wantToPlayCount > playedCount * 2) {
    return _backlogWarrior;
  }

  final clearedCount = played.where((e) => e.log.isCleared).length;
  if (playedCount >= 5 && clearedCount / playedCount >= 0.7) {
    return _completionist;
  }

  final ratings =
      played.map((e) => e.log.rating).whereType<double>().toList();
  final avgRating = ratings.isEmpty
      ? null
      : ratings.reduce((a, b) => a + b) / ratings.length;
  if (avgRating != null && playedCount >= 5 && avgRating <= 2.5) {
    return _harshCritic;
  }
  if (avgRating != null && playedCount >= 5 && avgRating >= 4.5) {
    return _generousFan;
  }

  final genreCounts = <String, int>{};
  final categoryCounts = <String, int>{};
  for (final entry in played) {
    for (final genre in entry.game.genres) {
      final label = genreLabel(genre);
      genreCounts[label] = (genreCounts[label] ?? 0) + 1;
      final category = _genreCategories[label];
      if (category != null) {
        categoryCounts[category] = (categoryCounts[category] ?? 0) + 1;
      }
    }
  }

  if (genreCounts.length >= 8) return _explorer;
  if (genreCounts.isNotEmpty && genreCounts.length <= 2) return _craftsman;

  if (categoryCounts.isEmpty) return _allRounder;
  final topCategory =
      categoryCounts.entries.reduce((a, b) => a.value >= b.value ? a : b);
  // 突出したカテゴリが無い（僅差で分散している）場合はオールラウンダー扱いにする。
  final totalCategorized = categoryCounts.values.fold(0, (a, b) => a + b);
  if (topCategory.value / totalCategorized < 0.4) return _allRounder;

  return switch (topCategory.key) {
    'story' => _storyTraveler,
    'action' => _battler,
    'strategy' => _strategist,
    'casual' => _casual,
    _ => _allRounder,
  };
}
