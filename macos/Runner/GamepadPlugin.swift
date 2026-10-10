import Cocoa
import FlutterMacOS
import GameController
import IOKit.pwr_mgt

/// The native half of `lib/src/tv/tv_input.dart` on the Mac, the same as on
/// the iPhone, iPad and Apple TV (`ios/Runner/GamepadPlugin.swift`): reads
/// the game controllers through GameController and streams what they hold
/// to Dart, about sixty times a second while something changes.
///
/// Every controller is reported on its own, in the order they came in:
/// whoever picks one up steers with it right away, and two of them play a
/// duel on a split screen. The menus stay with keyboard and mouse, as in
/// the browser; only the round reads the controllers.
class GamepadPlugin: NSObject, FlutterPlugin, FlutterStreamHandler {
  static func register(with registrar: FlutterPluginRegistrar) {
    let plugin = GamepadPlugin()
    let events = FlutterEventChannel(
      name: "wargame/gamepad", binaryMessenger: registrar.messenger)
    events.setStreamHandler(plugin)
    let methods = FlutterMethodChannel(
      name: "wargame/tv", binaryMessenger: registrar.messenger)
    registrar.addMethodCallDelegate(plugin, channel: methods)
  }

  private var sink: FlutterEventSink?
  // CADisplayLink needs macOS 14, the app runs from 12.
  private var timer: Timer?
  private var last: [String: AnyHashable] = [:]
  private var sleepBlock: IOPMAssertionID = 0

  func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method {
    case "keepAwake":
      // Controller input does not count as activity for the display sleep,
      // so a round would go dark in the middle of a fight.
      keepAwake(call.arguments as? Bool ?? false)
      result(nil)
    default:
      result(FlutterMethodNotImplemented)
    }
  }

  private func keepAwake(_ on: Bool) {
    if on && sleepBlock == 0 {
      IOPMAssertionCreateWithName(
        kIOPMAssertionTypePreventUserIdleDisplaySleep as CFString,
        IOPMAssertionLevel(kIOPMAssertionLevelOn),
        "Panzergefecht round" as CFString, &sleepBlock)
    } else if !on && sleepBlock != 0 {
      IOPMAssertionRelease(sleepBlock)
      sleepBlock = 0
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
    let timer = Timer(timeInterval: 1.0 / 60, repeats: true) { [weak self] _ in
      self?.tick()
    }
    RunLoop.main.add(timer, forMode: .common)
    self.timer = timer
    return nil
  }

  func onCancel(withArguments arguments: Any?) -> FlutterError? {
    NotificationCenter.default.removeObserver(self)
    timer?.invalidate()
    timer = nil
    sink = nil
    last = [:]
    return nil
  }

  /// Every pad gets its player number, which lights up on controllers that
  /// have lights.
  @objc private func controllersChanged() {
    for (index, controller) in Self.ordered().enumerated() {
      controller.playerIndex =
        GCControllerPlayerIndex(rawValue: min(index, 3)) ?? .indexUnset
    }
    last = [:]
  }

  private func tick() {
    let state: [String: AnyHashable] = ["pads": Self.ordered().map(Self.read)]
    if state == last {
      return
    }
    last = state
    sink?(state)
  }

  /// Controllers with two sticks, in the order they came in. A Mac has no
  /// Siri Remote, and the few one-stick pads would only confuse the seats.
  private static func ordered() -> [GCController] {
    GCController.controllers().filter { $0.extendedGamepad != nil }
  }

  /// What one controller holds right now. Stick axes point up with positive
  /// y, as GameController has them.
  private static func read(_ controller: GCController) -> [String: AnyHashable] {
    let pad = controller.extendedGamepad!
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
}
