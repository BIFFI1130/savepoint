# App Review Resolution Center 返信文（下書き）

## 1. 画面録画
Recorded on a physical device (iPhone), running the latest iOS version:

- Main recording: https://drive.google.com/file/d/1TTxha2wjhoqnSf0lYeX0z_CxGloLenWe/view?usp=sharing
- Supplementary clip (new account registration screen): https://drive.google.com/file/d/16lnMLUCfg9BL4Uc7hY5zrtEB1xGz75fE/view?usp=sharing

The main recording begins with launching the app from the sign-in screen and shows:
- Signing in with the demo account provided below, then completing the one-time username setup shown on first sign-in
- Browsing the home feed, opening a game detail page, and checking the trending screen
- Logging a played game with a star rating and a written review (user-generated content)
- Searching for another user and opening their profile (which shows the "フォロー中"/following state)
- Opening the report dialog (with reason options) and the block/report menu on that profile, to show the content-moderation mechanism is implemented (not actually submitted, to avoid acting on a real account)
- Account deletion flow: Settings > Account > "Delete Account", the two-step confirmation (typing "削除" to confirm), completing the deletion, and returning to the sign-in screen afterward

The supplementary clip shows the account-registration screen (tapping "アカウントをお持ちでない方はこちら" from the sign-in screen to reach the email/password registration form), which was not included in the main recording.

## 2. アプリの目的とターゲットユーザー
SavePoint is a personal game-log app for Japanese-speaking gamers. Users search a game database (powered by IGDB), mark games as "played" or "want to play," write star-rated reviews, track completion time, and follow other users to see their activity. It solves the problem of remembering and organizing one's own gaming history and discovering new games through IGDB's catalog and other users' reviews.

## 3. 主要機能へのアクセス方法・デモアカウント
No special setup is required. After launching the app, sign in with the demo account below (already provided in the "Sign-In Information" section of App Review Information) and all features (search, logging, reviews, follow, block/report, account deletion) are immediately accessible from the bottom tab bar and the Settings screen.

- Demo email: savepoint.record.game+applereview@gmail.com
- Demo password: CfmZbXfDuGJhR3rD

## 4. 外部サービス一覧
- **Supabase** — authentication, PostgreSQL database, edge functions, and file storage (the app's entire backend)
- **IGDB (via Twitch API, proxied through our own Supabase Edge Function)** — game metadata (titles, cover art, genres, release dates)
- **Firebase (Core, Crashlytics, Analytics, Cloud Messaging)** — crash reporting, usage analytics, and push notifications for follow activity
- **Google AdMob** — banner/native/interstitial ads
- **RevenueCat** — subscription purchases (an optional "remove ads" plan)
- **Sign in with Apple / Google Sign-In** — third-party authentication, offered alongside email/password sign-in

## 5. 地域差
The app has no region-specific features or content. It is Japanese-locale only (fixed to ja-JP) and functions identically for all users regardless of region.

## 6. 規制業界・保護された第三者素材
The app displays game metadata (titles, cover art, descriptions) licensed from IGDB/Twitch under the Twitch Developer Services Agreement. We comply with IGDB's attribution requirements: every screen showing game data includes an "IGDB.com" attribution footer with a link, and each game detail page links to the game's official IGDB page. No other regulated or protected third-party material is used.
