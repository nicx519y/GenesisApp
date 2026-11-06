# 生图 Collect 埋点方案与字段表

适用于 Location Chat 正式回复、候选卡的拍照，以及 MiniPhone Camera 快门。`photo_generation` 是业务事件。`photo_generation_timeout` 是任务超时监控，字段沿用[现有 Collect 埋点表](mini-phone-collect-events.md#photo-generation-timeout)。

## 上报明细

表内 `w1`、`l1`、`a1`、`r1`、`t1` 分别代表 World ID、地点 ID、点击 ID、请求 ID 和任务 ID。`ext_data` 按 JSON 字符串上报。`""` 表示空字符串。Collect 自动填充 `event_id` 和 `app_timestamp`。

| 入口与情况 | `action_type` | `action` | `object1` | `object2` | `object3` | `object4` | `ext_data` |
| --- | --- | --- | --- | --- | --- | --- | --- |
| Location Chat · 点击相机按钮 | `event` | `photo_generation` | `w1` | `chat` | `click` | `a1` | `{"location_id":"l1"}` |
| Location Chat · `create` 成功受理 | `event` | `photo_generation` | `w1` | `chat` | `accepted` | `a1` | `{"location_id":"l1","client_request_id":"r1","task_id":"t1","conversation_round_id":"101","card_id":"201"}` |
| Location Chat · 生成成功 | `event` | `photo_generation` | `w1` | `chat` | `succeeded` | `a1` | `{"location_id":"l1","client_request_id":"r1","task_id":"t1","conversation_round_id":"101","card_id":"201"}` |
| Location Chat · 生成失败 | `event` | `photo_generation` | `w1` | `chat` | `failed` | `a1` | `{"location_id":"l1","client_request_id":"r1","task_id":"t1","conversation_round_id":"101","card_id":"201","failure_code":"insufficient_balance"}` |
| Location Chat · `create` 因余额不足被拒绝 | `event` | `photo_generation` | `w1` | `chat` | `rejected` | `a1` | `{"location_id":"l1","client_request_id":"r1","conversation_round_id":"101","card_id":"201","failure_code":"insufficient_balance"}` |
| MiniPhone · 点击快门 | `event` | `photo_generation` | `w1` | `camera` | `click` | `a1` | `""` |
| MiniPhone · `create` 成功受理 | `event` | `photo_generation` | `w1` | `camera` | `accepted` | `a1` | `{"client_request_id":"r1","task_id":"t1"}` |
| MiniPhone · 生成成功 | `event` | `photo_generation` | `w1` | `camera` | `succeeded` | `a1` | `{"client_request_id":"r1","task_id":"t1"}` |
| MiniPhone · 生成失败 | `event` | `photo_generation` | `w1` | `camera` | `failed` | `a1` | `{"client_request_id":"r1","task_id":"t1","failure_code":"insufficient_balance"}` |
| MiniPhone · `create` 因余额不足被拒绝 | `event` | `photo_generation` | `w1` | `camera` | `rejected` | `a1` | `{"client_request_id":"r1","failure_code":"insufficient_balance"}` |
| Location Chat · 120 秒无任务终态（现有） | `monitor` | `photo_generation_timeout` | `w1` | `chat` | `r1` | `t1` | `{"timeout_ms":120000,"location_id":"l1"}` |
| MiniPhone · 120 秒无任务终态（现有） | `monitor` | `photo_generation_timeout` | `w1` | `camera` | `r1` | `t1` | `{"timeout_ms":120000}` |

## 上报口径

- **点击与受理**。有效点击在确认弹窗前记录 `click`。取消确认时只有这条点击事件。`create` 成功返回且通过身份校验时记录 `accepted`，表示 HTTP 已受理。
- **生成结果与余额不足**。按服务端任务终态记录 `succeeded` 或 `failed`。上表的失败行以异步余额不足为例。一般生成失败携带服务端结构化 `failure_code`，缺失时省略。`create` 同步返回余额不足时记录 `rejected`，将 `3001` 和 `21001` 统一为 `insufficient_balance`。
- **扩展字段**。所有 ID 按字符串传输，未知字段省略。Location Chat 示例使用候选卡，普通正式回复省略 `card_id`，按实际请求携带 `conversation_round_id`。业务事件字段限于表中标识和结构化错误码。超时监控的 `task_id` 未知时，`object4` 为空字符串。
- **超时**。HTTP 超时沿用现有恢复流程，当下没有新增 Collect 事件。任务发出 120 秒后仍无终态时，已有监控最多上报一次。同一会话稍后收到终态时，照常记录 `succeeded` 或 `failed`。

## 关联与去重

- 每次有效点击生成独立的 `attempt_id`。首次实际发出 `create` 时绑定 `client_request_id`。手动重试各记一次点击，复用请求 ID 的受理和任务结果沿用首次提交的关联。
- 由 World 会话共用的 `PhotoGenerationMonitor` 汇总 HTTP 回包、WebSocket 推送和现有恢复查询。按来源和请求 ID 去重，推送缺少请求 ID 时用任务 ID 关联。每个请求最多记录一次受理，成功与失败合计最多一次。推送先到时，终态可早于 `accepted`。
- 返回地图、关闭手机或短暂重连后继续追踪。退出 World、切换账号或结束 App 进程时结束追踪。

## 验收用例

- 两个入口分别核对点击、取消确认、受理、生成成功、生成失败和余额不足的字段。Location Chat 分别覆盖正式回复和候选卡。
- 覆盖推送先到、缺少请求 ID、重复推送、同请求重试和恢复查询。核对受理与终态各自去重。
- 核对 HTTP 超时、120 秒任务超时、超时后的迟到终态，以及退出 World 后收到旧结果的事件数量。
