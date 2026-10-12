/// 共有・紹介用のURL定数。ランディングページ（GitHub Pages）はApp Store/Google Playへの
/// 導線を持つため、共有テキストに添えるリンクはこれに統一する。
class AppLinks {
  const AppLinks._();

  static const landingUrl = 'https://biffi1130.github.io/savepoint/';
  static const shareHashtag = '#SavePoint';

  /// 共有テキストの末尾に付ける、ハッシュタグとインストール導線。
  static const shareFooter = '$shareHashtag\n$landingUrl';

  /// App Storeのレビュー投稿画面を直接開くURL。OS標準のレビュー依頼ダイアログ
  /// （[ReviewPromptService]）と違い、表示回数の制限を受けない。
  static const appStoreWriteReviewUrl =
      'https://apps.apple.com/app/id6799825415?action=write-review';

  /// プロフィール共有リンク。アプリ未導入でもタップできるよう、カスタムスキーム
  /// （`savepoint://user/{id}`）ではなくhttpsの中継ページ（docs/u/）を経由する。
  static String profileUrl(String userId) => '${landingUrl}u/?id=$userId';
}
