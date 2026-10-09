import Flutter
import GameController
import UIKit

/// The native half of `lib/src/tv/tv_input.dart` on the iPhone and iPad, the
/// same as on the Apple TV (`tvos/Runner/GamepadPlugin.swift`): reads the
/// game controllers through GameController and streams what they hold to
/// Dart, about sixty times a second while something changes.
///
/// Every controller is reported on its own, controllers with two sticks
/// first: whoever picks one up steers with it right away, and two of them
/// play a duel. The remote's touch surface reports where the thumb rests,
/// from -1 to 1 on both axes, which the game reads as a stick.
///
/// The menus do not need this: the engine turns swipes, the select button
/// and the controller's pad and A into arrow keys and enter for Flutter's
/// focus. Only the round reads the raw state.
class GamepadPlugin: NSObject, FlutterPlugin, FlutterStreamHandler {
  static func register(with registrar: FlutterPluginRegistrar) {
    let plugin = GamepadPlugin()
    let events = FlutterEventChannel(
      name: "wargame/gamepad", binaryMessenger: registrar.messenger())
    events.setStreamHandler(plugin)
    let methods = FlutterMethodChannel(
      name: "wargame/tv", binaryMessenger: registrar.messenger())
    registrar.addMethodCallDelegate(plugin, channel: methods)
  }

  private var sink: FlutterEventSink?
  private var link: CADisplayLink?
  private var last: [String: AnyHashable] = [:]

  func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method {
    case "keepAwake":
      // Controller input does not count as activity for the screen saver,
      // so a round would dim in the middle of a fight.
      UIApplication.shared.isIdleTimerDisabled = call.arguments as? Bool ?? false
      result(nil)
    default:
      result(FlutterMethodNotImplemented)
    }
  }

  func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink)
    -> FlutterError?
  {
    sink = events
    let center = NotificationCenter.default
    center.addObserver(
      self, selector: #selector(controllersChanged),
      name: .GCControllerDidConnect, object: nil)
    center.addObserver(
      self, selector: #selector(controllersChanged),
      name: .GCControllerDidDisconnect, object: nil)
    controllersChanged()
    let link = CADisplayLink(target: self, selector: #selector(tick))
    link.preferredFramesPerSecond = 60
    link.add(to: .main, forMode: .common)
    self.link = link
    return nil
  }

  func onCancel(withArguments arguments: Any?) -> FlutterError? {
    NotificationCenter.default.removeObserver(self)
    link?.invalidate()
    link = nil
    sink = nil
    last = [:]
    return nil
  }

  /// The remote reports where the thumb rests instead of how far it moved,
  /// and keeps its axes the same way up however it is held. Every pad gets
  /// its player number, which lights up on controllers that have lights.
  @objc private func controllersChanged() {
    for (index, controller) in Self.ordered().enumerated() {
      if let micro = controller.microGamepad, controller.extendedGamepad == nil {
        micro.reportsAbsoluteDpadValues = true
        micro.allowsRotation = false
      }
      controller.playerIndex =
        GCControllerPlayerIndex(rawValue: min(index, 3)) ?? .indexUnset
    }
    last = [:]
  }

  @objc private func tick() {
    let state: [String: AnyHashable] = ["pads": Self.ordered().map(Self.read)]
    if state == last {
      return
    }
    last = state
    sink?(state)
  }

  /// Controllers with two sticks first, in the order they came in, the Siri
  /// Remote after them: the first one steers alone, the first two play a
  /// duel.
  private static func ordered() -> [GCController] {
    // The Simulator brings a virtual gamepad of its own, which hides the
    // touch sticks. Launched with `-ignoreGamepads YES` (store screenshots)
    // the app plays as on a phone without a controller.
    if UserDefaults.standard.bool(forKey: "ignoreGamepads") {
      return []
    }
    let all = GCController.controllers()
    return all.filter { $0.extendedGamepad != nil }
      + all.filter { $0.extendedGamepad == nil && $0.microGamepad != nil }
  }

  /// What one controller holds right now. Stick axes point up with positive
  /// y, as GameController has them.
  private static func read(_ controller: GCController) -> [String: AnyHashable] {
    if let pad = controller.extendedGamepad {
      return [
        "kind": "gamepad",
        "lx": Double(pad.leftThumbstick.xAxis.value),
        "ly": Double(pad.leftThumbstick.yAxis.value),
        "rx": Double(pad.rightThumbstick.xAxis.value),
        "ry": Double(pad.rightThumbstick.yAxis.value),
        "a": pad.buttonA.isPressed,
        "b": pad.buttonB.isPressed,
        "x": pad.buttonX.isPressed,
        "y": pad.buttonY.isPressed,
        "l1": pad.leftShoulder.isPressed,
        "r1": pad.rightShoulder.isPressed,
        "l2": pad.leftTrigger.isPressed,
        "r2": pad.rightTrigger.isPressed,
        "up": pad.dpad.up.isPressed,
        "down": pad.dpad.down.isPressed,
        "left": pad.dpad.left.isPressed,
        "right": pad.dpad.right.isPressed,
      ]
    }
    let remote = controller.microGamepad!
    return [
      "kind": "remote",
      "lx": Double(remote.dpad.xAxis.value),
      "ly": Double(remote.dpad.yAxis.value),
      // The click of the touch surface, and play/pause.
      "a": remote.buttonA.isPressed,
      "x": remote.buttonX.isPressed,
    ]
  }
}
