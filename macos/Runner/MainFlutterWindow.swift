import Cocoa
import FlutterMacOS

class MainFlutterWindow: NSWindow {
  override func awakeFromNib() {
    let flutterViewController = FlutterViewController()
    self.contentViewController = flutterViewController

    // The template's 800 x 600 is cramped for the field: open at 16:10, which
    // most screens fit, and remember where the player left the window.
    self.setContentSize(NSSize(width: 1280, height: 800))
    self.contentMinSize = NSSize(width: 720, height: 480)
    self.center()
    self.setFrameAutosaveName("Panzergefecht")

    RegisterGeneratedPlugins(registry: flutterViewController)

    super.awakeFromNib()
  }
}
