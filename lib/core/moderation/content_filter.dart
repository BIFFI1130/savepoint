/// レビュー投稿時の不適切表現の一次フィルタ。
///
/// App Storeガイドライン1.2（UGC）が求める「不適切なコンテンツをフィルタリングする
/// 仕組み」を満たすための最低限の仕組み。ここでの語句リストはあくまで明白に悪質な
/// 表現（差別的な蔑称・強い暴力/性的示唆の罵倒語）を投稿時点でブロックするための
/// 一次防御であり、これだけで全ての不適切投稿を防げるとは想定していない。
/// 実際の運用は、これに加えて通報機能（[[ReportReason]]）による事後モデレーションと
/// 組み合わせて成り立つ。
///
/// 語句は大文字小文字・全角半角を無視して部分一致で判定する。
const _prohibitedTerms = <String>[
  // 差別的な蔑称（日本語）
  'ちょん', 'チョン公', '土人', '穢多', 'えた', '非人',
  // 差別的な蔑称（英語）
  'nigger', 'nigga', 'chink', 'spic', 'kike', 'faggot', 'retard',
  // 強い暴力・脅迫表現
  '殺すぞ', 'ぶっ殺す', '死ね死ね', 'レイプするぞ',
  'kill yourself', 'kys',
];

class ContentFilterResult {
  const ContentFilterResult({required this.isAllowed, this.matchedTerm});

  final bool isAllowed;
  final String? matchedTerm;
}

/// 全角英数を半角に、大文字を小文字に正規化してから比較する
/// （全角"ＫＹＳ"のような回避入力を防ぐため）。
String _normalize(String input) {
  final buffer = StringBuffer();
  for (final rune in input.runes) {
    if (rune >= 0xFF21 && rune <= 0xFF3A) {
      buffer.writeCharCode(rune - 0xFF21 + 0x41);
    } else if (rune >= 0xFF41 && rune <= 0xFF5A) {
      buffer.writeCharCode(rune - 0xFF41 + 0x61);
    } else if (rune >= 0xFF10 && rune <= 0xFF19) {
      buffer.writeCharCode(rune - 0xFF10 + 0x30);
    } else {
      buffer.writeCharCode(rune);
    }
  }
  return buffer.toString().toLowerCase();
}

ContentFilterResult checkReviewText(String text) {
  final normalized = _normalize(text);
  for (final term in _prohibitedTerms) {
    if (normalized.contains(_normalize(term))) {
      return ContentFilterResult(isAllowed: false, matchedTerm: term);
    }
  }
  return const ContentFilterResult(isAllowed: true);
}
