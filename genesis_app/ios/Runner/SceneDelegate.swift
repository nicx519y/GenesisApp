import Flutter
import UIKit

class SceneDelegate: FlutterSceneDelegate {
  override func sceneDidBecomeActive(_ scene: UIScene) {
    super.sceneDidBecomeActive(scene)
    GenesisAppLifecycleStreamHandler.shared.sceneDidBecomeActive()
  }

  override func sceneDidEnterBackground(_ scene: UIScene) {
    super.sceneDidEnterBackground(scene)
    GenesisAppLifecycleStreamHandler.shared.sceneDidEnterBackground()
  }
}
