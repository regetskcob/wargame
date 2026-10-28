import Flutter
import Foundation

/// The native half of `lib/src/app/chat_result.dart`: leaves the result of
/// every finished round in the app group, for the iMessage app.
class ChatResultPlugin: NSObject, FlutterPlugin {
  static func register(with registrar: FlutterPluginRegistrar) {
    let channel = FlutterMethodChannel(
      name: "wargame/chat_result", binaryMessenger: registrar.messenger())
    registrar.addMethodCallDelegate(ChatResultPlugin(), channel: channel)
  }

  func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    guard call.method == "record", let args = call.arguments as? [String: Any],
          let room = args["room"] as? String
    else {
      result(nil)
      return
    }
    ChatResult.record(ChatResult(
      room: room,
      pilot: args["pilot"] as? String ?? "",
      mode: args["mode"] as? String ?? "multi",
      won: args["won"] as? Bool ?? false,
      winner: args["winner"] as? String,
      kills: (args["kills"] as? NSNumber)?.intValue ?? 0,
      wave: (args["wave"] as? NSNumber)?.intValue ?? 0,
      waves: (args["waves"] as? NSNumber)?.intValue ?? 8,
      at: .now))
    result(nil)
  }
}
