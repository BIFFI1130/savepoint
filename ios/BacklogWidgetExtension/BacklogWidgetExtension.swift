import SwiftUI
import WidgetKit

/// 積みゲー（「遊びたい」）の中で発売が一番近い作品を常時表示するホーム画面ウィジェット。
/// データ（タイトル・発売日・ゲームID）はFlutter側（BacklogWidgetService）が
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

struct BacklogEntry: TimelineEntry {
  let date: Date
  let title: String?
  let countdown: String?
  let gameId: String?
}

struct BacklogProvider: TimelineProvider {
  func placeholder(in context: Context) -> BacklogEntry {
    BacklogEntry(date: Date(), title: "Horror Prison: Escape", countdown: "発売まであと2日", gameId: nil)
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
    let countdown = releaseDateIso.flatMap(countdownLabel(from:))
    return BacklogEntry(date: Date(), title: title, countdown: countdown, gameId: gameId)
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
    VStack(alignment: .leading, spacing: 4) {
      Text(hasEntry ? entry.title! : "積みゲーの発売予定はありません")
        .font(.system(size: 14, weight: .bold))
        .foregroundColor(Color(red: 0.10, green: 0.10, blue: 0.18))
        .lineLimit(1)
      Text(hasEntry ? entry.countdown! : "SavePoint")
        .font(.system(size: 13))
        .foregroundColor(Color(red: 0.24, green: 0.35, blue: 1.0))
        .lineLimit(1)
    }
    .frame(maxWidth: .infinity, alignment: .leading)
    .padding(12)
    .widgetURL(destinationUrl)
  }
}

@main
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
    .configurationDisplayName("積みゲー")
    .description("発売が一番近い「遊びたい」作品を表示します。")
    .supportedFamilies([.systemSmall, .systemMedium])
  }
}
