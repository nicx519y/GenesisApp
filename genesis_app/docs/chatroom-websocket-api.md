# Chatroom WebSocket API

本文档按 `/Users/ionix/Downloads/aitown-chat-ws-new.yaml` 更新，描述 AITown 聊天室 WebSocket `2.0.0` 最新协议，以及 Flutter 侧当前实现需要遵守的字段契约。

## 1. 概览

| 项 | 值 |
| --- | --- |
| OpenAPI | `3.0.3` |
| 标题 | `AITown Chat WebSocket API` |
| 版本 | `2.0.0` |
| Dev WS 服务 | `wss://dev.hushie.ai/aitown-chat/ws` |
| Flutter WS 配置 | `GENESIS_CHATROOM_WS_URL` |
| Flutter 默认 WS | `wss://api.worldo.ai/aitown-chat/ws` |
| Flutter HTTP 配置 | `GENESIS_CHATROOM_HTTP_URL` |

建联时服务端自动创建 Session；同一用户建立新连接时，服务端会踢掉该用户的旧连接。客户端需要通过心跳维持连接，当前 Flutter 默认每 2 秒发送一次。所有 WebSocket 消息使用 JSON，字段命名采用 `snake_case`。

世界级广播使用单一世界通道：

```text
channel:chat:world:{world_id}
```

Flutter 侧 WebSocket 域名使用独立配置 `GENESIS_CHATROOM_WS_URL`，不复用 chatroom HTTP 接口的 `GENESIS_CHATROOM_HTTP_URL`。

## 2. 建联接口

```text
GET wss://dev.hushie.ai/aitown-chat/ws?world_id={world_id}
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

## 3. 客户端上行消息

上行消息不再包 `payload`，业务字段直接放在顶层。

### 3.1 `join`

进入指定地点聊天室。

| 字段 | 类型 | 必填 | 说明 |
| --- | --- | --- | --- |
| `type` | `string` | 是 | 固定 `join` |
| `client_msg_id` | `string` | 否 | 客户端消息 ID，用于 ack 匹配 |
| `world_id` | `string` | 是 | 世界实例 ID |
| `location_id` | `string` | 是 | 地点 ID |

```json
{
  "type": "join",
  "client_msg_id": "client_abc_001",
  "world_id": "world_001",
  "location_id": "loc_001"
}
```

### 3.2 `send_message`

发送聊天消息到当前聊天室。

| 字段 | 类型 | 必填 | 说明 |
| --- | --- | --- | --- |
| `type` | `string` | 是 | 固定 `send_message` |
| `client_msg_id` | `string` | 否 | 客户端消息 ID，用于 ack 匹配 |
| `content` | `string` | 是 | 消息内容 |

```json
{
  "type": "send_message",
  "client_msg_id": "client_abc_002",
  "content": "大家好！"
}
```

### 3.3 `heartbeat`

心跳消息。

```json
{
  "type": "heartbeat"
}
```

### 3.4 `leave`

离开当前聊天室，保持 WebSocket 连接。

```json
{
  "type": "leave",
  "client_msg_id": "client_abc_003"
}
```

## 4. 服务端下行统一结构

服务端下行消息使用统一顶层结构，公共元数据直接放在顶层，个性化内容放在 `payload`。

| 字段 | 类型 | 必填 | 说明 |
| --- | --- | --- | --- |
| `type` | `string` | 是 | 事件类型 |
| `ts` | `integer(int64)` | 是 | 毫秒时间戳 |
| `world_id` | `string` | 是 | 世界实例 ID |
| `payload` | `object` | 是 | 个性化消息载荷 |
| `session_id` | `string` | 否 | 会话 ID，排查用 |
| `global_msg_id` | `integer(int64)` | 否 | 全局消息 ID，全局递增 |
| `msg_id` | `integer(int64)` | 否 | 消息 ID，world 级别递增 |
| `location_msg_id` | `integer(int64)` | 否 | 地点消息 ID，location 级别递增；世界级消息为 `0` |
| `conversation_round_id` | `integer(int64)` | 否 | 对话轮次 ID |
| `user_id` | `string` | 否 | 用户 ID |
| `sender_id` | `string` | 否 | 发送者 ID |
| `sender_name` | `string` | 否 | 发送者名称 |
| `location_id` | `string` | 否 | 地点 ID |
| `current_time` | `string` | 否 | 世界时间，如 `Day 45, 19:30` |
| `err_no` | `string` | 是 | ack 错误码；成功为空字符串 |
| `err_msg` | `string` | 是 | ack 错误信息；成功为空字符串 |

Flutter 解析时只接受本文档列出的顶层字段与 `payload` 结构，不兼容旧协议字段或旧事件类型。

## 5. 服务端下行消息

### 5.1 `ack`

服务端确认收到客户端消息。正常 ack 的 `err_no` 和 `err_msg` 均为空字符串；错误也统一通过 `type: "ack"` 返回，不再发送 `type: "error"`。

```json
{
  "type": "ack",
  "ts": 1717300000000,
  "world_id": "world_001",
  "session_id": "sess_abc",
  "global_msg_id": 1001,
  "msg_id": 501,
  "location_msg_id": 201,
  "conversation_round_id": 123,
  "err_no": "",
  "err_msg": "",
  "payload": {
    "client_msg_id": "client_abc_002"
  }
}
```

错误 ack 示例：

```json
{
  "type": "ack",
  "ts": 1717300000000,
  "world_id": "world_001",
  "session_id": "sess_abc",
  "err_no": "2006",
  "err_msg": "世界正在推进中，请稍候...",
  "payload": {
    "client_msg_id": "client_abc_002"
  }
}
```

### 5.2 系统通知

这些事件共用 `SystemNotifyPayload`：

| 事件 | 触发时机 | 客户端行为 |
| --- | --- | --- |
| `tick_start` | 外部 tick 服务调用 lock 接口 | 用户不能发送消息，但可以进出 location |
| `tick_done` | 外部 tick 服务调用 unlock 接口 | 用户可以发送消息 |
| `world_change` | Tick 完成后世界发生变更 | 调用 `/api/v1/world/detail?world_id=xxx` 拉取世界详情 |
| `user_location_change` | 玩家 join/leave 或收到 `tick_start` | 调用 `/aitown-chat/api/ulocation?world_id=xxx` 拉取玩家位置 |
| `world_new_message` | 世界某地点产生新对话 | 调用 `/aitown-chat/api/messages?...` 拉取历史消息 |

`SystemNotifyPayload`：

| 字段 | 类型 | 说明 |
| --- | --- | --- |
| `title` | `string` | 标题 |
| `summary` | `string` | 摘要 |
| `detail_url` | `string` | 详情 URL，空字符串表示无详情 |

示例：

```json
{
  "type": "world_change",
  "ts": 1717300000000,
  "world_id": "world_001",
  "payload": {
    "title": "世界变更",
    "summary": "角色位置变更，新玩家加入",
    "detail_url": "/api/v1/world/detail?world_id=world_001"
  }
}
```

`world_new_message` 还会携带顶层 `location_id`。

### 5.3 `tick_advance`

世界时间推进消息。格式与普通内容消息一致，顶层 `current_time` 和 `payload.content` 值相同；`payload.tick_no` 是页面展示的 Tick 编号。历史消息接口中对应 `sender_type: "tick"`，并应携带 `tick_no`。

```json
{
  "type": "tick_advance",
  "ts": 1780924703973,
  "world_id": "w_4LA63V",
  "global_msg_id": 1001,
  "msg_id": 501,
  "location_msg_id": 0,
  "conversation_round_id": 123,
  "current_time": "Day 45, 19:34",
  "payload": {
    "content": "Day 45, 19:34",
    "tick_no": 7
  }
}
```

### 5.4 `user_message`

广播用户发送的消息给世界内所有用户。

```json
{
  "type": "user_message",
  "ts": 1717300000000,
  "world_id": "world_001",
  "session_id": "sess_abc",
  "global_msg_id": 1001,
  "msg_id": 501,
  "location_msg_id": 201,
  "conversation_round_id": 123,
  "user_id": "user_001",
  "sender_id": "user_001",
  "sender_name": "张三",
  "location_id": "loc_001",
  "payload": {
    "content": "大家好！",
    "client_msg_id": "client_abc_002"
  }
}
```

### 5.5 `nar_new_message`

旁白或角色旁白式消息。`payload` 使用 `UserMessagePayload`，不再使用系统通知 payload。

```json
{
  "type": "nar_new_message",
  "ts": 1717300000000,
  "world_id": "world_001",
  "location_id": "loc_001",
  "global_msg_id": 1003,
  "msg_id": 503,
  "location_msg_id": 203,
  "conversation_round_id": 123,
  "sender_id": "nar",
  "sender_name": "旁白",
  "payload": {
    "content": "新的旁白内容..."
  }
}
```

### 5.6 LLM 流式消息

#### `llm_stream_start`

```json
{
  "type": "llm_stream_start",
  "ts": 1717300000000,
  "world_id": "world_001",
  "location_id": "loc_001",
  "global_msg_id": 1002,
  "msg_id": 502,
  "location_msg_id": 202,
  "conversation_round_id": 123,
  "payload": {
    "sender_type": "character",
    "sender_id": "char_001",
    "sender_name": "村长"
  }
}
```

#### `llm_chunk`

```json
{
  "type": "llm_chunk",
  "ts": 1717300000500,
  "world_id": "world_001",
  "location_id": "loc_001",
  "global_msg_id": 1002,
  "msg_id": 502,
  "location_msg_id": 202,
  "conversation_round_id": 123,
  "payload": {
    "sender_type": "character",
    "sender_id": "char_001",
    "sender_name": "村长",
    "seq": 5,
    "content": "欢迎来到"
  }
}
```

#### `llm_stream_end`

```json
{
  "type": "llm_stream_end",
  "ts": 1717300001000,
  "world_id": "world_001",
  "location_id": "loc_001",
  "global_msg_id": 1002,
  "msg_id": 502,
  "location_msg_id": 202,
  "conversation_round_id": 123,
  "payload": {
    "sender_type": "character",
    "sender_id": "char_001",
    "sender_name": "村长",
    "content": "欢迎来到我们的小镇！有什么可以帮助你的吗？"
  }
}
```

`sender_type` 可为 `character` 或 `narrator`。`llm_chunk.payload.seq` 用于排序，防止乱序。

## 6. 配套 HTTP 接口

这些接口由 chatroom 服务提供。Flutter 侧通过 `GenesisApi.chatroomHttp` 访问，base URL 由 `GENESIS_CHATROOM_HTTP_URL` 配置，默认 `https://api.worldo.ai/`。

### 6.1 GET `/api/v1/world/detail`

获取世界详情。该接口由主 HTTP 服务提供，字段以 `docs/apifox-http-api-contract.md` 的 `World detail` 契约为准。

Query：

- `world_id*`: string，世界实例 ID

### 6.2 GET `/aitown-chat/api/ulocation`

获取世界内所有已加入 location 的玩家位置信息，按地点分组返回。未加入任何 location 的用户不会出现在结果中。AI 角色位置仍以 `/api/v1/world/detail` 为准，不在该接口返回。

Query：

- `world_id*`: string，世界实例 ID

响应字段：

- `world_id`: string，世界实例 ID
- `locations`: `{ location_id, users: ChatroomLocationUser[] }[]`
- `users[].user_id`: string，用户 ID
- `users[].user_name`: string，用户显示名
- `users[].avatar`: string，用户头像 URL

响应：

```json
{
  "err_no": 0,
  "err_msg": "",
  "data": {
    "world_id": "world_001",
    "locations": [
      {
        "location_id": "loc_001",
        "users": [
          {
            "user_id": "user_001",
            "user_name": "张三",
            "avatar": "https://example.com/avatar/user_001.jpg"
          }
        ]
      }
    ]
  }
}
```

### 6.3 GET `/aitown-chat/api/messages`

YAML 的 `paths` 写作 `/api/messages`，但通知 `detail_url` 使用 `/aitown-chat/api/messages`，项目实现按 chatroom 服务前缀访问。

Query：

- `world_id*`: string，世界实例 ID
- `location_id*`: string，地点 ID
- `since`: integer，起始消息 ID，`0` 表示获取最新
- `limit`: integer，默认 `20`，最大 `100`

响应消息字段按当前 HTTP 文档的 `MessageDTO`：`global_message_id` 全局递增，`message_id` world 级别递增，`location_message_id` location 级别递增；`sender_type` 取值为 `user`、`character`、`narrator`、`npc` 或 `tick`；`created_at` 格式为 `2006-01-02 15:04:05`。

响应：

```json
{
  "err_no": 0,
  "err_msg": "succ",
  "data": {
    "messages": [
      {
        "global_message_id": 90001,
        "message_id": 1001,
        "location_message_id": 101,
        "location_id": "loc_001",
        "conversation_round_id": 7001,
        "sender_type": "user",
        "sender_id": "char_user_001",
        "sender_name": "小明",
        "user_id": "u_001",
        "content": "大家好！",
        "current_time": "Day 1, 08:00",
        "tick_no": 3,
        "created_at": "2026-07-01 10:00:00"
      },
      {
        "global_message_id": 90002,
        "message_id": 1002,
        "location_message_id": 102,
        "location_id": "loc_001",
        "conversation_round_id": 7002,
        "tick_no": 7,
        "sender_type": "tick",
        "sender_id": "tick",
        "sender_name": "Time",
        "user_id": null,
        "content": "Day 45, 19:30",
        "current_time": "Day 45, 19:30",
        "created_at": "2026-07-01 10:05:00"
      }
    ],
    "has_more": false,
    "newest_message_id": 1002
  }
}
```

## 7. 错误码

| 范围 | 错误码 | 说明 |
| --- | --- | --- |
| WebSocket `1xxx` | `1001` | 参数错误 |
| WebSocket `1xxx` | `1002` | 消息格式错误 |
| WebSocket `1xxx` | `1003` | 未知消息类型 |
| WebSocket `1xxx` | `1004` | 已加入聊天室 |
| WebSocket `1xxx` | `1005` | 未加入聊天室，无法发送消息 |
| WebSocket `1xxx` | `1006` | join 消息格式错误 |
| WebSocket `1xxx` | `1008` | send_message 消息格式错误 |
| WebSocket `1xxx` | `1009` | content 必填 |
| WebSocket `1xxx` | `1012` | 未建立连接 |
| WebSocket `1xxx` | `1013` | location_id 必填 |
| WebSocket `1xxx` | `1014` | 地点不存在 |
| WebSocket `1xxx` | `1015` | 被踢下线 |
| 业务 `2xxx` | `2001` | 创建 Session 失败 |
| 业务 `2xxx` | `2002` | 生成消息 ID 失败 |
| 业务 `2xxx` | `2003` | 生成轮次 ID 失败 |
| 业务 `2xxx` | `2004` | 保存消息失败 |
| 业务 `2xxx` | `2006` | 世界正在推进中 |
| 业务 `2xxx` | `2010` | 消息发送过于频繁 |
| 内部 `5xxx` | `5000` | 服务暂时不可用 |
| 认证 `100xx` | `10001` | 未授权 |

## 8. Flutter 实现约定

- `ChatroomClient.connect` 使用 `GENESIS_CHATROOM_WS_URL` 拼接 `world_id` query，并通过 `Authorization: Bearer ...` 建联。
- `join`、`send_message`、`heartbeat`、`leave` 上行消息只使用顶层字段，不发送旧 `payload` 包裹；`join` 只发送 `client_msg_id`、`world_id`、`location_id`。
- `heartbeat` 只发送 `{ "type": "heartbeat" }`，不携带 `client_msg_id`，也不等待 ack。
- 服务端错误只接受 `type: "ack"` 携带 `err_no` / `err_msg`；不兼容旧 `type: "error"` 或 `err_code`。
- `send_message` 的 ack 必须通过 `payload.client_msg_id` 匹配；服务端缺失该字段时请求会超时。
- `join()` 只接受携带相同 `payload.client_msg_id` 的 `ack` 作为完成信号。
- `tick_advance` 会进入所有叶子地点的消息队列，Flutter 展示为系统时间推进提示，文案为 `Tick {payload.tick_no} · {payload.content}`；历史消息里的 `sender_type: "tick"` 同样按系统提示处理。
- `llm_stream_start`、`llm_chunk`、`llm_stream_end` 在 Flutter 内部仍复用 `ChatroomAiMessageStream` 事件模型。
- 原始帧通过 `developer.log(name: 'ChatroomSocketFrame')` 输出到 Flutter DevTools Logging。
