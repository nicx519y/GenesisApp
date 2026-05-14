import Flutter
import Security
import UIKit

class SceneDelegate: FlutterSceneDelegate {
  private let channelName = "com.genesis.ai/device"
  private let uidKey = "uid"
  private let authTokenKey = "auth_token"
  private let deviceIdKey = "genesis_device_id"
  private let deviceIdKeychainService = "com.genesis.ai.device-id"
  private let prefs = UserDefaults.standard

  override func scene(
    _ scene: UIScene,
    willConnectTo session: UISceneSession,
    options connectionOptions: UIScene.ConnectionOptions
  ) {
    super.scene(scene, willConnectTo: session, options: connectionOptions)
    configureGenesisMethodChannel()
  }

  private func configureGenesisMethodChannel() {
    guard let controller = window?.rootViewController as? FlutterViewController else {
      return
    }

    let channel = FlutterMethodChannel(
      name: channelName,
      binaryMessenger: controller.binaryMessenger
    )
    channel.setMethodCallHandler { [weak self] call, result in
      guard let self = self else {
        result(FlutterError(code: "unavailable", message: "SceneDelegate released", details: nil))
        return
      }
      switch call.method {
      case "getDeviceId", "getAndroidId":
        result(self.deviceId())
      case "setUid":
        let args = call.arguments as? [String: Any]
        let uid = (args?["uid"] as? String ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        self.prefs.set(uid, forKey: self.uidKey)
        result(nil)
      case "getUid":
        result(self.prefs.string(forKey: self.uidKey) ?? "")
      case "setAuthToken":
        let args = call.arguments as? [String: Any]
        let token = (args?["token"] as? String ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        self.prefs.set(token, forKey: self.authTokenKey)
        result(nil)
      case "getAuthToken":
        result(self.prefs.string(forKey: self.authTokenKey) ?? "")
      case "clearUid":
        self.prefs.removeObject(forKey: self.uidKey)
        self.prefs.removeObject(forKey: self.authTokenKey)
        result(nil)
      case "getSignInDiagnostics":
        result(self.signInDiagnostics())
      default:
        result(FlutterMethodNotImplemented)
      }
    }
  }

  private func deviceId() -> String {
    if let existing = readKeychainDeviceId() {
      return existing
    }

    if let legacy = prefs.string(forKey: deviceIdKey), !legacy.isEmpty {
      saveKeychainDeviceId(legacy)
      return legacy
    }

    let value = "ios:\(UUID().uuidString)"
    saveKeychainDeviceId(value)
    return value
  }

  private func readKeychainDeviceId() -> String? {
    var query = keychainDeviceIdQuery()
    query[kSecReturnData as String] = true
    query[kSecMatchLimit as String] = kSecMatchLimitOne

    var item: CFTypeRef?
    let status = SecItemCopyMatching(query as CFDictionary, &item)
    guard status == errSecSuccess,
      let data = item as? Data,
      let value = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines),
      !value.isEmpty
    else {
      return nil
    }
    return value
  }

  private func saveKeychainDeviceId(_ value: String) {
    let normalized = value.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !normalized.isEmpty, let data = normalized.data(using: .utf8) else {
      return
    }

    SecItemDelete(keychainDeviceIdQuery() as CFDictionary)

    var item = keychainDeviceIdQuery()
    item[kSecValueData as String] = data
    item[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
    SecItemAdd(item as CFDictionary, nil)
  }

  private func keychainDeviceIdQuery() -> [String: Any] {
    return [
      kSecClass as String: kSecClassGenericPassword,
      kSecAttrService as String: deviceIdKeychainService,
      kSecAttrAccount as String: deviceIdKey,
    ]
  }

  private func signInDiagnostics() -> [String: Any] {
    return [
      "platform": "ios",
      "bundleIdentifier": Bundle.main.bundleIdentifier ?? "",
      "systemVersion": UIDevice.current.systemVersion,
    ]
  }
}
