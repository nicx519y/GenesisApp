# Chatroom WebSocket 使用说明

## 1. 适用范围

本文说明 Flutter 端 `ChatroomClient` 的使用方式。协议字段和完整消息体定义见：

- `docs/chatroom-interface.md`
- `lib/network/chatroom/chatroom_client.dart`
- `lib/network/chatroom/chatroom_models.dart`
- `lib/network/chatroom/chatroom_socket_transport.dart`

当前模块是底层 WebSocket 能力，不直接替换 `ChatPage` 的 HTTP 轮询逻辑。页面接入时应通过 `AppServicesScope.read(context).chatroom` 获取服务。

## 2. 配置

WebSocket 公共配置位于 `AppConfig`：

```dart
const config = AppConfig(
  chatroomWsBaseUrl: 'ws://47.77.195.140:5002/ws',
  chatroomHeartbeatInterval: Duration(seconds: 30),
  chatroomAckTimeout: Duration(seconds: 12),
);
```

字段说明：

| 字段 | 说明 |
| --- | --- |
| `chatroomWsBaseUrl` | 聊天室 WebSocket 地址。连接时会自动追加 `world_instance_id` 和 `location_id` query 参数 |
| `chatroomHeartbeatInterval` | 收到 `joined` 后自动发送 `heartbeat` 的周期 |
| `chatroomAckTimeout` | `join` 等待 `joined`、`sendMessage` 等待 `ack` 的超时时间 |

默认值由 `ServiceRegistry.build()` 注入到 `AppServices.chatroom`。

## 3. 获取客户端

页面或业务对象内优先从 `AppServicesScope` 获取：

```dart
final chatroom = AppServicesScope.read(context).chatroom;
```

测试或非 Widget 代码中也可以直接构造：

```dart
final chatroom = ChatroomClient(
  wsBaseUrl: 'ws://localhost:8080/ws',
  sessionStore: sessionStore,
);
```

`ChatroomClient` 会优先使用传入的 `userId`；如果不传，会从 `UserSessionStore.readUid()` 读取当前 uid。

## 4. 建立连接

```dart
final session = await chatroom.connect(
  worldInstanceId: wid,
  locationId: locationId,
  senderId: 'player1',
  senderName: displayName,
);
```

连接行为：

1. 连接到 `chatroomWsBaseUrl`。
2. 自动拼接 query：`world_instance_id={wid}&location_id={locationId}`。
3. 建立 socket 后发送 `join`。
4. 等待服务端返回 `joined`。
5. `joined` 成功后启动自动心跳。

如果 `joined` 超时，会抛出 `ChatroomErrorEvent(code: 'join_timeout')` 并关闭 socket。

## 5. 监听通用事件

`session.events` 会广播所有已识别的服务端事件：

```dart
final eventSub = session.events.listen((event) {
  switch (event) {
    case ChatroomUserMessage message:
      // 展示其他用户或自己的广播消息
      break;
    case ChatroomQueuePosition queue:
      // 更新排队状态
      break;
    case ChatroomAck ack:
      // 通常 sendMessage 的 Future 已处理 ack，这里可用于日志或全局状态
      break;
    default:
      break;
  }
});
```

常见事件类型：

| 类型 | 说明 |
| --- | --- |
| `ChatroomJoined` | 加入成功 |
| `ChatroomAck` | 用户消息已被服务端接收 |
| `ChatroomUserMessage` | 用户消息广播 |
| `ChatroomAiStreamStart` | AI 回复开始 |
| `ChatroomAiStreamChunk` | AI 回复内容块 |
| `ChatroomAiStreamEnd` | AI 回复结束 |
| `ChatroomQueuePosition` | 排队位置 |
| `ChatroomErrorEvent` | 服务端或本地错误 |

## 6. 发送消息并等待 ack

`sendMessage()` 已封装 `client_msg_id -> ack` 的匹配关系，调用方按 Future 使用即可：

```dart
try {
  final ack = await session.sendMessage('hello');
  debugPrint('message_id=${ack.messageId}');
  debugPrint('round=${ack.conversationRoundId}');
  debugPrint('queue=${ack.queuePosition}');
} on ChatroomErrorEvent catch (error) {
  // 例如 ack_timeout、socket_closed、服务端 error 等
  debugPrint('send failed: ${error.code} ${error.message}');
}
```

可选传入自定义 `clientMsgId`，便于 UI 本地占位消息对齐：

```dart
final ack = await session.sendMessage(
  text,
  clientMsgId: localMessageId,
);
```

处理规则：

- 收到相同 `client_msg_id` 的 `ack` 后，Future 成功完成。
- 超过 `chatroomAckTimeout` 未收到 `ack`，Future 失败，错误码为 `ack_timeout`。
- socket 关闭或 session 主动关闭时，所有未完成的 ack Future 都会失败。

## 7. 监听 AI Stream 生命周期

每次收到 `ai_stream_start`，模块会创建一个 `ChatroomAiMessageStream` 对象并推送到 `session.streams`：

```dart
final streamSub = session.streams.listen((aiStream) {
  final start = aiStream.start;

  final chunkSub = aiStream.chunks.listen((chunk) {
    final currentText = aiStream.content;
    // 用 currentText 或 chunk.chunk 更新 UI
  });

  aiStream.done
      .then((end) {
        // 单条 AI 回复完成
        final finalText = aiStream.content;
        debugPrint('AI message ${end.messageId} done: $finalText');
      })
      .catchError((error) {
        // ai_error 或 socket/session 关闭会使该 stream 失败
        debugPrint('AI stream failed: $error');
      })
      .whenComplete(() => chunkSub.cancel());
});
```

`ChatroomAiMessageStream` 关键字段：

| 字段/方法 | 说明 |
| --- | --- |
| `start` | `ChatroomAiStreamStart`，包含 `messageId`、`conversationRoundId`、`senderId` 等 |
| `chunks` | 内容块流 |
| `content` | 当前累计文本 |
| `done` | 单条 AI 回复完成或失败的 Future |
| `isCompleted` | 是否已经完成 |

如果需要按 `message_id` 查询当前活跃 stream：

```dart
final aiStream = session.streamForMessage(messageId);
```

## 8. 通用错误监听

建议每个连接都注册 `errors`：

```dart
final errorSub = session.errors.listen((error) {
  switch (error.code) {
    case 'invalid_token':
      // 重新登录或提示登录过期
      break;
    case 'ack_timeout':
      // 标记本地消息发送超时
      break;
    case 'socket_closed':
      // 触发重连或回退到历史消息同步
      break;
    default:
      // 展示通用错误或记录日志
      break;
  }
});
```

错误来源包括：

- 服务端 `error`
- 服务端 `ai_error`
- 本地 JSON 解析失败，错误码 `protocol_error`
- socket 异常，错误码 `socket_error`
- socket 关闭，错误码 `socket_closed`
- ack 超时，错误码 `ack_timeout`
- join 超时，错误码 `join_timeout`

## 9. 关闭连接

页面销毁或离开聊天室时关闭 session：

```dart
await session.close();
await eventSub.cancel();
await streamSub.cancel();
await errorSub.cancel();
```

关闭行为：

1. 尝试发送 `leave`。
2. 停止 heartbeat。
3. 让所有 pending ack Future 失败。
4. 让所有活跃 AI stream 失败。
5. 关闭 socket 和内部 stream controller。

## 10. 页面接入建议

推荐的页面生命周期：

1. `initState` 或进入聊天室后调用 `connect()`。
2. 连接成功后注册 `events`、`errors`、`streams`。
3. 发送消息时先创建本地占位消息，然后调用 `sendMessage()`。
4. `ack` 返回后，用服务端 `messageId` 和 `conversationRoundId` 更新本地占位消息。
5. 收到 `ChatroomUserMessage` 时按 `messageId` 合并或补齐消息。
6. 收到 `ChatroomAiMessageStream` 时创建 AI 消息占位，并用 `chunks/content/done` 更新。
7. `dispose` 时关闭 session 并取消所有 subscription。

消息展示应按 `messageId` 排序，不依赖 WebSocket 推送顺序。

## 11. 测试写法

底层 socket 已抽象为 `ChatroomSocketTransport`，测试可使用 fake transport：

```dart
final socket = FakeChatroomSocket();
final client = ChatroomClient(
  wsBaseUrl: 'ws://localhost:8080/ws',
  sessionStore: sessionStore,
  transport: FakeChatroomTransport(socket),
);
```

已有测试覆盖：

- 建连时 URL query 和 `join` payload
- `sendMessage()` 等待匹配 `ack`
- ack timeout
- AI stream start/chunk/end 生命周期
- 通用 error stream
- joined 后自动 heartbeat，close 后停止

参考：

- `test/network/chatroom/chatroom_client_test.dart`
