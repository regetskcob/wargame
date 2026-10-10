import Foundation

/// How a round ended, handed from the app to the iMessage app, so the
/// bubble that invited to the room can show it. Both read and write the
/// defaults of their shared app group; the app writes every round, the
/// iMessage app picks the rooms it sent or joined from a chat.
struct ChatResult: Codable, Equatable {
  let room: String
  /// This player's name in the round.
  let pilot: String
  /// The game's `GameMode` name: `multi`, `flag` or `defense`.
  let mode: String
  let won: Bool
  /// Whoever won when it was not this player, if anybody did.
  let winner: String?
  let kills: Int
  /// The wave the defense reached, 0 outside the defense.
  let wave: Int
  let waves: Int
  let at: Date

  static let group = "group.de.regetskcob.wargame"
  private static let key = "chatResults"

  /// The latest results, one per room, newest first.
  static func all() -> [ChatResult] {
    guard let data = UserDefaults(suiteName: group)?.data(forKey: key),
          let results = try? JSONDecoder().decode([ChatResult].self, from: data)
    else { return [] }
    return results
  }

  /// Keeps [result] in place of an older one of its room. A handful is
  /// enough, nobody shares the round of last week.
  static func record(_ result: ChatResult) {
    let kept = [result] + all().filter { $0.room != result.room }
    guard let data = try? JSONEncoder().encode(Array(kept.prefix(10))) else { return }
    UserDefaults(suiteName: group)?.set(data, forKey: key)
  }
}
