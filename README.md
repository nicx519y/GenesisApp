# GenesisApp 本地 Chatroom WebSocket 测试

本仓库包含一套本地 WebSocket mock 服务和 Flutter 测试页面，用于端到端验证 chatroom 协议。

## 1. 启动 mock WebSocket 服务

```sh
cd /Users/ionix/Works/GenesisApp/chatroom_ws_mock
npm install
npm start
```

默认服务地址：

```text
ws://localhost:8787/ws
```

健康检查：

```sh
curl http://localhost:8787/health
```

覆盖监听 host 或端口：

```sh
HOST=0.0.0.0 PORT=9090 npm start
```

## 2. 让 Flutter App 连接 mock 服务

App 通过 `GENESIS_CHATROOM_WS_URL` 读取 WebSocket 地址。

macOS / iOS 模拟器：

```sh
cd /Users/ionix/Works/GenesisApp/genesis_app
flutter run --dart-define=GENESIS_CHATROOM_WS_URL=ws://localhost:8787/ws
```

Android 模拟器：

```sh
cd /Users/ionix/Works/GenesisApp/genesis_app
flutter run --dart-define=GENESIS_CHATROOM_WS_URL=ws://10.0.2.2:8787/ws
```

同一局域网内的真机：

```sh
cd /Users/ionix/Works/GenesisApp/chatroom_ws_mock
HOST=0.0.0.0 npm start
```

然后使用 Mac 的局域网 IP 启动 Flutter：

```sh
cd /Users/ionix/Works/GenesisApp/genesis_app
flutter run --dart-define=GENESIS_CHATROOM_WS_URL=ws://<mac-lan-ip>:8787/ws
```

## 3. 打开 Flutter 测试页

App 内入口：

```text
Me -> Settings -> WebSocket test
```

该入口位于 Settings 页的 `About us` 下方。

## 4. 测试流程

1. 点击 `Connect`。
2. 客户端打开 WebSocket，并发送 `join`。
3. 服务端返回 `joined`。
4. 客户端在收到 `joined` 后自动开始发送心跳。
5. 输入消息并点击 `Send message`。
6. 服务端返回 `ack`。
7. 页面展示 `message_id`、`conversation_round_id`、`client_msg_id` 和 `queue_position`。
8. 服务端依次推送 `ai_stream_start`、多个 `ai_stream_chunk` 和 `ai_stream_end`。
9. 页面创建本地 stream 对象，并根据 stream chunk 渐进式渲染 AI 内容。
10. 点击 `Disconnect`，客户端发送 `leave`、关闭 socket，并停止心跳。

## 5. Mock 协议行为

Node 服务支持：

- `join` -> `joined`
- `send_message` -> `ack` -> `ai_stream_start` -> `ai_stream_chunk` x 3 -> `ai_stream_end`
- `heartbeat` -> 记录日志并静默接受
- `leave` -> 清理连接并关闭

服务端接受的连接格式：

```text
ws://localhost:8787/ws?world_instance_id=world_test&location_id=location_test
```

Flutter 客户端会根据测试页字段自动追加 `world_instance_id` 和 `location_id`。

## 6. 常用验证命令

```sh
cd /Users/ionix/Works/GenesisApp/chatroom_ws_mock
node --check src/server.js
```

```sh
cd /Users/ionix/Works/GenesisApp/genesis_app
dart analyze lib/app/config/app_config.dart lib/pages/me/chatroom_test_page.dart lib/pages/me/settings_page.dart test/widget_test.dart
flutter test test/widget_test.dart
```
