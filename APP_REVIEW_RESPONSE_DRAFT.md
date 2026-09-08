# App Review Resolution Center 返信文（下書き）

## 2026-09-08 却下（Submission ID 3fda0e2f-b809-43b9-9100-e3086e26a131）への返信案

Guideline 1.2 (Safety - User Generated Content), 2.1(a) (Information Needed), 2.1 (Information Needed) の3件への回答。

---

Thank you for the detailed feedback. We have addressed all three points below.

**Guideline 1.2 — User Generated Content safeguards**

The following precautions are now in place:
- Age rating has been updated to 17+ in App Store Connect.
- New users must agree to the Terms of Service (which now explicitly states a zero-tolerance policy for objectionable content and abusive users) before creating an account; users signing in via Sign in with Apple / Google see the same notice.
- A keyword-based filter now blocks review submissions containing objectionable content at the point of posting.
- Users can flag/report any individual review (via the report icon on that review) and any user profile.
- Users can block abusive users directly from their profile; blocking is mutual (both sides can no longer follow each other).
- Users can delete their own posts at any time; deletion is immediate (a real-time database delete), so the content disappears from the feed instantly.
- We commit to reviewing reports within 24 hours and removing violating content / suspending the offending account when warranted (stated in the Terms of Service, section 3).
- Contact information for reporting inappropriate activity is now available in-app at Settings > About > "お問い合わせ・不適切なコンテンツの報告" (savepoint.record.game@gmail.com).

**Guideline 2.1(a) — Demo account / full feature access**

We apologize — the demo account provided did not yet have any other users or reviews to browse, so the social features (Following, "Everyone's Reviews") appeared empty. We have now populated the production database with several additional demo user accounts, each with multiple posted reviews, and had the demo account follow them. Signing in with the demo account below now shows:
- A populated "つながり" (Following) feed with reviews from followed users
- Populated "みんなのレビュー" (Everyone's Reviews) sections on game detail pages, with multiple reviews per game
- Working report/block actions on those reviews and profiles

Demo account (same as before, in App Review Information):
- Email: savepoint.record.game+applereview@gmail.com
- Password: CfmZbXfDuGJhR3rD

**Guideline 2.1 — Steps to post a review**

1. Sign in (or use the demo account above).
2. From the home tab, search for a game by title (or tap a game from the Home/Trending list).
3. On the game's detail page, tap "遊んだ" (Played).
4. Set a star rating (optional) and write a review in the text field (optional — a rating or review text is required to appear in public feeds, but the log itself can be saved with neither).
5. Optionally toggle "ネタバレあり" (Contains spoilers) and choose visibility (Public / Private).
6. Tap "保存" (Save). The review is saved immediately and, if set to Public, appears on the game's "みんなのレビュー" section and in followers' "つながり" feed right away.

We believe all three issues are now resolved and a new build reflecting these fixes has been submitted. Please let us know if any further information is needed.

---


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
