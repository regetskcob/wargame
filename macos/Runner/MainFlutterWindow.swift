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
    if UserDefaults.standard.string(forKey: "SHOT_SCENE") != nil {
      // Store pictures (tool/store_shots.sh): a 16:10 window of exactly
      // 1440 x 900 points, 2880 x 1800 pixels on a Retina screen, with the
      // game reaching up under an invisible title bar.
      self.styleMask.insert(.fullSizeContentView)
      self.titlebarAppearsTransparent = true
      self.titleVisibility = .hidden
      for button in [NSWindow.ButtonType.closeButton, .miniaturizeButton, .zoomButton] {
        self.standardWindowButton(button)?.isHidden = true
      }
      self.setContentSize(NSSize(width: 1440, height: 900))
      self.center()
    } else {
      DispatchQueue.main.async {
        if !self.styleMask.contains(.fullScreen) {
          self.toggleFullScreen(nil)
        }
      }
    }

    RegisterGeneratedPlugins(registry: flutterViewController)
    GamepadPlugin.register(
      with: flutterViewController.registrar(forPlugin: "GamepadPlugin"))

    super.awakeFromNib()
  }
}
