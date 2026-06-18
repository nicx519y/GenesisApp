import Flutter
import PhotosUI
import Security
import UIKit
import UniformTypeIdentifiers

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate, PHPickerViewControllerDelegate {
  private let channelName = "com.worldo.ai/device"
  private let discussImagePickerChannelName = "com.worldo.ai/discuss_image_picker"
  private let uidKey = "uid"
  private let authTokenKey = "auth_token"
  private let userInfoKey = "user_info"
  private let deviceIdKey = "genesis_device_id"
  private let deviceIdKeychainService = "com.worldo.ai.device-id"
  private let prefs = UserDefaults.standard
  private var pendingDiscussImagePickerResult: FlutterResult?

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
    configureGenesisMethodChannel(messenger: engineBridge.applicationRegistrar.messenger())
    configureDiscussImagePickerChannel(messenger: engineBridge.applicationRegistrar.messenger())
  }

  private func configureGenesisMethodChannel(messenger: FlutterBinaryMessenger) {
    let channel = FlutterMethodChannel(
      name: channelName,
      binaryMessenger: messenger
    )
    channel.setMethodCallHandler { [weak self] call, result in
      guard let self = self else {
        result(FlutterError(code: "unavailable", message: "AppDelegate released", details: nil))
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
      case "setUserInfo":
        let args = call.arguments as? [String: Any]
        let userInfo = (args?["userInfo"] as? String ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        self.prefs.set(userInfo, forKey: self.userInfoKey)
        result(nil)
      case "getUserInfo":
        result(self.prefs.string(forKey: self.userInfoKey) ?? "")
      case "clearUid":
        self.prefs.removeObject(forKey: self.uidKey)
        self.prefs.removeObject(forKey: self.authTokenKey)
        self.prefs.removeObject(forKey: self.userInfoKey)
        result(nil)
      case "getSignInDiagnostics":
        result(self.signInDiagnostics())
      case "getAppName":
        let info = Bundle.main.infoDictionary
        let displayName = info?["CFBundleDisplayName"] as? String
        let bundleName = info?["CFBundleName"] as? String
        result(displayName ?? bundleName ?? "")
      case "getAppVersion":
        result(self.appVersionInfo())
      case "openExternalUrl":
        let args = call.arguments as? [String: Any]
        let value = (args?["url"] as? String ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        guard let url = URL(string: value), !value.isEmpty else {
          result(false)
          return
        }
        UIApplication.shared.open(url, options: [:]) { success in
          result(success)
        }
      default:
        result(FlutterMethodNotImplemented)
      }
    }
  }

  private func appVersionInfo() -> [String: Any] {
    let info = Bundle.main.infoDictionary
    return [
      "versionName": info?["CFBundleShortVersionString"] as? String ?? "",
      "versionCode": info?["CFBundleVersion"] as? String ?? "",
      "packageName": Bundle.main.bundleIdentifier ?? ""
    ]
  }

  private func configureDiscussImagePickerChannel(messenger: FlutterBinaryMessenger) {
    let channel = FlutterMethodChannel(
      name: discussImagePickerChannelName,
      binaryMessenger: messenger
    )
    channel.setMethodCallHandler { [weak self] call, result in
      guard let self = self else {
        result(FlutterError(code: "unavailable", message: "AppDelegate released", details: nil))
        return
      }
      switch call.method {
      case "pickImages":
        let args = call.arguments as? [String: Any]
        let limit = max(1, args?["limit"] as? Int ?? 6)
        self.pickDiscussImages(limit: limit, result: result)
      default:
        result(FlutterMethodNotImplemented)
      }
    }
  }

  private func pickDiscussImages(limit: Int, result: @escaping FlutterResult) {
    guard #available(iOS 14, *) else {
      result(FlutterError(code: "unsupported_ios", message: "PHPicker requires iOS 14 or later.", details: nil))
      return
    }
    guard pendingDiscussImagePickerResult == nil else {
      result(FlutterError(code: "picker_active", message: "An image picker is already active.", details: nil))
      return
    }
    guard let presenter = topViewController() else {
      result(FlutterError(code: "no_presenter", message: "Cannot find a view controller to present image picker.", details: nil))
      return
    }

    pendingDiscussImagePickerResult = result

    var config = PHPickerConfiguration(photoLibrary: .shared())
    config.filter = .images
    config.selectionLimit = limit
    config.preferredAssetRepresentationMode = .automatic

    let picker = PHPickerViewController(configuration: config)
    picker.delegate = self
    presenter.present(picker, animated: true)
  }

  @available(iOS 14, *)
  func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
    picker.dismiss(animated: true)
    guard let result = pendingDiscussImagePickerResult else {
      return
    }
    pendingDiscussImagePickerResult = nil

    guard !results.isEmpty else {
      result([])
      return
    }

    let group = DispatchGroup()
    var paths = Array<String?>(repeating: nil, count: results.count)
    var failures: [String] = []
    let lock = NSLock()

    for (index, item) in results.enumerated() {
      group.enter()
      saveDiscussPickedImage(item.itemProvider) { path, error in
        lock.lock()
        if let path = path {
          paths[index] = path
        } else if let error = error {
          failures.append(error)
          NSLog("Discuss image selection failed for item \(index): \(error)")
        }
        lock.unlock()
        group.leave()
      }
    }

    group.notify(queue: .main) {
      let loadedPaths = paths.compactMap { $0 }
      if loadedPaths.isEmpty, let firstFailure = failures.first {
        result(FlutterError(code: "invalid_image", message: firstFailure, details: failures))
      } else {
        result(loadedPaths)
      }
    }
  }

  @available(iOS 14, *)
  private func saveDiscussPickedImage(
    _ provider: NSItemProvider,
    completion: @escaping (String?, String?) -> Void
  ) {
    loadDiscussUIImageRepresentation(provider) { [weak self] path, error in
      if let path = path {
        completion(path, nil)
        return
      }

      NSLog("Discuss UIImage representation failed: \(error ?? "unknown error")")
      self?.loadDiscussImageDataRepresentation(provider) { dataPath, dataError in
        if let dataPath = dataPath {
          completion(dataPath, nil)
        } else {
          completion(nil, dataError ?? error ?? "Cannot load selected image.")
        }
      }
    }
  }

  @available(iOS 14, *)
  private func loadDiscussImageDataRepresentation(
    _ provider: NSItemProvider,
    completion: @escaping (String?, String?) -> Void
  ) {
    var remaining = provider.registeredTypeIdentifiers.filter { identifier in
      guard let type = UTType(identifier) else {
        return false
      }
      return type.conforms(to: .image)
    }

    func tryNext(lastError: String?) {
      guard !remaining.isEmpty else {
        completion(nil, lastError)
        return
      }

      let identifier = remaining.removeFirst()
      provider.loadDataRepresentation(forTypeIdentifier: identifier) { [weak self] data, error in
        if let data = data,
           let image = UIImage(data: data),
           let path = self?.writeDiscussJPEGImage(image) {
          completion(path, nil)
        } else {
          let message = error?.localizedDescription ?? "Cannot load data representation of type \(identifier)."
          NSLog("Discuss image data representation failed: \(message)")
          tryNext(lastError: message)
        }
      }
    }

    tryNext(lastError: nil)
  }

  private func loadDiscussUIImageRepresentation(
    _ provider: NSItemProvider,
    completion: @escaping (String?, String?) -> Void
  ) {
    guard provider.canLoadObject(ofClass: UIImage.self) else {
      completion(nil, "Provider cannot load UIImage.")
      return
    }

    provider.loadObject(ofClass: UIImage.self) { [weak self] object, error in
      guard let image = object as? UIImage,
            let path = self?.writeDiscussJPEGImage(image) else {
        completion(nil, error?.localizedDescription ?? "Cannot load UIImage representation.")
        return
      }
      completion(path, nil)
    }
  }

  private func writeDiscussJPEGImage(_ image: UIImage) -> String? {
    guard let data = image.jpegData(compressionQuality: 0.92) else {
      return nil
    }
    return writeDiscussImageData(data, extension: "jpg")
  }

  private func writeDiscussImageData(_ data: Data, extension fileExtension: String) -> String? {
    let destination = discussPickerTempURL(fileExtension: fileExtension)
    do {
      try data.write(to: destination, options: .atomic)
      return destination.path
    } catch {
      NSLog("Discuss image data write failed: \(error)")
      return nil
    }
  }

  private func discussPickerTempURL(fileExtension: String) -> URL {
    let filename = "\(UUID().uuidString).\(fileExtension)"
    return URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true).appendingPathComponent(filename)
  }

  private func topViewController() -> UIViewController? {
    let activeScene = UIApplication.shared.connectedScenes
      .compactMap { $0 as? UIWindowScene }
      .first { $0.activationState == .foregroundActive }
    let root = activeScene?.windows.first { $0.isKeyWindow }?.rootViewController
      ?? UIApplication.shared.windows.first { $0.isKeyWindow }?.rootViewController
    return topViewController(from: root)
  }

  private func topViewController(from controller: UIViewController?) -> UIViewController? {
    if let navigationController = controller as? UINavigationController {
      return topViewController(from: navigationController.visibleViewController)
    }
    if let tabBarController = controller as? UITabBarController {
      return topViewController(from: tabBarController.selectedViewController)
    }
    if let presented = controller?.presentedViewController {
      return topViewController(from: presented)
    }
    return controller
  }

  private func deviceId() -> String {
    if let existing = readKeychainDeviceId() {
      return existing
    }

    if let legacy = prefs.string(forKey: deviceIdKey), !legacy.isEmpty {
      saveKeychainDeviceId(legacy)
      return legacy
    }

    let generated = UUID().uuidString
    let value = "ios:\(generated)"
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
          !value.isEmpty else {
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
    let info = Bundle.main.infoDictionary ?? [:]
    let googleServiceInfo = googleServiceInfoPlist()
    return [
      "platform": "ios",
      "bundleIdentifier": Bundle.main.bundleIdentifier ?? "",
      "systemVersion": UIDevice.current.systemVersion,
      "gidClientId": normalizedString(info["GIDClientID"]),
      "gidServerClientId": normalizedString(info["GIDServerClientID"]),
      "googleServiceClientId": normalizedString(googleServiceInfo["CLIENT_ID"]),
      "googleServiceServerClientId": normalizedString(googleServiceInfo["SERVER_CLIENT_ID"]),
    ]
  }

  private func googleServiceInfoPlist() -> [String: Any] {
    guard let url = Bundle.main.url(forResource: "GoogleService-Info", withExtension: "plist"),
          let data = NSDictionary(contentsOf: url) as? [String: Any] else {
      return [:]
    }
    return data
  }

  private func normalizedString(_ value: Any?) -> String {
    return (value as? String ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
  }
}
