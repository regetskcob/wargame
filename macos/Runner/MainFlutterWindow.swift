import Cocoa
import FlutterMacOS

class MainFlutterWindow: NSWindow {
  override func awakeFromNib() {
    let flutterViewController = FlutterViewController()
    self.contentViewController = flutterViewController

    // Leaving full screen falls back to a 16:10 window most screens fit,
    // instead of the template's cramped 800 x 600.
    self.setContentSize(NSSize(width: 1280, height: 800))
    self.contentMinSize = NSSize(width: 720, height: 480)
    self.center()

    // A game takes the whole screen, every time: without restoring, macOS
    // cannot reopen the window as a window and undo the switch below.
    self.isRestorable = false
    self.collectionBehavior.insert(.fullScreenPrimary)
    DispatchQueue.main.async {
      if !self.styleMask.contains(.fullScreen) {
        self.toggleFullScreen(nil)
      }
    }

    RegisterGeneratedPlugins(registry: flutterViewController)
    GamepadPlugin.register(
      with: flutterViewController.registrar(forPlugin: "GamepadPlugin"))

    super.awakeFromNib()
  }
}
