# Chatroom WebSocket API

本文档对齐 `/Users/ionix/Desktop/aitown-chat-ws.yaml`，描述 AITown 聊天室 WebSocket 协议，以及 Flutter 侧当前实现需要遵守的字段契约。

## 1. 概览

| 项 | 值 |
| --- | --- |
| OpenAPI | `3.0.3` |
| 标题 | `AITown Chat WebSocket API` |
| 版本 | `1.0.0` |
| 本地服务 | `ws://localhost:8082/aitown-chat/ws` |
| Flutter WS 配置 | `GENESIS_CHATROOM_WS_URL` |
| Flutter 默认 WS | `ws://dev.hushie.ai/aitown-chat/ws` |

WebSocket 建联时自动创建 Session。同一用户建立新连接时，服务端会踢掉该用户的旧连接。

Flutter 侧 WebSocket 域名使用独立配置 `GENESIS_CHATROOM_WS_URL`，不复用 chatroom HTTP 接口的 `GENESIS_CHATROOM_HTTP_URL`。

## 2. 建联接口

```text
GET ws://{host}:{port}/aitown-chat/ws?world_id={world_id}
```

示例：

```text
ws://localhost:8082/aitown-chat/ws?world_id=world_123
```

请求头：

| 参数 | 必填 | 示例 | 说明 |
| --- | --- | --- | --- |
| `Authorization` | 是 | `Bearer user_token_001` | 用户认证 token |

查询参数：

| 参数 | 类型 | 必填 | 示例 | 说明 |
| --- | --- | --- | --- | --- |
| `world_id` | `string` | 是 | `world_123` | 世界实例 ID |

成功响应：

| 状态码 | 说明 |
| --- | --- |
| `101` | `Switching Protocols`，WebSocket 连接成功 |

## 3. 连接生命周期

1. 客户端连接 `/aitown-chat/ws`，query 中传入 `world_id`，header 中传入 `Authorization`。
2. 建联成功后服务端创建 Session，并踢掉该用户的旧连接。
3. 客户端发送 `join` 进入指定地点聊天室。
4. 服务端返回 `joined`，并广播 `world_notification`，`event_type=user_join`。
5. 客户端发送 `send_message`。
6. 服务端返回 `ack`，随后广播 `user_message`。
7. AI 处理完成后，服务端广播 `character_message` 或 `narrator_message`，也可能发送 AI 流式消息。
8. 客户端发送 `leave` 离开聊天室，服务端返回 `leaved`，并广播 `world_notification`，`event_type=user_leave`。
9. 客户端按固定间隔发送 `heartbeat` 维持连接。Flutter 默认间隔为 2 秒。
10. 连接断开后，服务端广播 `world_notification`，`event_type=user_leave`。

## 4. 通用消息结构

所有 WebSocket 消息使用 JSON envelope：

```json
{
  "type": "message_type",
  "ts": 1748352000000,
  "payload": {}
}
```

顶层字段：

| 字段 | 类型 | 必填 | 说明 |
| --- | --- | --- | --- |
| `type` | `string` | 是 | 消息类型 |
| `ts` | `integer(int64)` | 否 | 时间戳，毫秒 |
| `payload` | `object` | 否 | 常规消息载荷 |
| `world_payload` | `object` | 否 | `world_notification` 专用载荷 |
| `broadcast` | `boolean` | 否 | 是否为广播消息 |
| `my_session_id` | `string` | 否 | 当前客户端会话 ID，服务端心跳响应可能携带 |

## 5. 客户端上行消息

### 5.1 `join`

进入指定地点聊天室。

Payload 字段：

| 字段 | 类型 | 必填 | 说明 |
| --- | --- | --- | --- |
| `location_id` | `string` | 是 | 地点 ID |

示例：

```json
{
  "type": "join",
  "ts": 1748352000000,
  "payload": {
    "location_id": "location_001"
  }
}
```

### 5.2 `send_message`

发送聊天消息到当前聊天室。

Payload 字段：

| 字段 | 类型 | 必填 | 说明 |
| --- | --- | --- | --- |
| `text` | `string` | 是 | 消息内容 |
| `client_uuid` | `string` | 否 | 客户端消息 UUID，用于幂等去重和本地 pending 消息对齐 |

示例：

```json
{
  "type": "send_message",
  "ts": 1748352000000,
  "payload": {
    "text": "你好，今天天气怎么样？",
    "client_uuid": "client_uuid_001"
  }
}
```

### 5.3 `heartbeat`

心跳消息。客户端发送空 payload。

```json
{
  "type": "heartbeat",
  "ts": 1748352000000,
  "payload": {}
}
```

### 5.4 `leave`

离开当前聊天室，但保持 WebSocket 连接。

```json
{
  "type": "leave",
  "ts": 1748352000000,
  "payload": {}
}
```

## 6. 服务端下行消息

### 6.1 连接控制

`joined`、`leaved`、`kicked` 共用 `WSPayload`。

`WSPayload` 字段：

| 字段 | 类型 | 说明 |
| --- | --- | --- |
| `ts` | `integer(int64)` | 消息时间戳，毫秒 |
| `world_id` | `string` | 世界实例 ID |
| `location_id` | `string` | 聊天室地点 ID |
| `session_id` | `string` | 会话 ID |
| `user_id` | `string` | 用户 ID |
| `code` | `integer` | 状态码，`0` 表示成功 |
| `code_msg` | `string` | 状态或错误描述 |

`joined` 示例：

```json
{
  "type": "joined",
  "ts": 1748352000000,
  "payload": {
    "ts": 1748352000000,
    "world_id": "world_123",
    "location_id": "location_001",
    "session_id": "session_abc123",
    "user_id": "user_001",
    "code": 0,
    "code_msg": "ok"
  }
}
```

`leaved` 表示服务端确认用户已离开聊天室。

`kicked` 表示用户在新设备登录，当前连接被踢下线。示例 `code=1001`、`code_msg=new_connection`。

`disconnected` 表示 WebSocket 连接已断开：

```json
{
  "type": "disconnected",
  "payload": {}
}
```

### 6.2 `ack`

服务端确认收到用户消息。

Payload 字段：

| 字段 | 类型 | 说明 |
| --- | --- | --- |
| `message_id` | `integer(int64)` | 服务端消息 ID |
| `conversation_round_id` | `integer(int64)` | 对话轮次 ID |
| `client_uuid` | `string` | 客户端消息 UUID；服务端可能不回传，客户端需按 pending 顺序兜底 |

示例：

```json
{
  "type": "ack",
  "ts": 1748352000000,
  "payload": {
    "ts": 1748352000000,
    "world_id": "world_123",
    "location_id": "location_001",
    "session_id": "session_abc123",
    "user_id": "user_001",
    "code": 0,
    "code_msg": "ok",
    "message_id": 1001,
    "conversation_round_id": 201
  }
}
```

### 6.3 `error`

服务端错误消息。

Payload 字段：

| 字段 | 类型 | 说明 |
| --- | --- | --- |
| `code` | `integer` | 错误码 |
| `code_msg` | `string` | 错误描述 |

示例：

```json
{
  "type": "error",
  "ts": 1748352000000,
  "payload": {
    "ts": 1748352000000,
    "world_id": "world_123",
    "location_id": "location_001",
    "session_id": "session_abc123",
    "user_id": "user_001",
    "code": 1005,
    "code_msg": "未加入聊天室"
  }
}
```

### 6.4 输入状态

`input_blocked` 表示世界正在推进中，暂时阻止用户输入。

`input_ready` 表示世界推进完成，用户可以继续输入。

二者使用 `WSPayload`。

### 6.5 `world_notification`

世界级事件通知，广播给世界内所有用户。

顶层使用 `world_payload`，不是 `payload`。

`world_payload` 字段：

| 字段 | 类型 | 说明 |
| --- | --- | --- |
| `ts` | `integer(int64)` | 消息时间戳，毫秒 |
| `world_id` | `string` | 世界实例 ID |
| `event_type` | `string` | `user_join` 或 `user_leave` |
| `title` | `string` | 标题 |
| `summary` | `string` | JSON 字符串摘要 |
| `detail_url` | `string` | 详情链接 |

`summary` 格式：

```json
{
  "location_id": "location_001",
  "online_count": 5,
  "users": [
    {
      "uid": "user_001",
      "avatar": "https://example.com/avatar/user_001.png"
    }
  ]
}
```

示例：

```json
{
  "type": "world_notification",
  "ts": 1748352000000,
  "world_payload": {
    "ts": 1748352000000,
    "world_id": "world_123",
    "event_type": "user_join",
    "title": "用户加入",
    "summary": "{\"location_id\":\"location_001\",\"online_count\":3,\"users\":[{\"uid\":\"user_001\",\"avatar\":\"https://example.com/avatar/user_001.png\"}]}"
  },
  "broadcast": true
}
```

触发时机：

| 触发 | `event_type` |
| --- | --- |
| 用户发送 `join` 成功加入地点 | `user_join` |
| 用户发送 `leave` 离开地点 | `user_leave` |
| 用户断开连接 | `user_leave` |

### 6.6 聊天消息广播

`user_message`、`character_message`、`narrator_message` 都使用通用聊天消息结构。

Payload 字段：

| 字段 | 类型 | 说明 |
| --- | --- | --- |
| `message_id` | `integer(int64)` | 服务端消息 ID |
| `conversation_round_id` | `integer(int64)` | 对话轮次 ID |
| `round_order` | `integer` | 当前轮次内顺序 |
| `sender_type` | `string` | `user`、`character` 或 `narrator` |
| `sender_id` | `string` | 发送者 ID；旁白可能为空 |
| `sender_name` | `string` | 发送者名称；旁白可能为空 |
| `content` | `string` | 完整消息内容 |

用户消息示例：

```json
{
  "type": "user_message",
  "ts": 1748352000000,
  "payload": {
    "ts": 1748352000000,
    "world_id": "world_123",
    "location_id": "location_001",
    "session_id": "session_abc123",
    "user_id": "user_001",
    "code": 0,
    "code_msg": "ok",
    "message_id": 1001,
    "conversation_round_id": 201,
    "round_order": 0,
    "sender_type": "user",
    "sender_id": "sender_001",
    "sender_name": "玩家小明",
    "content": "你好，今天天气怎么样？"
  },
  "broadcast": true
}
```

### 6.7 AI 流式消息

`ai_stream_start` 表示 AI 开始流式输出。

Payload 字段：

| 字段 | 类型 | 说明 |
| --- | --- | --- |
| `conversation_round_id` | `integer(int64)` | 对话轮次 ID |

`ai_stream_chunk` 表示增量内容：

| 字段 | 类型 | 说明 |
| --- | --- | --- |
| `chunk` | `string` | 增量内容 |

`ai_stream_end` 表示流式输出结束：

| 字段 | 类型 | 说明 |
| --- | --- | --- |
| `message_id` | `integer(int64)` | 最终消息 ID |

## 7. 错误码

### 7.1 WebSocket 错误

| Code | Message | 说明 |
| --- | --- | --- |
| `1001` | 参数错误 | 请求参数不正确 |
| `1002` | 消息格式错误 | WebSocket 消息 JSON 格式不正确 |
| `1003` | 未知消息类型 | 发送了不支持的消息类型 |
| `1004` | 已加入聊天室 | 用户已经在当前聊天室中 |
| `1005` | 未加入聊天室 | 用户未加入聊天室，无法发送消息 |
| `1006` | join 消息格式错误 | join 消息的 payload 格式不正确 |
| `1007` | user_id、sender_id、sender_name 必填 | 旧字段校验错误；新版客户端不再上行这些字段 |
| `1008` | send_message 消息格式错误 | send_message payload 格式不正确 |
| `1009` | text 必填 | 发送消息缺少 `text` 字段 |
| `1010` | 地点已满 | 当前地点人数已达上限 |
| `1011` | 会话不存在 | Session 不存在或已过期 |
| `1012` | 未建立连接 | WebSocket 连接未建立 |
| `1013` | location_id 必填 | join 消息缺少 `location_id` |

### 7.2 业务错误

| Code | Message | 说明 |
| --- | --- | --- |
| `2001` | 创建会话失败 | 创建 Session 时发生错误 |
| `2002` | 生成消息ID失败 | Redis INCR 生成消息 ID 失败 |
| `2003` | 生成轮次ID失败 | Redis INCR 生成轮次 ID 失败 |
| `2004` | 保存消息失败 | 消息持久化到 MySQL 失败 |
| `2005` | 队列已满 | 消息队列已达上限 |
| `2006` | 世界正在推进中 | Tick 锁定中，请稍候 |
| `2007` | AI 服务暂时不可用 | LLM 调用失败 |
| `2008` | 开场白生成失败 | 生成开场白时发生错误 |
| `2009` | Tick 已被锁定 | 世界正在推进中，请稍候 |
| `2010` | 消息发送过于频繁 | 用户消息频次限制，10 秒内只能发送一条 |

### 7.3 内部错误和认证错误

| Code | Message | 说明 |
| --- | --- | --- |
| `5000` | 服务暂时不可用 | 内部服务错误 |
| `5001` | 服务暂时不可用 | Redis 操作错误 |
| `5002` | 服务暂时不可用 | MySQL 操作错误 |
| `5003` | 服务暂时不可用 | 外部服务调用错误 |
| `10001` | 未授权 | 请先登录 |

## 8. Flutter 实现对齐点

- `ChatroomClient.connect` 使用 `GENESIS_CHATROOM_WS_URL` 拼接 `world_id` query，并通过 `Authorization: Bearer ...` 建联。
- `ChatroomSession.join` 只发送 `payload.location_id`，不再发送 `user_id`、`sender_id`、`sender_name`。
- `ChatroomSession.sendMessage` 发送 `payload.text` 和 `payload.client_uuid`。
- `heartbeat` 和 `leave` 都发送空 payload。
- 下行 `world_notification` 从顶层 `world_payload` 解析。
- `ack` 优先用 `client_uuid` 关联 pending 消息；服务端未回传时，客户端按最早 pending 消息兜底。
- `joined`、`leaved`、`kicked`、`disconnected`、`input_blocked`、`input_ready`、聊天消息和 AI 流式事件均映射为 `ChatroomEvent`。
