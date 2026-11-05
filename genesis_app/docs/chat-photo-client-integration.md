# LocationChat 聊天生图（2026-11-04）

依据《聊天生图客户端对接-20261104-更新版》。LocationChat 与 MiniPhone Camera 使用独立接口和确认偏好；MiniPhone 规则见 [相机接入](mini-phone-camera-integration.md)。本次交互更新按用户确认的新契约执行。客户端实现和受控测试不等于真实后端、费用或设备验收。

## 协议与实现入口

- `lib/network/chatroom/chatroom_http_api.dart`：GET `/aitown-chat/api/v1/message/photo/price` 返回整数 `price_cent`；POST `/aitown-chat/api/v1/message/photo/create` 仅发送 `client_request_id/world_id/location_id`。复用认证、Gateway 签名、会话失效与余额错误拦截。
- `chat_photo.dart`：共享 photo/receipt/request/target 模型。创建响应 `data.photo`，V2/WS `payload.photo`，World History 顶层 `photo`。ID 只接受整数或十进制整数字符串，不经过浮点数。
- `chat_photo_events.dart`、`world_chatroom_photos.dart`：独立 `live_photo` 消息和 `phone.photo.result`（仅 `source=chat`）。以地点消息 ID 合并，以 task ID 关联提前结果；请求键允许为空。终态不回退为 generating；保留原位置、时间，不创建普通回复候选或等待锁。
- `chat_photo_request_store.dart`：按环境、账号、World、地点隔离未确认请求及活跃任务。原请求参数原样保存；活跃任务保留轮次和正式消息身份，独立于有界聊天缓存。受理后允许下一次拍照。
- `location_chat_photos.dart`：询价、确认、提交、失败展示周期、历史恢复与通知定位；`location_chat_photo_visibility.dart` 只控制显示，不删除记录、分页游标或去重身份。

## 拍照与错误处理

仅实际打开 Sheet 时异步请求 price 并通过 `formatGemCent` 填充数字；尚未返回时显示占位，不阻塞 Generate。询价失败走公共提示但不禁用生成。create 不带价格字段；首张免费和实际费用由服务端决定。聊天“记住”按环境、账号保存布尔偏好（兼容已有真实价格确认记录），以后直接提交，不弹 Sheet、不请求 price；与 MiniPhone 相机及旧预览偏好隔离。

create 请求期间相机显示 busy，其余回复操作图标 disabled；请求返回恢复。受理前不插入占位。create 发出时即使用 Send 相同的锚点测量与滚动留白，不等待响应。受理后先隐藏整排 actions 图标（保留行高以避免跳动），等待本次滚动完成后照片行从零高度在 420 ms 内展开，完全展开后恢复图标；重复 HTTP/WS、状态更新和列表重建不重复入场，用户手势可打断自动滚动。 展开中的照片行保持挂载至动画结束；消息先到、请求标识稍后登记时仍补上一次入场并使行缓存失效。操作栏同方向的展开／收起不因滚动重建重启计时。超时、断线、响应损坏保留原请求；再次点击复用原键及参数，不自动重发。已记住时同样跳过 Sheet；未记住时 Sheet 显示恢复说明。旧请求日志中的价格字段在恢复时忽略。

| 错误 | 客户端处理 |
| --- | --- |
| 1001 / 2061 | 服务端用户提示，结束本次请求，不创建气泡 |
| 10001 | 公共会话失效流程，丢弃旧账号响应，不自动登录或重发 |
| 2062 | 停止原请求恢复并提示，不自动更换请求键 |
| 2070（兼容旧服务端） | 按普通业务错误提示并结束；不重新询价或自动重提 |
| 3001 / 21001 | 公共余额不足与购买面板，无本地余额预拦截 |
| generation_failed / 未知任务失败码 | failed 卡片；优先服务端 failure.message，缺失用本地化提示 |
| insufficient_balance | failed 卡片；仅本人实时 result 进入公共充值提示 |
| 未知业务错误 | 优先服务端用户文案，无文案用通用本地化错误，不展示诊断内容 |

外层 err_no=0 不代表生成成功。退款、免费资格、扣款及余额由服务端决定。

## 状态、恢复和通知

共享 `ChatImageMessage` 为照片保留固定 2:3 图片区域：generating 静态占位无虚假进度；succeeded 显示图片与 description，可打开现有查看器；failed 显示失败文案且无重生成入口。下载失败不改变任务状态。

首次进入校准发现的失败照片隐藏，包括缓存生成中随后被历史确认失败。本次实时新照片及本次确认生成中的任务随后失败继续显示；普通重建、刷新、重连不清除。离开地点、切换地点/账号重置。World History 不使用该过滤，展示三态并在现有历史同步中校准含未完成照片的驻留页。

进入、重连、回前台按已知未完成轮次读取 V2 历史；不新增任务轮询。恢复旧任务不把孤立轮次插入最新窗口。照片状态进入消息存储和历史比较。

World 会话以 event_id 去重结果弹窗，使用服务端 title/summary；只处理到达时仍在该 World 前台的实时通知。后台/离线/离开后不补弹。结果弹窗与公共余额面板串行，充值按任务去重。历史和 Inbox 阅读不弹结果/充值。

## Inbox 与定位

- `message_notification_model.dart` 独立识别 photo_succeeded/photo_failed，不当入世申请，无审核按钮。
- failed 保留正文、时间、未读点；InkWell 回调为 null，无点击语义；列表原有进入已读机制继续生效。
- succeeded 通过 `ChatPhotoTarget` 传递 location/round/chat_global_message_id，路由 World ID 来自 biz_id，obj_id 仅任务 ID。
- 已缓存目标直接识别；缺失时指定轮次确认，再从最新消息沿分页补齐连续窗口。只有相邻、无缺口的缓存段才可复用，不把孤立目标轮次拼到最新列表。
- 定位期间保护连续窗口；离开、切换账号/地点或用户手势取消。目标无法读取时提示并恢复最新聊天。
- `LocationChatAnchoredMessageList.historyRevealAlignTop` 使用布局测量的图片锚点，位于 Header 下的消息视口顶部，偏移限制在实际可滚动范围。尾部不足则真实贴底，不填充空白。定位优先于首次贴底/旧锚点；保持历史阅读状态，布局修正不重新启动动画。用户拖动取得控制后释放定位窗口保护。

## 验证入口与待联调

定向测试：`chat_photo_test.dart`、`world_chatroom_service_test.dart`（photo cases）、`location_chat_photo_visibility_test.dart`、`location_chat_photo_navigation_test.dart`、`camera_moment_confirmation_test.dart`、`world_history_latest_sync_test.dart`、`gem_balance_prompt_host_test.dart`、`widget_test.dart` 的 photo Inbox 场景。新增文案走全部目标语言翻译与 `tool/l10n/check`。

LocalMock 的报价/创建/重复键及历史仅用于本地协议验证，不提供正式服务、费用结论或模拟成功资产回退。真实后端与设备仍需验收：成功/失败推送、首张免费与扣费/退款、后台与断线恢复、多任务并行、长历史定位、图片解码后位置及手势取消。

## 初次接入本地验证记录

- 定向回归：286 项通过、1 项原有跳过；最终照片合并/长历史加载与 Inbox 场景另跑 8 项通过。
- `tool/l10n/check`：目录/指纹/生成检查通过，本地化与 Settings 共 90 项通过。旧法语桌面测试已改为核对相机 Dock 的无障碍标签，匹配现有布局。
- 扩展回归：847 项通过、1 项跳过、8 项失败。这 8 项在未修改 HEAD 的临时副本中同样失败：feature quota 错误 Toast、LLM card 全局错误 Toast、普通短消息顶部提示、历史边界替换、Tick 装饰、普通图片 OSS 尺寸，以及 World History 的账号/World 切换请求次数两个场景。没有将其计作本次功能通过。
- 修改文件静态检查和 `git diff --check` 作为最终交付检查。真实后端/设备尚未验收。

## 询价与入场交互更新验证（2026-11-04）

- Sheet 异步价格、记住偏好兼容、三字段 create、旧日志恢复、相机 busy/其他图标 disabled、照片展开和发送等待滚动专项：163 项通过。
- 照片入场/Inbox 定位、照片接口模型、World 消息合并与 MiniPhone 导航回归：262 项通过，与上一组存在重叠，不累加为独立用例数。
- 入场覆盖空列表、短列表、长列表、零高度等待、逐步展开、重复重建不重播，以及用户拖动中断；普通 Send、Go On、Regenerate 的滚动回归通过。
- 本次修改文件静态检查无问题，`git diff --check` 通过。沿用已有多语言文案，无新增翻译 key；真实后端无价格字段契约和设备动画体验仍需联调。

后续时序修正：提交时滚动、快速/慢速返回后展开、操作栏在展开期间隐藏及等待滚动回归，110 项通过；静态检查与 `git diff --check` 为本轮交付检查。

### 2026-11-05 操作栏恢复修正

原隐藏条件遍历页面保留的全部照片动画，页面切换、动画被覆盖页面暂停、消息移出展示列表时没有统一结束入场状态，旧动画会继续影响操作栏显示。现只检查当前展示照片；离开/覆盖页面、滚动上下文或等待操作重置时结束旧入场并释放准备等待；移出列表的照片不再阻止图标恢复。同请求重试替换准备记录前也会释放原等待。

新增切页返回、页面覆盖返回、消息移除三个回归场景，修复前切页返回用例可复现隐藏状态残留；相关照片/操作栏/等待滚动测试 113 项通过，修改文件静态检查及 `git diff --check` 通过。尚未进行真实设备验收。
