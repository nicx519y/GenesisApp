# World 主线历史：客户端对接文档

> 更新：2026-10-20。按用户提供的 [OpenAPI v1.1.0](client_world_history.yaml) 对齐消息顶层 `tick` / `sub_tick`；新契约替代此前不返回编号的设计。本文不代表真实服务已经完成部署或联调验收。

按 World 分页读取完整主线历史，包含地点消息和 Tick 消息。不返回小手机私聊、累计摘要，也不受模型记忆窗口限制。

## 请求

`GET /aitown-chat/api/v1/world/history`

沿用现有登录凭证：`Authorization: Bearer <session_id>` 或 `AIUSS` Cookie。服务端从登录态识别当前用户，无需传 `user_id`。

| 参数 | 类型 | 必传 | 说明 |
| --- | --- | --- | --- |
| `world_id` | string | 是 | 要查询的 World ID |
| `cursor` | string | 否 | 首次不传；下一页原样传回上次响应的 `cursor` |
| `limit` | integer | 否 | 每页消息数，默认 20，范围 1–100；一条消息关联多个地点仍只计一条 |

```http
GET /aitown-chat/api/v1/world/history?world_id=w_001&limit=20
Authorization: Bearer <session_id>
```

仅 World 创建者或当前有效成员可以访问，每页请求都会校验权限。待加入、仅申请获批、已退出、已移除的用户不能读取；World 不存在或已删除时返回错误。

## 成功响应

以下示例包含一条普通消息和一条 Tick。**两条消息的顶层 `content` 都是字符串；Tick 的字符串内容是一段 JSON。**

```json
{
  "err_no": 0,
  "err_msg": "succ",
  "data": {
    "world_id": "w_001",
    "messages": [
      {
        "global_message_id": "2103",
        "type": "character",
        "tick": 7,
        "sub_tick": 3,
        "sender_id": "char_001",
        "sender_name": "林舟",
        "user_id": null,
        "message_type": "text",
        "content": "我们去港口看看吧。",
        "min_app_version": 0,
        "current_time": "第5天 18:05",
        "created_at": "2026-10-19T18:05:00+08:00",
        "location_refs": [
          "B"
        ]
      },
      {
        "global_message_id": "2100",
        "type": "tick",
        "tick": 7,
        "sub_tick": 0,
        "sender_id": "tick",
        "sender_name": "Tick",
        "user_id": null,
        "message_type": "text",
        "content": "{\"current_time\":\"第5天 18:00\",\"global\":\"夜幕降临，雨水打湿了街道。\",\"global_status\":[{\"owner\":\"world\",\"icon\":\"🌧️\",\"form\":\"天气\",\"content\":\"持续降雨，街道湿滑。\"}],\"story_events\":[{\"location_id\":\"A\",\"timestamp\":\"第5天 18:00\",\"visibility\":\"public\",\"visible_to\":[],\"text\":\"广场的钟声响起，守卫提醒行人尽快回家。\",\"clue\":\"可向守卫打听港口宵禁。\",\"cast\":[{\"id\":\"char_001\",\"name\":\"林舟\"}],\"status\":[{\"owner\":\"char_001\",\"icon\":\"🧥\",\"form\":\"衣着\",\"content\":\"披上雨衣。\"}]}],\"characters_moved\":[{\"char_id\":\"char_001\",\"old_loc_id\":\"A\",\"to_loc_id\":\"B\"}]}",
        "min_app_version": 0,
        "current_time": "第5天 18:00",
        "created_at": "2026-10-19T18:00:00+08:00",
        "location_refs": [
          "A",
          "B"
        ]
      }
    ],
    "has_more": true,
    "cursor": "opaque_cursor"
  }
}
```

`err_no = 0` 表示成功。分页字段如下：

| 字段 | 类型 | 说明 |
| --- | --- | --- |
| `data.world_id` | string | 本次查询的 World ID |
| `data.messages` | array | 本页消息，按服务端给定的从旧到新顺序返回 |
| `data.has_more` | boolean | 当前 World 是否还有更早的历史可继续加载 |
| `data.cursor` | string | 下一页游标；无下一页时为空字符串 |

每条消息的字段如下：

| 字段 | 类型 | 说明 |
| --- | --- | --- |
| `global_message_id` | string | 消息唯一 ID，用于本接口消息去重；保持字符串，避免大整数精度丢失 |
| `type` | string | 消息来源：`user`、`character`、`narrator`、`tick` |
| `tick` | int64 | 所有消息必返的主 Tick 存储序号，保留 0，不按当前世界或消息顺序推算 |
| `sub_tick` | int64 | 所有消息必返的子 Tick 存储序号；主 Tick 为 0，子 Tick 为对应序号 |
| `sender_id` | string | 发送方 ID |
| `sender_name` | string | 发送方展示名 |
| `user_id` | string / null | 消息关联的用户 ID；无关联用户时为 `null` |
| `message_type` | string | 正文类型：`text`、`image`、`narration`；Tick 为 `text`，仍需按下文解析 |
| `content` | string | 完整正文。普通消息直接使用；聚合 Tick 为 JSON 字符串，其内部结构见下一节 |
| `min_app_version` | integer | 消息要求的最低客户端版本号；`0` 表示无最低要求 |
| `current_time` | string | 世界内的展示时间，不作为分页或排序依据 |
| `created_at` | string | 消息创建时间，使用带时区的 RFC 3339 格式 |
| `location_refs` | string[] | 这条消息实际关联的全部 `location_id`；无关联时为 `[]` |

消息直接提供顶层 `content`、`tick` 和 `sub_tick`，没有 `payload` 包装；不返回 `message_id`、`conversation_round_id`、`tick_no`、`subtick_no` 或 `sub_tick_no`，Tick 正文内也不补回这些字段。`tick` / `sub_tick` 只从消息顶层读取；History 复用现有 Tick 标签格式：主 Tick 为 `Tick 7`，子 Tick 为 `Tick 7-3`，零值为 `Tick 0`。这两个字段缺失或不是整数属于契约错误，不使用分页位置、世界当前 Tick 或旧字段名补造编号。

## Tick 的 content

当 `type = "tick"` 时，先取得字符串 `message.content`，再执行一次 `JSON.parse(message.content)`。上面示例的解析结果为：

```json
{
  "current_time": "第5天 18:00",
  "global": "夜幕降临，雨水打湿了街道。",
  "global_status": [
    {
      "owner": "world",
      "icon": "🌧️",
      "form": "天气",
      "content": "持续降雨，街道湿滑。"
    }
  ],
  "story_events": [
    {
      "location_id": "A",
      "timestamp": "第5天 18:00",
      "visibility": "public",
      "visible_to": [],
      "text": "广场的钟声响起，守卫提醒行人尽快回家。",
      "clue": "可向守卫打听港口宵禁。",
      "cast": [
        {
          "id": "char_001",
          "name": "林舟"
        }
      ],
      "status": [
        {
          "owner": "char_001",
          "icon": "🧥",
          "form": "衣着",
          "content": "披上雨衣。"
        }
      ]
    }
  ],
  "characters_moved": [
    {
      "char_id": "char_001",
      "old_loc_id": "A",
      "to_loc_id": "B"
    }
  ]
}
```

### TickContent 字段

| 字段 | 类型 | 说明 |
| --- | --- | --- |
| `current_time` | string | 该 Tick 的世界时间，与消息顶层 `current_time` 一致；它是展示时间，不是旁白正文 |
| `global` | string | 世界级旁白正文，例如“夜幕降临……”；允许为空字符串 |
| `global_status` | Status[]，可省略 | 世界状态变化；无变化时可能省略，客户端按空数组处理 |
| `story_events` | StoryEvent[] | 该 Tick 的完整地点事件列表，可包含多个地点；没有事件时为 `[]` |
| `characters_moved` | CharacterMove[] | 该 Tick 的角色移动记录；没有移动时为 `[]` |

`content` 中的对象是整个 Tick 的聚合内容，并非某个地点独有的正文。共享旁白读取 `global`，地点事件正文读取 `story_events[].text`。

### StoryEvent：地点事件

| 字段 | 类型 | 说明 |
| --- | --- | --- |
| `location_id` | string | 事件所属地点 ID；客户端按此字段筛选当前地点的事件 |
| `timestamp` | string | 事件在世界内的发生时间，作为展示文本；不要求等于 Tick 时间，也不要求是 RFC 3339 |
| `visibility` | string | 剧情可见性标记，例如 `public`、`char_only`；历史值按原值保留，不应因未知值导致解析失败 |
| `visible_to` | string[] / null | 剧情中可见此事件的角色 ID 列表，值为角色 ID，不是用户 UID；`null` 按空列表兼容 |
| `text` | string | 地点事件正文 |
| `clue` | string | 事件线索或提示，允许为空字符串 |
| `cast` | Cast[]，可省略 | 事件涉及的角色；每项为 `{"id":"角色 ID","name":"角色名称"}` |
| `status` | Status[]，可省略 | 事件中的角色状态变化；无变化时按空数组处理 |

`visibility` / `visible_to` 是剧情内容元数据，不替代服务端的 World 权限校验。它们也不代表小手机私聊记录。

### Status：世界或角色状态变化

`global_status[]` 与 `story_events[].status[]` 使用同一结构：

| 字段 | 类型 | 说明 |
| --- | --- | --- |
| `owner` | string | 状态归属：世界状态使用 `world`，角色状态使用角色 ID |
| `icon` | string | 状态图标，通常为 emoji |
| `form` | string | 状态的展示形式或标签，例如“天气”“衣着”“公告” |
| `content` | string | 这条状态的正文，例如“持续降雨，街道湿滑。”；这是嵌套状态字段，与消息顶层 `content` 区分 |

### CharacterMove：角色移动记录

| 字段 | 类型 | 说明 |
| --- | --- | --- |
| `char_id` | string | 移动的角色 ID |
| `old_loc_id` | string | 移动前地点 ID |
| `to_loc_id` | string | 移动后地点 ID |

这是该 Tick 发生时的历史记录。加载历史页时不要据此覆盖角色的实时位置。

### 解析和兼容规则

- HTTP 响应完成 JSON 解码后，`message.content` 仍是字符串。仅对聚合 Tick 再解析一次；普通文本消息不做 JSON 解析。
- `message_type = "text"` 不能区分普通文本与 Tick，先看 `type`。
- 历史 Tick 可能只有纯文本。若解析失败或解析结果不是 Tick 对象，按原始字符串展示，不丢弃消息；不能仅因为 `type = "tick"` 就假设解析一定成功。
- 可选的 `global_status`、`cast`、`status` 缺失时按 `[]` 处理；兼容旧数据时，对值为 `null` 的数组也作空数组处理。

## 客户端分页与地点聚合

1. 首次传入 `world_id`，不传 `cursor`。保存返回的消息与游标。
2. 加载更早历史时，将上一页 `cursor` 原样传回，继续使用同一个 `world_id`。切换 World 时重置分页状态。
3. 每页消息保持服务端从旧到新的顺序，加载到的更早页放在现有消息之前，用 `global_message_id` 去重（重叠消息以较新页为准）；不要按 ID 或时间重新推导顺序。
4. 遍历每条消息的 `location_refs`，将消息归入对应地点。同一地点内保留消息相对顺序；一条 Tick 在响应中只出现一次，但可以归入多个地点。
5. `has_more = false` 时停止加载；`messages = []`、`has_more = false`、`cursor = ""` 是正常的空结果。

**Tick 是否属于某地点，只看 `location_refs`；该地点有哪些事件，再看 `story_events[].location_id`。** 上面示例的 Tick 关联 A、B，只有 A 有地点事件。B 仍包含这条 Tick，可展示其世界时间、共享旁白和世界状态；不能因为 B 没有 `story_events` 就认为它没有这条 Tick。

后续新增地点不会自动获得更早 Tick。若某条 Tick 仅返回 `location_refs: ["A"]`，它就不属于 B；不能依据当前地点列表、角色移动或事件列表自行补齐关联。每条消息的 `location_refs` 一次性返回完整，不拆到不同页；空数组不代表“所有地点”。

分页是整个 World 的分页。某一页没有 B 的消息，不代表 B 没有更早历史；是否继续请求由 World 级的 `has_more` 判断。

客户端首次打开 History 后，利用 World WebSocket 的正式消息／变化通知合并触发首页校准；关闭 History 后仍更新最新页缓存。旧阅读分页与最新页分开保存，采用新首页时使用新游标，不拼接新旧分页。消息正文、Tick 编号和地点关联仍全部来自本接口，详见[同步与阅读生命周期](world-history-client-implementation.md)。

## 错误处理

`err_no != 0` 时按现有客户端统一错误处理流程处理，并读取 `err_msg`。未登录、无权访问、World 不存在、参数或游标无效均属于失败，不应当作空历史。请求失败时保留已有消息及游标，修复问题后重试。
