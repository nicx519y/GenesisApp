# LocationChat Send 统一超时兜底与监控

共用实现入口：`lib/network/chat_send_gate.dart`（`ChatSendGate`）；`lib/network/chatroom/location_chat_send_gate.dart` 保留 LocationChat 类型别名与导出兼容。正式 App 由 `AppServices.chatSendGate` 持有账号会话级实例，World 服务、回复控制器、页面共用它。本文描述本地 Send 阻塞的截止时间，不代表服务端生成、保存、扣费或 Tick 已经完成。

## 共用实现与场景配置

LocationChat 与 MiniPhone Messages 共用 `ChatSendGate` 的期限判断、调度、前台校时、进展去重、guard 与释放回调。`ChatSendTimeoutConfig` 集中定义默认值，各场景可用 `sceneConfigs` 覆盖；`ChatSendWaitPolicy` 同时用于下一次调度、上报及释放，业务层只提供有效进展和自己的收尾回调。

LocationChat 保留账号会话级实例；MiniPhone 使用 World 手机会话持有的独立实例，避免地点 Tick 或地点操作阻塞私聊。手机的 `phone_dm_prepare`、`phone_dm` 使用普通 15／20 秒规则，不模拟流式事件。手机上报 `mini_phone_send_lock_timeout`，object2 是 char_id；LocationChat 上报字段保持不变。

手机超时仅标记 `sendReleased` 并解除本地提交／回复等待，不标记失败或成功、不自动重发。新 Send 建立新请求；旧请求以独立恢复键保留在原请求日志中，继续按原 client_request_id 查询，迟到结果不能清除新请求的 busy 或恢复其草稿。释放标记随日志保存，重开后不重新加锁；未释放记录在新进程首次识别时开始计时。同一会话内重新打开及回到前台沿用原计时。

## 计时与释放规则

| 阶段 | 起算点与有效进展 | 上报 | 本地释放 |
| --- | --- | --- | --- |
| 普通异步等待 | 本次操作开始；匹配 ACK、首次轮次绑定、保存／选卡确认等真实推进刷新最近进展时间 | 停滞 15 秒，`wait_stalled`，同操作一次 | 停滞 20 秒；不追加事件 |
| 流式输出 | 当前操作第一条有效 start 或 chunk；后续有效 start／非空新 chunk 刷新 | 停滞 5 秒，`stream_stalled`，同操作一次 | 与上报同时执行 |
| World Tick | 首次识别本次真实 Tick 锁定的时间；轮询和流消息不延长 | 总时长 60 秒，`tick_timeout`，同 Tick 一次 | 仅解除 Tick 对 Send 的本地阻塞 |

各操作独立计时，Send 取当前地点操作及同 World Tick 的阻塞并集。一个操作释放后，其他操作仍可能阻塞按钮。空输入、非叶子地点、页面未激活和权限条件继续校验，不能被超时绕过。

- 只有收到有效 start／chunk 才启用 5 秒规则。发送写入 Socket、ACK 或“仍在重试”不算开流。
- 多个角色流共用操作活动时间。单条 end 仅关闭自身，不延长其他静默角色的 5 秒期限；全部已开始的流结束后，若仍等待整轮／候选终态，则从最后一个 end 转回普通等待。
- 重复 seq、旧生成尝试、其他操作消息、心跳、无变化查询和动画帧不刷新流式期限。新生成尝试替换旧尝试的流关联；迟到旧尝试不能延长时间。
- 展示收尾属于独立普通等待。真实文字揭示进展可以刷新展示等待，但不能刷新网络流的 5 秒计时。
- Regenerate／Go On 的准备阶段交给实际请求后，准备记录停止独立计时，清理责任随实际请求转移，不会在持续正常流式输出时额外触发准备阶段的 20 秒释放。
- 后台、重连及页面重建不重新起算；重新绑定、激活和恢复前台时核对当前状态并处理绝对时间已到期的记录。同进程复用操作关联与超时标记；进程重启没有原始计时记录时，从首次识别开始。

### 进入页面后的残留锁检查

进入或重新激活 LocationChat 后，等初始消息就绪、文字揭示及布局收尾完成，在帧结束时再次读取当前状态。如果 Send 仍因回复等待或 Tick 被锁住，取最后一条实际展示的消息（排除 AI 内容说明行）：

- **普通消息**：没有已有操作记录的残留回复等待，登记为 `conversation_wait`，从首次识别时按无进展 15 秒预警、20 秒释放。渲染历史消息不等于收到流 start／chunk，不启动 5 秒计时。
- **Tick 消息**：残留等待接入同 World 的 `tick` 操作，60 秒上报并释放本地 Send 等待；保留真实 Tick 推进状态。
- 已存在的发送、流式、Regenerate／Go On 或 Tick 操作继续沿用原阶段与时间，不按最后消息覆盖它们，不额外叠加计时器。重新进入不重置计时；正常完成提前结束恢复等待；旧恢复回调不能清除后来发起的回复操作。
- 空输入、未激活、非叶子地点等资格条件不触发恢复计时。原来进入页面即刻结束孤立历史回复等待的行为，已改为上述统一计时。

## 身份历史、活动集合与资源所有权

管理器保留两层状态：

- **身份索引**保留 `begin/find/forRound` 所需的稳定句柄、请求／轮次关联、`finished/released`、时间与标量诊断字段。同身份重绑仍返回原句柄，不能重新计时或重新锁住 Send。历史句柄到账号会话 `reset()` 才清理，本方案不设置数量上限或过期淘汰。
- **活动集合**仅包含仍承担截止时间的操作。阻塞查询、最近截止时间调度、连接进展和超时诊断的阻塞列表只遍历此集合；正常结束、超时释放或准备阶段交接立即退出。`forRound` 仍保留原历史查找行为，不宣称所有查询均与历史数量无关。
- **可释放运行时状态**承载进度去重键、打开的流、生成尝试关联、取消等待与回调。终态断开这些状态的引用，不给每个历史句柄留下空集合或永久取消 Future。诊断字段不得存放页面、正文、气泡对象或业务回调。

`guard()` 在原任务成功／失败后移除注册。正常 `finish()` 只解除本地管理，不向未返回的 ACK／正式回显抛取消异常；它们仍返回原结果。只有释放等待才返回 `ChatSendWaitReleased`，且继续接住原 Future 的迟到错误。`handoffTo()` 由实际请求接管取消传播；准备阶段即使先执行 `finally/finish()`，仍在返回的等待也能接到实际请求的释放。实际请求正常结束或失败后，不保留准备阶段回调。

`onRelease()` 返回可重复调用的取消订阅函数，已释放操作仍立即通知。页面、服务和回复控制器各自使用 `ChatSendReleaseScope` 管理所属监听，销毁或更换绑定时清除；仅隐藏页面继续保留业务等待。连接代次失效及正式回显等待的清理归服务持有，不依赖页面 Toast／状态监听。正式回显等待结束不阻止迟到消息继续进入原地点队列。

共享流式动画的 `onProgress()` 只在实际揭示量变化时发出无参数通知；页面调用展示操作的 `presentationProgress()`。它仅更新时间，不记录气泡或逐帧键，也不能刷新网络流的 5 秒期限。网络重复帧、乱序和 attempt 过滤保留原行为。

释放采用快照和身份检查，允许回调结束其他操作、取消其他订阅或重置账号；重置期间不登记新活动操作，旧一轮通知不能继续触发新会话中的页面回调。同一次 Tick 超时后仍复用释放标记，只有真实完成后下一次 Tick 才创建新身份。

**边界：本次消除已结束操作的重资源引用及调度对历史数量的依赖，不将全部历史记录数量变为有界。** 原网络 Future、当前活动操作和仍显示在页面上的内容各自保留正常生命周期；不能通过提前取消正常 ACK 或丢弃内容来降低内存。

## 正常完成、未知结果和迟到回调

解锁与本地等待展示使用同一操作身份收尾：ACK／回复等待气泡、Go On 等待行、Regenerate loading 与残留展示动画一起停止；保留已经收到的消息正文。Tick 的 Socket 事件和 World 页面推进状态统一绑定计时，60 秒释放时移除本地推进占位；重复通知／重开页面不补回旧占位，真实结束后的下一次 Tick 重新计时。MiniPhone 同时停止本人气泡发送 loading 与“正在输入／重连中”提示，旧请求继续待确认与只读恢复。旧操作的清理不得取消新请求的等待。

正常匹配的完成或明确失败立即结束阻塞。超时只表示本地等待停止：保留正文、请求／轮次／候选关联及未确认草稿，不合成成功、失败、正式 ID 或计费结果。

普通会话收到服务端 `type: error` 时，按 World、地点及请求／轮次关联立即结束该会话的本地等待：释放 Send、清理 ACK／回复 loading，并将已知回复轮次标记为失败，不再等待 5／20 秒兜底，也不记录超时事件。用户消息保留，未收到 ACK 的受理状态仍为未知，不自动重发；已有临时 AI 流内容沿用错误清理逻辑。只有能关联的会话被释放，缺少请求和轮次标识的错误、其他地点／World 及旧会话错误不会解除当前新会话的锁，独立 Tick 锁不受影响。断线等客户端传输错误不视为此终态。

若普通会话先收到 `llm_generation_state.state=failed`，同样按匹配轮次释放本地等待并通知页面移除等待气泡；不能仅正常结束操作而跳过释放回调，否则随后到达的 `type=error`（如 `2007`）可能无法再清理残留 loading。重试中的 `state=retrying` 继续等待，旧轮次失败不能移除新发送的等待气泡。

| 类型 | 超时后的处理 |
| --- | --- |
| 普通 Send／重试／初始消息／灵感发送 | 停止旧 ACK 等待，结束对应 loading；未确认受理保留为 unknown。用户可手动发起新消息，旧消息不自动补发 |
| 连接／join | 使悬挂连接任务代次失效；下一次手动操作不复用旧任务；迟到连接关闭或忽略 |
| Regenerate | 候选、部分正文及请求记录保留，`sendReleased` 解除对 Send 的阻塞；真实迟到结果继续恢复对应内容 |
| Go On | 保留未知请求和已知新轮次；不伪造成功、不回滚为明确失败，不开放自动重复请求 |
| 发送前保存／选卡确认 | 保留草稿与不确定写入记录；旧任务不能继续发送消息、补发保存／选卡或把未确认内容当成已应用；新 Send 不等待超时任务 |
| Inspiration 请求／操作准备 | 失去继续提交后续步骤的资格，取消该来源的展示请求关联；保留已有草稿／缓存 |
| 动画与展示 | 结束对应本地等待效果，保留已收内容，并同步动作、展示与 prepared entry 快照 |
| Tick | 真实 `inputBlocked`／推进状态、查锁和避免重复推进的限制保留；解除本次 Tick 对 Send 的本地限制并移除本地等待占位 |

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
| `conversation_wait` | 服务端主动轮次／收到的普通流，或进入页面渲染后补登记的普通回复残留等待，没有匹配的本地 Send 请求 | `awaiting_stream`、`streaming`、`awaiting_terminal` | `round_id`；没有本地请求时不填 `client_msg_id`；入口恢复另有 `recovered_on_entry` 等字段 |
| `regenerate` | Regenerate 请求和候选流／终态等待 | `waiting`、`awaiting_stream`、`streaming`、`awaiting_terminal` | `client_msg_id` 为重新生成请求；`round_id` 为来源轮次；`card_id` 为已知候选 ID |
| `go_on` | Go On 请求及新轮次输出 | `waiting`、`awaiting_stream`、`streaming`、`awaiting_terminal` | `client_msg_id` 为 Go On 请求；`source_round_id` 为来源轮次；新轮次绑定后 `round_id` 指向新轮次 |
| `inspiration` | 打开灵感所需连接、来源确认、额度检查、缓存／生成请求 | `preparing` | `reply_action=inspiration`；不记录返回的建议文本 |
| `reply_prepare` | Regenerate／Go On／Edit 的连接与前置准备 | `preparing` | `reply_action=regenerate/goOn/edit`，指出具体入口；交接后不再独立阻塞 |
| `reply_presentation` | 剩余文字揭示、切卡及等待效果尚未结束 | `displaying` | `operation_id` 含展示轮次／卡片／等待位置操作身份；不含正文 |
| `tick` | 首次识别 World 推进锁，或渲染后补登记末条 Tick 对应的残留等待 | `waiting` | `object2=''`；同 World 页面共享操作 ID，不按地点重复上报；入口恢复带 `recovered_on_entry=true`、`last_message_type=tick` |

关联字段仅在实际获取后出现，不用 0 或虚构 ID 补齐。操作 ID 是客户端诊断身份，不是服务端幂等键。

### ext_data 字段

| 字段 | 类型 | 含义 |
| --- | --- | --- |
| `operation_id` | string | 当前超时操作的稳定身份；页面重建及重复回调沿用它 |
| `phase` | string | 当前技术等待阶段，含义见下表；与业务场景分开 |
| `reason` | string | 固定三种原因，见后表 |
| `locked_duration_ms` | int | 本操作开始至上报的总毫秒数，与 `object4` 数值相同 |
| `idle_duration_ms` | int | 距离最近有效进展的毫秒数；普通等待和流式据此判断 |
| `report_after_ms` | int | 本次上报阈值：普通 15000、流式 5000、Tick 60000 |
| `release_after_ms` | int | 本阶段释放阈值：普通 20000、流式 5000、Tick 60000 |
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
| `recovered_on_entry` | bool，可缺省 | `true` 表示该操作包含页面渲染完成后补登记的残留等待 |
| `last_message_type` | string，可缺省 | 入口恢复时最后实际消息的分类：`ordinary` 或 `tick`；与流式阶段无关 |
| `last_message_id` | string，可缺省 | 普通入口恢复等待对应的最后消息本地稳定 ID，不含正文；World 级 Tick 不填地点消息 ID，避免跨地点覆盖 |

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
| `wait_stalled` | 普通等待连续无进展 15 秒 | 否，继续等到无进展 20 秒 | 本操作只报一次，即使之后重新进入普通等待 |
| `stream_stalled` | 有效流活动中断 5 秒 | 是 | 本操作一次；之后迟到消息不重报 |
| `tick_timeout` | 本次 World Tick 锁定满 60 秒 | 仅释放对 Send 的本地阻塞 | 同 World、同次 Tick 一次 |

同一操作先发生 `wait_stalled`，后来成功开流又中断，可以再报一条 `stream_stalled`。不要将两条事件算成两次请求。建议以账号会话、World、Location、`operation_id` 聚合操作；按 `reason` 区分等待预警与实际释放。`object4` 可能大于阈值（此前有进展、后台挂起或主线程延迟），它不等于 `idle_duration_ms`。

普通等待 20 秒释放没有额外 collect 事件，所以不能只凭 `wait_stalled` 事件推断已经释放或请求最终失败。监控本身也不保证整个 Send 按钮可用。

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

同日追加“进入页面渲染后残留锁恢复”：350 项服务相关测试、10 项相关页面测试及修改范围静态检查通过。新增覆盖普通／Tick 分支、重建保留截止时间、真实完成提前结束、独立 Tick 不被展示完成清除、已有流式 5 秒计时不被覆盖、collect 字段及释放后实际手动发送。本次追加改动未另做真机验收。


### 2026-10-28 等待记录资源修复验证

- 实施前本地检查点：`b557a79a3712c127e65cc7716a19092fbdbb58e4`。包含当时已有代码、文档、测试及相关新增源文件；未推送。资源修复形成后续独立提交，回退只需撤销修复提交，保留此检查点，不执行工作区硬重置。
- 主范围修复前为 **748 通过、31 失败**。流式组件另在检查点源码的临时副本补跑，结果 **36 通过、2 失败**。合并基线共 **784 通过、33 失败**。
- 最终相同合并范围为 **809 通过、33 失败**，新增 **25** 项用例均通过；失败名称逐项一致，原断言未放宽。相关修改的 18 个 Dart 源码／测试文件静态检查通过。
- 资源测试连续结束 10,000 次操作：活动数、进度状态、去重键、回调、取消等待及截止计时器均为零，保留 10,000 个身份句柄；新增一个活动操作时调度只扫描一个。100,000 次展示进度通知不积累进度键，也不延长网络流期限。
- 异步测试覆盖正常结束先于 ACK、迟到成功／失败、超时后原 Future 报错、同步 Future、准备交接及提前 finally、重复结束、释放中取消订阅、重置／销毁／创建操作、Tick 重置隔离。服务及页面测试覆盖页面隐藏／销毁、ACK 前后销毁、独立连接清理、无页面监听时的回显等待清理及迟到入队、控制器销毁后的迟到保存失败。
- Flutter 测试 VM 堆快照：10,000 个历史句柄保留时，活动快照含 1 个真实共享动画 `_StreamRecord`、1 个进度状态、1 个取消状态、1 个回调注册，以及各 1 个模拟页面／进度对象。操作结束并卸载动画组件、GC 后，上述实例及 guard／guard 结果对象均为 0，`ChatSendOperation` 仍为 10,000。此为受控组件与模拟回调对象验证，不是生产真机整体内存验收。快照和临时实验代码未纳入提交。
- **待验收：** 本次未运行真机测试环境的连续聊天、地点切换、前后台及断网恢复，也未执行真实后端故障注入。不能沿用 10 月 27 日的真机结果作为本修复验收。

回归范围（从 `genesis_app/` 执行）：

```sh
flutter test --no-pub test/network/chatroom \
  test/components/chat_streaming_effects_test.dart \
  test/components/chat_stream_retraction_test.dart \
  test/components/location_chat_candidate_promotion_test.dart \
  test/components/location_chat_http_backfill_test.dart \
  test/components/location_chat_send_promotion_test.dart \
  test/pages/chat/location_chat_page_test.dart --reporter json
```

#### 检查点既有失败清单

以下记录失败断言／现象，不将未定位的问题归因为本次修复。主范围前后均有 31 项，补充流式组件范围前后均有 2 项。

| 用例名称 | 检查点失败表现 |
| --- | --- |
| only feature 2030 bypasses global reply-action toast; auth remains global | 全局 Toast 预期 3 次，实际 0 次。 |
| card HTTP keeps global login and server error toast rules including unknown codes | 全局 Toast 预期 1 次，实际 0 次。 |
| character avatar opens World MiniPhone chat (card: false) | Widget 销毁后仍有待执行 Timer。 |
| character avatar opens World MiniPhone chat (card: true) | Widget 销毁后仍有待执行 Timer。 |
| regenerate marks a bubble read when it starts entering viewport prepared=false | 已读集合缺少末条候选消息 90503。 |
| regenerate marks a bubble read when it starts entering viewport prepared=true | 已读集合缺少末条候选消息 90503。 |
| reopened database renders last browsed card in the first frame | 首帧找不到选卡计数 `2 / 3`。 |
| a Tick waits for in-flight Regenerate while retiring its controls | Tick 期间仍能找到 Regenerate 渐变控件。 |
| a Tick waits for in-flight Go on while retiring its controls | 回复动作状态预期 idle，实际 none。 |
| prepared entry first frame includes ordinary and supported idle toolbar before join | 首帧动作状态预期 idle，实际 disabled。 |
| prepared entry first frame includes candidates and supported idle toolbar before join | 首帧动作状态预期 idle，实际 disabled。 |
| prepared entry first frame includes confirmed and supported idle toolbar before join | 首帧动作状态预期 idle，实际 disabled。 |
| join failure releases reply recovery busy state | 无法找到可点击的 Go on 控件。 |
| prepared entry preserves live candidate chunk rendering | 找不到预期的 Live prepared candidate 正文。 |
| location chat keeps programmatic positioning in its coordinator | 源码结构断言仍要求页面内含 `_LocationChatKeyboardInsetLayoutState`。 |
| feature quota zero edit still opens and submits after repeated clicks | `pumpAndSettle` 超时。 |
| feature quota save rejection retains draft and presents one toast | `pumpAndSettle` 超时。 |
| Go on keeps the selected card through ACK and formal history | 找不到轮次 301／卡片 401 的 Go on 控件。 |
| regenerated card send keeps live rows during successful range refresh | 等待页面状态达到预期超时，候选展示仍未完成。 |
| regenerated card send keeps live rows during failed range refresh | 等待页面状态达到预期超时，候选展示仍未完成。 |
| regenerated card send keeps live rows during successful range refresh started mid-stream | 等待页面状态达到预期超时，候选展示仍未完成。 |
| inspiration result and loading reuse the message projection | 消息投影复用断言预期 true，实际 false。 |
| composer send hides buttons immediately while their height collapses | 找不到预期的 ACK loading dots。 |
| ACK timeout retains unknown bubble without automatic resend | 等待页面状态达到预期超时。 |
| ACK loading is released by the unified ordinary deadline | 布局尺寸预期 206.0，实际约 167.7。 |
| a synchronous send failure is still recorded once | 预期 2 条分析事件，实际 1 条。 |
| Opening balance rejection keeps a failed bubble | 找不到预期的用户失败气泡。 |
| Regular balance rejection keeps a failed bubble | 找不到预期的用户失败气泡。 |
| location chat renders structured and plain enter timeline events | 找不到预期的 Alice 文本。 |
| location chat projects one V2 tick into one composite card | Tick 卡片中仍能找到不应出现的 location-current 文本。 |
| location chat renders a positive-cursor tick without a typed payload | 找不到 `Tick 0 · Recovered fallback Tick` 文本。 |
| characters_moved routes streaming prose through the common animation | 流式高度预期大于 92.0，实际 92.0。 |
| streaming layout preserves scroll intent (reading history: false) | 滚动位置预期 1250.0，实际 1130.0。 |
