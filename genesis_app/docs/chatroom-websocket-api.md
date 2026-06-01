# Chatroom WebSocket API

## 1. 概览

本文档整理自 `/Users/ionix/Downloads/openapi-ws.yaml`，用于描述 AI Town 聊天室 WebSocket 协议。

| 项 | 值 |
| --- | --- |
| OpenAPI | `3.0.3` |
| 标题 | `aitown-chat WebSocket API` |
| 版本 | `1.0.0` |
| 本地服务 | `ws://localhost:8080` |
| WebSocket 路径 | `/ws` |

客户端建立 WebSocket 连接后，必须先发送 `join` 消息加入聊天室，之后才能发送聊天内容并接收服务端广播。

## 2. 建联接口

```text
GET ws://localhost:8080/ws?world_instance_id={world_instance_id}&location_id={location_id}
```

该接口通过 HTTP `101` 状态码完成协议升级，将 HTTP 连接升级为 WebSocket 连接。

查询参数：

| 参数 | 类型 | 必填 | 示例 | 说明 |
| --- | --- | --- | --- | --- |
| `world_instance_id` | `string` | 是 | `world_inst_001` | 世界实例 ID |
| `location_id` | `string` | 是 | `loc_tavern` | 地点 ID |

可能响应：

| 状态码 | 说明 |
| --- | --- |
| `101` | 协议升级成功，WebSocket 连接已建立 |
| `400` | 参数错误 |
| `503` | 地点连接数已满 |

错误响应示例：

```json
{
  "errNo": 1001,
  "errMsg": "参数错误",
  "data": {}
}
```

```json
{
  "errNo": 1010,
  "errMsg": "地点已满",
  "data": {}
}
```

## 3. 连接生命周期

1. 客户端连接 `/ws`，并在 query 中传入 `world_instance_id` 和 `location_id`。
2. WebSocket 建联成功后，客户端发送 `join`。
3. 服务端返回 `joined`，表示加入聊天室成功。
4. 客户端可以发送 `send_message`、`heartbeat` 或 `leave`。
5. 服务端通过下行消息广播用户消息、角色消息、旁白消息、AI 流式内容和输入状态。
6. 客户端退出聊天室时发送 `leave`，也可以直接关闭 WebSocket。

## 4. 通用消息结构

所有 WebSocket 消息统一使用 JSON envelope：

```json
{
  "type": "message_type",
  "payload": {}
}
```

| 字段 | 类型 | 必填 | 说明 |
| --- | --- | --- | --- |
| `type` | `string` | 是 | 消息类型 |
| `payload` | `object` | 是 | 消息载荷，不同 `type` 对应不同结构 |

## 5. 消息类型总览

### 5.1 客户端发送给服务端

| `type` | 说明 | 必填字段 |
| --- | --- | --- |
| `join` | 加入聊天室 | `user_id`, `sender_id`, `sender_name` |
| `send_message` | 发送聊天消息 | `text` |
| `heartbeat` | 心跳 | 无 |
| `leave` | 离开聊天室 | 无 |

### 5.2 服务端发送给客户端

| `type` | 说明 |
| --- | --- |
| `joined` | 加入聊天室成功 |
| `ack` | 消息确认 |
| `user_message` | 用户消息广播 |
| `character_message` | 角色消息广播 |
| `narrator_message` | 旁白消息广播 |
| `ai_stream_start` | AI 流开始 |
| `ai_stream_chunk` | AI 流内容块 |
| `ai_stream_end` | AI 流结束 |
| `input_blocked` | 输入被阻止 |
| `input_ready` | 输入就绪 |
| `error` | 错误 |

## 6. 客户端上行消息

### 6.1 `join`

加入聊天室。WebSocket 建联后必须先发送。

Payload 字段：

| 字段 | 类型 | 必填 | 说明 |
| --- | --- | --- | --- |
| `user_id` | `string` | 是 | 用户 ID |
| `sender_id` | `string` | 是 | 发送者 ID |
| `sender_name` | `string` | 是 | 发送者名称 |
| `tick_index` | `integer` | 否 | Tick 索引 |

示例：

```json
{
  "type": "join",
  "payload": {
    "user_id": "user_123",
    "sender_id": "sender_456",
    "sender_name": "玩家小明"
  }
}
```

### 6.2 `send_message`

发送一条用户聊天消息。

Payload 字段：

| 字段 | 类型 | 必填 | 说明 |
| --- | --- | --- | --- |
| `text` | `string` | 是 | 消息内容 |
| `client_msg_id` | `string` | 否 | 客户端消息 ID，用于本地消息和服务端确认对齐 |

示例：

```json
{
  "type": "send_message",
  "payload": {
    "text": "你好，今天天气真不错！"
  }
}
```

### 6.3 `heartbeat`

心跳消息。客户端可携带当前时间戳。

Payload 字段：

| 字段 | 类型 | 必填 | 说明 |
| --- | --- | --- | --- |
| `timestamp` | `integer(int64)` | 否 | 时间戳 |

示例：

```json
{
  "type": "heartbeat",
  "payload": {
    "timestamp": 1716441600000
  }
}
```

### 6.4 `leave`

离开聊天室。

示例：

```json
{
  "type": "leave",
  "payload": {}
}
```

## 7. 服务端下行消息

### 7.1 `joined`

表示客户端已成功加入聊天室。

Payload 字段：

| 字段 | 类型 | 说明 |
| --- | --- | --- |
| `session_id` | `string` | 本次连接的会话 ID |
| `world_instance_id` | `string` | 世界实例 ID |
| `location_id` | `string` | 地点 ID |
| `online_users` | `OnlineUser[]` | 当前在线用户列表 |

`OnlineUser` 字段：

| 字段 | 类型 | 说明 |
| --- | --- | --- |
| `user_id` | `string` | 用户 ID |
| `sender_id` | `string` | 发送者 ID |
| `sender_name` | `string` | 发送者名称 |

示例：

```json
{
  "type": "joined",
  "payload": {
    "session_id": "sess_abc123",
    "world_instance_id": "world_inst_001",
    "location_id": "loc_tavern",
    "online_users": [
      {
        "user_id": "user_123",
        "sender_id": "sender_456",
        "sender_name": "玩家小明"
      }
    ]
  }
}
```

### 7.2 `ack`

确认服务端已收到消息。

Payload 字段：

| 字段 | 类型 | 说明 |
| --- | --- | --- |
| `session_id` | `string` | 本次连接的会话 ID |
| `message_id` | `integer(int64)` | 服务端消息 ID |
| `queue_position` | `integer` | 队列位置，`0` 表示无需排队 |

示例：

```json
{
  "type": "ack",
  "payload": {
    "session_id": "sess_abc123",
    "message_id": 1001,
    "queue_position": 0
  }
}
```

### 7.3 聊天消息广播

`user_message`、`character_message` 和 `narrator_message` 都使用通用聊天消息结构。

Payload 字段：

| 字段 | 类型 | 说明 |
| --- | --- | --- |
| `message_id` | `integer(int64)` | 服务端消息 ID |
| `conversation_round_id` | `integer(int64)` | 对话轮次 ID |
| `round_order` | `integer` | 当前轮次内的展示顺序 |
| `sender_type` | `string` | `user`、`character` 或 `narrator` |
| `sender_id` | `string` | 发送者 ID |
| `sender_name` | `string` | 发送者名称 |
| `content` | `string` | 完整消息内容 |
| `created_at` | `string` | 创建时间 |

用户消息示例：

```json
{
  "type": "user_message",
  "payload": {
    "message_id": 1001,
    "conversation_round_id": 500,
    "round_order": 0,
    "sender_type": "user",
    "sender_id": "sender_456",
    "sender_name": "玩家小明",
    "content": "你好，今天天气真不错！",
    "created_at": "2026-05-23 14:30:00"
  }
}
```

角色消息示例：

```json
{
  "type": "character_message",
  "payload": {
    "message_id": 1002,
    "conversation_round_id": 500,
    "round_order": 1,
    "sender_type": "character",
    "sender_id": "char_alice",
    "sender_name": "爱丽丝",
    "content": "是啊，阳光明媚，正是出门冒险的好日子！",
    "created_at": "2026-05-23 14:30:05"
  }
}
```

旁白消息示例：

```json
{
  "type": "narrator_message",
  "payload": {
    "message_id": 1003,
    "conversation_round_id": 500,
    "round_order": 2,
    "sender_type": "narrator",
    "content": "酒馆的门被推开，一阵清脆的风铃声响起。",
    "created_at": "2026-05-23 14:30:10"
  }
}
```

### 7.4 `ai_stream_start`

表示一条 AI 流式消息开始。

Payload 字段：

| 字段 | 类型 | 说明 |
| --- | --- | --- |
| `message_id` | `integer(int64)` | 服务端消息 ID |
| `round_order` | `integer` | 当前轮次内的展示顺序 |
| `sender_type` | `string` | 发送者类型 |
| `sender_id` | `string` | 发送者 ID |
| `sender_name` | `string` | 发送者名称 |

示例：

```json
{
  "type": "ai_stream_start",
  "payload": {
    "message_id": 1002,
    "round_order": 1,
    "sender_type": "character",
    "sender_id": "char_alice",
    "sender_name": "爱丽丝"
  }
}
```

### 7.5 `ai_stream_chunk`

表示 AI 流式消息的一个内容块。

Payload 字段：

| 字段 | 类型 | 说明 |
| --- | --- | --- |
| `message_id` | `integer(int64)` | 服务端消息 ID |
| `sender_id` | `string` | 发送者 ID |
| `chunk` | `string` | 流式内容块 |
| `is_delta` | `boolean` | 是否为增量内容 |

示例：

```json
{
  "type": "ai_stream_chunk",
  "payload": {
    "message_id": 1002,
    "sender_id": "char_alice",
    "chunk": "是啊，",
    "is_delta": true
  }
}
```

### 7.6 `ai_stream_end`

表示一条 AI 流式消息结束。

Payload 字段：

| 字段 | 类型 | 说明 |
| --- | --- | --- |
| `message_id` | `integer(int64)` | 服务端消息 ID |
| `sender_id` | `string` | 发送者 ID |

示例：

```json
{
  "type": "ai_stream_end",
  "payload": {
    "message_id": 1002,
    "sender_id": "char_alice"
  }
}
```

### 7.7 `input_blocked`

表示当前聊天室暂时不能输入。

Payload 字段：

| 字段 | 类型 | 说明 |
| --- | --- | --- |
| `reason` | `string` | 阻止原因 |
| `message` | `string` | 提示消息 |
| `location_id` | `string` | 地点 ID |

示例：

```json
{
  "type": "input_blocked",
  "payload": {
    "reason": "tick_locked",
    "message": "世界正在推进中，请稍候...",
    "location_id": "loc_tavern"
  }
}
```

### 7.8 `input_ready`

表示当前聊天室可以输入。

Payload 字段：

| 字段 | 类型 | 说明 |
| --- | --- | --- |
| `reason` | `string` | 就绪原因 |
| `location_id` | `string` | 地点 ID |

示例：

```json
{
  "type": "input_ready",
  "payload": {
    "reason": "tick_unlocked",
    "location_id": "loc_tavern"
  }
}
```

### 7.9 `error`

表示服务端返回错误。

Payload 字段：

| 字段 | 类型 | 说明 |
| --- | --- | --- |
| `code` | `integer` | 错误码 |
| `message` | `string` | 错误消息 |

示例：

```json
{
  "type": "error",
  "payload": {
    "code": 2006,
    "message": "世界正在推进中，请稍候..."
  }
}
```

## 8. 客户端处理建议

- 连接成功后先发送 `join`，收到 `joined` 后再开放输入。
- `send_message` 的 `client_msg_id` 是可选字段；如果客户端需要本地占位消息和服务端确认对齐，应主动生成并携带。
- 收到 `ack` 后，用 `message_id` 更新本地消息状态；`queue_position > 0` 时展示排队状态。
- `user_message`、`character_message`、`narrator_message` 可以用同一个消息模型承载。
- `ai_stream_start` 创建或定位一条 AI 消息，后续 `ai_stream_chunk` 按 `message_id` 追加内容，`ai_stream_end` 标记完成。
- `input_blocked` 和 `input_ready` 控制输入区可用状态，不应只作为普通聊天消息展示。
- `heartbeat` 可按固定间隔发送，`leave` 可在用户主动离开聊天室时发送。

## 9. 字段速查

| 字段 | 类型 | 出现场景 | 说明 |
| --- | --- | --- | --- |
| `type` | `string` | 所有消息 | 消息类型 |
| `payload` | `object` | 所有消息 | 消息载荷 |
| `world_instance_id` | `string` | 建联、`joined` | 世界实例 ID |
| `location_id` | `string` | 建联、`joined`、输入状态 | 地点 ID |
| `user_id` | `string` | `join`、在线用户 | 用户 ID |
| `sender_id` | `string` | `join`、在线用户、聊天消息、AI 流 | 发送者 ID |
| `sender_name` | `string` | `join`、在线用户、聊天消息、AI 流 | 发送者名称 |
| `tick_index` | `integer` | `join` | 可选 Tick 索引 |
| `text` | `string` | `send_message` | 用户输入文本 |
| `client_msg_id` | `string` | `send_message` | 可选客户端消息 ID |
| `timestamp` | `integer(int64)` | `heartbeat` | 时间戳 |
| `session_id` | `string` | `joined`、`ack` | WebSocket 会话 ID |
| `online_users` | `OnlineUser[]` | `joined` | 在线用户列表 |
| `message_id` | `integer(int64)` | `ack`、聊天消息、AI 流 | 服务端消息 ID |
| `queue_position` | `integer` | `ack` | 队列位置 |
| `conversation_round_id` | `integer(int64)` | 聊天消息 | 对话轮次 ID |
| `round_order` | `integer` | 聊天消息、AI 流开始 | 轮次内顺序 |
| `sender_type` | `string` | 聊天消息、AI 流开始 | `user`、`character` 或 `narrator` |
| `content` | `string` | 聊天消息 | 完整消息内容 |
| `chunk` | `string` | `ai_stream_chunk` | 流式内容块 |
| `is_delta` | `boolean` | `ai_stream_chunk` | 是否增量内容 |
| `created_at` | `string` | 聊天消息 | 创建时间 |
| `reason` | `string` | 输入状态 | 状态原因 |
| `message` | `string` | 输入状态、错误 | 提示或错误消息 |
| `code` | `integer` | `error` | 错误码 |
