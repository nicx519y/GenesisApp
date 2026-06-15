# GenesisApp iOS / Android 跨平台目录组织说明

## 1. 目标

`genesis_flutter_android` 后续需要同时支持 Android 和 iOS。目录组织的核心原则是：

- **页面渲染和业务逻辑尽量共享**：Flutter 页面、组件、路由、模型、API 解析逻辑默认放在 `lib/` 的共享层。
- **平台能力通过接口隔离**：设备 ID、登录、会话存储、MethodChannel、平台 header 等能力集中在 `lib/platform/` 和 `lib/app/config/`。
- **不大规模重构 UI 目录**：当前 `pages/`、`components/`、`routers/` 保持为共享目录，不先改成 feature-first 或 Clean Architecture。
- **不改变后端 API 合约**：接口路径、字段、鉴权语义保持不变。`x-platform` 只作为平台配置项处理，不能未经后端验证就直接切成 `ios`。

---

## 2. 推荐目标目录树

```text
genesis_flutter_android/
  lib/
    main.dart
    app/
      genesis_app.dart
      bootstrap/
        app_bootstrap.dart
        service_registry.dart
        app_services_scope.dart
      config/
        app_config.dart
        platform_config.dart
    components/
    pages/
    routers/
    models/
    network/
      api_client.dart
      api_exception.dart
      http_transport.dart
      io_http_transport.dart
      genesis_api.dart
      json_utils.dart
      local_mock_genesis_transport.dart
      mock_data/
      models/
    platform/
      platform_services.dart
      channels/
        genesis_method_channels.dart
      device/
        device_id_service.dart
        method_channel_device_id_service.dart
      session/
        user_session_store.dart
        method_channel_user_session_store.dart
        memory_user_session_store.dart
      auth/
        identity_auth_service.dart
        backend_auth_coordinator.dart
        auth_session.dart
        google_firebase_auth_service.dart
  android/
  ios/
  assets/
  test/
  docs/
```

---

## 3. 顶层目录职责

### `lib/`

Flutter/Dart 主源码目录。这里的代码默认应当是 **Android 和 iOS 共享** 的。

放在这里的内容包括：

- Flutter app 入口和应用组装
- 页面、组件、路由
- API client、response model、JSON 解析
- 平台能力的 Dart 抽象接口
- 平台能力的 Flutter/Dart adapter

不建议在共享页面里直接写：

- `MethodChannel`
- `Platform.isAndroid` / `Platform.isIOS`
- `firebase_auth` / `google_sign_in` 等 SDK 直接调用
- `GenesisApi()` 随处直接构造

这些应通过 `app/bootstrap/`、`app/config/`、`platform/` 中的边界来访问。

---

### `android/`

Android 原生工程目录。

职责：

- Android Gradle 配置
- Android Manifest、启动图、权限配置
- Android 原生 MethodChannel 实现
- Android 特有资源、签名、Firebase `google-services.json` 等配置

当前重点文件：

```text
android/app/src/main/kotlin/com/genesis/ai/genesis_flutter_android/MainActivity.kt
```

它当前负责：

- `getAndroidId`
- `setUid`
- `getUid`
- `clearUid`
- `getSignInDiagnostics`

未来要求：

- Android 原生方法名应与 `lib/platform/channels/genesis_method_channels.dart` 中定义的常量保持一致。
- Android 代码只实现 Android 原生能力，不承载 Flutter 页面业务逻辑。

---

### `ios/`

iOS 原生工程目录。当前项目还没有 `ios/`，这是未来通过 Flutter 工具生成和补齐的目录。

职责：

- iOS Runner 工程
- `AppDelegate.swift` / `AppDelegate.m`
- iOS MethodChannel 实现
- iOS Firebase 配置，例如 `GoogleService-Info.plist`
- Google Sign-In URL Scheme / plist 配置
- iOS 权限、Bundle ID、签名、Capabilities 等配置

注意：

- 现在不能声称项目已经 iOS 可编译，因为 `ios/` 尚不存在。
- `flutter build ios --debug --no-codesign` 只能在 iOS scaffold、Xcode/CocoaPods/Firebase iOS 配置都补齐后验证。

---

### `assets/`

共享静态资源目录。

职责：

- 图片
- SVG
- 自定义字体 / icon font
- 启动图源素材

资源默认是跨平台共享的。只有 Android/iOS 原生启动图、App Icon 等必须放在各自原生目录时，才放入 `android/` 或 `ios/`。

---

### `test/`

测试目录。

职责：

- API client 测试
- GenesisApi 测试
- mock transport 测试
- 后续平台接口 fake 测试
- UI/widget smoke 测试

后续跨平台改造时，测试重点是：

- 平台服务可以被 fake/mock
- `GenesisApi` 不直接依赖 Android-only 类
- Android 默认 header 保持兼容
- iOS header 只有在后端确认支持后才启用

---

### `docs/`

项目文档目录。

职责：

- 架构说明
- 登录/session 文档
- 目录组织说明
- 迁移计划
- API/平台边界说明

本文档就放在：

```text
docs/cross_platform_directory_organization.md
```

---

## 4. `lib/app/` 目录职责

### `lib/app/genesis_app.dart`

Flutter 应用根组件。

职责：

- 创建 `MaterialApp`
- 配置主题
- 配置初始路由或根页面
- 包住全局 app scope，例如未来的 `AppServicesScope`

不建议放：

- 设备 ID 获取细节
- Google/Firebase 登录细节
- API endpoint 细节
- MethodChannel 调用

---

### `lib/app/bootstrap/`

应用启动和服务组装目录。

这是 Minimum Boundary+ 的关键目录。

职责：

- 初始化 Firebase 等启动依赖
- 组装生产环境服务实例
- 管理 `GenesisApi`、平台服务、auth/session 服务的构造
- 提供 app-wide services 给页面使用

推荐文件：

#### `app_bootstrap.dart`

职责：

- 从 `main.dart` 中承接启动逻辑
- 执行 `WidgetsFlutterBinding.ensureInitialized()` 后的初始化步骤
- 初始化 Firebase
- 检查 uid / guest bind
- 返回可传给 app 的服务对象

目标是让 `main.dart` 变薄：

```dart
Future<void> main() async {
  final services = await AppBootstrap.initialize();
  runApp(GenesisApp(services: services));
}
```

#### `service_registry.dart`

职责：

- 生产环境服务的唯一 composition root
- 构造：
  - `PlatformConfig`
  - `DeviceIdService`
  - `UserSessionStore`
  - `IdentityAuthService`
  - `BackendAuthCoordinator`
  - `GenesisApi`

规则：

- 页面和组件后续不应直接 `GenesisApi()`。
- 页面应通过 `AppServicesScope` 获取共享服务。
- 不引入新的第三方 DI 依赖，先使用 Flutter 原生 inherited scope 即可。

#### `app_services_scope.dart`

职责：

- 用 `InheritedWidget` / `InheritedNotifier` / 类似方式暴露 app services
- 让页面使用：

```dart
final api = AppServicesScope.of(context).api;
```

而不是：

```dart
final api = GenesisApi();
```

---

### `lib/app/config/`

应用配置目录。

职责：

- API base URL
- asset base URL
- 平台 header
- 环境变量 / dart-define 读取
- 平台能力开关

推荐文件：

#### `app_config.dart`

职责：

- 定义共享配置：
  - `apiBaseUrl`
  - `assetBaseUrl`
  - timeout
  - mock 开关

#### `platform_config.dart`

职责：

- 定义平台相关配置：

```dart
abstract interface class PlatformConfig {
  String get platformHeader;
  String get apiBaseUrl;
  String get assetBaseUrl;
}
```

注意：

- Android 默认保持 `x-platform: android`。
- iOS 是否发送 `x-platform: ios` 需要后端兼容验证。
- 不能因为目录重组就改变后端 API 合约。

---

## 5. `lib/components/` 目录职责

共享 UI 组件目录。

职责：

- 可复用 Widget
- 页面内共用 UI block
- 登录弹窗 UI
- logo、tab、header、list item 等展示组件

当前示例：

```text
components/bottom_tabs.dart
components/google_login_sheet.dart
components/page_header.dart
components/world_map.dart
components/me/profile_collection_list.dart
components/origin/*
```

规则：

- 组件可以接收 callback、view model、service interface。
- 组件不应直接 import `GoogleSignInService`、`UserSession`、`MethodChannel`。
- `google_login_sheet.dart` 后续应依赖 `IdentityAuthService` 或由外层传入登录 action，而不是直接调用 Google/Firebase 实现。

---

## 6. `lib/pages/` 目录职责

共享页面目录。

职责：

- Home / Search / Messages / Me / Create / Origin / World / Chat 等 Flutter 页面
- 页面布局
- 页面状态
- 页面级交互

当前目录：

```text
pages/app_shell_page.dart
pages/home/
pages/search/
pages/messages/
pages/me/
pages/create/
pages/origin/
pages/world/
pages/chat/
```

规则：

- 页面默认是 Android/iOS 共享的。
- 页面不应直接依赖平台实现。
- 页面不应直接调用 `MethodChannel`。
- 页面不应直接 import `firebase_auth` / `google_sign_in`。
- 页面中的 `GenesisApi()` 直接构造后续应迁移到 `AppServicesScope`。

典型改造方向：

- `AppShellPage`：认证流程改为调用 `BackendAuthCoordinator` 和 `IdentityAuthService`。
- `MePage`：不要直接读取 `FirebaseAuth.instance.currentUser`，改为 identity profile/service。
- `ChatPage`：不要直接读取 `UserSession` 或构造 `GenesisApi()`，改用 scoped services。
- `Home/Search/Messages/World/Origin/Create`：API 调用从 `GenesisApi()` 迁到 scope 注入。

---

## 7. `lib/routers/` 目录职责

共享路由目录。

职责：

- route name
- route 构造
- 页面跳转集中定义

规则：

- 路由本身不应包含平台判断。
- 如果某个页面需要服务，应通过页面参数或 `AppServicesScope` 获取，不在 router 中构造平台服务。

---

## 8. `lib/models/` 目录职责

应用层共享模型目录。

职责：

- UI view model
- 页面展示用模型
- 不直接对应后端 response 的轻量模型

与 `network/models/` 的区别：

- `lib/network/models/`：后端 API response/domain parsing 模型
- `lib/models/`：页面或 app 侧展示模型

---

## 9. `lib/network/` 目录职责

共享网络层目录。

职责：

- HTTP client
- API facade
- transport interface
- API exception
- JSON parsing
- response model
- mock transport / mock data

### `api_client.dart`

职责：

- 通用 HTTP 请求封装
- 处理 headers、query、body、response processor
- 不关心 Android/iOS

### `http_transport.dart`

职责：

- 定义 transport 抽象：

```dart
abstract class HttpTransport {
  Future<TransportResponse> send(TransportRequest request);
}
```

这是网络请求的底层 seam。

### `io_http_transport.dart`

职责：

- 使用 `dart:io` 的 `HttpClient`
- Android/iOS Flutter VM 都可使用

注意：

- 它不是 Android-only。
- 如果未来支持 Web，才需要额外 transport。

### `genesis_api.dart`

职责：

- Genesis 后端 API facade
- 负责 endpoint 调用、response parse、业务 API 方法

后续改造规则：

- 不直接 import `DeviceId`、`UserSession`、`GoogleSignInService`
- 通过接口注入：
  - `DeviceIdService`
  - `UserSessionStore`
  - `PlatformConfig`
  - auth/backend coordinator
- `x-platform` 来自 `PlatformConfig`
- 不改变 endpoint、字段、鉴权语义

### `json_utils.dart`

职责：

- JSON 安全读取
- 类型转换
- fallback helper

共享，无平台差异。

### `network/models/`

职责：

- API response model
- 后端数据结构模型

规则：

- 不能夹带 Android/iOS 判断。
- 字段命名应跟后端解析逻辑保持一致。

### `mock_data/` 和 `local_mock_genesis_transport.dart`

职责：

- 本地 mock 数据
- 测试或无后端环境下的 fake transport

共享，无平台差异。

---

## 10. `lib/platform/` 目录职责

平台能力边界目录。

这是 Android/iOS 差异的主要集中区。

职责：

- MethodChannel 常量
- 设备 ID 抽象和实现
- session/local uid 存储抽象和实现
- Google/Firebase identity auth adapter
- 平台服务聚合导出

规则：

- `MethodChannel` 只能出现在这里，不能散落到 pages/components/network。
- `Platform.isAndroid` / `Platform.isIOS` 应集中在这里或 `app/config/`。
- 页面只能依赖接口，不依赖具体 Android/iOS 实现。

---

### `platform/platform_services.dart`

职责：

- 聚合导出平台相关服务接口
- 可定义一个 app services 结构体：

```dart
class PlatformServices {
  const PlatformServices({
    required this.deviceId,
    required this.sessionStore,
    required this.identityAuth,
  });

  final DeviceIdService deviceId;
  final UserSessionStore sessionStore;
  final IdentityAuthService identityAuth;
}
```

---

### `platform/channels/`

MethodChannel 常量目录。

#### `genesis_method_channels.dart`

职责：

- 统一定义 channel name 和 method name

示例：

```dart
class GenesisMethodChannels {
  static const device = MethodChannel('com.worldo.ai/device');

  static const getAndroidId = 'getAndroidId';
  static const setUid = 'setUid';
  static const getUid = 'getUid';
  static const clearUid = 'clearUid';
  static const getSignInDiagnostics = 'getSignInDiagnostics';
}
```

好处：

- Dart 和 Android/iOS 原生方法名更容易对齐
- 避免字符串散落
- 方便未来 iOS `AppDelegate` 实现同一套 channel contract

---

### `platform/device/`

设备 ID 服务目录。

#### `device_id_service.dart`

职责：

```dart
abstract interface class DeviceIdService {
  Future<String> getDeviceId();
}
```

#### `method_channel_device_id_service.dart`

职责：

- Android 调用当前 `getAndroidId`
- iOS 未来调用 iOS 对应 method 或使用 app-scoped persistent id

规则：

- `GenesisApi.bindDevice()` 不再直接调用 `DeviceId.androidId()`。
- iOS 不应简单返回 `unknown`，至少应有明确 fallback 策略。

---

### `platform/session/`

用户会话 / uid 存储目录。

#### `user_session_store.dart`

职责：

```dart
abstract interface class UserSessionStore {
  Future<String?> readUid();
  Future<void> saveUid(String uid);
  Future<void> clearUid();
}
```

#### `method_channel_user_session_store.dart`

职责：

- 使用原生 MethodChannel 保存/读取 uid
- 对齐当前 Android `MainActivity.kt` 的 `setUid/getUid/clearUid`

#### `memory_user_session_store.dart`

职责：

- 测试或 fallback 用的内存实现
- 不作为正式持久化方案

备注：

- 现在项目已有 `shared_preferences`，如果后续确认够用，可以用 Dart 层 shared preferences 做跨平台持久化。
- 如果涉及安全凭证，再评估 Keychain/Keystore 或安全存储依赖。

---

### `platform/auth/`

身份认证目录。

这里需要拆清楚三件事：

1. Google/Firebase identity 登录
2. 后端 auth/session 绑定
3. 本地 uid/session 存储

#### `auth_session.dart`

职责：

- 定义登录后返回的共享 session DTO
- 承接当前 `GoogleFirebaseSession` 字段：
  - `googleIdToken`
  - `firebaseIdToken`
  - `firebaseUid`
  - `email`
  - `displayName`
  - `photoUrl`

#### `identity_auth_service.dart`

职责：

```dart
abstract interface class IdentityAuthService {
  bool hasLocalIdentitySession();
  Future<AuthSession> signInWithGoogle();
  Future<AuthSession?> refreshSilently();
  Future<void> signOutIdentity();
}
```

它只处理平台 identity（Google/Apple/Firebase），不直接处理后端业务登录。

#### `google_firebase_auth_service.dart`

职责：

- 包装当前 `GoogleSignInService`
- 保留现有 Google/Firebase 登录行为
- Android diagnostics 仍可保留，但应在实现内部，不暴露给 UI 页面

#### `backend_auth_coordinator.dart`

职责：

- 协调 identity auth 和后端 auth
- 调用 `GenesisApi.hasAuthenticatedSession()`
- 调用 `GenesisApi.loginWithIdentity(session)`，再由 HTTP 层走 `/api/v1/user/oauth/google` 或 `/api/v1/user/oauth/apple`
- 调用 `UserSessionStore.saveUid/clearUid`

页面只应调用 coordinator，不自己拼登录流程。

---

## 11. 当前重点文件归属表

| 当前文件 | 目标归属 | 说明 |
| --- | --- | --- |
| `lib/main.dart` | `main.dart` + `app/bootstrap/app_bootstrap.dart` | main 保持很薄，启动逻辑移入 bootstrap。 |
| `lib/app/genesis_app.dart` | `app/genesis_app.dart` | App 根组件，包住 service scope。 |
| `lib/pages/**` | 共享页面 | 保留目录，不做大规模 feature-first 重组。 |
| `lib/components/**` | 共享组件 | 保留目录，移除直接平台依赖。 |
| `lib/routers/app_router.dart` | 共享路由 | 保持平台无关。 |
| `lib/network/api_client.dart` | 共享网络 core | 保持平台无关。 |
| `lib/network/http_transport.dart` | 共享 transport 接口 | 保留。 |
| `lib/network/io_http_transport.dart` | 移动端 transport 实现 | Android/iOS Flutter VM 可共享。 |
| `lib/network/genesis_api.dart` | 共享 API facade | 注入 config/session/device/auth，不直接 import 平台实现。 |
| `lib/platform/device_id.dart` | 拆到 `platform/device/` | 抽象 `DeviceIdService` + MethodChannel 实现。 |
| `lib/platform/user_session.dart` | 拆到 `platform/session/` | 抽象 `UserSessionStore` + 实现。 |
| `lib/platform/google_sign_in_service.dart` | 拆到 `platform/auth/` | 包成 `IdentityAuthService` 实现。 |
| `android/.../MainActivity.kt` | Android native adapter | 保留 Android MethodChannel 实现。 |
| `ios/Runner/AppDelegate.swift` | iOS native adapter | 未来创建 iOS scaffold 后补。 |

---

## 12. 静态边界检查

完成后续实现后，以下检查应通过。

```bash
cd /Users/ionix/Works/GenesisApp/genesis_flutter_android

# pages/components 不应 import 具体 platform 服务
if grep -R "\.\./.*platform/\|\.\./\.\./.*platform/" -n lib/pages lib/components; then exit 1; fi

# shared UI 不应直接 import Firebase/Google SDK 或当前 concrete auth service
if grep -R "package:firebase_auth\|package:google_sign_in\|GoogleSignInService" -n lib/pages lib/components; then exit 1; fi

# MethodChannel 应集中在 lib/platform/**
if grep -R "MethodChannel" -n lib | grep -v "lib/platform/"; then exit 1; fi

# network/pages/components 中不应保留硬编码 Android 平台 header
if grep -R "'x-platform': 'android'\|\"x-platform\": \"android\"" -n lib/network lib/pages lib/components; then exit 1; fi

# 页面/组件不应继续直接构造 GenesisApi
if grep -R "GenesisApi()" -n lib/pages lib/components; then exit 1; fi
```

---

## 13. 构建和验证命令

当前 Android 验证：

```bash
cd /Users/ionix/Works/GenesisApp/genesis_flutter_android
flutter analyze
flutter test
flutter build apk --debug
```

未来 iOS 验证：

```bash
cd /Users/ionix/Works/GenesisApp/genesis_flutter_android
flutter build ios --debug --no-codesign
```

前提：

- `ios/` 已生成
- Xcode 可用
- CocoaPods 可用
- Firebase iOS 配置已补齐
- Google Sign-In plist / URL scheme 已配置

---

## 14. 执行顺序建议

虽然最初规划不要求详细迁移顺序，但真正实施时建议按下面低风险顺序：

1. 新增 `app/config/` 和 `platform/*` 接口，不改变现有调用。
2. 新增 `service_registry.dart` 和 `app_services_scope.dart`。
3. 用 adapter 包住现有 `DeviceId`、`UserSession`、`GoogleSignInService`。
4. 改造 `GenesisApi` 构造参数，注入 `PlatformConfig` / session / device 服务。
5. 改造 `main.dart` 和 `AppShellPage`。
6. 改造 API-heavy pages，移除直接 `GenesisApi()`。
7. 跑 analyze/test/build 和静态边界检查。
8. 最后再创建/补齐 `ios/` scaffold 和 iOS MethodChannel。

---

## 15. 总结

这个目录方案的核心不是“把文件移动得更漂亮”，而是建立清晰边界：

- `pages/` 和 `components/` 负责共享 UI
- `network/` 负责共享 API 和解析
- `platform/` 负责平台能力
- `app/bootstrap/` 负责服务组装
- `app/config/` 负责环境和平台配置
- `android/` / `ios/` 只负责原生平台实现

这样可以在不大规模重写页面的前提下，让项目逐步具备 Android/iOS 双端编译和维护能力。
