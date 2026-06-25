# GenesisApp

GenesisApp 是一个 Flutter 客户端项目，外层仓库同时包含 Flutter App、本地 chatroom WebSocket mock 服务和少量运行脚本。主要业务包括 Home/Origin/World/Discuss/Messages/Me 五个主 Tab，Origin 创建与编辑，World 地图与地点聊天室，私信、通知、搜索、登录和图片上传。

## 仓库结构

```text
/Users/ionix/Works/GenesisApp/
├── README.md                 # 本说明
├── AUTH_LOGIN_STATE.md       # 登录状态与认证调试记录
├── scripts/                  # 外层运行脚本
├── chatroom_ws_mock/         # 本地 WebSocket mock 服务
├── agent_workflow/           # agent/流程相关报告与辅助内容
└── genesis_app/              # Flutter App 主工程
```

### 外层目录

- `genesis_app/`：真正的 Flutter 项目。运行、测试、构建 App 时都先进入这个目录。
- `chatroom_ws_mock/`：Node.js WebSocket mock，供 chatroom 本地联调使用。
- `scripts/flutter_run_debug_proxy.sh`：真机调试代理脚本，会自动解析本机局域网 IP 并注入 `GENESIS_DEBUG_PROXY`。
- `.vscode/`：工作区级 VS Code 启动配置。
- `.omx/`、`agent_workflow/`：自动化/agent 工作流状态和报告，不属于 App 业务代码。

## Flutter 工程结构

```text
genesis_app/
├── lib/
│   ├── main.dart                     # Flutter 入口，初始化服务后 runApp
│   ├── app/                          # App 装配、配置、依赖注入
│   ├── routers/                      # 路由名和参数解析
│   ├── pages/                        # 页面级业务入口
│   ├── components/                   # 跨页面 UI 组件
│   ├── network/                      # HTTP、WebSocket、mock、缓存和 API 模型
│   ├── platform/                     # 登录、设备 ID、原生图片选择等平台能力
│   ├── utils/                        # 图片、时间、数字、显示名等工具
│   ├── ui/                           # 主题和基础 UI token
│   ├── icons/                        # 自定义图标 Dart 封装
│   └── models/                       # 旧/共享业务模型
├── assets/                           # 图片、svg、自定义图标字体
├── docs/                             # 接口、组件、跨端结构等项目文档
├── test/                             # widget/component/network/utils 测试
├── android/                          # Android 平台工程
├── ios/                              # iOS 平台工程
├── third_party/                      # 本地依赖覆盖，如 firebase_auth
├── pubspec.yaml                      # Flutter 依赖和资源声明
└── analysis_options.yaml             # Dart analyzer 规则
```

## World 多 Location Chat VM Panel

`genesis_app/lib/pages/world/world_page.dart` 的地点聊天不是普通 route push，而是在 World 详情页内部用 `WorldDetailsPageScaffold.topOverlay` 叠加的多 location chat VM panel。实现目标是：用户点击地图上不同 location 时，聊天面板可以像当前 World 页的一部分一样快速打开、切换、关闭，同时复用同一个世界级 WebSocket 连接和同一套 `LocationChatPanel` / shared chat UI。

核心状态：

- `_locationChatDescriptors`：保存每个 location 的 panel 描述，包括 `locationId`、展示名、是否 leaf location，以及用于本地消息匹配的 `localMessageLocationIds` aliases。
- `_cachedLocationChatIds`：记录已经创建过 widget 的 location panel。已缓存 panel 在切换时保留在 overlay stack 中，避免重复构建造成闪屏。
- `_readyLocationChatIds`：记录初始内容已经 ready 的 panel。未 ready 时先显示 `_LocationChatPanelSkeleton`，ready 后再把真实 panel opacity 切到 1。
- `_activeChatLocationId`：当前可见、可交互的 location。非 active panel 通过 `IgnorePointer`、`ExcludeSemantics`、`Opacity(0)` 和 `TickerMode(false)` 保留 VM/widget 状态，但不接收交互、不暴露语义、不跑动画。

打开目标：

- `_openChatForPoint` 只负责把 `WorldPoint` 转成 `_LocationChatPanelDescriptor`，并立即进入 `_showCachedLocationChat`。
- `updateUserPosition(wid, locationId)` 是机会性副作用，必须 `unawaited`，不能阻塞 panel 打开。
- `_showCachedLocationChat` 先切换 active id、安排当前 panel 进入 overlay，再异步 `_hydrateActiveLocationChatMessages` 从本地缓存补消息。
- 首次打开未缓存 panel 时，先让 skeleton 过一帧，再把该 location 加入 `_cachedLocationChatIds`，等 `LocationChatPanel.onInitialContentReady` 回调后标记 ready。

连接和 join 目标：

- `WorldPage` 只在 `relation_status` 是 `owner` 或 `joined` 时启动长期 `WorldChatroomService`；`approved` 仍是 Launch 流，不直接连 WebSocket。
- 多 location panel 共用一个 `WorldChatroomService`，不要为每个 panel 新建 WebSocket。
- 只有 leaf location 可以触发 `join` / `leave`。非 leaf location 可以打开或下钻展示，但不产生聊天室 join 副作用。
- 关闭或切换 panel 时，`_leaveCachedLocationChat` 只在当前 joined location 是 leaf 且匹配时发送 leave；失败不阻塞 UI。

消息匹配目标：

- `localMessageLocationIds` 用来兼容 point id、scene/location id、node id 等多个来源，让本地缓存消息能归并到当前 location panel。
- `hydrateLocalMessages` 是本地缓存恢复入口；远端最新消息刷新和 WebSocket 实时事件由 `WorldChatroomService` 继续维护。
- skeleton 的视觉结构要跟真实 `LocationChatPanel` 的 shared chat UI 保持一致，避免加载态和 ready 态跳变。

这个设计的优先级是打开速度和状态连续性：地图点击后先出现 panel/skeleton，再补位置上报、缓存 hydrate 和 WebSocket join 等异步结果。后续改动不要把网络请求重新放回点击打开的同步路径里。

## 运行方式

先确认本机已有 Flutter SDK，并在 App 工程目录执行命令：

```sh
cd /Users/ionix/Works/GenesisApp/genesis_app
flutter pub get
flutter run
```

默认会连接真实 dev 服务：

- HTTP API：`https://dev.hushie.ai/api/`
- Chatroom WebSocket：`wss://dev.hushie.ai/aitown-chat/ws`
- Chatroom HTTP：`https://dev.hushie.ai/`

使用本地 mock HTTP 数据：

```sh
cd /Users/ionix/Works/GenesisApp/genesis_app
flutter run --dart-define=GENESIS_API_ENV=mock
```

启用 WebSocket frame 日志：

```sh
flutter run --dart-define=GENESIS_DEBUG_WS_LOG=true
```

覆盖 chatroom WebSocket 地址：

```sh
flutter run --dart-define=GENESIS_CHATROOM_WS_URL=ws://localhost:8787/ws
```

Android 模拟器访问宿主机 WebSocket mock 时使用：

```sh
flutter run --dart-define=GENESIS_CHATROOM_WS_URL=ws://10.0.2.2:8787/ws
```

## 本地 WebSocket mock

启动 mock 服务：

```sh
cd /Users/ionix/Works/GenesisApp/chatroom_ws_mock
npm install
npm start
```

默认地址：

```text
ws://localhost:8787/ws
```

健康检查：

```sh
curl http://localhost:8787/health
```

指定监听地址或端口：

```sh
HOST=0.0.0.0 PORT=9090 npm start
```

当前 App 内没有单独的 WebSocket test 页面入口；设置页的开发入口是：

```text
Me -> Settings -> Developer page
```

WebSocket 联调通过 World/Location Chat 业务流、`chatroom_ws_mock/` 服务和 `test/network/chatroom/` 下的 focused tests 验证。

## 真机代理调试

从外层仓库运行：

```sh
cd /Users/ionix/Works/GenesisApp
scripts/flutter_run_debug_proxy.sh
```

默认设备是脚本中的 `DEFAULT_DEVICE_ID`，默认代理端口是 `9090`。可覆盖：

```sh
GENESIS_DEVICE_ID=<device-id> GENESIS_PROXY_PORT=9090 scripts/flutter_run_debug_proxy.sh
```

或：

```sh
scripts/flutter_run_debug_proxy.sh -d <device-id> --proxy-port 9090
```

## 常用验证命令

在 `genesis_app/` 下执行：

```sh
dart format .
flutter analyze
flutter test
```

针对常见接口/业务改动的 focused 测试：

```sh
flutter test test/network/genesis_api_test.dart
flutter test test/network/local_mock_genesis_transport_test.dart
flutter test test/network/chatroom/chatroom_client_test.dart
flutter test test/network/chatroom/world_chatroom_service_test.dart
flutter test test/components/discuss_page_test.dart
flutter test test/components/origin_discuss_list_test.dart
flutter test test/ui/genesis_avatar_test.dart
flutter test test/ui/genesis_list_image_test.dart
```

本地 WebSocket mock 语法检查：

```sh
cd /Users/ionix/Works/GenesisApp/chatroom_ws_mock
node --check src/server.js
```

## 构建

Android debug：

```sh
cd /Users/ionix/Works/GenesisApp/genesis_app
flutter build apk --debug
```

Android release 分 ABI：

```sh
cd /Users/ionix/Works/GenesisApp/genesis_app
flutter build apk --release --split-per-abi
```

常见输出目录：

```text
genesis_app/build/app/outputs/flutter-apk/
```

iOS debug 无签名构建：

```sh
cd /Users/ionix/Works/GenesisApp/genesis_app
flutter build ios --debug --no-codesign
```

## 关键文档

- HTTP API 契约：`genesis_app/docs/apifox-http-api-contract.md`
- Chatroom WebSocket 契约：`genesis_app/docs/chatroom-websocket-api.md`
- UI 组件索引：`genesis_app/docs/ui-component-library.md`
- 跨平台目录组织：`genesis_app/docs/cross_platform_directory_organization.md`
- 真机 API 联调记录：`genesis_app/docs/real-device-api-integration-report-2026-05-29.md`

改接口时优先同步 `docs/`、`lib/network/`、`lib/network/local_mock_genesis_transport.dart` 和对应 focused tests。
