# LocationChat Send 统一超时兜底与监控

实现入口：`lib/network/chatroom/location_chat_send_gate.dart`。正式 App 由 `AppServices.chatSendGate` 持有账号会话级实例，World 服务、回复控制器、页面共用它。本文描述本地 Send 阻塞的截止时间，不代表服务端生成、保存、扣费或 Tick 已经完成。

## 计时与释放规则

| 阶段 | 起算点与有效进展 | 上报 | 本地释放 |
| --- | --- | --- | --- |
| 普通异步等待 | 本次操作开始；匹配 ACK、首次轮次绑定、保存／选卡确认等真实推进刷新最近进展时间 | 停滞 30 秒，`wait_stalled`，同操作一次 | 停滞 45 秒；不追加事件 |
| 流式输出 | 当前操作第一条有效 start 或 chunk；后续有效 start／非空新 chunk 刷新 | 停滞 5 秒，`stream_stalled`，同操作一次 | 与上报同时执行 |
| World Tick | 首次识别本次真实 Tick 锁定的时间；轮询和流消息不延长 | 总时长 60 秒，`tick_timeout`，同 Tick 一次 | 仅解除 Tick 对 Send 的本地阻塞 |

各操作独立计时，Send 取当前地点操作及同 World Tick 的阻塞并集。一个操作释放后，其他操作仍可能阻塞按钮。空输入、非叶子地点、页面未激活和权限条件继续校验，不能被超时绕过。

- 只有收到有效 start／chunk 才启用 5 秒规则。发送写入 Socket、ACK 或“仍在重试”不算开流。
- 多个角色流共用操作活动时间。单条 end 仅关闭自身，不延长其他静默角色的 5 秒期限；全部已开始的流结束后，若仍等待整轮／候选终态，则从最后一个 end 转回普通等待。
- 重复 seq、旧生成尝试、其他操作消息、心跳、无变化查询和动画帧不刷新流式期限。新生成尝试替换旧尝试的流关联；迟到旧尝试不能延长时间。
- 展示收尾属于独立普通等待。真实文字揭示进展可以刷新展示等待，但不能刷新网络流的 5 秒计时。
- Regenerate／Go On 的准备阶段交给实际请求后，准备记录停止独立计时，清理责任随实际请求转移，不会在持续正常流式输出时额外触发准备阶段的 45 秒释放。
- 后台、重连及页面重建不重新起算；重新绑定、激活和恢复前台时核对当前状态并处理绝对时间已到期的记录。同进程复用操作关联与超时标记；进程重启没有原始计时记录时，从首次识别开始。

## 正常完成、未知结果和迟到回调

正常匹配的完成或明确失败立即结束阻塞。超时只表示本地等待停止：保留正文、请求／轮次／候选关联及未确认草稿，不合成成功、失败、正式 ID 或计费结果。

| 类型 | 超时后的处理 |
| --- | --- |
| 普通 Send／重试／初始消息／灵感发送 | 停止旧 ACK 等待，结束对应 loading；未确认受理保留为 unknown。用户可手动发起新消息，旧消息不自动补发 |
| 连接／join | 使悬挂连接任务代次失效；下一次手动操作不复用旧任务；迟到连接关闭或忽略 |
| Regenerate | 候选、部分正文及请求记录保留，`sendReleased` 解除对 Send 的阻塞；真实迟到结果继续恢复对应内容 |
| Go On | 保留未知请求和已知新轮次；不伪造成功、不回滚为明确失败，不开放自动重复请求 |
| 发送前保存／选卡确认 | 保留草稿与不确定写入记录；旧任务不能继续发送消息、补发保存／选卡或把未确认内容当成已应用；新 Send 不等待超时任务 |
| Inspiration 请求／操作准备 | 失去继续提交后续步骤的资格，取消该来源的展示请求关联；保留已有草稿／缓存 |
| 动画与展示 | 结束对应本地等待效果，保留已收内容，并同步动作、展示与 prepared entry 快照 |
| Tick | 真实 `inputBlocked`／推进状态、查锁和避免重复推进的限制保留；只解除本次 Tick 对 Send 的本地限制 |

每个异步后续写入、状态清理及 finally 都必须服从原操作身份／代次。迟到旧事件不能解除新操作的锁，也不能再次加上已释放的旧锁。超时释放不等待网络、持久化或 collect 上传；服务端仍可因真实状态拒绝下一次手动请求。

## 替换范围

已移除原业务截止计时：普通整轮 Timer、旧普通流 watchdog Timer、Regenerate／Go On 的首包与生成 watchdog、ACK 展示 10 秒 Timer，以及正式回显“5 秒后查历史、再等 2 秒”的页面兜底。相关收尾入口改由统一管理器调用。

保留 ACK／HTTP 通信超时、正常错误处理、正常重连与历史同步、Tick 查锁、心跳以及纯展示／滚动调度。普通 Send（包括旁白）的 ACK 超时自动重发已取消；Regenerate／Go On 继续只发一次。超时不再先查询卡片／历史才解锁；通信层报错后的只读恢复及正常历史同步仍可继续。

## Collect 埋点表

| 字段 | 类型／固定值 | 含义 |
| --- | --- | --- |
| `action_type` | string，`chat_timeout` | 此次统一超时事件的类别 |
| `action` | string，`location_chat_send_lock_timeout` | LocationChat Send 本地阻塞超时 |
| `object1` | string，World ID | 操作所属世界 |
| `object2` | string，Location ID | 操作所属地点；World 级 Tick 固定为空字符串 |
| `object3` | string，场景代码 | **业务来源**，不会因为进入流式阶段统一改成 stream |
| `object4` | 十进制毫秒字符串 | 从该操作 `startedAt` 到本次上报的总时长；不是距离最后一个 chunk 的时长，也不是按钮所有锁的合计时长 |
| `ext_data` | JSON 字符串 | 下表定义的诊断字段；不包含聊天正文、草稿或灵感文本 |

### 每种场景的 object 与关联字段

下面所有地点级场景的 `object1=World ID`、`object2=Location ID`，`object4=本次操作总时长毫秒字符串`；只有 Tick 的 `object2` 为空。

| `object3` | 场景及起算含义 | 常见 phase | 可用关联字段／说明 |
| --- | --- | --- | --- |
| `send_connect` | 用户发送所需的连接／join 开始等待 | `connecting` | `operation_id` 标识本次连接准备；连接状态见 `connected`／`joining` |
| `initial_send` | 初始消息自动发送前的准备，或该初始消息实际发送 | `preparing`、`awaiting_ack`、`awaiting_round`、`awaiting_stream`、`streaming`、`awaiting_terminal` | 准备记录用本地消息 ID；实际发送有 `client_msg_id`，已绑定后有 `round_id`；以 `operation_id` 区分两段 |
| `send_finalize` | 手动发送之前的保存草稿、确认选卡 | `confirming`／`waiting` | `operation_id` 标识本次确认；可能覆盖多个旧轮次，因此不强制单个 `round_id` |
| `save_confirmation` | 控制器保存草稿的异步等待 | `saving`、`confirming` | `round_id` 为被编辑轮次；`card_id` 为候选 ID，正式回复时为 null |
| `send` | 普通手动 Send；同一记录覆盖 ACK、整轮及普通回复流 | `waiting`、`awaiting_ack`、`awaiting_round`、`awaiting_stream`、`streaming`、`awaiting_terminal` | `client_msg_id` 为本次发送请求；`round_id` 为关联回复轮次 |
| `retry_send` | 用户主动重试明确失败的消息 | 同 `send` | 新的 `client_msg_id`；不是 ACK 超时自动重发 |
| `inspiration_send` | 用户选择灵感后，实际发送消息及等待回复 | 同 `send` | 发送请求与轮次关联同 `send`；不记录灵感正文 |
| `conversation_wait` | 服务端主动轮次／收到的普通流，没有匹配的本地 Send 请求 | `awaiting_stream`、`streaming`、`awaiting_terminal` | `round_id`；没有本地请求时不填 `client_msg_id` |
| `regenerate` | Regenerate 请求和候选流／终态等待 | `waiting`、`awaiting_stream`、`streaming`、`awaiting_terminal` | `client_msg_id` 为重新生成请求；`round_id` 为来源轮次；`card_id` 为已知候选 ID |
| `go_on` | Go On 请求及新轮次输出 | `waiting`、`awaiting_stream`、`streaming`、`awaiting_terminal` | `client_msg_id` 为 Go On 请求；`source_round_id` 为来源轮次；新轮次绑定后 `round_id` 指向新轮次 |
| `inspiration` | 打开灵感所需连接、来源确认、额度检查、缓存／生成请求 | `preparing` | `reply_action=inspiration`；不记录返回的建议文本 |
| `reply_prepare` | Regenerate／Go On／Edit 的连接与前置准备 | `preparing` | `reply_action=regenerate/goOn/edit`，指出具体入口；交接后不再独立阻塞 |
| `reply_presentation` | 剩余文字揭示、切卡及等待效果尚未结束 | `displaying` | `operation_id` 含展示轮次／卡片／等待位置操作身份；不含正文 |
| `tick` | 首次识别 World 推进锁 | `waiting` | `object2=''`；同 World 页面共享操作 ID，不按地点重复上报 |

关联字段仅在实际获取后出现，不用 0 或虚构 ID 补齐。操作 ID 是客户端诊断身份，不是服务端幂等键。

### ext_data 字段

| 字段 | 类型 | 含义 |
| --- | --- | --- |
| `operation_id` | string | 当前超时操作的稳定身份；页面重建及重复回调沿用它 |
| `phase` | string | 当前技术等待阶段，含义见下表；与业务场景分开 |
| `reason` | string | 固定三种原因，见后表 |
| `locked_duration_ms` | int | 本操作开始至上报的总毫秒数，与 `object4` 数值相同 |
| `idle_duration_ms` | int | 距离最近有效进展的毫秒数；普通等待和流式据此判断 |
| `report_after_ms` | int | 本次上报阈值：普通 30000、流式 5000、Tick 60000 |
| `release_after_ms` | int | 本阶段释放阈值：普通 45000、流式 5000、Tick 60000 |
| `timeout_basis` | string | `idle` 表示无进展时长；Tick 为 `elapsed`，表示总锁定时长 |
| `blockers` | array<object> | 上报瞬间的有效阻塞快照，每项含 `operation_id/scene/phase`；地点事件包含本地点和 World Tick，Tick 事件包含该世界各地点 |
| `foreground` | bool | 上报时管理器记录的前台状态 |
| `resume_count` | int | 本管理器观察到的 resumed 次数，供前后台问题排查 |
| `connected` | bool，可缺省 | 最近一次服务状态中的连接状态；不能证明链路可达 |
| `joining` | bool，可缺省 | 最近一次服务状态是否正在 join |
| `joined_location_id` | string，可缺省 | 最近一次服务状态已加入的地点，未加入为空 |
| `client_msg_id` | string，可缺省 | Send／Regenerate／Go On 请求关联 ID |
| `round_id` | string 或 int，可缺省 | 当前已关联轮次；消费端应按字符串规范化，避免大整数精度损失 |
| `source_round_id` | int，可缺省 | Go On 的来源轮次 |
| `card_id` | int 或 null，可缺省 | 候选卡身份；正式编辑没有候选卡时为 null |
| `gateway_request_id` | string，可缺省 | 有效 V2 流携带的生成请求身份 |
| `global_message_id` | int，可缺省 | 最近有效流消息的全局消息 ID；不含正文 |
| `generation_key` | string，可缺省 | 客户端生成尝试分组键，用于区分轮次、请求及候选 |
| `attempt_no` | int，可缺省 | 当前有效生成尝试编号 |
| `reply_action` | string，可缺省 | 操作准备／灵感请求对应的入口名称 |

| phase | 含义 |
| --- | --- |
| `waiting` | 已建立操作，等待初始进展；Tick 保持此阶段 |
| `connecting` | 连接或 join 准备 |
| `preparing` | 初始消息、灵感或回复操作的前置准备 |
| `saving` | 保存编辑草稿 |
| `confirming` | 发送前确认，或保存后继续确认 |
| `awaiting_ack` | 已写入发送请求，等待匹配 ACK |
| `awaiting_round` | Send ACK 已到，尚待正式轮次关联 |
| `awaiting_stream` | 已有轮次／请求接受信息，等待有效流消息 |
| `streaming` | 至少一个有效流尚未结束，使用 5 秒停滞规则 |
| `awaiting_terminal` | 全部已开始的流结束，仍等待整轮／候选终态 |
| `displaying` | 网络阶段之外的展示收尾 |

### reason、去重与统计口径

| reason | 触发点 | 上报后是否释放 | 去重 |
| --- | --- | --- | --- |
| `wait_stalled` | 普通等待连续无进展 30 秒 | 否，继续等到无进展 45 秒 | 本操作只报一次，即使之后重新进入普通等待 |
| `stream_stalled` | 有效流活动中断 5 秒 | 是 | 本操作一次；之后迟到消息不重报 |
| `tick_timeout` | 本次 World Tick 锁定满 60 秒 | 仅释放对 Send 的本地阻塞 | 同 World、同次 Tick 一次 |

同一操作先发生 `wait_stalled`，后来成功开流又中断，可以再报一条 `stream_stalled`。不要将两条事件算成两次请求。建议以账号会话、World、Location、`operation_id` 聚合操作；按 `reason` 区分等待预警与实际释放。`object4` 可能大于阈值（此前有进展、后台挂起或主线程延迟），它不等于 `idle_duration_ms`。

普通等待 45 秒释放没有额外 collect 事件，所以不能只凭 `wait_stalled` 事件推断已经释放或请求最终失败。监控本身也不保证整个 Send 按钮可用。

上报调用 `GenesisTelemetry.collectLog`，沿用既有 collect 持久队列和上传重试。入队／上传异常不影响释放。上传重试的事件 ID 去重属于既有 collect 层；操作超时去重属于管理器，两者不可混淆。

## 验收边界

自动化用例覆盖时间边界、开流阶段、重复帧、多角色、新旧尝试、准备交接、Tick 共享、迟到写入隔离以及页面释放后手动发送。断网与后台恢复真机验收结果应单独记录，不能用单元测试或旧版本设备运行替代。

### 2026-10-27 本次验证

- 管理器、聊天室服务、回复控制器与客户端：346 项测试通过。
- 此次新增及直接相关的页面回归：8 项通过，包含超时后的下一次手动发送、页面重建和已释放操作隔离。
- 完整 LocationChat 页面测试：231 项通过、29 项失败。独立原始基线为 230 项通过、29 项失败；逐项对比后，失败项一致（两项测试随新规则改名），没有新增失败项。共享组件的两项失败也在独立基线上复现。这些既有失败仍待处理，不能将本次结果表述为全套回归通过。
- 本次修改相关的服务、控制器、页面、共享组件和测试静态检查通过。
- Pixel 6 安装并运行本次 production release，进入 LocationChat 后关闭 Wi-Fi 与移动数据、退到后台超过 45 秒，再返回并恢复两种网络；应用仍位于聊天室，输入框可用。设备网络已恢复到验收前状态。
- 真机检查仅证明断网／后台返回的页面恢复冒烟结果；没有向生产聊天室发送测试消息，也未在设备上强制制造丢 ACK、流中断或 Tick 停滞。5／30／45／60 秒阈值和迟到回调隔离由受控自动化验证，真实服务端故障注入与恢复联调尚未验收。
