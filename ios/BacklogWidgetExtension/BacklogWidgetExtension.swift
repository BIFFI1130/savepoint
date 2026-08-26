import SwiftUI
import WidgetKit

/// 積みゲー（「遊びたい」）の中で発売が一番近い作品を常時表示するホーム画面ウィジェット。
/// データ（タイトル・発売日・ゲームID・カバー画像パス）はFlutter側（BacklogWidgetService）が
/// App Group共有のUserDefaultsに保存し、「発売まであと○日」の文字列自体はここ
/// （Provider）で毎回計算し直す。こうすることでアプリを開かない日でも、
/// WidgetKitの定期リロードだけでカウントダウンが古くならない
/// （Android側のBacklogWidgetProvider.ktと同じ設計）。
private let widgetGroupId = "group.com.biffi.savepoint"

/// [releaseDateIso]（"YYYY-MM-DD"）を元に、時刻・タイムゾーンを無視した日付単位で
/// 「本日発売」「発売まであと○日」を返す。発売済み・解析失敗時はnil。
private func countdownLabel(from releaseDateIso: String) -> String? {
  let formatter = DateFormatter()
  formatter.dateFormat = "yyyy-MM-dd"
  formatter.calendar = Calendar(identifier: .gregorian)
  formatter.timeZone = TimeZone.current
  guard let releaseDate = formatter.date(from: releaseDateIso) else { return nil }

  let calendar = Calendar.current
  let today = calendar.startOfDay(for: Date())
  let release = calendar.startOfDay(for: releaseDate)
  guard let days = calendar.dateComponents([.day], from: today, to: release).day else {
    return nil
  }
  if days == 0 { return "本日発売" }
  if days > 0 { return "発売まであと\(days)日" }
  return nil
}

/// [path]が存在すれば読み込んだUIImageを返す。存在しない・デコード失敗時はnil
/// （強制アンラップせず、常に安全にフォールバックする）。
private func loadImage(from path: String?) -> UIImage? {
  guard let path = path, FileManager.default.fileExists(atPath: path) else { return nil }
  return UIImage(contentsOfFile: path)
}

struct BacklogEntry: TimelineEntry {
  let date: Date
  let title: String?
  let countdown: String?
  let gameId: String?
  let coverImagePath: String?
  let streak: String?
}

struct BacklogProvider: TimelineProvider {
  func placeholder(in context: Context) -> BacklogEntry {
    BacklogEntry(
      date: Date(), title: "Horror Prison: Escape", countdown: "発売まであと2日", gameId: nil,
      coverImagePath: nil, streak: nil)
  }

  func getSnapshot(in context: Context, completion: @escaping (BacklogEntry) -> Void) {
    completion(currentEntry())
  }

  func getTimeline(in context: Context, completion: @escaping (Timeline<BacklogEntry>) -> Void) {
    let entry = currentEntry()
    // 発売日の日付が変わるタイミング（翌日0:00）で再読み込みし、それまでは
    // 保存済みデータを都度計算し直すだけで表示を最新に保つ。
    let nextRefresh = Calendar.current.date(byAdding: .day, value: 1, to: Calendar.current.startOfDay(for: Date()))
      ?? Date().addingTimeInterval(6 * 60 * 60)
    completion(Timeline(entries: [entry], policy: .after(nextRefresh)))
  }

  private func currentEntry() -> BacklogEntry {
    let data = UserDefaults(suiteName: widgetGroupId)
    let title = data?.string(forKey: "backlog_title")
    let releaseDateIso = data?.string(forKey: "backlog_release_date")
    let gameId = data?.string(forKey: "backlog_game_id")
    let coverImagePath = data?.string(forKey: "backlog_cover_image")
    let streak = data?.string(forKey: "backlog_streak")
    let countdown = releaseDateIso.flatMap(countdownLabel(from:))
    return BacklogEntry(
      date: Date(), title: title, countdown: countdown, gameId: gameId,
      coverImagePath: coverImagePath, streak: (streak?.isEmpty ?? true) ? nil : streak)
  }
}

struct BacklogWidgetEntryView: View {
  var entry: BacklogProvider.Entry

  private var hasEntry: Bool { entry.title != nil && entry.countdown != nil }

  private var destinationUrl: URL {
    if hasEntry, let gameId = entry.gameId {
      return URL(string: "savepoint://game/\(gameId)")!
    }
    return URL(string: "savepoint://home")!
  }

  var body: some View {
    HStack(alignment: .center, spacing: 10) {
      if hasEntry, let cover = loadImage(from: entry.coverImagePath) {
        Image(uiImage: cover)
          .resizable()
          .aspectRatio(contentMode: .fill)
          .frame(width: 40, height: 54)
          .clipShape(RoundedRectangle(cornerRadius: 4))
      }
      VStack(alignment: .leading, spacing: 4) {
        Text(hasEntry ? entry.title! : "もうすぐ発売の遊びたいゲームはありません")
          .font(.system(size: 14, weight: .bold))
          .foregroundColor(Color(red: 0.10, green: 0.10, blue: 0.18))
          .lineLimit(1)
        Text(hasEntry ? entry.countdown! : "SavePoint")
          .font(.system(size: 13))
          .foregroundColor(Color(red: 0.24, green: 0.35, blue: 1.0))
          .lineLimit(1)
        if let streak = entry.streak {
          Text(streak)
            .font(.system(size: 12))
            .foregroundColor(Color(red: 0.10, green: 0.10, blue: 0.18))
            .lineLimit(1)
        }
      }
    }
    .frame(maxWidth: .infinity, alignment: .leading)
    .padding(12)
    .widgetURL(destinationUrl)
  }
}

struct BacklogWidget: Widget {
  let kind: String = "BacklogWidget"

  var body: some WidgetConfiguration {
    StaticConfiguration(kind: kind, provider: BacklogProvider()) { entry in
      if #available(iOSApplicationExtension 17.0, *) {
        BacklogWidgetEntryView(entry: entry)
          .containerBackground(Color.white, for: .widget)
      } else {
        BacklogWidgetEntryView(entry: entry)
          .background(Color.white)
      }
    }
    .configurationDisplayName("もうすぐ発売の遊びたいゲーム")
    .description("発売が一番近い「遊びたい」作品を表示します。")
    .supportedFamilies([.systemSmall, .systemMedium])
  }
}

// MARK: - 本日発売ギャラリーウィジェット

/// Flutter側（BacklogWidgetService）がJSON配列として保存する1件分のデータ。
struct ReleaseItem: Codable {
  let id: String
  let title: String
  let image: String?
}

struct TodayReleasesEntry: TimelineEntry {
  let date: Date
  let items: [ReleaseItem]
}

struct TodayReleasesProvider: TimelineProvider {
  func placeholder(in context: Context) -> TodayReleasesEntry {
    TodayReleasesEntry(date: Date(), items: [])
  }

  func getSnapshot(in context: Context, completion: @escaping (TodayReleasesEntry) -> Void) {
    completion(currentEntry())
  }

  func getTimeline(in context: Context, completion: @escaping (Timeline<TodayReleasesEntry>) -> Void) {
    let entry = currentEntry()
    let nextRefresh = Calendar.current.date(byAdding: .day, value: 1, to: Calendar.current.startOfDay(for: Date()))
      ?? Date().addingTimeInterval(6 * 60 * 60)
    completion(Timeline(entries: [entry], policy: .after(nextRefresh)))
  }

  private func currentEntry() -> TodayReleasesEntry {
    let data = UserDefaults(suiteName: widgetGroupId)
    guard let json = data?.string(forKey: "today_releases_json"),
      let jsonData = json.data(using: .utf8),
      let items = try? JSONDecoder().decode([ReleaseItem].self, from: jsonData)
    else {
      return TodayReleasesEntry(date: Date(), items: [])
    }
    return TodayReleasesEntry(date: Date(), items: items)
  }
}

struct TodayReleasesWidgetEntryView: View {
  var entry: TodayReleasesProvider.Entry

  var body: some View {
    VStack(alignment: .leading, spacing: 6) {
      Text("本日発売")
        .font(.system(size: 13, weight: .bold))
        .foregroundColor(Color(red: 0.10, green: 0.10, blue: 0.18))
      if entry.items.isEmpty {
        Text("本日発売の作品はありません")
          .font(.system(size: 13))
          .foregroundColor(Color(red: 0.24, green: 0.35, blue: 1.0))
      } else {
        HStack(alignment: .top, spacing: 6) {
          ForEach(entry.items, id: \.id) { item in
            Link(destination: URL(string: "savepoint://game/\(item.id)")!) {
              VStack(spacing: 2) {
                if let cover = loadImage(from: item.image) {
                  Image(uiImage: cover)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(maxWidth: .infinity)
                    .frame(height: 64)
                    .clipShape(RoundedRectangle(cornerRadius: 4))
                } else {
                  RoundedRectangle(cornerRadius: 4)
                    .fill(Color(red: 0.9, green: 0.9, blue: 0.95))
                    .frame(height: 64)
                }
                Text(item.title)
                  .font(.system(size: 9))
                  .foregroundColor(Color(red: 0.10, green: 0.10, blue: 0.18))
                  .lineLimit(1)
              }
            }
          }
        }
      }
      Spacer(minLength: 0)
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    .padding(12)
  }
}

struct TodayReleasesWidget: Widget {
  let kind: String = "TodayReleasesWidget"

  var body: some WidgetConfiguration {
    StaticConfiguration(kind: kind, provider: TodayReleasesProvider()) { entry in
      if #available(iOSApplicationExtension 17.0, *) {
        TodayReleasesWidgetEntryView(entry: entry)
          .containerBackground(Color.white, for: .widget)
      } else {
        TodayReleasesWidgetEntryView(entry: entry)
          .background(Color.white)
      }
    }
    .configurationDisplayName("本日発売")
    .description("「遊びたい」の中で本日発売の作品を一覧表示します。")
    .supportedFamilies([.systemMedium])
  }
}

// MARK: - 週間記録ストリークウィジェット

struct StreakEntry: TimelineEntry {
  let date: Date
  let count: String
  let label: String
}

struct StreakProvider: TimelineProvider {
  func placeholder(in context: Context) -> StreakEntry {
    StreakEntry(date: Date(), count: "3", label: "週間記録ストリーク")
  }

  func getSnapshot(in context: Context, completion: @escaping (StreakEntry) -> Void) {
    completion(currentEntry())
  }

  func getTimeline(in context: Context, completion: @escaping (Timeline<StreakEntry>) -> Void) {
    let entry = currentEntry()
    let nextRefresh = Date().addingTimeInterval(6 * 60 * 60)
    completion(Timeline(entries: [entry], policy: .after(nextRefresh)))
  }

  private func currentEntry() -> StreakEntry {
    let data = UserDefaults(suiteName: widgetGroupId)
    let count = data?.string(forKey: "streak_widget_count") ?? "0"
    let label = data?.string(forKey: "streak_widget_label") ?? "週間記録ストリーク"
    return StreakEntry(date: Date(), count: count, label: label)
  }
}

struct StreakWidgetEntryView: View {
  var entry: StreakProvider.Entry

  var body: some View {
    VStack(spacing: 2) {
      Text(entry.count)
        .font(.system(size: 32, weight: .bold))
        .foregroundColor(Color(red: 0.10, green: 0.10, blue: 0.18))
      Text(entry.label)
        .font(.system(size: 12))
        .foregroundColor(Color(red: 0.24, green: 0.35, blue: 1.0))
        .lineLimit(1)
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .widgetURL(URL(string: "savepoint://home")!)
  }
}

struct StreakWidget: Widget {
  let kind: String = "StreakWidget"

  var body: some WidgetConfiguration {
    StaticConfiguration(kind: kind, provider: StreakProvider()) { entry in
      if #available(iOSApplicationExtension 17.0, *) {
        StreakWidgetEntryView(entry: entry)
          .containerBackground(Color.white, for: .widget)
      } else {
        StreakWidgetEntryView(entry: entry)
          .background(Color.white)
      }
    }
    .configurationDisplayName("週間記録ストリーク")
    .description("記録が連続している週数を表示します。")
    .supportedFamilies([.systemSmall])
  }
}

// MARK: - 今月の統計ウィジェット

struct MonthlyStatsEntry: TimelineEntry {
  let date: Date
  let monthLabel: String
  let playedCount: String
  let wantToPlayCount: String
}

struct MonthlyStatsProvider: TimelineProvider {
  func placeholder(in context: Context) -> MonthlyStatsEntry {
    MonthlyStatsEntry(date: Date(), monthLabel: "今月", playedCount: "3", wantToPlayCount: "1")
  }

  func getSnapshot(in context: Context, completion: @escaping (MonthlyStatsEntry) -> Void) {
    completion(currentEntry())
  }

  func getTimeline(in context: Context, completion: @escaping (Timeline<MonthlyStatsEntry>) -> Void) {
    let entry = currentEntry()
    let nextRefresh = Date().addingTimeInterval(6 * 60 * 60)
    completion(Timeline(entries: [entry], policy: .after(nextRefresh)))
  }

  private func currentEntry() -> MonthlyStatsEntry {
    let data = UserDefaults(suiteName: widgetGroupId)
    let monthLabel = data?.string(forKey: "monthly_stats_month_label") ?? "今月"
    let playedCount = data?.string(forKey: "monthly_stats_played_count") ?? "0"
    let wantToPlayCount = data?.string(forKey: "monthly_stats_want_to_play_count") ?? "0"
    return MonthlyStatsEntry(
      date: Date(), monthLabel: monthLabel, playedCount: playedCount,
      wantToPlayCount: wantToPlayCount)
  }
}

struct MonthlyStatsWidgetEntryView: View {
  var entry: MonthlyStatsProvider.Entry

  var body: some View {
    VStack(alignment: .leading, spacing: 4) {
      Text(entry.monthLabel)
        .font(.system(size: 14, weight: .bold))
        .foregroundColor(Color(red: 0.10, green: 0.10, blue: 0.18))
        .lineLimit(1)
      Text("遊んだ \(entry.playedCount)本")
        .font(.system(size: 13))
        .foregroundColor(Color(red: 0.24, green: 0.35, blue: 1.0))
        .lineLimit(1)
      Text("遊びたい追加 \(entry.wantToPlayCount)本")
        .font(.system(size: 12))
        .foregroundColor(Color(red: 0.10, green: 0.10, blue: 0.18))
        .lineLimit(1)
    }
    .frame(maxWidth: .infinity, alignment: .leading)
    .padding(12)
    .widgetURL(URL(string: "savepoint://home")!)
  }
}

struct MonthlyStatsWidget: Widget {
  let kind: String = "MonthlyStatsWidget"

  var body: some WidgetConfiguration {
    StaticConfiguration(kind: kind, provider: MonthlyStatsProvider()) { entry in
      if #available(iOSApplicationExtension 17.0, *) {
        MonthlyStatsWidgetEntryView(entry: entry)
          .containerBackground(Color.white, for: .widget)
      } else {
        MonthlyStatsWidgetEntryView(entry: entry)
          .background(Color.white)
      }
    }
    .configurationDisplayName("今月の統計")
    .description("今月「遊んだ」「遊びたい」に追加した件数を表示します。")
    .supportedFamilies([.systemSmall, .systemMedium])
  }
}

@main
struct BacklogWidgets: WidgetBundle {
  var body: some Widget {
    BacklogWidget()
    TodayReleasesWidget()
    StreakWidget()
    MonthlyStatsWidget()
  }
}
