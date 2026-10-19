# GenesisApp / Worldo

Worldo 的 Flutter 客户端，主要面向 Android 和 iOS。用户可以浏览和创建世界模板（代码中称为 Origin）、选择角色启动 World、在地图地点中参与聊天，并通过世界内的 MiniPhone 使用私聊、动态、相册和音乐等功能。

Flutter 工程位于 **`genesis_app/`**。以下说明以当前仓库源码和构建配置为准；模块列举表示客户端已包含相应实现，不代表所有真实后端、商店支付和设备流程都已验收。

## 快速运行

### 1. 准备环境

| 项目 | 要求 |
| --- | --- |
| Flutter / Dart | 当前 `pubspec.lock` 要求 **Flutter ≥ 3.44.0、Dart ≥ 3.12.0 且 < 4.0.0**。`pubspec.yaml` 的 Dart 声明为 `^3.9.0`，仅满足该声明不足以使用当前锁定依赖 |
| Android | Android SDK、JDK 17、已启动的模拟器或开启 USB 调试的设备；最低 Android API 24 |
| iOS | macOS、Xcode、CocoaPods；工程部署目标为 iOS 15.0，真机运行需要可用的开发团队和签名配置 |

Android 的 Debug 和 Release 都使用项目自定义签名。运行前确认 `genesis_app/android/key.properties` 及其 `storeFile` 指向的 keystore 可用；当前配置不会自动回退到默认 debug keystore。Google / Apple 登录、Firebase 和商店购买还依赖对应包名的原生配置与服务端配置。

### 2. 安装依赖并启动

从仓库根目录执行：

```sh
cd genesis_app
flutter --version
flutter doctor -v
flutter pub get
flutter devices
flutter run --debug --flavor production -d <device-id>
```

将 `<device-id>` 替换为 `flutter devices` 列出的 Android 或 iOS 设备 ID。后文 Flutter 命令均在 `genesis_app/` 内执行。

`pubspec.yaml` 已设置 `default-flavor: production`，只有一个目标设备时也可直接运行 `flutter run`。依赖中包含 `third_party/` 下的本地覆盖包，需要保留完整工程目录。

iOS 如需手动安装原生依赖，在 `flutter pub get` 后执行：

```sh
cd ios
pod install
open Runner.xcworkspace
cd ..
```

在 Xcode 中使用 `production` 或 `internal` scheme，配置签名后再通过 Xcode 或 `flutter run` 启动。

### 3. 选择包类型与服务环境

包类型（flavor）和服务环境是两个独立维度：

| Flavor | 应用标识 | 差异 |
| --- | --- | --- |
| `production`（默认） | `com.worldo.ai` | 主应用包，支持 Apple 登录 |
| `internal` | `com.worldo.ai.internal` | 可与主应用并存的内部包；客户端关闭 Apple 登录 |

```sh
# 内部包调试
flutter run --debug --flavor internal -d <device-id>

# 主应用包 Release 运行
flutter run --release --flavor production -d <device-id>
```

**未保存开发者地址覆盖时，默认服务由构建模式决定，而非 flavor：**

| 服务 | Debug / Profile | Release |
| --- | --- | --- |
| 业务 HTTP | `https://dev.hushie.ai/api/` | `https://api.worldo.ai/api/` |
| Gateway | `https://dev.hushie.ai/apix/` | `https://api.worldo.ai/apix/` |
| Chatroom / MiniPhone HTTP | `https://dev.hushie.ai/` | `https://api.worldo.ai/` |
| World WebSocket | `wss://dev.hushie.ai/aitown-chat/ws` | `wss://api.worldo.ai/aitown-chat/ws` |

因此，`flutter run --flavor production` 默认仍是连接 dev 服务的 Debug 包。`GENESIS_API_ENV` 默认值 `real` 表示使用真实 HTTP，而不是强制连接生产域名。

### 4. 常用调试参数

```sh
# 使用客户端内置的本地 HTTP mock（Debug / Profile 可用）
flutter run --debug --flavor production -d <device-id> \
  --dart-define=GENESIS_API_ENV=mock

# 输出 WebSocket frame 日志
flutter run --debug --flavor production -d <device-id> \
  --dart-define=GENESIS_DEBUG_WS_LOG=true
```

| 参数 | 作用 |
| --- | --- |
| `GENESIS_API_ENV=real` | 使用真实 HTTP；`prod` / `production` 是同义值，不负责切换域名 |
| `GENESIS_API_ENV=mock` | 使用内置 `LocalMockGenesisTransport`；`local` / `debug` 是同义值 |
| `GENESIS_CHATROOM_WS_URL=<url>` | 覆盖 World WebSocket 地址 |
| `GENESIS_CHATROOM_HTTP_URL=<url>` | 覆盖 Chatroom / MiniPhone HTTP base |
| `GENESIS_DEBUG_WS_LOG=true` | 开启 WebSocket frame 日志 |
| `GENESIS_DEBUG_PROXY=<host>:<port>` | 设置 HTTP / WebSocket 调试代理 |

Release 不包含本地 HTTP mock 实现，传入 `GENESIS_API_ENV=mock` 仍会使用真实服务。HTTP mock 也不等于完整的离线世界或 WebSocket 服务；当前仓库没有旧文档中的 `chatroom_ws_mock/` 目录。

Debug 默认显示开发浮钮，点击可打开 Developer 面板，配置 API、Gateway、WebSocket 域名及查看网络诊断。若浮钮已隐藏，可进入 **Me → Settings**，连续点击页面标题 10 次重新显示。面板保存的地址会持久化，并优先于默认值及对应启动参数；发现实际连接地址不符合预期时，先检查这里的覆盖配置。地址输入使用域名，应用会补齐服务路径。

代理辅助脚本在**仓库根目录**运行，会自动获取本机局域网 IP；默认代理端口为 `9090`：

```sh
scripts/flutter_run_debug_proxy.sh -d <device-id> --proxy-port 9090
```

需要先启动代理软件，并确保设备可访问该地址。也可通过 `GENESIS_PROXY_HOST` 指定代理主机。

## 主要功能模块

主导航是 **Home / Worldo / Create / Inbox / Me**，其中 Create 显示为创建图标。World 是启动后的世界实例；Worldo 模板在代码目录和接口中仍沿用 `Origin` 名称。

| 模块 | 主要功能 | 代码入口（相对 `genesis_app/lib/`） |
| --- | --- | --- |
| Home | 首页内容流、我的 World 入口和世界卡片 | `pages/home/` |
| Worldo / Origin | 模板列表、详情预览、角色和地点展示、选择角色 Launch 世界 | `pages/origin/` |
| Create / Edit | 创建和编辑模板的基础信息、角色、地点、开场和故事事件；草稿与图片上传 | `pages/create/`、`pages/edit/`、`pages/origin_editor/` |
| World 与地图 | 世界详情、角色和地点、Tilemap 地图、世界时间推进（Tick）、事件与回顾 | `pages/world/`、`components/tilemap/` |
| LocationChat | 地点聊天室、多地点面板切换、实时消息、历史缓存、消息编辑及 Tick 交互 | `pages/chat/`、`components/chat/`、`network/chatroom/` |
| MiniPhone | 世界内手机桌面、角色私聊、Posts 动态与评论、通知、相册、音乐播放与点赞、壁纸设置 | `pages/mini_phone/`、`network/mini_phone/` |
| Discuss | Worldo 讨论列表、发帖、帖子详情和回复 | `pages/discuss/`、`components/discuss/` |
| Inbox / 用户私信 | 消息中心、通知分类、用户私信、未读与已读管理、本地消息缓存 | `pages/messages/`、`pages/chat/` |
| Search | Worldo、World 和用户搜索，以及搜索历史 | `pages/search/` |
| Me / 账号与设置 | 用户资料、关注与粉丝、收藏、Google / Apple 登录、访客身份、新用户偏好、语言和账号设置 | `pages/me/`、`platform/`、`components/onboarding/` |
| Gems / Premium | Gems 钱包与记录、签到及任务奖励、订阅和商店购买、模型与记忆设置 | `pages/gems/`、`app/gems/`、`app/membership/` |
| 基础能力 | HTTP / Gateway 签名、世界级 WebSocket、图片处理与上传、SQLite 缓存、多语言、Firebase 遥测与 Adjust 归因 | `network/`、`app/`、`l10n/`、`ui/` |

MiniPhone 复用所属 World 的连接与会话，关闭手机仍保留世界会话，退出 World 时释放。其模型选择与记忆长度目前是会话内设置，不能据此认定已保存为后端设置或影响实际计费。具体接口和联调边界见 [MiniPhone 集成文档](genesis_app/docs/mini-phone-client-integration.md)。

## 仓库结构

```text
.
├── README.md                   # 项目概览与运行入口
├── genesis_app/                # Flutter 主工程
│   ├── lib/
│   │   ├── main.dart           # 应用入口
│   │   ├── app/                # 启动、配置、依赖装配与全局服务
│   │   ├── routers/            # 路由
│   │   ├── pages/              # 页面与业务模块
│   │   ├── components/         # 共享业务组件、地图与聊天 UI
│   │   ├── network/            # API、WebSocket、模型与缓存
│   │   ├── platform/           # 原生能力与身份认证
│   │   ├── l10n/               # 多语言资源
│   │   ├── ui/                 # 主题、基础控件与动画
│   │   └── utils/              # 通用工具
│   ├── assets/                 # 图片、图标和字体
│   ├── android/、ios/          # 移动端原生工程
│   ├── third_party/            # 本地依赖覆盖
│   ├── tool/                   # 多语言等维护工具
│   ├── test/                   # 单元与 Widget 测试
│   └── docs/                   # 接口、设计、维护与联调文档
├── scripts/                    # 代理、抓包等辅助脚本
├── tools/                      # Agent CLI、聊天调试面板等工具
└── agent_workflow/             # 工作流、用例及验证脚本
```

## 构建与验证

在 `genesis_app/` 下执行：

```sh
# Android Debug APK
flutter build apk --debug --flavor production

# Android Release APK：仅 ARM64，保持原始 versionCode
flutter build apk --release --flavor production --target-platform android-arm64

# Google Play App Bundle
flutter build appbundle --release --flavor production

# iOS Debug 编译检查（不签名，不能直接安装到真机）
flutter build ios --debug --flavor production --no-codesign
```

APK 输出位于 `build/app/outputs/flutter-apk/`，AAB 输出位于 `build/app/outputs/bundle/productionRelease/`。Android production release APK **不要加 `--split-per-abi`**，以免改变 `versionCode`。iOS 分发还需要在 Xcode 中完成签名、Archive 和导出。

按改动范围选择检查，不必每次执行所有测试：

```sh
flutter analyze
flutter test test/network/genesis_api_test.dart
flutter test test/network/chatroom/chatroom_client_test.dart
flutter test test/network/mini_phone test/pages/mini_phone
```

修改多语言资源时运行 `./tool/l10n/check`。纯文档修改检查链接与 `git diff --check` 即可。更多验证入口见 [工程维护参考](genesis_app/docs/project-maintenance-reference.md#verification)。

## 开发文档

- [工程维护指引](genesis_app/AGENTS.md)：目录职责、改动边界和专项规则入口。
- [HTTP API 契约](genesis_app/docs/apifox-http-api-contract.md) / [Gateway 鉴权](genesis_app/docs/gateway-auth.md)。
- [Chatroom WebSocket 契约](genesis_app/docs/chatroom-websocket-api.md)。
- [MiniPhone 模块结构](genesis_app/lib/pages/mini_phone/README.md) / [手机接口契约](genesis_app/docs/mini-phone-chat-client-api-2026-10-12.md)。
- [Gems 客户端契约](genesis_app/docs/gem-cent-app-contract.md)。
- [UI 组件库](genesis_app/docs/ui-component-library.md) / [多语言维护](genesis_app/docs/l10n/README.md)。
- [自动化工作流](agent_workflow/README.md) / [LocationChat 调试面板](tools/location_chat_debug_dashboard/README.md)。
