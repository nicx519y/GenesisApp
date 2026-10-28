# Chatroom WebSocket API

本文档按 `/Users/ionix/Downloads/frontend-location-message-tick-debug(2).md`、`/Users/ionix/Downloads/aitown-chat-ws(1).yaml`、`/Users/ionix/Downloads/2026-07-27-image-message-support.md`、`/Users/ionix/Downloads/0803接口.md` 与 `/Users/ionix/Downloads/waiting-conversation-round-client-guide.md` 更新。V2 部分是新版客户端的权威契约；后半部分保留旧 WS 协议，供版本降级和本地适配使用。

## V2 协议选择

WebSocket Gateway 根据最终握手 Header `x-app-version` 为整条连接选择协议：

| Header 值 | WS 协议 |
| --- | --- |
| 空值、非法版本、`<=0.3.3` | legacy |
| 有效版本 `>0.3.3`，包括 `0.3.4-rc` | V2 |

Flutter 在 Gateway signer 完成后，以不区分大小写的方式读取最终 Header。连接建立后，`ChatroomSession.protocolVersion` 固定不变；同一 socket 不混合解析 legacy 与 V2 envelope。

风险与发布要求：

- 不能只修改 Dart 包版本或请求头 provider；生产 Gateway signer 必须把真实安装包版本写入 `X-App-Version`。
- `app-version` 与 `x-app-version` 不是同一个 Header。旧的 `app-version` 不会选择 V2。
- 空值和拼写错误会静默选择 legacy，造成新版上行 payload 被当成旧结构。联调时必须同时检查握手 Header 和第一条 `join` 原始帧。
- 安装包版本变化需要冷启动新建 socket。热重载或复用旧 session 不能证明 V2 已生效。
- V2 HTTP `/aitown-chat/api/v2/messages` 不读取版本 Header，始终返回 V2 DTO；legacy HTTP `/aitown-chat/api/messages` 保持不变。

## V2 统一 envelope

```json
{
  "type": "user",
  "stream_type": "",
  "ts": 1786340797200,
  "world_id": "world_001",
  "location_id": "loc_2_2_2",
  "session_id": "sess_001",
  "global_message_id": 8703,
  "message_id": 102,
  "location_message_id": 30,
  "conversation_round_id": 7360,
  "conversation_type": "user_message",
  "trigger_uid": "user_1",
  "sender_type": "user",
  "sender_id": "char_1",
  "sender_name": "Alice",
  "user_id": "user_1",
  "client_msg_id": "client_002",
  "message_type": "text",
  "min_app_version": 0,
  "created_at": "2026-08-10 11:06:37",
  "current_time": "Day 1, 13:50",
  "payload": {
    "content": "Hello"
  },
  "err_no": 0,
  "err_msg": ""
}
```

字段规则：

- `type` 是业务类型；落库内容使用 `user`、`character`、`narrator`、`tick` 等值。
- `stream_type` 是独立路由轴，只允许 `""`、`llm_stream_start`、`llm_chunk`、`llm_stream_end`。解析时必须先路由 `stream_type`，再路由 `type`。
- V2 ID 使用全称 `global_message_id/message_id/location_message_id`。旧别名只存在于 legacy adapter。
- `trigger_uid` 是轮次触发用户 UID，位于顶层并在同轮 user/character/narrator、LLM start/chunk/end、waiting/end 和候选私有流中保持一致；opening、Tick 及无可用触发者的控制事件为字符串空值。UID 原样保存并精确比较，缺失、`null` 或非字符串兼容为空，不能由 `user_id/sender_id/type/round id` 补齐。
- `conversation_type` 是可选顶层字符串，取值包括 `user_message/user_enter_location/go_on/opening/tick`。地点历史可同时返回两个字段；实时 WS 当前只保证 opening 下发该字段，因此收到非空 `trigger_uid` 时协议解析不要求 `conversation_type` 同时存在。
- `current_time` 是消息产生时的世界时间元数据，位于顶层；客户端暂时兼容旧数据放在 `payload.current_time` 的情况。
- 元数据位于顶层，业务正文、Tick 内容和流式 `seq/content` 位于 `payload`。
- `payload`、整数 `err_no` 和字符串 `err_msg` 是统一字段。未知扩展字段可以忽略，但 payload 非 object、未知 `stream_type` 或未知业务 `type` 是单帧协议错误。
- Flutter 的共享 wire DTO 是 `ChatroomV2Message.fromJson/toJson`；HTTP 与 WS 应复用它，避免丢失 `type/stream_type/payload` 这三个持久化标记。

## V2 客户端上行

所有 V2 上行都包含 `type/stream_type/ts/client_msg_id/payload/err_no/err_msg`。`join`、`send_message` 和 `user_enter_location` 还包含 `world_id`。

所有客户端上行都不新增 `trigger_uid` 或 `conversation_type`；它们是服务端下行元数据，不改变连接、加入地点、鉴权、订阅或既有请求权限。

`join`：

```json
{
  "type": "join",
  "stream_type": "",
  "ts": 1786340797000,
  "world_id": "world_001",
  "client_msg_id": "client_001",
  "payload": {"location_id": "loc_2_2_2"},
  "err_no": 0,
  "err_msg": ""
}
```

`send_message`：

```json
{
  "type": "send_message",
  "stream_type": "",
  "ts": 1786340797001,
  "world_id": "world_001",
  "client_msg_id": "client_002",
  "message_type": "text",
  "payload": {"content": "Hello"},
  "err_no": 0,
  "err_msg": ""
}
```

### 用户发言身份（目标 0.5.2）

V2 `send_message` 顶层显式发送 `message_type: "text" | "narration"`，正文仍为 `payload.content`。发送原文，不拼接 `[User's note: ...]`，不提交 `min_app_version` 或发送者身份。省略、空串或非法发送类型按普通文本处理。图片沿用原协议，不由身份选择改变类型。

```json
{
  "type": "send_message",
  "world_id": "world_001",
  "client_msg_id": "client_note_001",
  "message_type": "narration",
  "payload": {"content": "门外下起了雨。"}
}
```

实时和 `GET /aitown-chat/api/v2/messages` 的历史使用同一形状：用户旁白仍是 `type=user`、`sender_type=user`，顶层 `message_type=narration`、`min_app_version=5002`。AI 旁白保留现有 narrator/nar 识别；不可将用户旁白改为 narrator 身份。

展示版本使用 `major * 1000000 + minor * 1000 + patch`，与原生 build number 无关；当前版本达到 `min_app_version` 才展示，0 不限制。版本过滤只在展示层执行。完整消息仍落入地点队列、缓存、去重和连续序号判断，不能把隐藏消息视为漏收。历史初始 `since=0`，后续使用完整响应批次最小的正数 `location_message_id`；整页隐藏且 `has_more=true` 时继续加载。服务端 `newest_message_id` 保持整个地点最大序号，轮次范围刷新不变。

输入默认角色口吻，以 icon 切换为旁白，占位文案不变；每条提交后恢复 text。待发送气泡、手动失败重试和正式回显均保留该条类型；普通 Send 不再因 ACK 超时自动重发。用户旁白复用 AI 旁白的整宽斜体、无头像昵称样式，前置 icon 颜色也与 AI 旁白一致，多人房也不显示昵称。错误仍走既有 Toast/失败状态，不写入正文。旁白沿用普通发言的 AI 回复、轮次、计价、Go On 和灵感流程。

此为目标契约，不能据此判断后端已上线。开放前需确认 API 实例、P3 模板、Chat 消费/生成、Chat 发送依次发布；首次生成、备用模型重试、重新生成保留类型以及 Prompt 只包装一次，须跨服务联调验收。

`user_enter_location` 不返回 ACK，但仍生成 `client_msg_id`：

```json
{
  "type": "user_enter_location",
  "stream_type": "",
  "ts": 1786340797002,
  "world_id": "world_001",
  "client_msg_id": "client_003",
  "payload": {"location_id": "loc_2_2_2"},
  "err_no": 0,
  "err_msg": ""
}
```

`heartbeat` 与 `leave` 不带 `world_id`，使用空 payload：

```json
{
  "type": "heartbeat",
  "stream_type": "",
  "ts": 1786340797003,
  "client_msg_id": "client_004",
  "payload": {},
  "err_no": 0,
  "err_msg": ""
}
```

## V2 ACK 与 canonical echo

```json
{
  "type": "ack",
  "stream_type": "",
  "ts": 1786340797100,
  "world_id": "world_001",
  "session_id": "sess_001",
  "client_msg_id": "client_002",
  "payload": {},
  "err_no": 0,
  "err_msg": ""
}
```

V2 ACK 只表示服务端收到并受理了对应命令。客户端内部 API 语义如下：

- `ChatroomSession.sendMessage` 保持返回 `Future<ChatroomAck>`，该 Future 只由顶层 `client_msg_id` 匹配的 ACK 完成。
- `ChatroomAck` 是 receipt-only；其可靠字段是 `clientMsgId/code/codeMsg/ts` 以及 session/world 等诊断字段。即使异常服务端 ACK 携带消息 ID，V2 adapter 也不把它们当成 canonical 元数据。
- 随后 `type=user` 的广播才是可落库、带 message/location/round ID 的 canonical echo。它不能提前完成 V2 ACK Future。
- UI/service 如需“已送达”和“已形成正式消息”两个阶段，应分别等待 ACK receipt 与 canonical echo；两者通过 `client_msg_id` 关联。
- 只有明确的 legacy adapter 允许旧 `user_message` echo 代替缺失 ACK，或对无 `client_msg_id` 的特定旧错误码做唯一 pending-send 回退。

## V2 内容与 Tick

非流式内容按 `type` 路由：

- `user` -> `ChatroomUserMessage`
- `character` 或 `narrator` -> `ChatroomNarratorMessage`，同时保留原始 `businessType`
- `tick` -> `ChatroomTickAdvanceMessage`

普通 typed message 保留 `businessType/streamType/minAppVersion/rawPayload`。地点级 Tick 另暴露 `v2TickPayload` 与 `isV2LocationTick`；`ChatroomV2TickPayload` 保存 `current_time/tick_no/sub_tick_no/global/story_events/characters_moved`，也支持历史纯文本 `payload.content` 回退。`tick_no=0` 和 `sub_tick_no=0` 都是有效值，不能用正数判断字段是否存在。

Location Chat 对最新 conversation 的四个回复功能集中判断资格：本人触发的 `user_message/go_on` 可用 Regenerate、Go On、Edit、灵感回复；`opening` 仅当前登录 UID 等于 World 详情的 `owner_uid` 时可用 Go On、Edit、灵感回复（创建者信息缺失时不可用）；`user_enter_location` 仅本人触发时可用 Go On、Edit、灵感回复；`tick` 对任何用户开放 Go On、灵感回复，不要求本人触发或 World 创建者身份，Regenerate、Edit 不可用。正式 `type=tick` 消息只要携带有效的正数 `conversation_round_id`，即可识别为 Tick 回复来源；不要求 `conversation_type`、同轮 AI 回复或轮次结束事件。其余用户触发的正常对话，以及缺失、未知或冲突元数据均不可用。普通实时轮次只有 `trigger_uid` 而缺少 `conversation_type` 时等待正常历史刷新，不主动查历史，也不从本地动作推断。Tick 直接以正式消息的类型和轮次识别。资格之上仍保留最新轮次、轮次非生成中（非 Tick 仍要求已完成且有正式 AI 回复）、连接、Tick 锁、busy/frozen、候选卡和生成上限等操作安全门槛；Enter、Tick、Opening 的灵感请求不传候选 `card_id`。

V2 只把地点级 `type=tick` 当作 canonical Tick：

- `global_message_id`：LocationMessage 自身 ID
- `message_id`：world 级消息 ID
- `location_message_id`：地点分页游标
- `conversation_round_id`：本次 Tick/P1I 对话轮次

## V2 `world_summary_updated` 摘要通知

P5 成功保存世界摘要后，服务端只向当时具有有效会员资格的世界 owner 在线连接发送世界级通知；同一 owner 在其他地点的连接也可能收到。通知不是聊天消息，没有消息序号、正文或 ACK。

```json
{
  "type": "world_summary_updated",
  "stream_type": "",
  "ts": 1790380800000,
  "world_id": "world_001",
  "user_id": "owner_001",
  "trigger_uid": "",
  "payload": {"generation": 3, "tick_no": 0},
  "err_no": 0,
  "err_msg": ""
}
```

`world_id` 是摘要所属世界，`user_id` 是接收通知的 owner，`generation` 是该世界摘要代次，`tick_no` 允许为 0 且不是地点消息序号。客户端按 `world_id + generation` 去重，对当前世界和账号调用 `GET /api/v1/world/recent_summary` 无游标刷新 Recap 首屏，保留原缓存直到新响应到达。若通知发生在请求进行中，请求完成后再刷新一次。重新连接或进入 Recap 时仍按原逻辑主动查询；HTTP 会员与访问权限检查不变。

生成或保存失败、重复触发不会发送通知；通知没有离线补发或重试。滚动发布期间连在旧服务实例上的客户端可能暂时收不到该提醒。

## V2 LLM 流与错误隔离

LLM 流的外层 `type` 仍表示发送者业务类型，状态只看 `stream_type`。例如 `type=character, stream_type=llm_chunk` 必须解析为 chunk，而不是完整 character message。

活跃流以 `world|location|conversation_round_id|sender_id` 为主要身份；session 用于进一步隔离，`message_id` 只作辅助，因为 V2 流帧允许缺少 ID：

- chunk/end 提供的非空字段必须与 start 兼容。
- 精确字段越多，匹配优先级越高；同 round 不同 sender 不得串流。
- 缺少 round/message ID 时，只允许归并到唯一候选。
- 多个候选同分时发出 `stream_ambiguous`，保留全部流且不写入任何候选，避免静默串流。
- 正序 `seq` 被去重；乱序 chunk 暂存，直到缺口补齐后按序发布。stream end 的完整 `content` 是最终权威文本。

任何单帧 JSON、字段、type 或 stream_type 解析错误只产生 `protocol_error`，不能关闭 socket，也不能阻止下一帧正常交付。

## V2 保留的控制事件

以下控制通知保留既有外层 `type` 与业务 payload：`tick_start`、`tick_done`、`world_change`、`user_location_change`、`world_new_message`、`map_updated`、`character_updated`、`new_user_join`、`balance_low`。`user_enter_location/story_events/characters_moved` 的既有通知/正式消息适配也继续存在。

`balance_low` 的 Gems 余额只使用 `payload.balance_cent`。该字段必须是 JSON 整数 cent；缺失或类型不合法时，本帧按协议错误隔离。业务模型保存原始 cent，用户可见余额由统一 Gems 格式化工具转换为固定一位小数。

V2 地点聊天不跟随控制通知中的 legacy `detail_url`：`world_new_message` 或 `characters_moved` 带 `location_id` 时只调用 `/aitown-chat/api/v2/messages` 刷新该地点；缺少地点时对当前世界的叶子地点做限并发 V2 刷新。这条 runtime 链路不调用 `/aitown-chat/internal/world/messages` 或 legacy `/aitown-chat/api/messages`。

#### MiniPhone 私聊角色移动正式消息（2026-10-21）

`phone_characters_moved` 是地点正式消息，替代此前无消息 ID 的临时控制事件。`conversation_round_id` 可选；以下为不关联对话轮次的消息：

```json
{
  "type": "phone_characters_moved",
  "world_id": "world_1",
  "location_id": "loc_b",
  "global_message_id": 1001,
  "message_id": 1001,
  "location_message_id": 25,
  "conversation_type": "phone_characters_moved",
  "sender_type": "phone_characters_moved",
  "payload": {
    "content": [{"char_id": "char_1", "old_loc_id": "loc_a", "to_loc_id": "loc_b"}]
  }
}
```

- `global_message_id/message_id/location_message_id` 三个消息 ID 必须是正整数，world/location 为非空字符串，`conversation_type` 与 `sender_type` 使用上述值。`stream_type` 可省略或为空；`ts`、`trigger_uid`、发送者名称/ID 可省略，`err_no` 省略时按 0 处理，非零业务错误不入队。旧的无正式 ID 的通知形态不再接受，不再用时间戳和内容生成临时去重键。
- `conversation_round_id` 可省略或为 `null`；提供非空值时必须是正整数，`0`、负数、字符串和小数均无效。缺省表示该消息不关联对话轮次，不生成临时/替代轮次号；仍正常入地点队列、排序、去重、持久化、展示并更新实时角色位置，HTTP 回填和本地恢复遵循相同语义。缺省消息不建立轮次等待锁、不等待 `end_conversation_round`，也不通过自身入场揭露动画阻塞 Send。已有的 Tick、发送、其他轮次和回复动画等待仍生效，不因收到该消息而解除。
- 携带正数 `conversation_round_id` 时保留原有轮次处理；独立的新移动轮次可由同世界、同地点、同轮次的成功 `end_conversation_round` 结束。不通过省略轮次字段解除其他消息的等待状态。
- `payload.content` 为数组，每项 `char_id/old_loc_id/to_loc_id` 为非空字符串。保留原始 payload 和 old_loc_id；一个消息只占用一个地点游标/缓存行。展示时与 Tick 共用聚合规则：单条消息内按去除首尾空白后的 `to_loc_id` 分组，不区分出发地，目的地按首次出现顺序排列，姓名按原顺序拼接且不去重。聚合不改写原始记录，也不跨消息合并。空数组可保留正式消息和游标，但不生成卡片。
- 收到后按顶层 `location_id` 通过普通消息 upsert 写入地点队列和 SQLite，使用 `location_message_id` 排序、分页和去重。不会按移动数组额外广播或复制到出发/目的地点，不合并不同正式消息中的同一角色。HTTP V2 messages 回填同样解析，和 WSS/SQLite 恢复共用 ID 语义。
- 实时收到合法消息时，同时按每项 `char_id → to_loc_id` 更新世界角色位置及地点实体索引，地图通过已有世界状态订阅刷新。每个角色记录最近应用的私聊移动 `global_message_id`，重复/较旧的同类事件只入消息队列、不回退位置；切换账号或世界清空此记录。HTTP 历史回填与 SQLite 恢复不重放位置变化。没有世界快照或缺少角色资料时走已有世界详情刷新。
- 不依赖 MiniPhone 是否打开、是否返回、是否仍处于观察期；不再维护页面临时行、位置差异或公共消息消重观察。覆盖页面时队列照常更新，返回按正常聊天恢复渲染。角色/地点名称和地点图仍从已有世界信息解析，目的地点击行为保持原样。
- 该正式消息沿用 History 变更提示；History 的实际内容仍从独立 HTTP 档案接口获取，不能将 WSS 行直接作为档案结果。
- 此处记录客户端支持的新契约；真实后端和设备联调需独立验证。

### Go On：创建新的续写轮次

2026-09-08：依据 `go-on-client-guide.md`。`ChatroomSession.goOn(locationId, sourceConversationRoundId, clientMsgId)` 只在已认证 V2、成功 join 目标地点后发送一次：

```json
{"type":"go_on","world_id":"world_001","client_msg_id":"go-on-001","payload":{"location_id":"loc_001","source_conversation_round_id":101}}
```

来源轮次为正整数 int64，不能放在外层 `conversation_round_id`；请求不带 content、message、card_id 或操作者 UID。请求 ID 必须非空，不能重复占用在途 ID。最新来源、本人归属、Tick 与计费资格由后端校验，客户端接口不判断按钮状态。

```json
{"type":"ack","world_id":"world_001","location_id":"loc_001","conversation_round_id":102,"client_msg_id":"go-on-001","payload":{"billing":{"price":1,"price_cent":120,"pricing_version":"round_v3"}},"err_no":0,"err_msg":""}
```

成功返回 `ChatroomGoOnReceipt`，包含世界、地点、来源轮次、新轮次、请求 ID 和可选 `ChatroomRoundBilling`。匹配世界/地点并验证新轮次后，ACK 即完成 Future；不等待用户消息回显或三层正式消息 ID。`receiptConversationRoundId` 与历史消息元数据分开，不改变 `hasCanonicalMessageMetadata`。billing 不要求候选专用 status；缺失价格不补造，精确费用取 price_cent（示例 1.20 Gem），接口不刷新或增减钱包。Location Chat 的 Go On 在 ACK、结束或不确定结果前后都不主动拉取正式历史；正式历史只由 `conversation_range_updated` 更新，连接初始化/重连的系统级同步除外。

**Go On 的 client_msg_id 不提供业务幂等。** ACK 超时、发送异常、断线均返回异常且绝不自动重发/重连补发；超时代表结果不明，不能据此判断服务器未受理。迟到 ACK 仍通过 events 暴露。后续业务恢复须按新轮次查询历史，无 ACK 时没有按请求 ID 查询受理结果的接口。未知请求关联与迟到结果恢复由客户端统一 Send 管理器及回复控制器维护，不新增服务端查询接口。

正式 waiting/character/narrator/end 事件按世界、地点、新轮次正常分发，可能先于 ACK 到达。`llm_stream_end` 只结束一条消息，`end_conversation_round.err_no=0` 也不保证整轮已成功持久化。接口不创建 Go On 用户气泡，不拼装候选到正式历史。

V2 `type=error` 解析为 `ChatroomErrorEvent`，保留 world/location/round/user/client 请求上下文、数值 `errNo` 及兼容字符串 `code`。入队前失败为错误 ACK；ACK 后的 error 可能没有 client_msg_id，依靠新轮次关联。保留所有服务端错误码，不用英文提示文本作为枚举；仅 end 或流中断也不代表可自动重试。

普通 Send 的 `type=error` 同样按请求／轮次结束对应会话：立即释放本地发送锁和回复等待，已知回复轮次标记失败，保留用户消息并沿用错误 Toast；不自动重发、不等待超时兜底。请求与轮次标识均缺失、World／地点不匹配或明确属于旧会话时，不解除新会话的锁；独立 World Tick 等待不受影响。释放本地等待不等于证明未受理或未扣费。

### LLM 轮次卡片命令与私有事件

2026-09-08：依据 `llm-round-cards-client-guide.md` 1.1 版。本次只接入协议能力，不加入重生成按钮、自动选卡、候选拼装、轮询或本地待提交记录；服务端部署状态需另行联调确认。

仅支持 V2（合法 `x-app-version > 0.3.3`），复用当前已认证连接。最新完成轮次、轮次发起人、次数上限和计费资格由服务端校验。

```json
{"type":"regenerate_llm_card","world_id":"world_001","conversation_round_id":7358,"client_msg_id":"regen-7358-1","payload":{"location_id":"loc_1"}}
{"type":"select_llm_card","world_id":"world_001","conversation_round_id":7358,"client_msg_id":"select-7358-1","payload":{"location_id":"loc_1","card_id":9902}}
```

`ChatroomSession.regenerateLlmCard` 要求当前已加入目标地点；`selectLlmCard` 允许补报旧地点。两者要求调用方提供 1～128 字符幂等 ID，禁止重复占用在途请求 ID；不会自动重发，调用方负责用同一 ID 恢复请求。
不携带操作者 UID，也不提供 HTTP 重生成接口。

成功 ACK 保持 receipt-only，不带正式消息三层 ID。`ChatroomAck.receiptConversationRoundId` 保存受理轮次（`cardConversationRoundId` 保留兼容别名），`regeneration` / `selection` 是独立类型，`hasCanonicalMessageMetadata` 不因此变为 true。

- `ack.payload.regeneration`：`conversation_round_id`、`original_card_id`、`card_id`、`generation_state`、`billing`，失败已有候选还可包含 `error`。ACK 成功仅表示受理/恢复已有状态，不代表生成成功。
- `ack.payload.selection`：与 HTTP select 的 `ChatroomCardSelection` 完全相同，含最终卡和刷新范围。接口仅返回结果，未接业务刷新或自动确认。
- 错误 ACK 保留现有 `ChatroomFailureEvent` code/message/clientMsgId/requestType，不当作候选成功。

余额失败补充（2026-09-11，目标环境须部署 regenerate 前置余额预检查）：

- Go on 与 regenerate 都可返回外层 `err_no=3001`、`payload={}`。按外层 `client_msg_id` 关联请求，立即撤销本次等待并保留原回复；Go on 不创建新轮次或气泡，regenerate 不新增候选或次数。错误 ACK 的 `location_id`、`trigger_uid` 可以缺失或为空。
- regenerate 外层 `0` 必须继续读取内部状态：`failed` 读取 `error.err_no` / `error.err_msg`，保留真实失败候选以计次、立即恢复此前完整卡，并刷新卡组和钱包；`succeeded` 查询完整卡片（幂等回执不重放流）；仅非终态继续等待。
- 余额相关错误只识别 `3001`、`21001`，复用发消息的错误 Toast、Gems 购买 Sheet 与钱包刷新；其余错误走通用失败提示。`3001` 也可能表示余额检查服务异常，不将余额本地设为 0。
- `llm_card_generation_end` 与失败 ACK 可重复或乱序到达；有候选按 world / location / round / card 去重，无候选按 world / client_msg_id 去重，同一失败只提示一次。transport timeout 与后续明确业务拒绝分别处理，不能让超时吞掉充值提示。
- ACK 超时后保留请求关联，仍消费迟到的明确错误及 regenerate 终态回执。迟到结果须匹配原请求和轮次，不能覆盖用户后来发起的新操作；成功回执查卡失败时保留真实候选、显示此前完整回复并刷新钱包，后续通过只读查询恢复内容。
- 失败候选仍占用每轮最多 9 次的机会，次数以卡组真实记录为准。`billing.status=cancelled/reserved`、`price_cent=null` 不用于本地增减钱包。充值后只刷新，由用户主动再次操作；不自动重发 Go on，不改变既有结果不明时的恢复流程。

候选流：

```json
{"type":"llm_card_stream","stream_type":"chunk","world_id":"world_001","location_id":"loc_1","conversation_round_id":7358,"global_message_id":8701,"user_id":"user_001","sender_type":"character","sender_id":"char_1","sender_name":"Alice","payload":{"card_id":9902,"card_message_index":1,"seq":1,"content":"Hello","current_time":"Day 1, 12:00"},"err_no":0,"err_msg":""}
```

`ChatroomLlmCardStream` 只接受 start/chunk/end；卡内序号从 1 开始，chunk 必须有正数 seq，content 是增量，end 是该条完整正文。与普通 `llm_stream_*` 路由隔离，每条候选携带正整数 `global_message_id`，从 start 到最终采用保持稳定；不携带正式 `message_id/location_message_id`。候选不进入正式队列、持久化缓存或现有 AI 流拼装，也不发送客户端 ACK。当前仅分发事件，未来业务层按 `(card_id, global_message_id, seq)` 去重、按固定 `card_message_index` 排序，不能使用数组下标定位编辑目标。

整张卡终态：

```json
{"type":"llm_card_generation_end","stream_type":"","world_id":"world_001","location_id":"loc_1","conversation_round_id":7358,"user_id":"user_001","payload":{"card_id":9902,"generation_state":"succeeded","billing":{"status":"committed","price_cent":180,"pricing_version":"round_v3"}},"err_no":0,"err_msg":""}
```

`ChatroomLlmCardGenerationEnd` 只接受 succeeded/failed；失败保留 payload.error、外层错误号和信息。单条流 end 不等于整卡成功。私有事件在 session 按世界、用户隔离，可通过 events 或 ChatroomMessageHandlers 的 onLlmCardStream/onLlmCardGenerationEnd 消费。

generation_state：preparing / queued / generating / succeeded / failed。
billing.status：not_required / not_started / reserved / committed / cancelled；price_cent 为整数 cent 或 null，pricing_version 原样保存。原卡 not_required 不表示原始消息免费。ACK、终态模型不推算费用，不进行预占、结算或退款。

断线不迁移/重播私有流，恢复依赖 GET /cards；后续业务需按指南实现退避查询、待确认记录及固定卡触发。目前没有自动重生成、后台轮询、自动选卡或新消息拦截。
确认产生的 `conversation_range_updated` 是正式历史范围刷新的唯一业务入口；选卡响应、Regenerate、Go On、Edit 和灵感回复自身均不触发该机制。

### `conversation_range_updated`（批量编辑 / 删除）

2026-09-08：批量 POST 成功后，无论纯编辑、纯删除或混合操作，统一向同世界、地点的 V2 连接广播一次，包含操作人。新接口不再发送 `llm_message_updated`。客户端保留旧编辑事件解析仅作旧版本通知兼容；新批量链路不依赖它。

```json
{"type":"conversation_range_updated","stream_type":"","ts":1788854400000,"world_id":"world_001","location_id":"loc_2_2_2","payload":{"start_conversation_round_id":7358,"end_conversation_round_id":7362,"newest_message_id":84},"err_no":0,"err_msg":""}
```

此事件是控制通知，不携带正文或删除列表，不追加普通气泡、不进入流式拼装、不发送客户端 ACK；`ts` 不作为版本号。

- 只有 WS `conversation_range_updated` 启动业务范围刷新；HTTP 成功响应中的范围只作协议返回，不由 Reply Actions 或批量编辑入口主动消费。
- 收到范围后废弃旧历史请求与分页状态；从 `since=0, limit=100` 开始，携带原闭区间，以已返回的最小正 `location_message_id` 前翻，直到 `has_more=false`，游标不前进视为失败。
- 新范围到达时取消旧请求、合并未完成范围并重拉；全部页成功后在内存与 SQLite 原子替换闭区间，空结果也清除旧消息，范围外保留。失败不提交部分结果，保留待刷新范围。
- 消息按稳定全局 ID 去重、按新地点序号排序。地点最新序号允许降低到 0，不复用世界 `lastMessageId`。SQLite 沿用版本 4 和每地点 200 条上限，写入按地点串行。
- 初始化、补洞、缓存读取和翻页受请求代次保护；活跃流式缓存独立，完成事件与刷新协调，旧历史响应不得覆盖新内容。
- 加入、重连或显式 `refreshLocationHistory` 属于系统级同步，从最新页重建最多 200 条缓存。网络写入结果不明时等待范围事件或后续连接级同步，不自动重发整批。
- 编辑状态 `status=20` 由服务端保存，历史不包含该状态；客户端不新增已编辑视觉标记。

### `waiting_conversation_round`

普通 `send_message` 或 `user_enter_location` 自动触发 P3 时，Chat 服务在处理本轮消息前发送以下 V2-only 控制事件：

```json
{
  "type": "waiting_conversation_round",
  "stream_type": "",
  "ts": 1785890000000,
  "world_id": "world_001",
  "location_id": "loc_001",
  "conversation_round_id": 301,
  "payload": {},
  "err_no": 0,
  "err_msg": ""
}
```

客户端按 `location_id` 保存等待中的 `conversation_round_id`，并同时禁用该地点的 Send 按钮和发送/重试入口。该事件不渲染气泡、不写入消息缓存。用户主动发送从调用 `send_message` 时立即建立统一操作；服务端主动 P3 从收到 waiting 时建立操作。普通等待连续无有效进展 15 秒上报、20 秒释放；同一轮重复 waiting 不刷新进展。

### `end_conversation_round`

本轮所有普通消息完成后，服务端发送字段与 waiting 对称的结束事件：

```json
{
  "type": "end_conversation_round",
  "stream_type": "",
  "ts": 1785890001000,
  "world_id": "world_001",
  "location_id": "loc_001",
  "conversation_round_id": 301,
  "payload": {},
  "err_no": 0,
  "err_msg": ""
}
```

只有 `err_no=0`、同地点且同 `conversation_round_id` 的 end 可以正常结束该轮等待。Character、Narrator、Tick 和单条 `llm_stream_end` 不伪造 V2 整轮完成。旧轮次、其他地点、重复或错误 end 不能清理新操作。

所有本地 Send 超时统一由账号会话级 `LocationChatSendGate` 调度：普通等待停滞 15 秒上报、20 秒释放；首条有效 start／chunk 后使用 5 秒流式停滞规则，同时上报和释放；World Tick 按本次锁定总时长 60 秒处理，仅解除其对 Send 的本地阻塞。所有已开始的流结束后，若仍需整轮或候选终态，转回普通等待。重复帧、旧尝试、无变化查询、重试提示和展示动画不能延长流式期限。

普通 Send、Regenerate、Go On 均不因 ACK 超时自动重发。保留 ACK／HTTP 通信超时、正常重连和历史同步；删除旧普通整轮、普通流、候选／Go On 生成计时器及 ACK 展示／正式回显业务超时。超时释放不以查历史或查卡成功为前提，不把未知结果转换成成功或明确失败。

后台、断线、页面重建及同会话服务重建不重置已记录的截止时间；回到前台或重新进入时校验当前状态并处理到期记录。迟到真实结果可恢复内容，但旧回调、finally 和回显不能清除新锁或重新加上旧锁。`snapshotForActions`、`snapshotForPresentation` 及 prepared entry 同步 `sendReleased`／本地展示收尾状态。

场景代码、阶段、释放动作与 `action_type=chat_timeout` 的完整字段定义见 [统一超时机制与埋点表](location-chat-send-gate.md)。

进入 LocationChat 后，初始消息渲染收尾时检查残留 Send 等待。没有已有计时记录的残留锁，按最后一条实际消息分类：普通消息补登记普通 15／20 秒等待，Tick 消息接入 World 级 60 秒计时。已有操作沿用原阶段和截止时间，历史渲染不作为实时流活动；重新进入不重置期限。

Tick 解锁后，V2 还会收到世界级结束通知，顺序为 `tick_done → end_conversation_round → world_change`。同一世界各地点接收同一条通知，复用 Tick 的真实 int64 `conversation_round_id`，不逐地点重复发送：

```json
{"type":"end_conversation_round","stream_type":"","ts":1785890005000,"world_id":"world_001","conversation_round_id":302,"trigger_uid":"","payload":{},"err_no":0,"err_msg":""}
```

此分支不下发 `location_id`、`user_id`，也没有配套 waiting。客户端允许缺失地点，按 `world_id + conversation_round_id` 结束已有对应轮次的等待状态；不创建聊天气泡、空地点轮次或清除其他 P3 轮次。重复通知幂等，本地无对应等待轮次时不修改等待状态。`err_no=0` 仅表示结束通知无错误，不代表 AI 内容生成成功。通知可能缺失且不会自动补发，世界推进仍由 `tick_done` 解锁，不等待此事件。带地点的 P3 结束处理保持原规则。

Tick reply 资格仅从正式 `type=tick` 消息及其正数 `conversation_round_id` 确定，WSS 与历史消息共用该规则，缺失 `conversation_type` 时也识别为 Tick。`tick_start`、`tick_done`、`end_conversation_round` 不参与 Tick 来源识别，不凭控制事件创建没有正式消息的回复来源。`tick_start/tick_done` 仍负责世界推进输入锁；`tick_done` 触发的详情刷新在后台继续。世界推进结束时，地点聊天同时清除本地 Tick 等待及 `Progressing the World` 占位，不等待正式 Tick 正文、详情刷新或结束轮次通知；失败或无正文也按此收尾，迟到的正式 Tick 正常展示。仅解除本次 Tick 等待，其他对话轮次、回复生成及资格限制继续生效。当前地点最新的正式 Tick 在连接就绪、世界推进解锁且无其他操作锁时，Go On、Inspiration 为 `idle`，Edit、Regenerate 为 `none`；不需要 waiting、AI 回复或 end。

# Legacy WebSocket 适配附录

以下章节描述 `x-app-version` 为空、非法或 `<=0.3.3` 时使用的旧协议。实现入口是 `chatroomLegacyEventFromEnvelope`；不要把旧别名或 ACK echo 回退扩散到 V2 路径。

## 1. 概览

| 项 | 值 |
| --- | --- |
| OpenAPI | `3.0.3` |
| 标题 | `AITown Chat WebSocket API` |
| 版本 | `2.5.0` |
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

`join`、`send_message`、`heartbeat`、`leave` 的业务字段直接放在顶层；`user_enter_location` 使用客户端通用消息外层，并将地点放在 `payload.loc_id`。

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

### 3.2 `user_enter_location`

显式触发用户进入地点消息。该命令与 `join` 完全独立，不要求固定先后顺序；客户端每次显式地点进入只发送一次，自动重连不补发。命令不携带 `client_msg_id`，服务端成功受理不发送 ACK；Tick 锁定或入场历史规则不满足时可能静默忽略。

```json
{
  "type": "user_enter_location",
  "ts": 1785890000000,
  "world_id": "world_001",
  "payload": {
    "loc_id": "loc_001"
  },
  "err_no": "",
  "err_msg": "",
  "broadcast": false
}
```

### 3.3 `send_message`

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

### 3.4 `heartbeat`

心跳消息。

```json
{
  "type": "heartbeat"
}
```

### 3.5 `leave`

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
| `schema_version` | `integer` | 否 | 事件 schema 版本；Flutter 会解析并保留 |
| `event_id` | `string` | 否 | 事件 ID；Flutter 会解析并保留 |
| `ts` | `integer(int64)` | 是 | 毫秒时间戳 |
| `world_id` | `string` | 是 | 世界实例 ID |
| `payload` | `object` | 是 | 个性化消息载荷 |
| `session_id` | `string` | 否 | 会话 ID，排查用 |
| `global_msg_id` | `integer(int64)` | 否 | 全局消息 ID，全局递增 |
| `msg_id` | `integer(int64)` | 否 | 消息 ID，world 级别递增 |
| `location_msg_id` | `integer(int64)` | 否 | 地点消息 ID，location 级别递增；世界级消息为 `0` |
| `conversation_round_id` | `integer(int64)` | 否 | 对话轮次 ID |
| `tick_no` | `integer` | 否 | Tick 序号；既可位于顶层，也兼容从事件 payload 读取 |
| `sub_tick_no` | `integer` | 否 | 当前 Tick 内的子 Tick 序号；与 `tick_no` 组合显示为 `Tick {tick_no}-{sub_tick_no}` |
| `user_id` | `string` | 否 | 用户 ID |
| `sender_id` | `string` | 否 | 发送者 ID |
| `sender_name` | `string` | 否 | 发送者名称 |
| `location_id` | `string` | 否 | 地点 ID |
| `current_time` | `string` | 否 | 世界时间，如 `Day 45, 19:30` |
| `err_no` | `string` | 是 | ack 错误码；成功为空字符串 |
| `err_msg` | `string` | 是 | ack 错误信息；成功为空字符串 |
| `broadcast` | `boolean` | 否 | 是否为世界广播 |

Flutter 解析器忽略 envelope 和 `payload` 中未识别的扩展字段，但不将未知的外层 `type` 当作已知事件处理；该单个事件记录为 `protocol_error` 后丢弃，WebSocket 连接继续。

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
| `world_new_message` | 世界某地点产生新对话 | Flutter 忽略 legacy `detail_url`：有 `location_id` 时调用 `/aitown-chat/api/v2/messages` 刷新该地点，无地点时限并发刷新当前世界的叶子地点 |

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

#### 5.2.1 世界时间线增量事件

| 事件 | 必需字段/载荷 | Flutter 行为 |
| --- | --- | --- |
| `user_enter_location` | 新版正式消息携带正数 `msg_id/location_msg_id`、真实 `location_id/sender_id/user_id` 与 `payload: { content, message_type }` | 转换为正式 `WorldChatroomMessage`，进入地点队列并持久化，同时调用 `/aitown-chat/api/ulocation` 刷新玩家位置；兼容旧 `{ char_id, to_location_id, text }` 通知形态 |
| `story_events` | 顶层 `msg_id > 0`；`payload` 可为 grouped `{ location_id, location_name, paragraphs }`，也可为 flat single-event `{ location_id, timestamp, visibility, visible_to, text, clue }` | 两种形态统一归一化为段落列表，立即转换为正式 `WorldChatroomMessage`，进入地点队列并持久化；后续 HTTP 同 `message_id` 消息替换该项，不重复显示 |
| `map_updated` | `payload: {}` | 递增 `WorldChatroomState.mapUpdatedRevision`，并与同批 `world_change`、`tick_done`、`character_updated` 合并刷新一次 world detail；从 `locations` 中筛选新增 ID、`level=3` 且 `is_new=true` 的项后发布顶部 Push 通知 |
| `character_updated` | `payload: {}` | 与同批 world detail 刷新合并；从 `characters` 中筛选新增 ID 且 `is_new=true` 的项后发布顶部 Push 通知 |
| `characters_moved` | `payload: { movements: [{ char_id, to_loc_id }] }`；正式消息优先携带顶层 `msg_id > 0`，`location_id` 可为空表示世界广播 | 有正式消息 ID 时直接进入 location/world 队列并持久化；空地点广播复制到所有叶子地点。兼容旧 envelope 缺少 `msg_id` 的通知形态：先以临时 ID 立即入队渲染，再通过 HTTP 拉取 canonical 消息原位替换；两种来源共用人物去向气泡 |

grouped 形态的 `story_events.payload.paragraphs[]` 字段：

- `timestamp`: string
- `visibility`: `public` 或 `char_only`
- `visible_to`: string[]；`char_only` 时必须非空
- `text`: string
- `clue`: string

flat single-event 形态直接将同一组 `timestamp/visibility/visible_to/text/clue` 字段放在 `payload` 顶层，不携带 `paragraphs`；客户端将其归一化成 `location_name: ""` 且只包含这一项的段落列表。HTTP `sender_type=story_events` 的 `content` JSON 字符串使用完全相同的两形态兼容规则。

示例：

```json
{
  "type": "story_events",
  "schema_version": 1,
  "event_id": "evt_story_001",
  "ts": 1785890000000,
  "world_id": "world_001",
  "location_id": "loc_station",
  "global_msg_id": 5626,
  "msg_id": 232,
  "location_msg_id": 0,
  "conversation_round_id": 6816,
  "tick_no": 4,
  "sub_tick_no": 1,
  "sender_id": "sub_tick",
  "sender_name": "sub_tick",
  "payload": {
    "location_id": "loc_station",
    "location_name": "旧火车站",
    "paragraphs": [
      {
        "timestamp": "Day 4, 18:46",
        "visibility": "public",
        "visible_to": [],
        "text": "远处传来列车的汽笛声。",
        "clue": ""
      }
    ]
  }
}
```

`story_events.msg_id` 缺失、为 `0` 或负数时，该帧按 `protocol_error` 丢弃，不进入消息队列或持久化。typed payload 格式不合法时同样只丢弃该帧，WebSocket 连接保持可用。

`characters_moved` 携带正数 `msg_id` 时直接作为正式消息处理；顶层 `location_id` 非空时进入该地点，为空时作为世界广播复制到所有叶子地点。兼容旧版仅有 `event_id/ts/world_id/payload` 的通知 envelope：typed payload 校验通过后，客户端先生成仅存在于内存的临时消息并立即加入所有叶子地点队列，再通过 `/aitown-chat/api/v2/messages` 对有地点的通知刷新该地点、对无地点通知限并发刷新叶子地点；canonical 记录按归一化后的 movements payload 原位替换临时项并持久化。V2 地点聊天运行时不调用 internal world messages 或 legacy messages 接口。即使 HTTP 暂时失败，本次 WSS 消息仍会立即显示；`movements[]` typed payload 非法时，该帧按 `protocol_error` 丢弃，连接继续。

HTTP 与 WebSocket 的合法 `characters_moved` 最终使用同一个气泡：标题为“人物去向”，每条 movement 显示“角色名 has gone to 地点名”。地点名可以点击；目标与当前地点不同时，客户端切换到目标地点聊天。V2 Tilemap 会在切换前登记目标地点，关闭目标聊天后重建到承载该地点的父级地图，并将视口聚焦到目标地点。

### 5.3 `tick_advance`

世界时间推进消息。格式与普通内容消息一致，顶层 `current_time` 和 `payload.content` 值相同；`payload.tick_no` 是页面展示的 Tick 编号。历史消息接口中对应 `sender_type: "tick"`，并应携带 `tick_no`。只有该事件投影出的零 `location_msg_id` legacy Tick 继续以 world `msg_id` 作为 supplemental 排序和双游标边界；带正数地点游标的 Tick 与其他 canonical V2 消息完全一样按 `location_message_id` 处理。

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

旁白或角色旁白式消息。`payload` 使用 `UserMessagePayload`，不再使用系统通知 payload。`payload.message_type` 表示内容类型：`text` 为文本，`image` 为图片且 `content` 保存图片 URL。字段缺失时，旧 `sender_id=nar_pic` 消息兼容为 `image`，其他发送方按 `text`；字段存在但为 `null` 或空字符串时按 `text`。

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
  "sender_id": "nar_pic",
  "sender_name": "Narrator",
  "payload": {
    "content": "https://example.com/images/scene.jpg",
    "message_type": "image"
  }
}
```

该增量只增加 `payload.message_type`，不改变事件名、顶层消息 ID 字段或已有 envelope。Flutter 读取时去除首尾空白并转为小写。只有 `message_type=image` 且 `sender_id=nar_pic` 的消息渲染图片；`image` 但发送方不是 `nar_pic`、以及其他未知非空类型，均保留在消息模型和缓存中但不渲染。

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

响应消息字段按当前 HTTP 文档的 `MessageDTO`：`global_message_id` 全局递增，`message_id` world 级别递增，`location_message_id` location 级别递增；`sender_type` 取值为 `user`、`character`、`narrator`、`npc`、`tick`、`user_enter_location`、`story_events` 或 `characters_moved`。`user_enter_location.content` 为纯文本入场文案；`story_events/characters_moved.content` 为 JSON 字符串。所有正数 `location_message_id` 均参与地点连续窗口、补洞、分页、本地 key 和去重。零游标 legacy 记录继续兼容入队和展示，但只有 `tick`（旧 `tick_advance` 投影）按 world `message_id` 排序并使用双游标分页/删除；零游标 `user_enter_location/story_events/characters_moved` 不参与 location continuity、gap 或分页边界。`sub_tick_no` 为可选整数；正数时与 `tick_no` 组合显示，例如 `tick_no=4, sub_tick_no=1` 显示为 `Tick 4-1`。`message_type` 取值为 `text` 或 `image`，图片 URL 保存在 `content`。字段缺失时，旧 `sender_id=nar_pic` 消息兼容为 `image`，其他发送方按 `text`；字段存在但为空时按 `text`。只有 `image + nar_pic` 渲染图片，其他图片发送方和未知类型只存储、不渲染。`created_at` 格式为 `2006-01-02 15:04:05`。

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
        "message_type": "text",
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
        "message_type": "text",
        "current_time": "Day 45, 19:30",
        "created_at": "2026-07-01 10:05:00"
      },
      {
        "global_message_id": 90003,
        "message_id": 1003,
        "location_message_id": 103,
        "location_id": "loc_001",
        "conversation_round_id": 7003,
        "tick_no": 7,
        "sender_type": "narrator",
        "sender_id": "nar_pic",
        "sender_name": "Narrator",
        "user_id": null,
        "content": "https://example.com/images/scene.jpg",
        "message_type": "image",
        "current_time": "Day 45, 19:35",
        "created_at": "2026-07-27 10:06:00"
      }
    ],
    "has_more": false,
    "newest_message_id": 1003
  }
}
```

## 7. 状态码与错误码

### 7.1 成功状态

| 场景 | 字段/状态码 | 说明 |
| --- | --- | --- |
| WebSocket 建联 | HTTP `101` | `Switching Protocols`，WebSocket 连接成功 |
| Chatroom HTTP API | HTTP `200` | HTTP 请求成功，业务结果继续看响应体 |
| `/aitown-chat/api/ulocation` | `err_no: 0` | 业务成功 |
| `/aitown-chat/api/messages` | `code: 0` | 业务成功 |
| WebSocket `ack` | `err_no: ""` | ack 成功；`err_msg` 同样为空字符串 |

注意：`ack.err_no` 在当前协议中是 `string`，成功值为空字符串 `""`；HTTP 接口里的 `err_no` 通常是 `integer`，成功值为 `0`。

### 7.2 WebSocket 错误 `1xxx`

| 错误码 | message | 注释 |
| --- | --- | --- |
| `1001` | 参数错误 | 请求参数不正确 |
| `1002` | 消息格式错误 | WebSocket 消息 JSON 格式不正确 |
| `1003` | 未知消息类型 | 发送了不支持的消息类型 |
| `1004` | 已加入聊天室 | 用户已经在当前聊天室中 |
| `1005` | 未加入聊天室 | 用户未加入聊天室，无法发送消息 |
| `1006` | join 消息格式错误 | join 消息 JSON 格式不正确 |
| `1007` | user_id、sender_id、sender_name 必填 | join 消息缺少必填字段 |
| `1008` | send_message 消息格式错误 | send_message 消息 JSON 格式不正确 |
| `1009` | content 必填 | 消息内容不能为空 |
| `1012` | 未建立连接 | WebSocket 连接未建立 |
| `1013` | location_id 必填 | 地点 ID 不能为空 |
| `1014` | 地点不存在 | 该地点不在当前世界中 |
| `1015` | 被踢下线 | 您已在其他设备登录 |

### 7.3 业务错误

| 错误码 | message | 注释 |
| --- | --- | --- |
| `3001` | 余额不足 | 用户余额不足，请充值后重试 |
| `21001` | 费用预占余额不足 | 已创建的 regenerate 候选可能透传此错误；刷新钱包并展示 Gems 购买入口 |
| `2001` | 创建会话失败 | 创建 Session 时发生错误 |
| `2002` | 生成消息ID失败 | Redis 生成消息 ID 失败 |
| `2003` | 生成轮次ID失败 | Redis 生成轮次 ID 失败 |
| `2004` | 保存消息失败 | 消息持久化失败 |
| `2006` | 世界正在推进中 | Tick 锁定中，请稍候 |
| `2010` | 消息发送过于频繁 | 消息发送过于频繁，请稍后重试 |

注：YAML 中该分组标记为 `业务逻辑错误 (2xxx)`，但包含 `3001` 余额不足，客户端应按具体错误码处理，不只按首位范围判断。

### 7.4 内部错误 `5xxx`

| 错误码 | message | 注释 |
| --- | --- | --- |
| `5000` | 服务暂时不可用 | 内部服务错误 |

### 7.5 认证错误 `100xx`

| 错误码 | message | 注释 |
| --- | --- | --- |
| `10001` | 未授权 | 请先登录 |

## 8. Flutter 实现约定

- `ChatroomClient.connect` 使用 `GENESIS_CHATROOM_WS_URL` 拼接 `world_id` query，并通过 `Authorization: Bearer ...` 建联。
- `join`、`send_message`、`heartbeat`、`leave` 上行消息只使用顶层字段；`join` 只发送 `client_msg_id`、`world_id`、`location_id`。
- `user_enter_location` 使用通用外层和 `payload.loc_id`，不携带 `client_msg_id`、不等待 ACK、不超时重试；只在显式地点进入时发送一次，发送失败不影响 `join` 状态，自动重连不补发。
- `heartbeat` 只发送 `{ "type": "heartbeat" }`，不携带 `client_msg_id`，也不等待 ack。
- 服务端错误只接受 `type: "ack"` 携带 `err_no` / `err_msg`；不兼容旧 `type: "error"` 或 `err_code`。
- `send_message` 的 ack 必须通过 `payload.client_msg_id` 匹配；服务端缺失该字段时请求会超时。
- `join()` 只接受携带相同 `payload.client_msg_id` 的 `ack` 作为完成信号。
- `tick_advance` 会进入所有叶子地点的消息队列，Flutter 展示为系统时间推进提示；`sub_tick_no > 0` 时文案为 `Tick {tick_no}-{sub_tick_no} · {current_time}`，缺少子 Tick 时保持 `Tick {tick_no} · {current_time}`。历史消息里的 `sender_type: "tick"` 同样处理。
- 新版 `user_enter_location` 下行先进入正式地点消息队列、缓存和现有入场气泡，再与旧通知形态一样通过 `/aitown-chat/api/ulocation` 刷新完整玩家位置快照；并发刷新由单 active + trailing 调度合并。
- `story_events` 必须携带正数 `msg_id`，并复用正式消息队列、缓存和 message-id 去重；不创建无 ID 的瞬时消息。WS `payload` 与 HTTP `content` JSON 都兼容 grouped `paragraphs[]` 和 flat single-event，两者归一化后走同一气泡渲染。
- `characters_moved` 有正数 `msg_id` 时直接使用正式消息队列、缓存和 message-id 去重；空 `location_id` 广播到所有叶子地点。旧版缺少 `msg_id` 的 envelope 会先以临时消息立即入队，再通过地点 V2 HTTP canonical 消息同步并原位替换；最终与 HTTP 记录共用可点击地点的人物去向气泡。
- `world_change`、`tick_done`、`map_updated`、`character_updated` 共用单 active 的 world detail 刷新调度；同一事件循环内的通知合并为一次请求，刷新期间的新通知最多触发尾随刷新，不并行请求。
- `map_updated` 仍发布递增 revision 供 Tilemap 刷新；location 只从 detail 的 `locations` 中筛选同时满足“ID 不在刷新前快照中”、S3（优先 `level=3`，缺失时按 location tree depth 判断）且 `is_new=true` 的项，character 继续按“新增 ID 且 `is_new=true`”筛选，生成去重后的顶部 Push 通知。
- `llm_stream_start`、`llm_chunk`、`llm_stream_end` 在 Flutter 内部仍复用 `ChatroomAiMessageStream` 事件模型。
- 原始帧通过 `developer.log(name: 'ChatroomSocketFrame')` 输出到 Flutter DevTools Logging。
- DevTools Network 将同一回复的 `llm_stream_start/llm_chunk/llm_stream_end`（含 V2 `stream_type`）或同一卡片消息的 `llm_card_stream start/chunk/end` 合并为一条 `WS_RECV` 记录。收到首帧即创建，后续帧以 NDJSON 追加到响应正文，结束帧关闭记录；世界、地点、轮次、发送者、卡片和消息 ID 用于隔离并发流，无法唯一匹配的帧单独记录。Logging 和应用内原始帧抓取仍逐帧保留。
- Network 正文最多保留 64 KB，超限标注截断；同时最多保留 32 条活跃流，2 分钟无新帧、断线或检测到暂停录制时结束未完成记录。心跳及最近 1024 个已发送心跳 ID 对应的 ACK 继续过滤，普通消息和业务 ACK 保持单独记录。


## P1 / P1i 章节状态扩展（2026-09-23 客户端适配）

- V2 `type=tick` 的外层、游标、轮次与排序规则不变；payload 继续使用 `current_time`、字符串 `global`、`story_events`、`characters_moved`。
- 新增 `global_status: [{owner, icon, form, content}]`；每个 `story_events` 新增 `cast: [{id, name}]` 与 `status: [{owner, icon, form, content}]`。保留 `location_id/text/clue`；新结构不依赖 `visibility/visible_to`。`clue` 缺失或为空允许继续。
- `icon/form` 是动态文案，原样展示。支持全局状态 2 条、每地点状态 6 条、P1/P1i 地点块 10/6 个，按返回顺序展示；客户端不按提示词原目标再次截断。既有帧大小、字符串及集合安全上限仍生效。
- HTTP 历史和本地 payload JSON 保留相同内容；legacy `sender_type=tick` 的 JSON `content` 也解码，纯文本内容保持可读。根据字段存在性区分旧结构和合法空数组，不迁移数据库列。
- 新章节在聊天显示全部返回地点；旧章节保留原地点筛选、可见角色和时间信息，统一使用新的卡片内容布局。不存在的地点块在地点资料就绪后丢弃；无头像使用公共默认头像，名字优先角色档案、其次 `cast.name`。cast 排除用户 ID；非 world owner 必须属于本地点 cast。
- 仅 Tick 内容损坏时显示静态骨架，原始 payload 保留，后续有效历史记录可替换；外层 V2 校验继续执行。合法空数组不显示骨架。字段扩展不改变 Tick 等待和回复按钮资格。
- 此处为客户端目标契约与兼容行为，真实服务端发布状态需联调确认。

章节的 `global_status`，以及每个地点项（HTTP `paragraphs[]` / 聊天 `story_events[]`）的 `cast`、`status` 均为独立可选数组，可分别省略或同时省略；模型层统一按空数组处理，保留章节旁白、地点叙述和线索，不因此把整条 Tick 判为损坏。字段存在时仍校验数组类型及元素结构（`null` 不视为空数组）。适用于实时 Tick、历史消息、缓存恢复以及 World / Origin 地点段落；旧结构识别和可见性规则不变。


## MiniPhone V2 extension (client, 2026-10-13)

The existing world connection also routes `phone.messages.delivered`,
`phone.reply.updated` and `phone.post.notification.created`. Their business IDs,
request correlation, event ID, message batches and failure/notification data
remain in `payload`. They require no location and do not become LocationChat
messages. See `mini-phone-chat-client-api-2026-10-12.md` and
`mini-phone-client-integration.md` for the 2026-10-16 current dev contract.
Reply events support generating (nullable failure) and failed. Messages carry
request-correlated reply_status/failure for HTTP recovery; pushes have no offline
replay guarantee. Player peers do not emit AI reply-state events.

## 客户端持续断线监控（Collect）

`WorldChatroomService` 通过独立 `ChatroomDisconnectMonitor` 观察仍被业务需要的连接，不改变重连、join 或历史恢复逻辑。首次实际发起握手后，前台连续 15 秒仍未成功，或已成功连接异常断开后连续 15 秒未恢复，记录一次 `monitor / websocket_disconnect`。握手成功即取消观察，不等待 join/历史；重试不重置起点，无失败回调的连接卡住也覆盖。首次上报后，每次连接失败继续补报详情；握手恢复后清理本轮。主动断开、退出/切换 World、切账号、释放取消；后台取消，回前台仍需连接时重新观察 15 秒。异步网络读取期间恢复或取消会丢弃旧观察，旧 session/attempt 回调不能影响新观察。

| action_type | action | object1 | object2 | object3 | object4 | ext_data |
| --- | --- | --- | --- | --- | --- | --- |
| monitor | websocket_disconnect | World ID | initial_connect / reconnect | 详细诊断 JSON，见下文 | 上报时 network_type | 有界诊断 JSON |

`object3` 使用下文详细诊断 JSON，其中 cause 保留本轮起始原因（无失败回调时为 unknown），attempt_details 记录每次具体异常。关闭码仅取实际 socket 值，缺失不补造。心跳无 ACK 不作为断线依据，仅明确发送失败进入异常观察。`object4` 不上报耗时；类型为 `none / wifi / mobile / ethernet / bluetooth / vpn / satellite / unknown`，多类型去重后按上述具体类型顺序以英文逗号分隔，如 `wifi,vpn`；`none` 不与具体类型并存。只记录平台实际可检测信息：Android 读取 active NetworkCapabilities，iOS NWPath 仅明确提供 Wi-Fi/蜂窝/以太网，不推测 VPN、蓝牙或卫星；无法识别/读取失败为 `unknown`。这些类型不是互联网或服务端可达性证明。

通过 `GenesisTelemetry.collectLog` 进入既有 SQLite Collect 队列，沿用公共身份快照、event_id 和时间戳；离线重试不重建事件，不走 event/report、Firebase 或 Adjust，不套用 HTTP 采样。诊断不主动读取消息正文、Token 或请求头，底层异常与堆栈仅有界摘要。受控测试与本地编译不等于真机/Collect 服务端入库验收。


### websocket_disconnect 详细诊断（2026-10-27）

`action_type=monitor`；object1=world_id，object2=initial_connect/reconnect，object4=采样网络类型。object3 改为 JSON，包含 cause、connect_attempts、可用的 close_code/last_error_code，以及最近最多 10 条 attempt_details（截断历史不代表未发生）。object3 最多2000字符，ext_data 最多4000字符；超限优先删除旧详情并标记 history_truncated，确保 JSON 不被 Collect 截成非法字符串。

每条详情记录 attempt、UTC time、cause、连接失败时实测 connect_duration_ms、底层 error_type/error_message、SocketException 的 os_error_code/os_error_message、最多 8 行堆栈摘要，以及可取得的 ws_close_code/ws_close_reason/local_close_requested/local_close_reason。单条异常消息最多400字符、堆栈最多600字符。无原生信息不伪造：WebSocket.connect 不暴露 DNS/TCP/TLS 分段耗时，不上传这些字段及不可用原因；总耗时覆盖连接调用，不能解释为 TCP 耗时。

前台需要连接且持续断连15秒后首次上报，包含该观察窗口的失败详情；超过门槛后的每次失败补报。后台、恢复连接、取消连接或切换账号/世界清理观察。正常主动退出不新增异常事件。local_close_requested 是采样时真实 socket.close 调用状态，不能用后续清理动作倒推断连原因。连接恢复成功事件见下文。


### WebSocket 重试成功监控

`action_type=monitor`、`action=websocket_reconnect_success`。在首次连接失败后重试成功，或已建立连接异常中断后重新连接成功时上报；无需先达到15秒异常上报门槛。首次直接成功不报，同一成功回调不重复报，旧 attempt 忽略。成功表示底层 WS 连接建立，不代表 join、历史恢复或业务请求成功。

- object1：World ID。
- object2：retry_count。首次建联失败后的重试不含最初一次；已连接中断后的恢复，每次连接尝试均算重试，均包含最后成功的一次。
- object3：duration_ms，从本轮初始连接尝试/已知断连起到连接成功的前台累计毫秒数，包含前台重试间隔，排除后台停留。
- object4：initial_connect / reconnect。
- ext_data：connect_attempts（本轮连接尝试总数，含成功一次）、duration_unit=ms、duration_scope=foreground_recovery、success_stage=ws_connected。

前后台切换保留本轮恢复计数、暂停/恢复耗时累计；主动取消、切换账号/世界或释放清理恢复状态。打点异常不影响连接流程。

### AI 自动重试的 attempt 隔离与本地撤回

普通 P3／Go On 的 `llm_stream_start/chunk/end` 与候选 `llm_card_stream` 可在外层携带 `gateway_request_id`、正整数 `attempt_no`。两个字段同时缺省保留旧协议；部分缺失或非法值不推算。生成范围为世界、地点、轮次、候选 card_id（若有）及 gateway_request_id；单条流再按 attempt 和 global_message_id 隔离，不能用角色代替消息身份。

新增控制事件 `type=llm_generation_state`，`stream_type=""`。payload 包含 `state=retrying/failed`、`retract_attempt_no`、`reason_code`，retrying 另有更大的 `next_attempt_no`，候选另有 `card_id`。外层 `err_no=0` 不表示生成成功。控制类型先于正文流路由。候选控制使用认证连接和世界／地点／轮次／候选身份，不额外要求此事件携带 trigger_uid。

收到更大的 attempt 的任意正文帧时，先撤回该生成全部较小 attempt 的输出，包括已经收到单条 end 的气泡，再从空正文处理新帧。支持首帧为 chunk 或 end、跳号、同一角色多条消息和消息身份复用。已撤回尝试、单条 end 后的 chunk/start，以及明确终态后的正文不会重新创建消息。重复通知不得推进等待状态；next_attempt_no 与实际已接收 attempt 分开记录。

业务撤回立即清理正文、分片、地点消息索引及带本次来源的本地缓存，不调用删除接口。缓存保存生成来源，异步写入前重新检查是否失效；没有显式生成身份的权威历史不推断临时来源，不按复用 ID 一并删除。候选流仍不进入正式历史缓存。

HTTP V2 messages 历史项同样可携带 `gateway_request_id`、`attempt_no`。HTTP DTO、实时消息模型及本地缓存必须传递这组身份；回填进入地点队列时复用服务持有的同一 `LlmAttempt`，不能因 `stream_type` 变为空或流式结束而丢失身份。同一生成、attempt 和消息 ID 的回填保留已有文字揭露进度，完成后重复刷新不重播；真正的新 attempt 仍使用独立身份。两字段均缺省保持旧协议，部分缺失或非法值沿用 V2 校验。已撤回或落后于当前 attempt 的 HTTP 行不得重新进入实时队列或缓存。

候选卡片的本地完成组装必须保留流中已明确提供的请求与 attempt 字段，候选转展示消息时还必须包含 `card_id`，不能使用普通历史消息缺省的无卡片生成身份。候选接口两字段缺省时，可在当前轮次内按 card 与 global message ID 复用有效流的本地展示身份，以衔接已播放进度；此兜底仅用于展示，不给权威 HTTP 数据补写推断的生成字段。显式不同的生成身份不得被该兜底覆盖。

展示层可保留独立退场快照：旧气泡从下到上依次以正向两倍速度收起文字，随后将整行高度收至零；新 attempt 在退场期间只拼装，不提前展示。退场结束后，有正文则从零按正常速度播放（即使已经收到完整 end），否则显示现有三点等待气泡。具体动画见 `location-chat-bubble-design.md`。

普通流退场动画不暂停、不重置统一管理器的 5 秒流式期限；只有当前生成尝试的新有效 start／chunk 才刷新流活动。已本地超时的轮次不重新锁住发送。无展示消费者时不等待动画回执；候选同样使用统一超时释放，正常只读恢复仍保留。服务端生成重试通知不会让客户端发送新的生成、计费或取消请求。

本次不接入 generation-status HTTP 查询，也不因 `end_conversation_round` 新增历史刷新。该事件继续沿用现有轮次结束职责，不用作本次生成成功判据。服务端新字段和事件的实际启用仍需联调确认。
