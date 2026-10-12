import Cocoa
import FlutterMacOS
import app_links

@main
class AppDelegate: FlutterAppDelegate {
  override func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
    return true
  }

  override func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool {
    return true
  }

  // A room link from the web (associated domain www.regetskcob.de) arrives
  // as a browsing activity. app_links handles custom schemes on the Mac by
  // itself but leaves universal links to the app, so hand them on here.
  override func application(
    _ application: NSApplication,
    continue userActivity: NSUserActivity,
    restorationHandler: @escaping ([any NSUserActivityRestoring]) -> Void
  ) -> Bool {
    guard let url = AppLinks.shared.getUniversalLink(userActivity) else {
      return false
    }
    AppLinks.shared.handleLink(link: url.absoluteString)
    return true
  }
}
