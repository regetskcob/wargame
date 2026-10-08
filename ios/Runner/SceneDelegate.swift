import Flutter
import UIKit
import WidgetKit

class SceneDelegate: FlutterSceneDelegate {
  // Leaving the game is the moment the online count on the home screen is
  // most likely stale, so let the widget ask again right away.
  override func sceneWillResignActive(_ scene: UIScene) {
    super.sceneWillResignActive(scene)
    WidgetCenter.shared.reloadAllTimelines()
  }
}
