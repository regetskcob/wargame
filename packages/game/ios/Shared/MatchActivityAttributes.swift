import ActivityKit
import Foundation

/// A round of Panzergefecht as a Live Activity. Compiled into the app, which
/// starts and updates it, and into the widget extension, which draws it.
@available(iOS 16.1, *)
struct MatchActivityAttributes: ActivityAttributes {
  struct ContentState: Codable, Hashable {
    /// `countdown`, `playing`, `spectating` or `roundOver`, as `GamePhase`.
    var phase: String
    /// When the round starts or started; the countdown runs towards it.
    var startsAt: Date
    var alive: Int
    var total: Int
    /// Own armour from 0 to 1.
    var hp: Double
    var kills: Int
    /// Whose tank the camera follows after the own one fell.
    var spectating: String?
    /// Defense rounds: running wave, 0 before the first.
    var wave: Int
    var waves: Int
    /// Defense rounds: hit points of the base from 0 to 1.
    var baseHp: Double
    /// Defense rounds: when the next wave rolls in, nil while one is running.
    var nextWaveAt: Date?
    /// `none`, `won` or `lost`, as `RoundOutcome`.
    var outcome: String
    var winner: String?
  }

  var room: String
  var pilot: String
  /// `solo`, `multi` or `defense`, as `GameMode`.
  var mode: String
  var map: String
}
