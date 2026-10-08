import ActivityKit
import Flutter
import Foundation

/// The native half of `lib/src/app/live_activity.dart`: starts, updates and
/// ends the Live Activity of the running round. Silently does nothing below
/// iOS 16.2 or when the player switched Live Activities off.
class LiveActivityPlugin: NSObject, FlutterPlugin {
  static func register(with registrar: FlutterPluginRegistrar) {
    let channel = FlutterMethodChannel(
      name: "wargame/live_activity", binaryMessenger: registrar.messenger())
    registrar.addMethodCallDelegate(LiveActivityPlugin(), channel: channel)
  }

  func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    guard #available(iOS 16.2, *), let args = call.arguments as? [String: Any] else {
      result(nil)
      return
    }
    let state = (args["state"] as? [String: Any]).map(Self.contentState)
    Task {
      switch call.method {
      case "start":
        if let state { await Self.start(args, state) }
      case "update":
        if let state { await Self.update(state) }
      case "end":
        await Self.end(state, linger: args["linger"] as? Bool ?? false)
      default:
        break
      }
      result(nil)
    }
  }

  @available(iOS 16.2, *)
  private static func start(
    _ args: [String: Any], _ state: MatchActivityAttributes.ContentState
  ) async {
    await end(nil, linger: false)
    guard ActivityAuthorizationInfo().areActivitiesEnabled else { return }
    let attributes = MatchActivityAttributes(
      room: args["room"] as? String ?? "",
      pilot: args["pilot"] as? String ?? "",
      mode: args["mode"] as? String ?? "multi",
      map: args["map"] as? String ?? "")
    _ = try? Activity.request(attributes: attributes, content: content(state))
  }

  @available(iOS 16.2, *)
  private static func update(_ state: MatchActivityAttributes.ContentState) async {
    for activity in Activity<MatchActivityAttributes>.activities {
      await activity.update(content(state))
    }
  }

  @available(iOS 16.2, *)
  private static func end(_ state: MatchActivityAttributes.ContentState?, linger: Bool) async {
    for activity in Activity<MatchActivityAttributes>.activities {
      await activity.end(
        state.map(content),
        dismissalPolicy: linger ? .after(.now.addingTimeInterval(5 * 60)) : .immediate)
    }
  }

  /// Without updates for a while the game was most likely left in the
  /// background, and the system greys the activity out.
  @available(iOS 16.2, *)
  private static func content(_ state: MatchActivityAttributes.ContentState)
    -> ActivityContent<MatchActivityAttributes.ContentState>
  {
    ActivityContent(state: state, staleDate: .now.addingTimeInterval(2 * 60))
  }

  @available(iOS 16.1, *)
  private static func contentState(_ json: [String: Any]) -> MatchActivityAttributes.ContentState {
    func date(_ key: String) -> Date? {
      guard let ms = (json[key] as? NSNumber)?.doubleValue, ms > 0 else { return nil }
      return Date(timeIntervalSince1970: ms / 1000)
    }
    return MatchActivityAttributes.ContentState(
      phase: json["phase"] as? String ?? "playing",
      startsAt: date("startsAt") ?? .now,
      alive: (json["alive"] as? NSNumber)?.intValue ?? 0,
      total: (json["total"] as? NSNumber)?.intValue ?? 0,
      hp: (json["hp"] as? NSNumber)?.doubleValue ?? 0,
      kills: (json["kills"] as? NSNumber)?.intValue ?? 0,
      spectating: json["spectating"] as? String,
      wave: (json["wave"] as? NSNumber)?.intValue ?? 0,
      waves: (json["waves"] as? NSNumber)?.intValue ?? 8,
      baseHp: (json["baseHp"] as? NSNumber)?.doubleValue ?? 0,
      nextWaveAt: date("nextWaveAt"),
      outcome: json["outcome"] as? String ?? "none",
      winner: json["winner"] as? String)
  }
}
