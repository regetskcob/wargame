import SwiftUI
import WidgetKit

/// The same hosted project as `lib/src/env.dart`. The publishable key only
/// reaches what row level security and the granted functions allow.
private enum Backend {
  static let url = URL(string: "https://wowtrfleffnfaiadhujj.supabase.co/rest/v1/rpc/online_status")!
  static let key = "sb_publishable__f2Lb3vqafUovQCsYilkiQ_nVNkoNhS"
}

/// Colours of the training ground, as `BwColors` in `lib/src/theme.dart`.
enum Bw {
  static let background = Color(red: 0x16 / 255, green: 0x1C / 255, blue: 0x0F / 255)
  static let surface = Color(red: 0x2A / 255, green: 0x35 / 255, blue: 0x20 / 255)
  static let olive = Color(red: 0x8A / 255, green: 0x9A / 255, blue: 0x5B / 255)
  static let sand = Color(red: 0xC2 / 255, green: 0xA8 / 255, blue: 0x78 / 255)
  static let amber = Color(red: 1, green: 0xB3 / 255, blue: 0)
  static let danger = Color(red: 0xD1 / 255, green: 0x49 / 255, blue: 0x2E / 255)
  static let text = Color(red: 0xE6 / 255, green: 0xE2 / 255, blue: 0xD3 / 255)
  static let textDim = Color(red: 0xBF / 255, green: 0xC6 / 255, blue: 0xAA / 255)
}

struct OnlineStatus: Decodable {
  let online: Int
  let inMatch: Int
  let roundsToday: Int

  enum CodingKeys: String, CodingKey {
    case online
    case inMatch = "in_match"
    case roundsToday = "rounds_today"
  }

  static let preview = OnlineStatus(online: 7, inMatch: 4, roundsToday: 42)

  static func fetch() async throws -> OnlineStatus {
    var request = URLRequest(url: Backend.url, timeoutInterval: 10)
    request.httpMethod = "POST"
    request.setValue(Backend.key, forHTTPHeaderField: "apikey")
    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
    request.httpBody = Data("{}".utf8)
    let (data, response) = try await URLSession.shared.data(for: request)
    guard (response as? HTTPURLResponse)?.statusCode == 200 else {
      throw URLError(.badServerResponse)
    }
    // A function returning a table answers with a list of one row.
    guard let row = try JSONDecoder().decode([OnlineStatus].self, from: data).first else {
      throw URLError(.cannotParseResponse)
    }
    return row
  }
}

struct OnlineEntry: TimelineEntry {
  let date: Date
  /// Nil when the server could not be reached.
  let status: OnlineStatus?
}

struct OnlineProvider: TimelineProvider {
  func placeholder(in context: Context) -> OnlineEntry {
    OnlineEntry(date: .now, status: .preview)
  }

  func getSnapshot(in context: Context, completion: @escaping (OnlineEntry) -> Void) {
    if context.isPreview {
      completion(placeholder(in: context))
      return
    }
    Task { completion(await load()) }
  }

  func getTimeline(in context: Context, completion: @escaping (Timeline<OnlineEntry>) -> Void) {
    Task {
      let entry = await load()
      // WidgetKit hands out a few dozen refreshes a day; ask for one every
      // ten minutes, sooner after a failed request.
      let wait: TimeInterval = entry.status == nil ? 5 * 60 : 10 * 60
      completion(Timeline(entries: [entry], policy: .after(.now.addingTimeInterval(wait))))
    }
  }

  private func load() async -> OnlineEntry {
    OnlineEntry(date: .now, status: try? await OnlineStatus.fetch())
  }
}

struct OnlineWidgetView: View {
  @Environment(\.widgetFamily) private var family
  let entry: OnlineEntry

  var body: some View {
    switch family {
    case .accessoryCircular:
      circular
    case .accessoryRectangular:
      rectangular
    case .accessoryInline:
      Text(entry.status.map { tr("\($0.online) Piloten online", "\($0.online) pilots online") } ?? tr("Panzergefecht offline", "Panzergefecht offline"))
    case .systemMedium:
      medium
    default:
      small(showMatches: true)
    }
  }

  private var onlineText: String {
    entry.status.map { "\($0.online)" } ?? "–"
  }

  private var title: some View {
    Text("PANZERGEFECHT")
      .font(.system(size: 11, weight: .black))
      .tracking(1.5)
      .foregroundStyle(Bw.sand)
      .lineLimit(1)
      .minimumScaleFactor(0.7)
  }

  private var dot: some View {
    Circle()
      .fill((entry.status?.online ?? 0) > 0 ? Bw.amber : Bw.textDim.opacity(0.4))
      .frame(width: 8, height: 8)
  }

  private func small(showMatches: Bool) -> some View {
    VStack(alignment: .leading, spacing: 4) {
      title
      Spacer(minLength: 0)
      Text(onlineText)
        .font(.system(size: 52, weight: .black, design: .rounded))
        .foregroundStyle(Bw.text)
        .contentTransition(.numericText())
        .minimumScaleFactor(0.5)
      HStack(spacing: 6) {
        dot
        Text(entry.status == nil ? tr("keine Verbindung", "no connection") : tr("Piloten online", "pilots online"))
          .font(.system(size: 13, weight: .semibold))
          .foregroundStyle(Bw.textDim)
      }
      if showMatches, let status = entry.status, status.inMatch > 0 {
        Text(tr("\(status.inMatch) im Gefecht", "\(status.inMatch) in battle"))
          .font(.system(size: 12, weight: .medium))
          .foregroundStyle(Bw.olive)
      }
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
  }

  private var medium: some View {
    HStack(spacing: 16) {
      small(showMatches: false)
      VStack(alignment: .leading, spacing: 10) {
        stat(entry.status.map { "\($0.inMatch)" } ?? "–", tr("im Gefecht", "in battle"))
        stat(entry.status.map { "\($0.roundsToday)" } ?? "–", tr("Runden heute", "rounds today"))
        Text("\(tr("Stand", "As of")) \(entry.date, style: .time)")
          .font(.system(size: 11))
          .foregroundStyle(Bw.textDim.opacity(0.7))
      }
      .padding(12)
      .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
      .background(Bw.surface, in: RoundedRectangle(cornerRadius: 14))
    }
  }

  private func stat(_ value: String, _ label: String) -> some View {
    VStack(alignment: .leading, spacing: 0) {
      Text(value)
        .font(.system(size: 24, weight: .heavy, design: .rounded))
        .foregroundStyle(Bw.amber)
      Text(label)
        .font(.system(size: 12, weight: .medium))
        .foregroundStyle(Bw.textDim)
    }
  }

  private var circular: some View {
    ZStack {
      AccessoryWidgetBackground()
      VStack(spacing: -2) {
        Text(onlineText)
          .font(.system(size: 22, weight: .black, design: .rounded))
          .minimumScaleFactor(0.5)
        Text(tr("online", "online"))
          .font(.system(size: 9, weight: .semibold))
      }
    }
  }

  private var rectangular: some View {
    VStack(alignment: .leading, spacing: 0) {
      Text("Panzergefecht")
        .font(.headline)
        .widgetAccentable()
      Text(entry.status.map { "\($0.online) online" } ?? tr("keine Verbindung", "no connection"))
      if let status = entry.status {
        Text(tr("\(status.inMatch) im Gefecht", "\(status.inMatch) in battle"))
          .foregroundStyle(.secondary)
      }
    }
    .frame(maxWidth: .infinity, alignment: .leading)
  }
}

struct OnlineWidget: Widget {
  var body: some WidgetConfiguration {
    StaticConfiguration(kind: "OnlineWidget", provider: OnlineProvider()) { entry in
      OnlineWidgetView(entry: entry)
        .containerBackground(for: .widget) { Bw.background }
    }
    .configurationDisplayName(tr("Piloten online", "Pilots online"))
    .description(tr("Wie viele gerade Panzergefecht spielen.", "How many are playing Panzergefecht right now."))
    .supportedFamilies([
      .systemSmall, .systemMedium,
      .accessoryCircular, .accessoryRectangular, .accessoryInline,
    ])
  }
}

@main
struct OnlineWidgetBundle: WidgetBundle {
  var body: some Widget {
    OnlineWidget()
    MatchLiveActivity()
  }
}

#Preview(as: .systemMedium) {
  OnlineWidget()
} timeline: {
  OnlineEntry(date: .now, status: .preview)
  OnlineEntry(date: .now, status: nil)
}

/// The text in the language of the device: German on German devices, English
/// everywhere else. The app picks the same way on its first start.
func tr(_ de: String, _ en: String) -> String {
  Locale.current.language.languageCode?.identifier == "de" ? de : en
}
