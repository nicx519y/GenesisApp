# Chatroom 接口文档

## 1. 范围

本文档从 `/Users/ionix/Documents/chatroom.docx` 中抽离并重组聊天室通信相关内容，覆盖：

- WebSocket 连接与消息协议
- 客户端上行消息体
- 服务端下行消息体
- HTTP 历史消息接口
- 消息排序、排队、流式 AI 回复与断线重连机制
- Redis Pub/Sub、分布式锁、队列、Session 映射等通信支撑机制

聊天室以 `Location` 为单位划分：一个 `world_instance_id + location_id` 对应一个聊天室。

## 2. 通信入口

### 2.1 WebSocket 连接

```text
ws://{host}/ws?world_instance_id={wid}&location_id={lid}
```

查询参数：

| 参数 | 类型 | 必填 | 说明 |
| --- | --- | --- | --- |
| `world_instance_id` | `string` | 是 | 世界实例 ID |
| `location_id` | `string` | 是 | 地点 ID，也是聊天室 ID |

### 2.2 HTTP 历史消息

```http
GET /api/messages?world_instance_id={wid}&location_id={lid}&since={message_id}&limit={limit}
```

查询参数：

| 参数 | 类型 | 必填 | 说明 |
| --- | --- | --- | --- |
| `world_instance_id` | `string` | 是 | 世界实例 ID |
| `location_id` | `string` | 是 | 地点 ID |
| `since` | `int64` | 否 | 只拉取大于该 `message_id` 的消息，用于增量同步 |
| `limit` | `int` | 否 | 返回条数上限 |

响应示例：

```json
{
  "err_no": 0,
  "data": {
    "messages": [
      {
        "message_id": 1001,
        "conversation_round_id": "round-aaa",
        "round_order": 0,
        "sender_type": "user",
        "sender_id": "player1",
        "sender_name": "玩家小明",
        "content": "你们在干什么？",
        "created_at": "2026-05-17T10:00:00.000Z"
      }
    ],
    "has_more": true,
    "last_message_id": 1002
  }
}
```

## 3. 连接生命周期

1. 用户进入 Location 后，客户端先调用 HTTP API 获取历史消息。
2. 客户端建立 WebSocket 连接。
3. 客户端发送 `join` 消息。
4. 服务端返回 `joined`，其中包含当前连接的 `session_id`。
5. 客户端开始发送消息、接收实时广播和 AI 流式回复。
6. 用户退出时，客户端可发送 `leave`，也可以直接关闭 WebSocket。
7. 服务端在 `leave` 或断开连接时清理连接映射。

## 4. 通用消息 Envelope

WebSocket 消息统一使用 JSON：

```json
{
  "type": "message_type",
  "payload": {}
}
```

字段说明：

| 字段 | 类型 | 必填 | 说明 |
| --- | --- | --- | --- |
| `type` | `string` | 是 | 消息类型 |
| `payload` | `object` | 是 | 消息负载，不同 `type` 对应不同结构 |

## 5. 消息类型总览

| 方向 | `type` | 说明 |
| --- | --- | --- |
| C -> S | `join` | 加入聊天室 |
| C -> S | `leave` | 离开聊天室，可选，也可直接关闭连接 |
| C -> S | `send_message` | 发送用户消息 |
| C -> S | `heartbeat` | 心跳，刷新 session TTL |
| S -> C | `joined` | 加入成功，返回 `session_id` 和在线用户 |
| S -> C | `ack` | 服务端已接收并持久化用户消息 |
| S -> C | `user_message` | 用户消息广播 |
| S -> C | `ai_stream_start` | AI 单条回复开始 |
| S -> C | `ai_stream_chunk` | AI 单条回复内容块 |
| S -> C | `ai_stream_end` | AI 单条回复结束 |
| S -> C | `ai_error` | AI 生成错误 |
| S -> C | `queue_position` | 排队位置通知 |
| S -> C | `error` | 通用错误 |

## 6. 客户端上行消息

### 6.1 `join`

加入聊天室。WebSocket 连接建立后必须先发送。

```json
{
  "type": "join",
  "payload": {
    "user_id": "google-12345",
    "sender_id": "player1",
    "sender_name": "玩家小明"
  }
}
```

Payload 字段：

| 字段 | 类型 | 必填 | 说明 |
| --- | --- | --- | --- |
| `user_id` | `string` | 是 | 用户账号 ID，例如 Google 用户 ID |
| `sender_id` | `string` | 是 | 聊天中展示/绑定的发送者 ID |
| `sender_name` | `string` | 是 | 聊天中展示的发送者名称 |

### 6.2 `send_message`

发送用户消息。

```json
{
  "type": "send_message",
  "payload": {
    "text": "你们在干什么？",
    "client_msg_id": "uuid-123"
  }
}
```

Payload 字段：

| 字段 | 类型 | 必填 | 说明 |
| --- | --- | --- | --- |
| `text` | `string` | 是 | 用户发送的消息内容 |
| `client_msg_id` | `string` | 是 | 客户端生成的临时消息 ID，用于本地占位消息和服务端 `ack` 对齐 |

### 6.3 `heartbeat`

心跳消息。服务端收到后刷新 `session:{session_id}` TTL，并更新活跃状态。服务端静默处理，不返回消息。

```json
{
  "type": "heartbeat",
  "payload": {
    "timestamp": 1716234567890
  }
}
```

### 6.4 `leave`

离开聊天室。客户端可发送该消息通知服务端清理连接映射；也可以直接关闭 WebSocket。

```json
{
  "type": "leave",
  "payload": {}
}
```

## 7. 服务端下行消息

### 7.1 `joined`

加入成功。`session_id` 由服务端在 WebSocket 连接建立时生成，用于标识本次连接。客户端收到后需要保存。

```json
{
  "type": "joined",
  "payload": {
    "session_id": "sess-uuid-xxx",
    "world_instance_id": "world-001",
    "location_id": "living-room",
    "online_users": [
      {
        "user_id": "google-123",
        "sender_id": "player1",
        "sender_name": "玩家小明"
      }
    ]
  }
}
```

### 7.2 `ack`

服务端接收用户消息、生成轮次 ID、分配 `message_id` 并写入消息表后返回。

```json
{
  "type": "ack",
  "payload": {
    "session_id": "sess-uuid-xxx",
    "message_id": 1001,
    "conversation_round_id": "round-aaa",
    "client_msg_id": "uuid-123",
    "queue_position": 0
  }
}
```

`queue_position` 说明：

| 值 | 说明 |
| --- | --- |
| `0` | 无需排队，直接处理 |
| `N` | 队列中第 N 位，需等待前 N 条消息处理完成，`N >= 1` |

### 7.3 `user_message`

用户消息广播。服务端将用户消息写入 MySQL 后，通过 Redis Pub/Sub 广播给该 Location 下所有在线连接。

```json
{
  "type": "user_message",
  "payload": {
    "session_id": "sess-uuid-xxx",
    "message_id": 1001,
    "conversation_round_id": "round-aaa",
    "round_order": 0,
    "sender_type": "user",
    "sender_id": "player1",
    "sender_name": "玩家小明",
    "user_id": "google-123",
    "content": "你们在干什么？",
    "created_at": "2026-05-17T10:00:00.000Z"
  }
}
```

### 7.4 `ai_stream_start`

单条 AI 回复开始。一个用户消息可能触发多条 AI 回复，同一个 `conversation_round_id` 下可收到多个 `ai_stream_start`。

```json
{
  "type": "ai_stream_start",
  "payload": {
    "session_id": "sess-uuid-xxx",
    "message_id": 1002,
    "conversation_round_id": "round-aaa",
    "round_order": 1,
    "sender_type": "character",
    "sender_id": "isabella",
    "sender_name": "Isabella"
  }
}
```

### 7.5 `ai_stream_chunk`

AI 回复内容块。客户端按 `message_id` 和 `sender_id` 追加到对应消息。

```json
{
  "type": "ai_stream_chunk",
  "payload": {
    "session_id": "sess-uuid-xxx",
    "message_id": 1002,
    "conversation_round_id": "round-aaa",
    "sender_id": "isabella",
    "chunk": "亲爱的...",
    "is_delta": true
  }
}
```

### 7.6 `ai_stream_end`

单条 AI 回复结束。

```json
{
  "type": "ai_stream_end",
  "payload": {
    "session_id": "sess-uuid-xxx",
    "message_id": 1002,
    "conversation_round_id": "round-aaa",
    "sender_id": "isabella",
    "created_at": "2026-05-17T10:00:05.000Z"
  }
}
```

### 7.7 `ai_error`

AI 生成过程失败。

```json
{
  "type": "ai_error",
  "payload": {
    "session_id": "sess-uuid-xxx",
    "conversation_round_id": "round-aaa",
    "sender_id": "isabella",
    "error_code": "llm_timeout",
    "message": "LLM 调用超时"
  }
}
```

### 7.8 `queue_position`

排队位置通知。

```json
{
  "type": "queue_position",
  "payload": {
    "session_id": "sess-uuid-xxx",
    "conversation_round_id": "round-aaa",
    "position": 2,
    "estimated_wait_seconds": 10
  }
}
```

### 7.9 `error`

通用错误。

```json
{
  "type": "error",
  "payload": {
    "session_id": "sess-uuid-xxx",
    "code": "invalid_token",
    "message": "Token 无效"
  }
}
```

## 8. 消息字段定义

| 字段 | 类型 | 说明 |
| --- | --- | --- |
| `session_id` | `string` | 服务端生成的 WebSocket 连接 ID |
| `message_id` | `int64` | Redis INCR 分配的全局有序消息 ID |
| `world_instance_id` | `string` | 世界实例 ID |
| `location_id` | `string` | 地点 ID |
| `conversation_round_id` | `string` | 对话轮次 ID，用户消息和其触发的 AI 回复共用 |
| `round_order` | `int` | 轮次内顺序，`0` 表示用户消息，`1/2/3...` 表示 AI 回复 |
| `sender_type` | `string` | 发送者类型，例如 `user`、`character`、`narrator`、`npc` |
| `sender_id` | `string` | 发送者 ID |
| `sender_name` | `string` | 发送者展示名 |
| `user_id` | `string` | 用户账号 ID，仅用户消息需要 |
| `content` | `string` | 完整消息内容 |
| `chunk` | `string` | AI 流式输出增量片段 |
| `client_msg_id` | `string` | 客户端临时消息 ID |
| `created_at` | `string` | ISO-8601 时间字符串 |

消息最大长度：`65536` 字节，与 WebSocket `max_message_size` 一致。

## 9. 错误码

| 错误码 | 含义 | 客户端处理建议 |
| --- | --- | --- |
| `invalid_token` | JWT Token 无效或过期 | 重新登录 |
| `join_failed` | 加入聊天室失败 | 检查参数后重试 |
| `llm_timeout` | LLM 调用超时，默认 30 秒 | 显示错误提示，可重发消息 |
| `llm_error` | LLM 返回错误 | 显示错误提示，可重发消息 |
| `json_parse_error` | LLM 返回 JSON 解析失败 | 显示错误提示 |
| `location_full` | Location 连接数已满 | 提示用户稍后再试 |
| `rate_limit` | 发送频率过快 | 提示用户稍后再试 |

## 10. 客户端处理规则

### 10.1 占位符与流式展示

1. 客户端发送 `send_message` 后，可先创建本地占位消息，并用 `client_msg_id` 标识。
2. 收到 `ack` 后，记录 `conversation_round_id`、服务端 `message_id` 和 `queue_position`。
3. 客户端在用户消息后创建 AI 回复占位符。
4. 收到 `ai_stream_start` 后，用服务端 `message_id` 替换占位符并开始流式显示。
5. 收到 `ai_stream_chunk` 后，追加内容。
6. 收到 `ai_stream_end` 后，完成该条 AI 回复。
7. 如果同一个 `conversation_round_id` 收到多个 `ai_stream_start`，客户端需要创建多个 AI 消息条目。

### 10.2 排序规则

客户端展示消息时按 `message_id` 排序，不依赖 WebSocket 推送顺序。

### 10.3 重连规则

1. 客户端检测到 WebSocket 断开。
2. 使用指数退避重连，例如 `1s, 2s, 4s, 8s...`。
3. 重连成功后重新发送 `join`。
4. 调用历史消息接口拉取增量：

```http
GET /api/messages?world_instance_id={wid}&location_id={lid}&since={last_message_id}
```

5. 合并本地消息和服务器消息：
   - 本地有但服务器无：保留，可能是发送中的消息。
   - 服务器有但本地无：添加。
   - 本地和服务器都有：以服务器为准。
6. 重新按 `message_id` 排序展示。

AI 流式输出中断时，服务端继续完成 LLM 调用；AI 回复完成后一次性写入 `messages` 表。用户重连后通过 HTTP API 获取完整消息。

## 11. 服务端通信机制

### 11.1 用户发送消息流程

1. 客户端发送 `send_message`。
2. 服务端生成 `conversation_round_id`。
3. 服务端通过 Redis 发号器分配 `message_id`。
4. 服务端写入 `messages` 表。
5. 服务端返回 `ack`。
6. 服务端向 Redis Pub/Sub 发布 `user_message`。
7. 所有订阅该 Location Channel 的服务实例收到广播。
8. 各服务实例查找本地 WebSocket 连接并推送 `user_message`。
9. 服务端将该轮对话入 Redis 队列。
10. 服务端尝试获取 Location 分布式锁。
11. 获取锁成功则处理 LLM；获取锁失败则等待，并向客户端发送 `queue_position`。

### 11.2 AI 流式回复流程

前置条件：服务端已获取当前 Location 的分布式锁。

1. 构建 Prompt：
   - 从 `messages` 表读取最近 N 条消息。
   - 从角色表读取角色设定。
2. 调用 LLM，并接收流式输出。
3. 解析到一个完整 AI 回复对象后：
   - 分配 `message_id`。
   - 广播 `ai_stream_start`。
   - 将该消息暂存于内存。
4. 持续接收内容时，广播 `ai_stream_chunk`。
5. 单个角色回复完成时：
   - 广播 `ai_stream_end`。
   - 将完整消息加入待写入列表。
6. 继续解析下一个 AI 回复对象，`round_order++`。
7. 所有回复完成后，一次性批量写入 `messages` 表。
8. 释放分布式锁，继续处理队列中的下一条消息。
9. 如发生超时或 LLM 错误，广播 `ai_error`，释放锁并处理下一条消息。

LLM 返回结构示例：

```json
[
  {
    "sender_type": "character",
    "sender_id": "isabella",
    "sender_name": "Isabella",
    "content": "亲爱的..."
  },
  {
    "sender_type": "narrator",
    "sender_id": "narrator",
    "sender_name": "旁白",
    "content": "*气氛微妙*"
  }
]
```

LLM 超时配置：

| 配置项 | 值 |
| --- | --- |
| 总超时 | 30 秒 |
| 流式超时 | 10 秒无数据 |
| 重试 | 不重试 |

### 11.3 多服务器广播机制

服务端通过 Redis Pub/Sub 支持多实例部署。

1. Server 1 收到用户消息。
2. Server 1 写入 MySQL。
3. Server 1 发布消息到 `location:{world_instance_id}:{location_id}`。
4. 所有订阅该 Channel 的 Server 收到消息。
5. 每个 Server 查找本地连接，并推送给对应 WebSocket。

## 12. Redis Key 设计

### 12.1 Pub/Sub Channel

| Channel | 用途 |
| --- | --- |
| `location:{world_instance_id}:{location_id}` | 该 Location 的消息广播 |

### 12.2 分布式锁

```text
Key: lock:location:{world_instance_id}:{location_id}
Value: {server_id}:{timestamp}:{conversation_round_id}
TTL: 30 秒，看门狗续期
```

续期规则：

- 锁持有期间每 10 秒检查一次。
- 如果 LLM 调用仍在进行，则续期 30 秒。
- 如果持有锁的服务崩溃，锁会在 TTL 到期后自动释放，不阻塞队列。

### 12.3 消息队列

```text
Key: queue:location:{world_instance_id}:{location_id}
Value: conversation_round_id
Operations: RPUSH / LPOP / LLEN / LPOS
```

### 12.4 ID 发号器

```text
Key: idgen:message:{world_instance_id}
Operation: INCR
```

`message_id` 需要在写入数据库前预分配，用于 WebSocket 推送；因此不使用 MySQL `AUTO_INCREMENT` 作为消息协议 ID。

### 12.5 Session 连接映射

```text
Key: session:{session_id}
Value: {
  server_id,
  user_id,
  sender_id,
  sender_name,
  world_instance_id,
  location_id
}
TTL: 每次 heartbeat 续期
```

### 12.6 Location 在线用户列表

```text
Key: location_users:{world_instance_id}:{location_id}
Type: Redis Set
Value: {"user_id":"...","sender_id":"...","sender_name":"..."}
```

维护规则：

- `join` 时通过 `SADD` 添加用户 JSON。
- `leave` 或断连时通过 `SREM` 移除用户 JSON。
- 返回 `joined` 时通过 `SMEMBERS` 获取在线用户列表。

## 13. 消息持久化字段

`messages` 表中与通信协议直接相关的字段如下：

| 字段 | 类型 | 说明 |
| --- | --- | --- |
| `message_id` | `BIGINT` | Redis INCR 分配，全局有序 |
| `world_instance_id` | `VARCHAR(64)` | 世界实例 ID |
| `location_id` | `VARCHAR(64)` | 地点 ID |
| `conversation_round_id` | `VARCHAR(64)` | 对话轮次 ID |
| `round_order` | `INT` | 轮次内顺序，`0` 为用户消息，`1/2/3...` 为 AI 回复 |
| `sender_type` | `VARCHAR` | 发送者类型 |
| `sender_id` | `VARCHAR` | 发送者 ID |
| `sender_name` | `VARCHAR` | 发送者展示名 |
| `content` | `TEXT` | 消息正文 |
| `created_at` | `DATETIME` | 创建时间 |

排序示例：

```text
message_id=1001, conversation_round_id=round-aaa, round_order=0, sender_type=user
message_id=1002, conversation_round_id=round-aaa, round_order=1, sender_type=character
message_id=1003, conversation_round_id=round-aaa, round_order=2, sender_type=narrator
```

## 14. 实现决策摘要

| 问题 | 决策 |
| --- | --- |
| 多服务器广播 | Redis Pub/Sub，所有服务订阅 `location:{wid}:{lid}` |
| 同一 Location 并发 | Redis 分布式锁 + Redis 队列，串行处理 LLM |
| 流式输出 | LLM 流式输出解析为 AI 回复对象后，通过 `ai_stream_*` 推送 |
| 消息顺序 | `message_id` 自增，客户端按 `message_id` 排序 |
| 消息关联 | `conversation_round_id` 关联用户消息和 AI 回复 |
| AI 回复持久化 | 流式过程中推送，完成后批量写入数据库 |
| 超时处理 | 发送 `ai_error`，释放锁，继续处理后续队列 |
| 断线重连 | WebSocket 重连后通过 HTTP 历史消息接口补齐 |
